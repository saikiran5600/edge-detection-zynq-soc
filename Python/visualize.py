# visualize.py
from PIL import Image
import numpy as np

#----------------------------------------
# Step 1: Read the serial log file
#----------------------------------------
print("Reading serial output...")

with open("output_log.txt", "r") as f:
    content = f.read()

# Extract data between markers
start = content.find("===IMAGE_START===")
end   = content.find("===IMAGE_END===")

if start == -1 or end == -1:
    print("ERROR: Could not find image markers!")
    print("Make sure output_log.txt has ===IMAGE_START=== and ===IMAGE_END===")
    exit()

# Get just the image data
image_text = content[start + len("===IMAGE_START==="):end]
image_text = image_text.strip()

print("Image data found!")

#----------------------------------------
# Step 2: Parse into pixel array
#----------------------------------------
rows = image_text.split("\n")
rows = [r.strip() for r in rows if r.strip()]

print(f"Rows found: {len(rows)}")

IMG_HEIGHT = 512
IMG_WIDTH  = 512

pixels = np.zeros((IMG_HEIGHT, IMG_WIDTH), dtype=np.uint8)

for y, row in enumerate(rows):
    if y >= IMG_HEIGHT:
        break
    for x, ch in enumerate(row):
        if x >= IMG_WIDTH:
            break
        # 1 = edge (white = 255), 0 = no edge (black = 0)
        pixels[y][x] = 255 if ch == '1' else 0

print("Pixels parsed!")

#----------------------------------------
# Step 3: Save edge output image
#----------------------------------------
edge_img = Image.fromarray(pixels, mode='L')
edge_img.save("edge_output.png")
print("Saved: edge_output.png")

#----------------------------------------
# Step 4: Load original for comparison
#----------------------------------------
original = Image.open("hand.jpg")
original = original.convert('L')
original = original.resize((512, 512))
original.save("original_gray.png")
print("Saved: original_gray.png")

#----------------------------------------
# Step 5: Create side by side comparison
#----------------------------------------
comparison = Image.new('L', (IMG_WIDTH * 2 + 20, IMG_HEIGHT), color=128)
comparison.paste(original,  (0, 0))
comparison.paste(edge_img,  (IMG_WIDTH + 20, 0))
comparison.save("comparison.png")
print("Saved: comparison.png")

#----------------------------------------
# Step 6: Show all images
#----------------------------------------
print("\n=== DONE ===")
print("Files created:")
print("  original_gray.png  → your input image")
print("  edge_output.png    → edges detected by hardware")
print("  comparison.png     → side by side view")

# Open comparison image automatically
import os
os.startfile("comparison.png")