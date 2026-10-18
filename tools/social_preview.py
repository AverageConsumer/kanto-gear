"""Render the 1280x640 GitHub social preview from the README screenshots.

Usage: python tools/social_preview.py [output]
Default output: .github/social-preview.png
Upload it under Settings > General > Social preview; committing it does not set it.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / ".github/social-preview.png"
FONTS = ROOT / "tools/hgss_font_atlas/sources"
W, H = 1280, 640
BG = (22, 28, 40)
DOTS = (32, 40, 56)
BLUE = (79, 179, 232)
WHITE = (238, 242, 247)
GRAY = (150, 164, 184)
FRAME = (10, 13, 20)

img = Image.new("RGB", (W, H), BG)
draw = ImageDraw.Draw(img)
for y in range(0, H, 24):
    for x in range((y // 24) % 2 * 12, W, 24):
        draw.point((x, y), fill=DOTS)


def text(value, font, size, scale, color, xy):
    """Draw pixel text at its native size, then scale it with nearest neighbour."""
    face = ImageFont.truetype(str(FONTS / font), size, layout_engine=ImageFont.Layout.BASIC)
    left, top, right, bottom = face.getbbox(value)
    mask = Image.new("L", (right - left + 2, bottom - top + 2), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.fontmode = "1"
    mask_draw.text((-left + 1, -top + 1), value, font=face, fill=255)
    mask = mask.resize((mask.width * scale, mask.height * scale), Image.NEAREST)
    img.paste(Image.new("RGB", mask.size, color), xy, mask)
    return mask.size


def shot(name):
    """Screenshots are 4x renders; 2x keeps every UI pixel square."""
    image = Image.open(ROOT / "screenshots" / name).convert("RGB")
    return image.resize((image.width // 2, image.height // 2), Image.NEAREST)


def framed(image, xy):
    x, y = xy
    draw.rectangle([x - 6, y - 6, x + image.width + 5, y + image.height + 5], fill=FRAME)
    img.paste(image, xy)


draw.polygon([(0, 0), (520, 0), (470, 44), (0, 44)], fill=BLUE)
draw.rectangle([56, 10, 62, 34], fill=WHITE)
text("SILPH LINK OS", "hgss_pixel.ttf", 10, 2, WHITE, (76, 10))

x = 64
_, title_height = text("Kanto Gear", "hgss_pixel.ttf", 10, 7, WHITE, (x - 6, 150))
draw.rectangle([x, 150 + title_height + 14, x + 96, 150 + title_height + 20], fill=BLUE)
text("Your adventure.", "hgss_pixel.ttf", 10, 4, WHITE, (x - 4, 290))
text("Reconnected.", "hgss_pixel.ttf", 10, 4, BLUE, (x - 4, 346))
text("Companion for Pokemon Gen 1-3", "hgss_small.ttf", 11, 2, GRAY, (x - 2, 440))
text("in Gen1Recomp", "hgss_small.ttf", 11, 2, GRAY, (x - 2, 474))
text("Android  Windows  Linux  Phone", "hgss_small.ttf", 11, 2, GRAY, (x - 2, 540))

framed(shot("4.0-home-pokegear-light.png"), (612, 70))
framed(shot("4.0-home-cgear-dark.png"), (744, 166))

OUT.parent.mkdir(parents=True, exist_ok=True)
img.save(OUT, optimize=True)
print(f"{OUT} {img.size[0]}x{img.size[1]} {OUT.stat().st_size} bytes")
