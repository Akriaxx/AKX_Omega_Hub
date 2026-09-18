"""Check shipped TrueType files and French glyph coverage without dependencies."""
from pathlib import Path
import struct

root = Path(__file__).resolve().parents[1] / 'Fonts'
required = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ÀÂÆÇÉÈÊËÎÏÔŒÙÛÜŸàâæçéèêëîïôœùûüÿ’"
for path in sorted(root.glob('*.ttf')):
    if path.stem in ('Cinzel-Regular','Metamorphous-Regular','PirataOne-Regular','MedievalSharp-Regular'): continue
    data = path.read_bytes()
    def u16(offset): return struct.unpack_from('>H', data, offset)[0]
    def u32(offset): return struct.unpack_from('>I', data, offset)[0]
    assert data[:4] == b'\x00\x01\x00\x00', path.name
    tables = {}
    for i in range(u16(4)):
        pos = 12 + i * 16
        tables[data[pos:pos+4]] = u32(pos+8)
    assert b'fvar' not in tables, 'Use static fonts for the game client'
    cmap = tables[b'cmap']
    covered = set()
    for i in range(u16(cmap+2)):
        record = cmap+4+i*8
        platform, encoding = u16(record), u16(record+2)
        if not (platform == 0 or platform == 3 and encoding in (1,10)): continue
        sub = cmap+u32(record+4)
        if u16(sub) != 4: continue
        count = u16(sub+6)//2
        ends = sub+14
        starts = ends+count*2+2
        deltas = starts+count*2
        offsets = deltas+count*2
        for j in range(count):
            for char in required:
                code = ord(char)
                if u16(starts+j*2) <= code <= u16(ends+j*2):
                    distance = u16(offsets+j*2)
                    glyph = u16(offsets+j*2+distance+(code-u16(starts+j*2))*2) if distance else code
                    if not distance or glyph: glyph = (glyph+u16(deltas+j*2)) & 65535
                    if glyph: covered.add(char)
    missing = set(required)-covered
    if path.name == 'Rye-Regular.ttf':
        assert missing == {'Ÿ'}, 'Recheck the documented Rye limitation'
        print('NOTE: Rye does not include capital Y with diaeresis')
        missing = set()
    assert not missing, (path.name, ''.join(sorted(missing)))
    assert (root / ('OFL-'+path.stem.replace('-Regular','')+'.txt')).exists(), path.name
    print('OK:', path.name, 'French glyphs, static TrueType, license')
