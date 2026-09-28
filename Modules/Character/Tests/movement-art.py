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
    return [(96+math.sin(i*2*math.pi/6)*r,96-math.cos(i*2*math.pi/6)*r) for i in range(6)]
poly(d,vertices(78),(9,15,24,245),gold,1.5)
poly(d,vertices(72),None,bronze,1)
for point in vertices(64): line(d,[(96,96),point],(157,122,64,90))
d.ellipse((73*S,73*S,119*S,119*S),fill=(7,12,20,255),outline=bronze,width=S)
im.resize((256,256),Image.Resampling.LANCZOS).save(M/'ActionHexagon.tga')
# Winged boot: a distinct movement symbol, gold outlines on transparent canvas.
im=Image.new('RGBA',(64*S,64*S));d=ImageDraw.Draw(im)
poly(d,[(28,10),(43,12),(40,31),(43,39),(55,44),(55,51),(24,51),(20,46),(24,32)],(25,35,48,255),gold,2)
line(d,[(25,46),(52,46)],pale,1.5)
line(d,[(29,17),(40,19)],gold,2)
for y in (23,28,33): line(d,[(29,y),(36,y+1)],bronze,1.5)
poly(d,[(24,32),(8,17),(10,29),(17,36),(7,31),(13,41),(23,43)],(26,39,51,255),gold,1.5)
line(d,[(12,25),(23,38)],pale,1)
line(d,[(5,49),(15,49)],bronze,1.5)
line(d,[(9,55),(24,55)],gold,1)
im=im.resize((64,64),Image.Resampling.LANCZOS)
im.save(M/'Nexus'/'IconMovement.png')
write_blp(im,str(M/'Nexus'/'IconMovement.blp'))
