"""Marque-pages en ruban ; texte réellement tourné du bas vers le haut."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import io,struct,math,argparse
ROOT=Path(__file__).resolve().parent.parent/'Media'/'Book'
FONT=ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',34)
parser=argparse.ArgumentParser();parser.add_argument('--only');args=parser.parse_args()
for name,label,color in (('personal','Personnel',(55,84,67)),('group','Groupe',(47,66,91)),('archives','Archive',(103,65,48)),('blank','',(84,72,51)),('mj','MJ',(25,26,28))):
    if args.only and name!=args.only:continue
    im=Image.new('RGBA',(128,384))
    mask=Image.new('L',im.size);d=ImageDraw.Draw(mask)
    d.polygon(((8,4),(120,4),(120,375),(64,347),(8,375)),fill=255)
    draw=ImageDraw.Draw(im)
    for x in range(128):
        light=1+.13*math.sin(x*math.pi/128)-.25*math.exp(-abs(x-116)/8)
        draw.line((x,0,x,384),fill=tuple(int(c*light) for c in color)+(255,))
    im.putalpha(mask);draw=ImageDraw.Draw(im)
    draw.line(((9,5),(119,5),(119,372),(64,345),(9,372),(9,5)),fill=(187,161,104,190),width=2)
    for y in range(18,341,15):
        for x in (18,109):draw.line((x,y,x,y+5),fill=(213,190,137,110),width=1)
    draw.line((20,29,107,29),fill=(216,188,123,140),width=2)
    # Un seul mot tourné de 90° ; pas une pile de lettres verticales.
    text=Image.new('RGBA',(290,54));td=ImageDraw.Draw(text)
    td.text((145,27),label,font=FONT,fill='#f0dfb9',anchor='mm',stroke_width=0)
    text=text.transpose(Image.Transpose.ROTATE_90)
    im.alpha_composite(text,(37,42))
    im.save(ROOT/f'bookmark-{name}.png')
    alpha=im.getchannel('A');matte=Image.new('RGBA',im.size,(*color,255));matte.alpha_composite(im);matte.putalpha(alpha)
    # Hauteur puissance de deux pour le client ; restitution à 144 px en jeu.
    matte=matte.resize((128,512),Image.Resampling.LANCZOS)
    stream=io.BytesIO();matte.save(stream,format='DDS',pixel_format='DXT5');data=stream.getvalue()[128:]
    header=b'BLP2'+struct.pack('<I4BII',1,2,8,7,0,128,512)+struct.pack('<16I',1172,*([0]*15))+struct.pack('<16I',len(data),*([0]*15))
    (ROOT/f'bookmark-{name}.blp').write_bytes(header+bytes(1024)+data)
    checked=Image.open(ROOT/f'bookmark-{name}.blp').convert('RGBA')
    assert checked.size==(128,512) and checked.getpixel((0,0))[3]==0

# Aperçu rapproché : mêmes textures BLP, trois rubans dans l'ordre du journal.
preview=Image.new('RGBA',(210,470),'#191c19')
for i,name in enumerate(('personal','group','archives')):
    image=Image.open(ROOT/f'bookmark-{name}.blp').convert('RGBA').resize((58,156),Image.Resampling.LANCZOS)
    preview.alpha_composite(image,(76,2+i*154))
preview.convert('RGB').save(ROOT/'bookmarks-preview.png')
print('Trois rubans BLP vérifiés, texte orienté bas vers haut.')
