import sys
from PIL import Image

def create_silhouette(input_path, output_path):
    img = Image.open(input_path).convert("RGBA")
    data = img.getdata()

    new_data = []
    for item in data:
        # Check alpha channel. If it has opacity, make it solid white.
        if item[3] > 0:
            new_data.append((255, 255, 255, item[3])) # keep original alpha, but make white
        else:
            new_data.append(item)

    img.putdata(new_data)
    # Resize appropriately for notification icon, approx 96x96 for xhdpi usually but drawable scales
    img = img.resize((96, 96), Image.Resampling.LANCZOS)
    img.save(output_path, "PNG")
    print(f"Saved silhouette to {output_path}")

create_silhouette('assets/images/android_icon.png', 'android/app/src/main/res/drawable/ic_notification.png')
