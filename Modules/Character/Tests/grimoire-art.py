"""Diamond menu plate and matching gold/blue-grey book icon."""
from pathlib import Path
from PIL import Image, ImageDraw
from blp import write_blp

MEDIA=Path(__file__).resolve().parent.parent/'Media'
S=4
def polygon(d,points,fill,outline=None,width=1):
    points=[(int(x*S),int(y*S)) for x,y in points]
    d.polygon(points,fill=fill)
    if outline: d.line(points+[points[0]],fill=outline,width=int(width*S),joint='curve')
def line(d,points,fill,width=1):
    d.line([(int(x*S),int(y*S)) for x,y in points],fill=fill,width=int(width*S),joint='curve')

im=Image.new('RGBA',(172*S,172*S));d=ImageDraw.Draw(im)
polygon(d,[(86,6),(166,86),(86,166),(6,86)],(9,15,24,245),(194,160,94,255),1.5)
polygon(d,[(86,14),(158,86),(86,158),(14,86)],None,(119,97,66,200))
for x,y in [(86,22),(150,86),(86,150),(22,86)]:
    line(d,[(86,86),(x,y)],(157,122,64,90))
d.ellipse((63*S,63*S,109*S,109*S),fill=(7,12,20,255),outline=(184,153,96,255),width=4)
im.resize((256,256),Image.Resampling.LANCZOS).save(MEDIA/'ActionDiamond.tga')

im=Image.new('RGBA',(64*S,64*S));d=ImageDraw.Draw(im)
gold=(217,184,115,255);pale=(232,204,145,255);bronze=(119,97,66,255)
# Open codex: distinct covers, curved page edges, spine and bookmark.
polygon(d,[(7,16),(24,14),(32,18),(40,14),(57,16),(57,49),(40,47),(32,51),(24,47),(7,49)],(9,16,26,255),bronze,2)
polygon(d,[(10,12),(24,13),(32,18),(32,46),(24,42),(10,42)],(29,39,52,255),gold,2)
polygon(d,[(32,18),(40,13),(54,12),(54,42),(40,42),(32,46)],(21,31,44,255),gold,2)
line(d,[(32,18),(32,47)],pale,1.5)
for y in (22,28,34):
    line(d,[(15,y),(23,y+1),(27,y+3)],bronze,1)
    line(d,[(37,y+3),(42,y+1),(49,y)],gold,1)
polygon(d,[(42,14),(47,14),(47,30),(44.5,27),(42,30)],(140,171,187,255),pale,1)
polygon(d,[(32,4),(35,8),(32,12),(29,8)],gold)
im=im.resize((64,64),Image.Resampling.LANCZOS)
im.save(MEDIA/'Nexus'/'IconGrimoire.png')
write_blp(im,str(MEDIA/'Nexus'/'IconGrimoire.blp'))
