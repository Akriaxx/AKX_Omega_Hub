"""Resolution hourglass: 48 draining frames followed by a 16-frame turn."""
from pathlib import Path
from PIL import Image, ImageDraw
import math

atlas = Image.new('RGBA', (512, 512))
for frame in range(64):
    im = Image.new('RGBA', (256, 256))
    d = ImageDraw.Draw(im)
    gold = (224, 195, 126, 255)
    dark = (9, 17, 27, 235)
    d.polygon([(76, 52), (180, 52), (164, 94), (136, 128),
               (164, 162), (180, 204), (76, 204), (92, 162),
               (120, 128), (92, 94)], fill=dark)
    t = min(1, frame / 47)
    # Similar triangles preserve sand area as it drains.
    top = 54 * math.sqrt(1-t)
    bottom = 54 * math.sqrt(t)
    if top > 0:
        d.polygon([(128-top*.72, 122-top), (128+top*.72, 122-top), (128, 122)], fill=gold)
    if bottom > 0:
        d.polygon([(128-bottom*.72, 188), (128+bottom*.72, 188), (128, 188-bottom)], fill=gold)
    if frame < 47:
        d.line([(128, 125), (128, 188-bottom)], fill=(245,221,157,255), width=3)
    for points in [[(76,52),(92,94),(128,128),(164,162),(180,204)],
                   [(180,52),(164,94),(128,128),(92,162),(76,204)]]:
        d.line(points, fill=gold, width=7, joint='curve')
    for y in (48,208):
        d.rounded_rectangle((65,y-5,191,y+5), radius=4, fill=gold)
    if frame >= 48:
        u = (frame-47)/16
        im = im.rotate(-180*(u*u*(3-2*u)), resample=Image.Resampling.BICUBIC)
    atlas.paste(im.resize((64,64), Image.Resampling.LANCZOS), ((frame%8)*64,(frame//8)*64))
atlas.save(Path(__file__).resolve().parent.parent/'Media'/'ResolutionHourglass.tga')
