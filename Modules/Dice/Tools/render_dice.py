"""Maillages précalculés en BLP2 : faces pleines, biseaux et gravures."""
from pathlib import Path
import json,math,io,struct
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from scipy.spatial import ConvexHull
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'Media'/'BLP';OUT.mkdir(parents=True,exist_ok=True)
MESH=json.loads((ROOT/'Tools'/'geometry.json').read_text(encoding='utf-8-sig'))
FONT=ImageFont.truetype('C:/Windows/Fonts/georgiab.ttf',120)
SIZE=512;TILE=256;COUNT=64
YY,XX=np.mgrid[:SIZE,:SIZE]

def dual(points):
    planes=np.unique(np.round(ConvexHull(points).equations,7),axis=0)
    verts=planes[:,:3]/(-planes[:,3,None]);faces=[]
    for p in points:
        ids=np.where(np.abs(verts@p-1)<1e-5)[0];n=p/np.linalg.norm(p)
        axis=np.array([1.,0,0]) if abs(n[0])<.9 else np.array([0.,1,0])
        u=np.cross(n,axis);u/=np.linalg.norm(u);v=np.cross(n,u);c=verts[ids].mean(axis=0)
        faces.append(ids[np.argsort(np.arctan2((verts[ids]-c)@v,(verts[ids]-c)@u))].tolist())
    return verts/np.max(np.linalg.norm(verts,axis=1)),faces

def mesh(s):
    if s==10:
        return dual(np.array([[math.cos((2*k+r)*math.pi/5),math.sin((2*k+r)*math.pi/5),(.55 if r==0 else -.55)] for r in range(2) for k in range(5)]))
    if s==100:
        pts=[]
        for i in range(100):
            y=1-(2*i+1)/100;a=i*math.pi*(3-math.sqrt(5));r=math.sqrt(1-y*y)
            pts.append([r*math.cos(a),y,r*math.sin(a)])
        return dual(np.array(pts))
    g=MESH[str(s)];return np.array(g['verts'],dtype=float),[[v-1 for v in f] for f in g['faces']]

def project(p):
    f=3.5/(3.5+p[:,2]);return np.column_stack((256+p[:,0]*f*190,256-p[:,1]*f*190))

def label(im,c,n,p,value,alpha):
    if alpha<=0:return
    u=p[1]-p[0];u/=np.linalg.norm(u);v=np.cross(n,u)
    radius=min(np.linalg.norm(x-c) for x in p)*.4
    if radius<.06:return
    corners=np.array([c-radius*u+radius*v,c+radius*u+radius*v,c+radius*u-radius*v,c-radius*u-radius*v])
    eq=[];rhs=[]
    for (x,y),(a,b) in zip(project(corners),((0,0),(256,0),(256,256),(0,256))):
        eq.extend(((x,y,1,0,0,0,-a*x,-a*y),(0,0,0,x,y,1,-b*x,-b*y)));rhs.extend((a,b))
    try:coeff=np.linalg.solve(eq,rhs)
    except np.linalg.LinAlgError:return
    ink=Image.new('RGBA',(256,256));ImageDraw.Draw(ink).text((128,133),str(value),font=FONT,anchor='mm',fill=(229,199,130,int(255*alpha)))
    im.alpha_composite(ink.transform((SIZE,SIZE),Image.Transform.PERSPECTIVE,coeff,Image.Resampling.BICUBIC))

def render(verts,faces,normals,index):
    t=index/63;e=1-(1-t)**3;n=normals[0]
    rx=math.atan2(n[1],n[2])+.18+(1-e)*math.pi*5
    ry=math.atan2(n[0],-math.hypot(n[1],n[2]))+.22+(1-e)*math.pi*4
    cx,sx,cy,sy=math.cos(rx),math.sin(rx),math.cos(ry),math.sin(ry)
    r=np.array([[cy,sy*sx,sy*cx],[0,cx,-sx],[-sy,cy*sx,cy*cx]])
    points=verts@r.T;ns=normals@r.T;im=Image.new('RGBA',(SIZE,SIZE));d=ImageDraw.Draw(im)
    light=np.array([-.5,.7,-1]);light/=np.linalg.norm(light)
    for fi in sorted(range(len(faces)),key=lambda i:points[faces[i],2].mean(),reverse=True):
        n=ns[fi]
        if n[2]>=-.015:continue
        p=points[faces[fi]];c=p.mean(axis=0);xy=project(p)
        diffuse=max(0,float(n@light));spec=max(0,float(n@np.array([-.24,.34,-.91])))**22
        gold=tuple(int(min(255,x*(.40+.55*diffuse)+45*spec)) for x in (177,143,87))
        d.polygon([tuple(x) for x in xy],fill=gold+(255,))
        inset=c+(p-c)*.91
        inner=project(inset)
        for k in range(len(xy)):
            j=(k+1)%len(xy);edge=xy[j]-xy[k]
            shine=.55+.4*abs(edge[0])/(np.linalg.norm(edge)+1)
            bevel=tuple(int(min(255,c*shine)) for c in gold)
            d.polygon([tuple(xy[k]),tuple(xy[j]),tuple(inner[j]),tuple(inner[k])],fill=bevel+(255,))
        mask=Image.new('L',(SIZE,SIZE));ImageDraw.Draw(mask).polygon([tuple(x) for x in inner],fill=255)
        # Reflet diffus d'une grande source : volume satiné, sans aplat uniforme.
        center=project(np.array([c]))[0]
        radius=max(20,np.max(np.linalg.norm(inner-center,axis=1)))
        u=(XX-center[0])/radius;v=(YY-center[1])/radius
        glow=np.exp(-((u+.45)**2+(v+.55)**2)*1.8)
        reflection=np.exp(-((u+.5*v+.4)/.23)**2)*max(0,-n[2])
        shade=18+28*diffuse+24*glow+16*reflection+40*spec-9*v
        body=np.zeros((SIZE,SIZE,4),dtype=np.uint8)
        for channel,offset in enumerate((0,7,12)):body[:,:,channel]=np.clip(shade+offset,0,255)
        body[:,:,3]=np.asarray(mask)
        im.alpha_composite(Image.fromarray(body))
        label(im,c,n,inset,fi+1,min(1,max(0,(.94-t)/.12)))
    return im.resize((TILE,TILE),Image.Resampling.LANCZOS)

def blp(im,path):
    alpha=im.getchannel('A');matte=Image.new('RGBA',im.size,(42,40,34,255));matte.alpha_composite(im);matte.putalpha(alpha)
    buf=io.BytesIO();matte.save(buf,format='DDS',pixel_format='DXT5');data=buf.getvalue()[128:]
    head=b'BLP2'+struct.pack('<I4BII',1,2,8,7,0,im.width,im.height)
    head+=struct.pack('<16I',1172,*([0]*15))+struct.pack('<16I',len(data),*([0]*15))
    path.write_bytes(head+bytes(1024)+data);decoded=Image.open(path).convert('RGBA')
    assert decoded.size==im.size and decoded.getpixel((0,0))[3]==0
    return decoded

if __name__=='__main__':
    preview=Image.new('RGB',(7*TILE,2*TILE),'#15191c')
    for column,sides in enumerate((4,6,8,10,12,20,100)):
        verts,faces=mesh(sides);assert len(faces)==sides;normals=[]
        for face in faces:
            p=verts[face];n=np.cross(p[1]-p[0],p[2]-p[0]);n/=np.linalg.norm(n)
            if n@p.mean(axis=0)<0:n=-n
            normals.append(n)
        atlas=Image.new('RGBA',(2048,2048))
        for i in range(COUNT):atlas.alpha_composite(render(verts,faces,np.array(normals),i),((i%8)*TILE,(i//8)*TILE))
        decoded=blp(atlas,OUT/f'd{sides}.blp');frames=[]
        for i in range(COUNT):
            tile=decoded.crop(((i%8)*TILE,(i//8)*TILE,(i%8+1)*TILE,(i//8+1)*TILE))
            bg=Image.new('RGBA',(TILE,TILE),'#15191c');bg.alpha_composite(tile);frames.append(bg.convert('RGB'))
        preview.paste(frames[5],(column*TILE,0));preview.paste(frames[-1],(column*TILE,TILE))
        ImageDraw.Draw(preview).text((column*TILE+12,10),f'D{sides}',fill='#e5c782')
        frames[0].save(OUT/f'd{sides}-preview.gif',save_all=True,append_images=frames[1:],duration=38,loop=0)
        print(f'D{sides}: {len(faces)} faces, 64 images BLP vérifiées',flush=True)
    preview.save(OUT/'dice-preview.png')
