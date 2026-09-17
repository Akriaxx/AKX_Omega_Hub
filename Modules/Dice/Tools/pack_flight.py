"""Une séquence de 144 poses par résultat, répartie sur trois planches BLP."""
import argparse,io,json,struct
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parent.parent/'Media'/'Flight'
OUT=ROOT/'Atlas';OUT.mkdir(parents=True,exist_ok=True)
parser=argparse.ArgumentParser();parser.add_argument('--sides',type=int)
args=parser.parse_args()
for sides in ([args.sides] if args.sides else [4,6,8,10,12,20,100]):
    folder=ROOT/f'd{sides}';rows={}
    for file in folder.glob('faces-*.json'):
        for row in json.loads(file.read_text()):rows[row['value']]=row
    meta=[rows[value] for value in range(1,sides+1)]
    assert min(r['front_dot'] for r in meta)>.99999
    assert max(r['center_error'] for r in meta)<1e-6
    assert max(r['max_speed_increase'] for r in meta)<.02
    assert max(r['last_speed'] for r in meta)<.03
    (folder/'faces.json').write_text(json.dumps(meta))
    preview=[]
    for value in range(1,sides+1):
        for page,count in enumerate((64,64,16),1):
            size=(2048,2048 if count==64 else 512)
            atlas=Image.new('RGBA',size)
            for local in range(count):
                index=(page-1)*64+local
                with Image.open(folder/f'face-{value:03}-{index:03}.png') as frame:
                    atlas.alpha_composite(frame.convert('RGBA'),((local%8)*256,(local//8)*256))
            alpha=atlas.getchannel('A')
            matte=Image.new('RGBA',size,(40,45,48,255));matte.alpha_composite(atlas);matte.putalpha(alpha)
            stream=io.BytesIO();matte.save(stream,format='DDS',pixel_format='DXT5')
            payload=stream.getvalue()[128:]
            header=b'BLP2'+struct.pack('<I4BII',1,2,8,7,0,*size)
            header+=struct.pack('<16I',1172,*([0]*15))+struct.pack('<16I',len(payload),*([0]*15))
            path=OUT/f'd{sides}-face-{value}-p{page}.blp'
            path.write_bytes(header+bytes(1024)+payload)
            assert Image.open(path).size==size
            decoded=Image.frombytes('RGBA',size,path.read_bytes()[1172:],'bcn',3)
            assert decoded.getpixel((0,0))[3]==0
            if sides==20 and value in (3,12,20):
                for local in range(count):
                    tile=decoded.crop(((local%8)*256,(local//8)*256,(local%8+1)*256,(local//8+1)*256))
                    bg=Image.new('RGBA',(256,256),'#14191c');bg.alpha_composite(tile)
                    preview.append(bg.convert('RGB'))
    if preview:
        durations=[(round((i+1)*240/143)-round(i*240/143))*10 for i in range(143)]+[1000]
        preview[0].save(ROOT/'d20-full-roll.gif',save_all=True,append_images=preview[1:],duration=durations*3,loop=0)
    print(f'D{sides} : {sides} mouvements complets de 144 images vérifiés',flush=True)
