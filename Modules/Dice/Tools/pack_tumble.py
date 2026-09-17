"""Assemble les quatre culbutes ; conserve les arrêts Continuous existants."""
import argparse,io,json,struct
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parent.parent/'Media'
OUT=ROOT/'Tumble'/'Atlas';OUT.mkdir(parents=True,exist_ok=True)
parser=argparse.ArgumentParser();parser.add_argument('--sides',type=int)
args=parser.parse_args()
for sides in ([args.sides] if args.sides else [4,6,8,10,12,20,100]):
    folder=ROOT/'Tumble'/f'd{sides}'
    checks=json.loads((folder/'motion-check.json').read_text())
    assert len(checks)==4 and max(x['direction_spread'] for x in checks)<.5
    junction=Image.open(ROOT/'Continuous'/f'd{sides}'/'land-001-00.png').convert('RGBA')
    previews=[]
    for variant in range(1,5):
        atlas=Image.new('RGBA',(2048,4096))
        for i in range(96):
            tile=Image.open(folder/f'roll-v{variant}-{i:02}.png').convert('RGBA')
            atlas.alpha_composite(tile,((i%8)*256,(i//8)*256))
        assert tile.tobytes()==junction.tobytes(),'Le raccord doit être identique aux arrêts existants'
        alpha=atlas.getchannel('A')
        matte=Image.new('RGBA',atlas.size,(40,45,48,255));matte.alpha_composite(atlas);matte.putalpha(alpha)
        stream=io.BytesIO();matte.save(stream,format='DDS',pixel_format='DXT5')
        payload=stream.getvalue()[128:]
        header=b'BLP2'+struct.pack('<I4BII',1,2,8,7,0,2048,4096)
        header+=struct.pack('<16I',1172,*([0]*15))+struct.pack('<16I',len(payload),*([0]*15))
        path=OUT/f'd{sides}-v{variant}.blp';path.write_bytes(header+bytes(1024)+payload)
        assert Image.open(path).size==(2048,4096)
        decoded=Image.frombytes('RGBA',(2048,4096),path.read_bytes()[1172:],'bcn',3)
        assert decoded.getpixel((0,0))[3]==0
        if sides==20:
            for i in range(95):
                previews.append(decoded.crop(((i%8)*256,(i//8)*256,(i%8+1)*256,(i//8+1)*256)))
            # Montrer le raccord réel et l'arrêt, pas uniquement le tournoiement.
            land=ROOT/'Continuous'/'Atlas'/'d20-face-12.blp'
            decoded_land=Image.frombytes('RGBA',(2048,2048),land.read_bytes()[1172:],'bcn',3)
            for i in range(48):
                previews.append(decoded_land.crop(((i%8)*256,(i//8)*256,(i%8+1)*256,(i//8+1)*256)))
    if previews:
        frames=[]
        for image in previews:
            background=Image.new('RGBA',(256,256),'#14191c');background.alpha_composite(image)
            frames.append(background.convert('RGB'))
        times=[(round((i+1)*156/95)-round(i*156/95))*10 for i in range(95)]
        times += [(round((i+1)*84/47)-round(i*84/47))*10 for i in range(47)]+[800]
        frames[0].save(ROOT/'Tumble'/'d20-variants.gif',save_all=True,append_images=frames[1:],duration=times*4,loop=0)
    print(f'D{sides} : 4 culbutes, raccords et BLP vérifiés',flush=True)
