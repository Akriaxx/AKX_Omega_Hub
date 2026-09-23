# Écriture BLP2 pour WoW : palette 256 couleurs, alpha 8 bits, mipmaps.
# (Le BLP de Pillow n'écrit qu'un alpha 1 bit : bords crénelés en jeu.)
import struct
from PIL import Image


def write_blp(image, path):
    base = image.convert("RGBA")
    w, h = base.size
    pal_img = base.convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    palette = pal_img.getpalette()[:768]
    palette += [0] * (768 - len(palette))
    levels = []
    lw, lh = w, h
    while True:
        level = base if (lw, lh) == (w, h) else base.resize((lw, lh), Image.LANCZOS)
        idx = level.convert("RGB").quantize(palette=pal_img, dither=Image.Dither.NONE).tobytes()
        levels.append(idx + level.getchannel("A").tobytes())
        if lw == 1 and lh == 1:
            break
        lw, lh = max(1, lw // 2), max(1, lh // 2)
    header = b"BLP2" + struct.pack("<IBBBBII", 1, 1, 8, 8, 1, w, h)
    offsets, sizes = [], []
    pos = len(header) + 16 * 4 * 2 + 256 * 4
    for data in levels:
        offsets.append(pos)
        sizes.append(len(data))
        pos += len(data)
    offsets += [0] * (16 - len(offsets))
    sizes += [0] * (16 - len(sizes))
    pal = b"".join(struct.pack("<BBBB", palette[i * 3 + 2], palette[i * 3 + 1], palette[i * 3], 0) for i in range(256))
    with open(path, "wb") as f:
        f.write(header + struct.pack("<16I", *offsets) + struct.pack("<16I", *sizes) + pal + b"".join(levels))


def read_blp(path):
    """Relecture selon la spécification WoW (niveau 0), pour vérifier."""
    d = open(path, "rb").read()
    _, _, _, _, _, _, w, h = struct.unpack("<4sIBBBBII", d[:20])
    off = struct.unpack("<16I", d[20:84])[0]
    pal = [struct.unpack("<BBBB", d[148 + i * 4:152 + i * 4]) for i in range(256)]
    idx, alpha = d[off:off + w * h], d[off + w * h:off + 2 * w * h]
    px = bytes(b for i in range(w * h) for b in (pal[idx[i]][2], pal[idx[i]][1], pal[idx[i]][0], alpha[i]))
    return Image.frombytes("RGBA", (w, h), px)


if __name__ == "__main__":
    # python3 Modules/Character/Tests/blp.py <image.png> <sortie.blp>
    import sys
    write_blp(Image.open(sys.argv[1]), sys.argv[2])
    print(sys.argv[2])
