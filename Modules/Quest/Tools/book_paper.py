"""Papier des pages : grain fixe, fibres et vieillissement local des bords.

Remplace les grands dégradés horizontaux, sujets aux bandes après DXT5.
La couverture et la tranche sont conservées ; le papier rejoint le pli central.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

def build_paper(root):
    original=Image.open(root/'grimoire.png').convert('RGBA')
    width,height=original.size
    rng=np.random.default_rng(1847)
    yy,xx=np.mgrid[:height,:width]
    x=xx*940/width;y=yy*650/height
    # Les limites suivent les courbes du SVG, en conservant son filet de bord.
    left=((x>30)&(x<469.5));right=((x>470.5)&(x<910))
    u=np.where(left,(x-29)/440,(x-471)/440)
    u=np.clip(u,0,1)
    top=np.where(left,(1-u)**2*23+2*(1-u)*u*12+u*u*29,
                 (1-u)**2*29+2*(1-u)*u*12+u*u*23)
    bottom=(1-u)**2*615+2*(1-u)*u*601+u*u*615
    mask=(left|right)&(y>top+1)&(y<bottom-1)
    coarse=Image.fromarray(rng.integers(80,177,(42,64),dtype=np.uint8)).resize((width,height),Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(9))
    clouds=(np.asarray(coarse,dtype=float)-128)/15
    fine=rng.normal(0,1.35,(height,width))
    fibers=Image.fromarray(rng.integers(90,166,(360,150),dtype=np.uint8)).resize((width,height),Image.Resampling.BILINEAR)
    fibers=(np.asarray(fibers,dtype=float)-128)/35
    gutter=np.abs(x-470)
    edge=np.minimum(np.abs(x-29),np.abs(x-911))
    vertical=np.minimum(np.maximum(0,y-top),np.maximum(0,bottom-y))
    aging=13*np.exp(-edge/8)+9*np.exp(-vertical/9)
    # Creux resserré et épaule arrondie des feuilles, éclairée depuis la gauche.
    shadow=68*np.exp(-gutter/9)+24*np.exp(-gutter/31)
    shoulder=np.where(x<470,10,5)*np.exp(-((gutter-44)/23)**2)
    shadow+=np.where(x>470,7,0)*np.exp(-gutter/40)
    variation=clouds+fine+fibers-aging-shadow+shoulder
    paper=np.empty((height,width,4),dtype=np.uint8)
    for channel,(base,factor) in enumerate(((224,1.0),(210,1.05),(177,1.12))):
        paper[:,:,channel]=np.clip(base+variation*factor,0,255).astype(np.uint8)
    paper[:,:,3]=255
    # Petites fibres irrégulières, dispersées et peu contrastées.
    texture=Image.fromarray(paper)
    draw=ImageDraw.Draw(texture)
    for _ in range(3500):
        px=int(rng.integers(0,width));py=int(rng.integers(0,height))
        if mask[py,px]:
            color=tuple(max(0,int(c)-int(rng.integers(3,9))) for c in paper[py,px,:3])+(255,)
            draw.line((px,py,px+int(rng.integers(1,4)),py+1),fill=color,width=1)
    original.paste(texture,(0,0),Image.fromarray((mask*255).astype(np.uint8)))
    original.save(root/'grimoire.png')

if __name__=='__main__':
    build_paper(Path(__file__).resolve().parent.parent/'Media'/'Book')
