"""Build the addon's self-contained, power-of-two, uncompressed RGBA skull asset."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

size = 256
im = Image.new('RGBA', (size, size))
d = ImageDraw.Draw(im)
bone = (255, 250, 220, 255)
edge = (25, 18, 12, 255)
# Join both shapes before outlining, so the jaw's top edge cannot cross the face.
silhouette = Image.new('L', (size, size))
shape = ImageDraw.Draw(silhouette)
shape.ellipse((25, 12, 231, 202), fill=255)
shape.rounded_rectangle((65, 143, 191, 244), radius=22, fill=255)
im.paste(edge, (0, 0), silhouette)
im.paste(bone, (0, 0), silhouette.filter(ImageFilter.MinFilter(21)))
d = ImageDraw.Draw(im)
d.ellipse((49, 75, 111, 139), fill=edge)
d.ellipse((145, 75, 207, 139), fill=edge)
d.polygon(((128, 129), (108, 165), (148, 165)), fill=edge)
for x in (96, 128, 160):
    d.line((x, 197, x, 235), fill=edge, width=7)
path = Path(__file__).resolve().parents[1] / 'DoesItDie' / 'Textures' / 'Skull.tga'
path.parent.mkdir(parents=True, exist_ok=True)
im.resize((64, 64), Image.Resampling.LANCZOS).save(path, compression=None)
print(path)
