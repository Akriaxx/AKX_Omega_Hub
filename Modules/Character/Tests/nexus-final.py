"""Final, reproducible vector/raster nexus assets. No gameplay or timing changes."""
import math, random, os, sys
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0,os.path.dirname(__file__))
from blp import write_blp, read_blp
OUT='Modules/Character/Media/Nexus'
S=4
BG=(7,10,14); BR=(119,97,66); BD=(70,58,38); GD=(133,107,64); GOLD=(217,184,115); PALE=(232,204,145)
def canvas(n,h=None): return Image.new('RGBA',(n*S,(h or n)*S))
def poly(d,pts,col): d.polygon([(x*S,y*S) for x,y in pts],fill=col)
def line(d,pts,col,w=1): d.line([(x*S,y*S) for x,y in pts],fill=col,width=max(1,round(w*S)),joint='curve')
def circle(d,x,y,r,col,w=1): d.ellipse(((x-r)*S,(y-r)*S,(x+r)*S,(y+r)*S),outline=col,width=round(w*S))
def arc(d,n,r,a,b,col,w):
 c=n/2;d.arc(((c-r)*S,(c-r)*S,(c+r)*S,(c+r)*S),a,b,fill=col,width=max(1,round(w*S)))
def point(c,r,a): return (c+r*math.cos(math.radians(a)),c+r*math.sin(math.radians(a)))
def down(im): return im.resize((im.width//S,im.height//S),Image.Resampling.LANCZOS)
def save(im,name,ss=True):
 if ss: im=down(im)
 im.save(f'{OUT}/{name}.png')
 os.makedirs(f'{OUT}/preview',exist_ok=True);im.save(f'{OUT}/preview/{name}.png')
 write_blp(im,f'{OUT}/{name}.blp')
 return im
os.makedirs(OUT,exist_ok=True)
# Jewelled bronze bezel around the original Eindhill logo; clear central aperture.
im=canvas(256);d=ImageDraw.Draw(im)
for r,w,col in [(121,2,BD+(255,)),(119,1.3,PALE+(245,)),(116,7,(12,18,27,255)),(112,2,GD+(255,)),(109,1,PALE+(235,)),(105,.8,BR+(185,))]:
 circle(d,128,128,r,col,w)
for a,b in [(-87,-12),(6,88),(109,189),(211,261)]:
 arc(d,256,116,a,b,GD+(255,),4)
 arc(d,256,117,a,b,GOLD+(255,),1.4)
 arc(d,256,113.5,a,b,BR+(255,),1)
for a in range(0,360,12):
 line(d,[point(128,112,a),point(128,108,a)],BR+(220,),.8)
# Asymmetric clasp arrangement makes the slow rotation visible.
for angle,size in [(-90,8),(30,5),(150,5)]:
 x,y=point(128,115,angle)
 poly(d,[(x,y-size),(x+size*.7,y),(x,y+size),(x-size*.7,y)],GD+(255,))
 poly(d,[(x,y-size*.72),(x+size*.48,y),(x,y+size*.72),(x-size*.48,y)],PALE+(255,))
 poly(d,[(x,y-size*.35),(x+size*.24,y),(x,y+size*.35),(x-size*.24,y)],(34,43,56,255))
for a in [-45,75,195]:
 x,y=point(128,116,a);circle(d,x,y,2.2,PALE+(250,),1)
save(im,'NexusRing')
# Quiet data disk, avoiding a visual grid moire behind the logo.
im=canvas(128);d=ImageDraw.Draw(im);rng=random.Random(31)
for y in range(4,128,6):
 for x in range(4,128,6):
  r=math.hypot(x-64,y-64)/62
  if r>=1:continue
  fade=(1-r*r)**1.3
  col=rng.choice([BG,BG,BD,BD,BR,GD]);alpha=int((80+rng.random()*140)*fade)
  poly(d,[(x,y),(x+3,y),(x+3,y+3),(x,y+3)],col+(alpha,))
for r in [25,39,53]: arc(d,128,r,12,318,BR+(55,),.5)
save(im,'NexusPixels')
# Additive gold radiance, zero alpha at the boundary, no bright opaque core.
im=Image.new('RGBA',(128,128));px=im.load()
for y in range(128):
 for x in range(128):
  r=math.hypot(x-63.5,y-63.5)/64
  a=max(0,1-r)**2*.55 + math.exp(-((r-.42)/.16)**2)*.22
  px[x,y]=GOLD+(int(min(1,a)*255) if r<1 else 0,)
save(im,'NexusGlow',False)
# Fixed frames with a clear aperture; segmented ring occupies a separate inner rail.
im=canvas(128);d=ImageDraw.Draw(im)
# Bevelled compass rim, with four small gold clasps and engraved brackets.
for r,w,col in [(61.5,2,BD+(255,)),(60.5,1,PALE+(250,)),(58.7,2.8,GD+(255,)),(57.5,.8,GOLD+(255,)),(55,.6,BR+(230,))]:circle(d,64,64,r,col,w)
for a,b in [(-140,-105),(-80,-35),(42,70),(122,160)]:arc(d,128,59.5,a,b,PALE+(255,),1.4)
for a in [0,90,180,270]:
 x,y=point(64,59,a)
 poly(d,[(x,y-4.5),(x+4.5,y),(x,y+4.5),(x-4.5,y)],GD+(255,))
 poly(d,[(x,y-3),(x+2.4,y),(x,y+3),(x-2.4,y)],PALE+(255,))
for a in range(15,360,30):
 line(d,[point(64,59,a),point(64,56,a)],BD+(255,),.9)
for a in [45,135,225,315]:
 arc(d,128,54,a-9,a+9,GD+(230,),1.2)
save(im,'DataFrame')
im=canvas(128);d=ImageDraw.Draw(im)
for a,b in [(-82,-43),(-31,10),(19,74),(94,113),(130,176),(197,251)]:
 arc(d,128,52,a,b,BR+(235,),2)
 arc(d,128,52,a,a+min(12,(b-a)/2),GOLD+(255,),2)
for a in range(0,360,15):
 if a in [30,45,165,180]:continue
 line(d,[point(64,48,a),point(64,45,a)],GD+(210,),.65)
arc(d,128,52,-82,-74,PALE+(255,),3)
save(im,'DataRing')
# Cube: quarter-turn periodic geometry and face motifs; frame 16 is followed by frame 1.
verts=[(x,y,z) for x in [-1,1] for y in [-1,1] for z in [-1,1]]
faces=[(0,1,3,2),(4,5,7,6),(0,1,5,4),(2,3,7,6),(0,2,6,4),(1,3,7,5)]
def cube_frame(i):
 im=canvas(128);d=ImageDraw.Draw(im);yaw=math.radians(20+i*90/16);pitch=math.radians(-24)
 def project(v):
  x,y,z=v;x,z=x*math.cos(yaw)-z*math.sin(yaw),x*math.sin(yaw)+z*math.cos(yaw)
  y,z=y*math.cos(pitch)-z*math.sin(pitch),y*math.sin(pitch)+z*math.cos(pitch)
  return (64+x*29,64+y*29),z
 pts=[project(v) for v in verts]
 for f in sorted(faces,key=lambda f:sum(pts[k][1] for k in f)):
  q=[pts[k][0] for k in f]
  poly(d,q,BG+(245,))
  def uv(u,v):return (q[0][0]*(1-u)*(1-v)+q[1][0]*u*(1-v)+q[2][0]*u*v+q[3][0]*(1-u)*v,q[0][1]*(1-u)*(1-v)+q[1][1]*u*(1-v)+q[2][1]*u*v+q[3][1]*(1-u)*v)
  for t in [.18,.38,.62,.82]:
   line(d,[uv(t,.12),uv(t,.88)],BR+(200,),.65);line(d,[uv(.12,t),uv(.88,t)],BR+(170,),.65)
  for u,v in [(.18,.18),(.82,.18),(.18,.82),(.82,.82)]:
   poly(d,[uv(u-.025,v-.025),uv(u+.025,v-.025),uv(u+.025,v+.025),uv(u-.025,v+.025)],GOLD+(240,))
  line(d,[uv(.5,.3),uv(.7,.5),uv(.5,.7),uv(.3,.5),uv(.5,.3)],PALE+(255,),1.2)
  line(d,q+[q[0]],GD+(255,),2.3);line(d,q+[q[0]],GOLD+(255,),.9)
 glow=im.filter(ImageFilter.GaussianBlur(1.5*S));glow.putalpha(glow.getchannel('A').point(lambda a:int(a*.20)))
 glow.alpha_composite(im);return down(glow)
sheet=Image.new('RGBA',(512,512))
for i in range(16):sheet.alpha_composite(cube_frame(i),((i%4)*128,(i//4)*128))
save(sheet,'DataCube',False)
im=canvas(64);d=ImageDraw.Draw(im)
poly(d,[(30,7),(48,28),(37,55),(17,39)],BG+(250,));poly(d,[(30,7),(48,28),(31,35)],BR+(235,))
line(d,[(30,7),(48,28),(37,55),(17,39),(30,7)],GOLD+(255,),1.3)
line(d,[(30,7),(31,35),(37,55)],PALE+(255,),.8);line(d,[(17,39),(31,35),(48,28)],GD+(255,),.8)
save(im,'DataShard')
# Periodic stream rendered with a wrap margin before filtering.
im=canvas(768,64);d=ImageDraw.Draw(im);rng=random.Random(19)
for i in range(105):
 x=rng.uniform(0,256);y=rng.uniform(5,59);length=rng.uniform(3,38)
 col=(GOLD if i%9==0 else BR if i%3==0 else BD)+(rng.randrange(145,245),)
 for offset in [0,256,512]:
  line(d,[(x+offset,y),(x+offset+length,y)],col,.65 if i%3 else 1.1)
  if i%4==0:poly(d,[(x+offset,y-1),(x+offset+2,y-1),(x+offset+2,y+1),(x+offset,y+1)],col)
im=down(im).crop((256,0,512,64));px=im.load()
for y in range(64):
 fade=math.sin(math.pi*y/63)**2
 for x in range(256):
  r,g,b,a=px[x,y];px[x,y]=(r,g,b,min(255,int(a*fade*1.65)))
# Exact endpoint agreement, including alpha, for the client's wrap sampling.
for y in range(64):px[255,y]=px[0,y]
save(im,'DataStream',False)
# Bold, original silhouettes that survive a 20–28 px display.
for name in ['Actions','Offensive','Defensive','Distance']:
 im=canvas(64);d=ImageDraw.Draw(im)
 if name=='Actions':
  for x,y in [(32,13),(13,32),(51,32),(32,51)]:
   line(d,[(32,32),(x,y)],BR+(255,),2)
   poly(d,[(x,y-5),(x+5,y),(x,y+5),(x-5,y)],GOLD+(255,))
  poly(d,[(32,21),(42,32),(32,43),(22,32)],PALE+(255,))
 elif name=='Offensive':
  poly(d,[(43,7),(48,6),(48,12),(29,38),(24,33)],GOLD+(255,))
  line(d,[(46,9),(26,35)],PALE+(255,),1)
  line(d,[(18,29),(34,43)],GD+(255,),4);line(d,[(25,37),(16,49)],GOLD+(255,),4)
  circle(d,15,51,3,PALE+(255,),2)
 elif name=='Defensive':
  poly(d,[(32,7),(50,14),(47,37),(41,48),(32,56),(23,48),(17,37),(14,14)],GOLD+(255,))
  poly(d,[(32,12),(45,18),(42,36),(37,45),(32,50),(27,45),(22,36),(19,18)],BG+(255,))
  line(d,[(32,16),(32,43)],PALE+(255,),2);line(d,[(24,29),(40,29)],GOLD+(255,),2)
 elif name=='Distance':
  line(d,[(18,10),(30,16),(37,26),(37,38),(30,48),(18,54)],GOLD+(255,),3)
  line(d,[(18,10),(25,32),(18,54)],BR+(255,),1.2)
  line(d,[(11,32),(52,32)],PALE+(255,),2)
  poly(d,[(54,32),(45,27),(47,32),(45,37)],GOLD+(255,))
 # A restrained luminous relief beneath the sharp gold engraving.
 if name=='Actions':
  circle(d,32,32,15,BR+(240,),.8)
  for a in [45,135,225,315]:
   line(d,[point(32,19,a),point(32,25,a)],GOLD+(255,),1.2)
  poly(d,[(32,26),(37,32),(32,38),(27,32)],BG+(255,))
  circle(d,32,32,2,PALE+(255,),2)
 elif name=='Offensive':
  line(d,[(18,29),(15,24),(20,26)],PALE+(255,),1.2)
  line(d,[(34,43),(39,44),(37,39)],PALE+(255,),1.2)
  line(d,[(21,39),(24,42),(18,42),(21,45)],BD+(255,),1)
  line(d,[(38,10),(35,16)],GOLD+(210,),1)
  line(d,[(48,19),(45,23)],GOLD+(210,),1)
 elif name=='Defensive':
  line(d,[(12,20),(8,16),(11,35),(19,45)],GD+(255,),1.6)
  line(d,[(52,20),(56,16),(53,35),(45,45)],GD+(255,),1.6)
  poly(d,[(32,21),(38,29),(32,38),(26,29)],GOLD+(255,))
  poly(d,[(32,24),(35,29),(32,33),(29,29)],PALE+(255,))
  line(d,[(23,16),(32,12),(41,16)],PALE+(255,),1)
 elif name=='Distance':
  line(d,[(19,10),(13,7),(16,15)],PALE+(255,),1.4)
  line(d,[(19,54),(13,57),(16,49)],PALE+(255,),1.4)
  line(d,[(32,19),(40,24),(42,32),(40,40),(32,45)],GD+(255,),1)
  line(d,[(12,28),(17,32),(12,36)],GOLD+(255,),1.6)
  line(d,[(35,28),(39,32),(35,36)],PALE+(255,),1)
 halo=im.filter(ImageFilter.GaussianBlur(1.4*S))
 halo.putalpha(halo.getchannel('A').point(lambda alpha:int(alpha*.4)))
 halo.alpha_composite(im)
 save(halo,'Icon'+name)
print('Generated 12 PNG + 8-bit-alpha BLP assets')

# Resting nexus: a readable gold seal, sharing the triangle/category geometry.
im=canvas(128);d=ImageDraw.Draw(im)
circle(d,64,64,37,BR+(210,),1)
points=[point(64,30,a) for a in [-90,30,150]]
line(d,points+[points[0]],GOLD+(255,),2.2)
for x,y in points:
 poly(d,[(x,y-5),(x+4,y),(x,y+5),(x-4,y)],PALE+(255,))
for x,y in points:line(d,[(64,64),(x,y)],GD+(255,),1.5)
poly(d,[(64,49),(77,57),(77,72),(64,80),(51,72),(51,57)],BG+(255,))
line(d,[(64,49),(77,57),(77,72),(64,80),(51,72),(51,57),(64,49)],PALE+(255,),2)
line(d,[(51,57),(64,65),(77,57)],GOLD+(255,),1.5)
line(d,[(64,65),(64,80)],GOLD+(255,),1.5)
for a in [-60,0,60,120,180,240]:line(d,[point(64,41,a),point(64,44,a)],GOLD+(220,),1.4)
save(im,'NexusCore')
