from pathlib import Path
from PIL import Image, ImageDraw
from blp import write_blp
import math
M=Path(__file__).resolve().parent.parent/'Media'
S=4
def line(d,pts,color,width=1):
    d.line([(round(x*S),round(y*S)) for x,y in pts],fill=color,width=round(width*S),joint='curve')
def poly(d,pts,fill,outline=None,width=1):
    d.polygon([(round(x*S),round(y*S)) for x,y in pts],fill=fill)
    if outline: line(d,pts+[pts[0]],outline,width)
gold=(217,184,115,255);pale=(232,204,145,255);bronze=(119,97,66,255)
im=Image.new('RGBA',(192*S,192*S));d=ImageDraw.Draw(im)
def vertices(r):
    return [(96+math.sin(i*2*math.pi/5)*r,96-math.cos(i*2*math.pi/5)*r) for i in range(5)]
poly(d,vertices(78),(9,15,24,245),gold,1.5)
poly(d,vertices(72),None,bronze,1)
for point in vertices(64): line(d,[(96,96),point],(157,122,64,90))
d.ellipse((73*S,73*S,119*S,119*S),fill=(7,12,20,255),outline=bronze,width=S)
im.resize((256,256),Image.Resampling.LANCZOS).save(M/'ActionPentagon.tga')
# Class insignia: a heraldic crown above a faceted diamond and laurel branches.
im=Image.new('RGBA',(64*S,64*S));d=ImageDraw.Draw(im)
poly(d,[(17,17),(22,25),(32,12),(42,25),(47,17),(43,34),(21,34)],(25,35,48,255),gold,2)
line(d,[(22,30),(42,30)],pale,1)
poly(d,[(32,37),(40,45),(32,56),(24,45)],(33,47,58,255),gold,2)
line(d,[(32,38),(32,54),(25,45),(39,45),(32,38)],bronze,1)
for side in (-1,1):
    line(d,[(32+side*12,54),(32+side*21,43),(32+side*24,28)],gold,1.5)
    for y,x in [(43,19),(36,22),(29,24)]:
        poly(d,[(32+side*x,y+5),(32+side*(x+5),y-1),(32+side*(x+4),y-7),(32+side*x,y)],(30,39,47,255),gold,1)
im=im.resize((64,64),Image.Resampling.LANCZOS)
im.save(M/'Nexus'/'IconClass.png')
write_blp(im,str(M/'Nexus'/'IconClass.blp'))
