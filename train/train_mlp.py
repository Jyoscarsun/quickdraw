import os
import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import transforms
from torch.utils.data import Dataset, DataLoader
from PIL import Image
import glob
from sklearn.model_selection import train_test_split

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
    
    def __getitem__(self, idx):  # Fixed typo
        path, label = self.samples[idx]
        image = Image.open(path).convert("L")
        if self.transform:
            image = self.transform(image)
        return image.view(-1), label

# Collect all file paths
all_samples = []
for cls in SELECTED_CLASSES:
    files = glob.glob(os.path.join("quickdraw_data", cls, "*.png"))
    for path in files:
        all_samples.append((path, CLASS_TO_IDX[cls]))

# Split into train and val sets
train_samples, val_samples = train_test_split(all_samples, test_size=0.1, random_state=42)

transform = transforms.Compose([transforms.ToTensor(),])

train_dataset = qd(train_samples, transform=transform)
val_dataset = qd(val_samples, transform=transform)

train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True)
val_loader = DataLoader(val_dataset, batch_size=BATCH_SIZE, shuffle=False)

# -------- Multi-Layer Perceptron MODEL --------
class mlp(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(784, 64)
        self.fc2 = nn.Linear(64, 10)
    
    def forward(self, x):
        x = F.relu(self.fc1(x))
        return self.fc2(x)

model = mlp()
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
        optimizer.step()  # Fixed typo
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
