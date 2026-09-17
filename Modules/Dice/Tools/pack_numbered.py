"""Assemblage et contrôle des rotations Blender numérotées en BLP2."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import io,struct,json,argparse
ROOT=Path(__file__).resolve().parent.parent/'Media'/'Continuous'
OUT=ROOT/'Atlas';OUT.mkdir(exist_ok=True)
p=argparse.ArgumentParser();p.add_argument('--sides',type=int);args=p.parse_args()
def pack(paths,target,grid,rows=None):
    atlas=Image.new('RGBA',(grid*256,(rows or grid)*256))
    for i,path in enumerate(paths):atlas.alpha_composite(Image.open(path).convert('RGBA'),((i%grid)*256,(i//grid)*256))
    a=atlas.getchannel('A');matte=Image.new('RGBA',atlas.size,(40,45,48,255));matte.alpha_composite(atlas);matte.putalpha(a)
    stream=io.BytesIO();matte.save(stream,format='DDS',pixel_format='DXT5');payload=stream.getvalue()[128:]
    header=b'BLP2'+struct.pack('<I4BII',1,2,8,7,0,atlas.width,atlas.height)
    header+=struct.pack('<16I',1172,*([0]*15))+struct.pack('<16I',len(payload),*([0]*15))
    target.write_bytes(header+bytes(1024)+payload)
    assert Image.open(target).size==atlas.size
    # Le décodeur BC3 natif contrôle le même payload DXT5 sans le coût du
    # décodeur BLP Python, très élevé sur les grandes planches.
    decoded=Image.frombytes('RGBA',atlas.size,target.read_bytes()[1172:],'bcn',3)
    assert decoded.size==atlas.size and decoded.getpixel((0,0))[3]==0
    return decoded
for sides in ([args.sides] if args.sides else (4,6,8,10,12,20,100)):
    folder=ROOT/f'd{sides}'
    by_value={}
    for path in folder.glob('faces-*.json'):
        for row in json.loads(path.read_text()):
            if 'join_speed' in row:by_value[row['value']]=row
    meta=[by_value[value] for value in range(1,sides+1)]
    (folder/'faces.json').write_text(json.dumps(meta))
    assert [x['value'] for x in meta]==list(range(1,sides+1))
    assert min(x['front_dot'] for x in meta)>.99999
    assert max(x['center_error'] for x in meta)<1e-6
    assert min(x['join_speed'] for x in meta)>11.8
    assert max(x['max_speed_increase'] for x in meta)<.08
    assert max(x['rendered_max_speed_increase'] for x in meta)<.08
    rolling=[folder/f'roll-{i:02}.png' for i in range(96)]
    roll=pack(rolling,OUT/f'd{sides}.blp',8,16)
    finals=[]
    for value in range(1,sides+1):
        paths=[folder/f'land-{value:03}-{i:02}.png' for i in range(48)]
        # Le premier arrêt part exactement de la dernière pose du lancer.
        assert Image.open(paths[0]).tobytes()==Image.open(rolling[-1]).tobytes()
        atlas=pack(paths,OUT/f'd{sides}-face-{value}.blp',8)
        finals.append(atlas.crop((1792,1280,2048,1536)))
        if value==min(12,sides):
            frames=[]
            for image in [roll.crop(((i%8)*256,(i//8)*256,(i%8+1)*256,(i//8+1)*256)) for i in range(95)]+[atlas.crop(((i%8)*256,(i//8)*256,(i%8+1)*256,(i//8+1)*256)) for i in range(48)]:
                bg=Image.new('RGBA',(256,256),'#14191c');bg.alpha_composite(image);frames.append(bg.convert('RGB'))
            durations=[(round((i+1)*156/95)-round(i*156/95))*10 for i in range(95)]
            durations += [(round((i+1)*84/47)-round(i*84/47))*10 for i in range(47)]+[1600]
            frames[0].save(ROOT/f'd{sides}-numbered.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0)
    sheet=Image.new('RGBA',(5*256,((sides+4)//5)*256),'#14191c')
    for i,image in enumerate(finals):sheet.alpha_composite(image,((i%5)*256,(i//5)*256))
    sheet.convert('RGB').save(ROOT/f'd{sides}-faces.jpg')
    print(f'D{sides}: {sides} résultats gravés vérifiés, jonctions sans saut',flush=True)
