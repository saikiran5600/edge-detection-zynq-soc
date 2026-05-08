from PIL import Image
import numpy as np

img = Image.open("road_lane.jpg")    
img = img.convert('L')
img = img.resize((512, 512))

pixels = np.array(img)

with open("image_data.h", "w") as f:
    f.write("#ifndef IMAGE_DATA_H\n#define IMAGE_DATA_H\n\n")
    f.write("#define IMG_WIDTH 512\n#define IMG_HEIGHT 512\n\n")
    f.write("unsigned char image_data[] = {\n")

    flat = pixels.flatten()
    for i, val in enumerate(flat):
        if i % 16 == 0:
            f.write("    ")
        f.write(f"{val}, ")
        if (i + 1) % 16 == 0:
            f.write("\n")

    f.write("\n};\n\n#endif\n")

print("Done!")