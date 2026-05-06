import os
from PIL import Image

def create_silhouette(image_path, size, output_path):
    img = Image.open(image_path).convert("RGBA")
    img = img.resize(size, Image.Resampling.LANCZOS)

    # Create a new image with white color and the original's alpha channel
    r, g, b, a = img.split()
    white_img = Image.new("RGBA", img.size, (255, 255, 255, 255))
    white_img.putalpha(a)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    white_img.save(output_path)

icon_source = "assets/images/app_icon.png"

resolutions = {
    "mdpi": (24, 24),
    "hdpi": (36, 36),
    "xhdpi": (48, 48),
    "xxhdpi": (72, 72),
    "xxxhdpi": (96, 96),
}

for density, size in resolutions.items():
    output_dir = f"android/app/src/main/res/drawable-{density}"
    output_path = os.path.join(output_dir, "ic_notification.png")
    create_silhouette(icon_source, size, output_path)
    print(f"Generated {output_path}")
