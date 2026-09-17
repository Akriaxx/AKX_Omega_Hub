"""Convertit les atlas en BLP2 DXT5 et produit les aperçus de contrôle."""
from pathlib import Path
from PIL import Image, ImageDraw
import io
import struct

root = Path(__file__).resolve().parent.parent / 'Media' / 'Envelope'
for stem in ('atlas-1','atlas-2','atlas-3','atlas-4','paper'):
    image = Image.open(root / f'{stem}.png').convert('RGBA')
    # Donner une couleur de papier aux texels invisibles évite les franges
    # colorées lors de la compression des blocs au bord de la silhouette.
    alpha = image.getchannel('A')
    matte = Image.new('RGBA', image.size, (180, 146, 90, 255))
    matte.alpha_composite(image)
    matte.putalpha(alpha)
    image = matte
    dds = io.BytesIO()
    image.save(dds, format='DDS', pixel_format='DXT5')
    payload = dds.getvalue()[128:]
    assert len(payload) == image.width*image.height
    header = b'BLP2' + struct.pack('<I4BII', 1, 2, 8, 7, 0, image.width, image.height)
    header += struct.pack('<16I', 1172, *([0]*15))
    header += struct.pack('<16I', len(payload), *([0]*15))
    data = header + bytes(1024) + payload
    (root / f'{stem}.blp').write_bytes(data)
    decoded = Image.open(io.BytesIO(data)).convert('RGBA')
    assert decoded.size == image.size
    assert decoded.getpixel((0, 0))[3] == 0
    decoded.save(root / ('blp-check-'+stem.replace('atlas-','')+'.png'))

frames=[]
for i in range(64):
    # L'aperçu montre les textures BLP décodées, compression comprise.
    sheet=Image.open(root / f'blp-check-{i//16+1}.png').convert('RGBA')
    x,y=(i%4)*512,((i%16)//4)*512
    image=sheet.crop((x,y,x+512,y+512))
    bg=Image.new('RGBA', image.size, '#101312')
    bg.alpha_composite(image)
    frames.append(bg.convert('RGB'))
frames[0].save(root/'opening.gif',save_all=True,append_images=frames[1:],duration=[750]+[50]*62+[1400],loop=0)
contact=Image.new('RGB',(1536,512),'#101312')
draw=ImageDraw.Draw(contact)
for col, i in enumerate((0,38,63)):
    contact.paste(frames[i],(col*512,0))
    draw.text((col*512+160,25),('01  /  SCELLEE','02  /  PLIEE EN DEUX','03  /  DEPLIEE')[col],fill='#c9b57e')
contact.save(root/'preview.png')
print('Quatre BLP2 DXT5 relus et verifies ; apercus issus des BLP generes.')
