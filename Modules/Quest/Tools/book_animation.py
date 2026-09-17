"""Précalcule ouverture et page tournée : le client ne lit que des cases BLP.

Les aperçus GIF sont issus des BLP décodés, comme les images utilisées en jeu.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance
import io, math, struct, argparse, os
import numpy as np

ROOT=Path(__file__).resolve().parent.parent/'Media'/'Book'
ROOT=Path(os.environ.get('OMEGA_BOOK_OUT',str(ROOT)))
parser=argparse.ArgumentParser()
parser.add_argument('--sequence',choices=('opening','turning'))
parser.add_argument('--output',type=Path,default=ROOT)
args=parser.parse_args()
args.output.mkdir(parents=True,exist_ok=True)
SIZE=(940,650)
TILE=1024
OPEN_COUNT=24
TURN_COUNT=16
book=Image.open(ROOT/'grimoire.png').convert('RGBA').resize(SIZE,Image.Resampling.LANCZOS)
cover=Image.open(ROOT/'cover.png').convert('RGBA').resize((470,650),Image.Resampling.LANCZOS)
right=book.crop((470,0,940,650))
left=book.crop((0,0,470,650))

def ease(t): return t*t*(3-2*t)

def warp(image,quad):
    # Homographie inverse : quatre coins, aucune transparence de couverture.
    src=((0,0),(image.width,0),(image.width,image.height),(0,image.height))
    equations=[]; values=[]
    for (x,y),(u,v) in zip(quad,src):
        equations.extend(((x,y,1,0,0,0,-u*x,-u*y),(0,0,0,x,y,1,-v*x,-v*y)))
        values.extend((u,v))
    coeff=np.linalg.solve(np.array(equations),np.array(values))
    return image.transform(SIZE,Image.Transform.PERSPECTIVE,coeff,Image.Resampling.BICUBIC)

def opening(index):
    if index==OPEN_COUNT-1: return book.copy()
    p=ease(index/(OPEN_COUNT-1)); cosine=math.cos(p*math.pi)
    hinge=235+235*ease(min(1,p*2))
    depth=math.sin(p*math.pi)
    edge=hinge+470*cosine/(1-.15*depth)
    # Le bord libre vient VERS le lecteur : il est plus grand que la
    # charnière, jamais plus petit. Recul discret du livre pour tout cadrer.
    inset=34*depth
    frame=Image.new('RGBA',SIZE)
    # Page droite uniquement dans la portion découverte par la couverture.
    base=warp(right,((hinge,inset),(hinge+470,inset),(hinge+470,650-inset),(hinge,650-inset)))
    # La couverture opaque assure elle-même l'occultation de la page droite.
    frame.alpha_composite(base)
    if abs(cosine)>.005:
        if cosine>0:
            texture=cover
            quad=((hinge,inset),(edge,0),(edge,650),(hinge,650-inset))
        else:
            texture=left
            quad=((edge,0),(hinge,inset),(hinge,650-inset),(edge,650))
        texture=ImageEnhance.Brightness(texture).enhance(1-.16*math.sin(p*math.pi))
        frame.alpha_composite(warp(texture,quad))
    return frame

def turning(index):
    if index in (0,TURN_COUNT-1): return book.copy()
    p=ease(index/(TURN_COUNT-1)); c=math.cos(p*math.pi)
    frame=book.copy()
    edge=470+438*c; lift=22*math.sin(p*math.pi)
    shadow=Image.new('RGBA',SIZE);d=ImageDraw.Draw(shadow)
    # Ombre locale portée par la feuille, jamais une seconde UI superposée.
    for k in range(12,0,-1):
        x=round(edge)+k
        d.line((x,40-lift,x,606+lift),fill=(48,32,18,3*(13-k)),width=2)
    frame.alpha_composite(shadow)
    if abs(c)>.005:
        page=(right if c>0 else left).crop((12,26,450,615))
        page=ImageEnhance.Brightness(page).enhance(1-.12*math.sin(p*math.pi))
        quad=((470,26),(edge,26-lift),(edge,615+lift),(470,615)) if c>0 else ((edge,26-lift),(470,26),(470,615),(edge,615+lift))
        frame.alpha_composite(warp(page,quad))
    return frame

def blp(image,path):
    alpha=image.getchannel('A')
    matte=Image.new('RGBA',image.size,(140,110,70,255));matte.alpha_composite(image);matte.putalpha(alpha)
    stream=io.BytesIO();matte.save(stream,format='DDS',pixel_format='DXT5')
    payload=stream.getvalue()[128:]
    assert len(payload)==image.width*image.height
    header=b'BLP2'+struct.pack('<I4BII',1,2,8,7,0,image.width,image.height)
    header+=struct.pack('<16I',1172,*([0]*15))+struct.pack('<16I',len(payload),*([0]*15))
    path.write_bytes(header+bytes(1024)+payload)
    result=Image.open(path).convert('RGBA')
    assert result.size==image.size
    return result

for name,count,render,duration in (('opening',OPEN_COUNT,opening,30),('turning',TURN_COUNT,turning,30)):
    if args.sequence and name!=args.sequence: continue
    frames=[render(i).resize((TILE,TILE),Image.Resampling.LANCZOS) for i in range(count)]
    previews=[]
    for sheet in range(count//4):
        atlas=Image.new('RGBA',(2048,2048))
        for cell in range(4): atlas.alpha_composite(frames[sheet*4+cell],((cell%2)*TILE,(cell//2)*TILE))
        decoded=blp(atlas,args.output/f'{name}-{sheet+1}.blp')
        for cell in range(4):
            x,y=(cell%2)*TILE,(cell//2)*TILE
            picture=decoded.crop((x,y,x+TILE,y+TILE)).resize(SIZE,Image.Resampling.LANCZOS)
            bg=Image.new('RGBA',SIZE,'#141716')
            bg.alpha_composite(picture);previews.append(bg.convert('RGB'))
    if name=='opening':
        frames_gif=previews+list(reversed(previews))
        delays=[700]+[duration]*(count-2)+[900]+[duration]*(count-1)+[700]
    else:
        frames_gif=previews;delays=[700]+[duration]*(count-2)+[700]
    frames_gif[0].save(args.output/f'{name}-blp.gif',save_all=True,append_images=frames_gif[1:],duration=delays,loop=0)
    contact=Image.new('RGB',(940,650),'#141716')
    indices=(0,count//3,2*count//3,count-1)
    for cell,i in enumerate(indices):contact.paste(previews[i].resize((470,325)),((cell%2)*470,(cell//2)*325))
    contact.save(args.output/f'{name}-blp-preview.png')
    print(f'{name}: {count} images, {count//4} atlas BLP2 DXT5 vérifiés',flush=True)
