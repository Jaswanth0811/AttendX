"""Generate Android launcher icons from AttendX Logo.png"""
import os
from PIL import Image

SRC = "AttendX Logo.png"
BASE = os.path.join("app", "src", "main", "res")

# Android mipmap sizes: (folder_suffix, icon_px, round_px)
DENSITIES = [
    ("mdpi",    48,  48),
    ("hdpi",    72,  72),
    ("xhdpi",   96,  96),
    ("xxhdpi",  144, 144),
    ("xxxhdpi", 192, 192),
]

# Foreground layer for adaptive icons (needs padding ~25% on each side)
ADAPTIVE_SIZES = [
    ("mdpi",    108),
    ("hdpi",    162),
    ("xhdpi",   216),
    ("xxhdpi",  324),
    ("xxxhdpi", 432),
]

img = Image.open(SRC).convert("RGBA")

for suffix, size, _ in DENSITIES:
    folder = os.path.join(BASE, f"mipmap-{suffix}")
    os.makedirs(folder, exist_ok=True)
    
    # Standard launcher icon
    resized = img.resize((size, size), Image.LANCZOS)
    resized.save(os.path.join(folder, "ic_launcher.png"), "PNG")
    
    # Round launcher icon (same image, Android clips it to circle)
    resized.save(os.path.join(folder, "ic_launcher_round.png"), "PNG")
    print(f"  OK mipmap-{suffix}: {size}x{size}")

# Adaptive icon foreground (logo centered on transparent bg with padding)
for suffix, size in ADAPTIVE_SIZES:
    folder = os.path.join(BASE, f"mipmap-{suffix}")
    os.makedirs(folder, exist_ok=True)
    
    # Create foreground with the logo centered (72% of adaptive size)
    fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    logo_size = int(size * 0.68)
    logo_resized = img.resize((logo_size, logo_size), Image.LANCZOS)
    offset = (size - logo_size) // 2
    fg.paste(logo_resized, (offset, offset), logo_resized)
    fg.save(os.path.join(folder, "ic_launcher_foreground.png"), "PNG")
    print(f"  OK mipmap-{suffix} foreground: {size}x{size}")

# Also save a high-res version for the Play Store (512x512)
store = img.resize((512, 512), Image.LANCZOS)
store.save(os.path.join(BASE, "..", "ic_launcher-playstore.png"), "PNG")
print("  OK Play Store icon: 512x512")

print("\nDone! All icons generated.")
