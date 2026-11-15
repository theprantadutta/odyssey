"""YouTube thumbnail for the Play Store video, made from the feature graphic.

    python store_video/tools/thumb.py

The feature graphic is 1024x500 (about 2:1) and a thumbnail is 1280x720
(16:9). Stretching would distort it and cropping would cut its edges, so it is
scaled to the full width and the strip above and below is filled with its own
background colour, with the art feathered into it. brand/feature-graphic.png
is only read.
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "brand" / "feature-graphic.png"
OUT = ROOT / "store_video" / "youtube-thumbnail-1280x720.png"
W, H = 1280, 720
FEATHER = 40

src = Image.open(SRC).convert("RGB")
scaled = src.resize((W, round(src.height * W / src.width)), Image.LANCZOS)
top = (H - scaled.height) // 2

# The graphic's own background colour, taken from its corners. A blurred copy
# of the art was tried first, but blurring the phones at the bottom edge left
# bright smudges under them.
corners = [scaled.crop(b).resize((1, 1), Image.LANCZOS).getpixel((0, 0))
           for b in [(0, 0, 40, 40), (W - 40, 0, W, 40),
                     (0, scaled.height - 40, 40, scaled.height),
                     (W - 40, scaled.height - 40, W, scaled.height)]]
fill = tuple(sum(c[i] for c in corners) // len(corners) for i in range(3))
base = Image.new("RGB", (W, H), fill)

mask = Image.new("L", scaled.size, 255)
md = ImageDraw.Draw(mask)
for i in range(FEATHER):
    a = round(255 * (i / FEATHER) ** 1.4)
    md.line([(0, i), (W, i)], fill=a)
    md.line([(0, scaled.height - 1 - i), (W, scaled.height - 1 - i)], fill=a)
base.paste(scaled, (0, top), mask)
base.save(OUT, optimize=True)
print(OUT, base.size)
