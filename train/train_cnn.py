import os
import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import transforms
from torch.utils.data import Dataset, DataLoader
from PIL import Image
import glob
from sklearn.model_selection import train_test_split
import torch.quantization as quant
import numpy as np

os.chdir("D:/Summer_25/veri-quickdraw")

# -------- CONFIG --------
SELECTED_CLASSES = ["car", "cat", "clock", "fish", "flower", "house", "smiley face", "star", "tree", "umbrella"]
CLASS_TO_IDX = {cls: i for i, cls in enumerate(SELECTED_CLASSES)}
IMG_SIZE = 28
BATCH_SIZE = 64
EPOCHS = 20

# -------- DATASET --------
class qd(Dataset):
    def __init__(self, samples, transform=None):
        self.samples = samples
        self.transform = transform

    def __len__(self):
        return len(self.samples)
    
    def __getitem__(self, idx):
        path, label = self.samples[idx]
        image = Image.open(path).convert("L")
        if self.transform:
            image = self.transform(image)
        return image, label  # CNN expects images in shape [C,H,W]

# Collect all file paths
all_samples = []
for cls in SELECTED_CLASSES:
    files = glob.glob(os.path.join("quickdraw_data", cls, "*.png"))
    for path in files:
        all_samples.append((path, CLASS_TO_IDX[cls]))

# Split into train and val sets
train_samples, val_samples = train_test_split(all_samples, test_size=0.1, random_state=42)

transform = transforms.Compose([transforms.ToTensor()])

train_dataset = qd(train_samples, transform=transform)
val_dataset = qd(val_samples, transform=transform)

train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True)
val_loader = DataLoader(val_dataset, batch_size=BATCH_SIZE, shuffle=False)

# -------- CNN MODEL --------
class cnn(nn.Module):
    def __init__(self):
        super().__init__()
        self.conv1 = nn.Conv2d(1, 16, 3, stride=1, padding=1)
        self.relu1 = nn.ReLU()
        self.pool1 = nn.MaxPool2d(2, 2)

        self.conv2 = nn.Conv2d(16, 32, 3, stride=1, padding=1)
        self.relu2 = nn.ReLU()
        self.pool2 = nn.MaxPool2d(2, 2)

        self.fc1 = nn.Linear(32 * 7 * 7, 128)
        self.relu3 = nn.ReLU()
        self.fc2 = nn.Linear(128, 10)

        # Quantization stubs
        self.quant = quant.QuantStub()
        self.dequant = quant.DeQuantStub()

    def forward(self, x):
        x = self.quant(x)
        x = self.pool1(self.relu1(self.conv1(x)))
        x = self.pool2(self.relu2(self.conv2(x)))
        x = x.reshape(x.size(0), -1)
        x = self.relu3(self.fc1(x))
        x = self.fc2(x)
        x = self.dequant(x)
        return x

model = cnn()
optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
criterion = nn.CrossEntropyLoss()

# -------- TRAIN --------
for epoch in range(EPOCHS):
    model.train()
    total_loss = 0
    for x, y in train_loader:
        optimizer.zero_grad()
        out = model(x)
        loss = criterion(out, y)
        loss.backward()
        optimizer.step()
        total_loss += loss.item()
    
    # -------- VALIDATE --------
    model.eval()
    correct, total = 0, 0
    with torch.no_grad():
        for x, y in val_loader:
            out = model(x)
            preds = out.argmax(dim=1)
            correct += (preds == y).sum().item()
            total += y.size(0)
    
    accuracy = 100. * correct / total
    print(f"Epoch {epoch+1}: Loss = {total_loss:.4f}, Validation Accuracy = {accuracy:.2f}%")

# -------- POST-TRAINING STATIC QUANTIZATION --------
model.eval()
model.qconfig = quant.get_default_qconfig('fbgemm')
quant.prepare(model, inplace=True)

# Calibration with a few batches from train loader
with torch.no_grad():
    for i, (x, y) in enumerate(train_loader):
        model(x)
        if i >= 10:  # calibrate on 10 batches
            break

quant.convert(model, inplace=True)

# Evaluate quantized model
correct, total = 0, 0
with torch.no_grad():
    for x, y in val_loader:
        out = model(x)
        preds = out.argmax(dim=1)
        correct += (preds == y).sum().item()
        total += y.size(0)

quant_accuracy = 100. * correct / total
print(f"Quantized model Validation Accuracy = {quant_accuracy:.2f}%")

# After quantization, access weights and biases like this:
conv1_w = model.conv1.weight().int_repr().numpy()
conv1_scale = model.conv1.scale 
conv1_bias = model.conv1.bias()  # Note: this is now a function call
conv1_b = (conv1_bias.detach().numpy() / conv1_scale).round().astype(np.int32)

conv2_w = model.conv2.weight().int_repr().numpy()
conv2_scale = model.conv2.scale
conv2_bias = model.conv2.bias()
conv2_b = (conv2_bias.detach().numpy() / conv2_scale).round().astype(np.int32)

fc1_w = model.fc1.weight().int_repr().numpy()
fc1_scale = model.fc1.scale
fc1_bias = model.fc1.bias()
fc1_b = (fc1_bias.detach().numpy() / fc1_scale).round().astype(np.int32)

fc2_w = model.fc2.weight().int_repr().numpy()
fc2_scale = model.fc2.scale
fc2_bias = model.fc2.bias()
fc2_b = (fc2_bias.detach().numpy() / fc2_scale).round().astype(np.int32)

def write_mif(filename, array, depth=None, width=None):
    """
    Write 1D or 2D numpy int array to a .mif file.
    depth = number of memory words (default = array size)
    width = bits per word (default = 8 * bytes per element)
    """
    array = array.flatten()
    depth = depth or len(array)
    width = width or (array.itemsize * 8)
    
    with open(filename, 'w') as f:
        f.write(f"DEPTH = {depth};\n")
        f.write(f"WIDTH = {width};\n")
        f.write("ADDRESS_RADIX = HEX;\n")
        f.write("DATA_RADIX = HEX;\n")
        f.write("CONTENT BEGIN\n")
        
        for i, val in enumerate(array):
            # convert val to unsigned hex if needed (e.g. for int8 convert to 2's complement hex)
            if val < 0:
                val = (1 << width) + val  # 2's complement
            f.write(f"{i:04X} : {val:0{width//4}X};\n")
        
        f.write("END;\n")

write_mif("conv1_w.mif", conv1_w)
write_mif("conv1_b.mif", conv1_b)
write_mif("conv2_w.mif", conv2_w)
write_mif("conv2_b.mif", conv2_b)
write_mif("fc1_w.mif", fc1_w)
write_mif("fc1_b.mif", fc1_b)
write_mif("fc2_w.mif", fc2_w)
write_mif("fc2_b.mif", fc2_b)