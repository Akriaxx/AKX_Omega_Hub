"""Texture du grimoire et aperçu de sa disposition, sans dépendance externe."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
import io, struct, os
from book_paper import build_paper
bookmark_root=Path(__file__).resolve().parent.parent/'Media'/'Book'
root=Path(os.environ.get('OMEGA_BOOK_OUT',str(bookmark_root)))
build_paper(root)
for name in ('grimoire','cover'):
 im=Image.open(root/(name+'.png')).convert('RGBA')
 alpha=im.getchannel('A'); matte=Image.new('RGBA',im.size,(160,130,85,255)); matte.alpha_composite(im); matte.putalpha(alpha)
 buf=io.BytesIO(); matte.save(buf,format='DDS',pixel_format='DXT5'); data=buf.getvalue()[128:]
 header=b'BLP2'+struct.pack('<I4BII',1,2,8,7,0,im.width,im.height)+struct.pack('<16I',1172,*([0]*15))+struct.pack('<16I',len(data),*([0]*15))
 (root/(name+'.blp')).write_bytes(header+bytes(1024)+data)
decoded=Image.open(root/'grimoire.blp').convert('RGBA')
assert decoded.size==(2048,2048)
preview=Image.new('RGBA',(1040,690),'#141716'); preview.alpha_composite(decoded.resize((940,650)),(76,20))
d=ImageDraw.Draw(preview); font=lambda n:ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',n)
d.text((123,55),'JOURNAL DE QUÊTE',font=font(12),fill='#795c34')
d.text((123,109),'Personnel · 2',font=font(23),fill='#46321c')
d.text((577,111),'Le registre oublié',font=font(23),fill='#46321c')
d.text((577,174),'Le gardien des archives',font=font(12),fill='#795c34')
d.text((577,195),'En cours · 1/3 étapes révélées',font=font(12),fill='#795c34')
for i,title in enumerate(('Le registre oublié','Un message à remettre')):
 y=164+i*56
 if i==0:d.rectangle((120,y-4,510,y+47),fill='#cbb58b')
 d.text((128,y),title,font=font(15),fill='#46321c');d.text((128,y+25),'En cours',font=font(11),fill='#795c34')
for i,line in enumerate(('01  Retrouver le gardien à la bibliothèque.','','02  ?????','','03  ?????')):d.text((577,245+i*27),line,font=font(15),fill='#46321c')
preview=ImageOps.expand(preview,border=(60,0,0,0),fill='#141716');d=ImageDraw.Draw(preview)
for i,name in enumerate(('personal','group','archives')):
 ribbon=Image.open(bookmark_root/f'bookmark-{name}.blp').convert('RGBA').resize((48,144),Image.Resampling.LANCZOS)
 if i:
  r,g,b,a=ribbon.split();ribbon=Image.merge('RGBA',(r.point(lambda p:int(p*.78)),g.point(lambda p:int(p*.78)),b.point(lambda p:int(p*.78)),a))
 preview.alpha_composite(ribbon,(117+(4 if i else 0),100+i*156))
preview.alpha_composite(Image.open(bookmark_root/'bookmark-mj.blp').convert('RGBA').resize((48,144),Image.Resampling.LANCZOS),(1047,494))
preview.convert('RGB').save(root/'layout-preview.png')
print('Grimoire BLP généré et décodé ; aperçu de composition disponible.')
