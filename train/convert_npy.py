import os
import numpy as np
from PIL import Image

# -------- SETTINGS --------
os.chdir("D:\Summer_25\\veri-quickdraw")
SELECTED_CLASSES = ["car", "cat", "clock", "fish", "flower", "house", "smiley face", "star", "tree", "umbrella"]
SOURCE_DIR = "./npy"  # Directory with .npy files like full_numpy_bitmap_cat.npy
DEST_DIR = "./quickdraw_data"  # Where to save the PNGs
SAMPLES_PER_CLASS = 1000  # Adjust for memory constraints

# -------- PROCESS --------
os.makedirs(DEST_DIR, exist_ok=True)

for cls in SELECTED_CLASSES:
    print(f"Processing {cls}...")
    class_dir = os.path.join(DEST_DIR, cls)
    os.makedirs(class_dir, exist_ok=True)

    npy_path = os.path.join(SOURCE_DIR, f"full_numpy_bitmap_{cls}.npy")
    data = np.load(npy_path, allow_pickle=True)
    
    for i, img_array in enumerate(data[:SAMPLES_PER_CLASS]):
        img = Image.fromarray((255 - img_array.reshape(28, 28)).astype(np.uint8))  # Invert so black = drawing
        img.save(os.path.join(class_dir, f"{i}.png"))

print("Done")
