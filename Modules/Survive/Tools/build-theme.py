
from pathlib import Path
import sys, math
from PIL import Image,ImageDraw
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'Character/Tests'))
from blp import write_blp
out=Path(__file__).resolve().parents[1]/'Core/Media'
S=4
gold=(217,184,115,255);light=(241,216,159,255);dim=(123,98,60,255);blue=(103,161,182,255)
def draw_icon(kind):
 im=Image.new('RGBA',(128*S,128*S));d=ImageDraw.Draw(im)
 def line(p,c=gold,w=2):d.line([(int(x*S),int(y*S)) for x,y in p],fill=c,width=int(w*S),joint='curve')
 def poly(p,fill=(23,34,46,255),c=gold):d.polygon([(int(x*S),int(y*S)) for x,y in p],fill=fill);line(p+[p[0]],c)
 def ellipse(box,c=gold,w=2,fill=None):d.ellipse(tuple(int(x*S) for x in box),outline=c,width=int(w*S),fill=fill)
 ellipse((4,4,124,124),dim,1,(8,15,24,255));ellipse((8,8,120,120),gold,2);ellipse((13,13,115,115),dim,1)
 for x,y in [(64,7),(121,64),(64,121),(7,64)]:poly([(x,y-3),(x+3,y),(x,y+3),(x-3,y)],gold)
 if kind=='Lantern':
  ellipse((52,24,76,47));poly([(46,46),(82,46),(88,94),(40,94)])
  line([(39,96),(89,96)],light,3);line([(45,43),(83,43)],light,3)
  for x in (48,80):line([(x,51),(x,87)],dim)
  poly([(64,82),(55,73),(59,62),(64,56),(65,67),(71,64),(74,75),(68,82)],(166,119,44,255),light)
 elif kind=='Water':
  poly([(54,32),(74,32),(76,44),(87,54),(87,86),(78,99),(50,99),(41,86),(41,54),(52,44)])
  poly([(53,24),(75,24),(75,34),(53,34)],(63,47,31,255))
  line([(45,65),(54,61),(64,66),(75,61),(83,65)],blue,3)
  poly([(64,70),(57,80),(57,85),(64,90),(71,85),(71,80)],(42,88,108,255),blue)
 elif kind=='Torch':
  poly([(58,64),(71,64),(68,102),(61,102)],(76,50,29,255))
  poly([(52,55),(77,55),(73,68),(56,68)])
  poly([(63,53),(48,45),(49,34),(60,23),(63,34),(71,18),(80,35),(79,46),(71,53)],(172,105,34,255),light)
  line([(59,71),(70,75),(59,81),(69,86),(60,92)],dim)
 elif kind=='Dive':
  poly([(34,47),(59,44),(64,50),(69,44),(94,47),(91,70),(70,70),(64,61),(58,70),(37,70)],(29,54,66,255))
  line([(40,53),(54,51)],light);line([(74,51),(88,53)],light)
  line([(95,65),(100,65),(100,33),(93,29)],gold,4)
  for y in (83,92):line([(33,y),(43,y-3),(54,y+2),(65,y-3),(76,y+2),(87,y-3),(96,y)],blue)
 elif kind=='Settings':
  pts=[]
  for i in range(32):
   a=i*math.pi/16;r=34 if i%4 in (0,1) else 26
   pts.append((64+math.cos(a)*r,64+math.sin(a)*r))
  poly(pts);ellipse((51,51,77,77),light,3)
 elif kind=='Survive':
  poly([(29,88),(52,42),(64,64),(75,35),(100,88)],(22,35,43,255))
  line([(52,42),(57,58),(51,55),(47,63)],light)
  poly([(64,96),(55,84),(59,74),(65,66),(66,79),(73,75),(75,86)],(156,104,32,255),light)
 elif kind=='Food':
  line([(39,28),(39,99)],gold,4)
  for x in (30,39,48):line([(x,28),(x,47),(39,55)],gold,3)
  poly([(79,28),(91,36),(90,57),(80,66),(80,99),(73,99),(73,61),(72,38)])
 return im.resize((128,128),Image.Resampling.LANCZOS)
icons=[]
for name in ('Survive','Lantern','Water','Torch','Dive','Settings','Food'):
 im=draw_icon(name);im.save(out/('Icon'+name+'.png'));write_blp(im,str(out/('Icon'+name+'.blp')));icons.append(im)
sheet=Image.new('RGBA',(7*148,168),(13,20,30,255))
for i,im in enumerate(icons):sheet.alpha_composite(im,(i*148+10,10))
sheet.save(out/'ThemePreview.png')
