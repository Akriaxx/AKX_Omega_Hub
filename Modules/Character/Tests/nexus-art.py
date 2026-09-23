# Images PROVISOIRES du nexus (bouton Action), aux couleurs du thème Character.
#   python3 Modules/Character/Tests/nexus-art.py      (Pillow requis)
# Écrit Media/Nexus/*.blp et un aperçu PNG par image dans Media/Nexus/preview/
# (non chargé par le jeu). Astra : remplacer ces BLP par les définitifs en
# gardant noms, tailles et découpage (voir THEME dans UI_ActionFX.lua).
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
from blp import write_blp

OUT = "Modules/Character/Media/Nexus"
PREVIEW = os.path.join(OUT, "preview")
os.makedirs(PREVIEW, exist_ok=True)
random.seed(7)

# Palette du cadre de ressources tel qu'affiché en jeu : fond gris-olive
# presque noir, bronze et or (aucun vert ni sarcelle). Les « données »
# sont en bronze, la structure en or.
DARK = (6, 8, 9)            # fond des fenêtres
BG = (28, 31, 27)           # fond des cadres #1c1f1b
BRONZE_DARK = (70, 58, 38)  # bronze sombre #463a26
BRONZE = (119, 97, 66)      # bronze #776142
GOLD_DARK = (133, 107, 64)
GOLD = (158, 122, 64)
GOLD_LIGHT = (217, 184, 115)
GOLD_PALE = (232, 204, 145)
SS = 4  # suréchantillonnage (anticrénelage)


def save(img, name):
    write_blp(img, os.path.join(OUT, name + ".blp"))
    img.save(os.path.join(PREVIEW, name + ".png"))
    print(name, img.size)


def canvas(w, h=None):
    h = h or w
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def down(img):
    return img.resize((img.width // SS, img.height // SS), Image.LANCZOS)


def glow(img, radius):
    blur = img.filter(ImageFilter.GaussianBlur(radius * SS))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(blur)
    out.alpha_composite(img)
    return out


def ring(draw, c, r_out, r_in, fill):
    draw.ellipse([c - r_out, c - r_out, c + r_out, c + r_out], fill=fill)
    draw.ellipse([c - r_in, c - r_in, c + r_in, c + r_in], fill=(0, 0, 0, 0))


# ── Nexus : fond de pixels (disque de petits carrés bronze/or, bord fondu) ─
def nexus_pixels():
    size, cell = 128, 8
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size / 2
    for gy in range(size // cell):
        for gx in range(size // cell):
            x, y = gx * cell + cell / 2, gy * cell + cell / 2
            r = math.hypot(x - c, y - c) / c
            if r > 1:
                continue
            fade = max(0, 1 - r) ** .6
            roll = random.random()
            col = GOLD if roll < .06 else BRONZE if roll < .2 else BRONZE_DARK if roll < .6 else BG
            a = int(255 * fade * (.35 + .65 * random.random()))
            d.rectangle([gx * cell + 1, gy * cell + 1, gx * cell + cell - 2, gy * cell + cell - 2], fill=col + (a,))
    save(img, "NexusPixels")


# ── Nexus : anneau d'or asymétrique (encoches, runes, losange) pour voir la rotation ─
def nexus_ring():
    size = 256
    img = canvas(size)
    d = ImageDraw.Draw(img)
    c = size * SS / 2
    ring(d, c, c * .96, c * .86, GOLD_DARK + (255,))
    ring(d, c, c * .945, c * .875, GOLD_LIGHT + (255,))
    # Encoches : trois trous inégaux dans la bande.
    for start, span in ((20, 14), (140, 8), (255, 22)):
        d.pieslice([0, 0, size * SS, size * SS], start, start + span, fill=(0, 0, 0, 0))
    ring(d, c, c * .84, c * .80, GOLD + (190,))
    # Runes : traits radiaux irréguliers sur l'anneau intérieur.
    for i in range(22):
        a = math.radians(i * 360 / 22 + random.uniform(-4, 4))
        r1, r2 = c * .80, c * (.74 if i % 3 else .70)
        d.line([c + r1 * math.cos(a), c + r1 * math.sin(a), c + r2 * math.cos(a), c + r2 * math.sin(a)],
               fill=GOLD_PALE + (230,), width=3 * SS // 2)
    # Losange brillant : repère de rotation.
    a = math.radians(-60)
    x, y, s = c + c * .91 * math.cos(a), c + c * .91 * math.sin(a), c * .07
    d.polygon([(x, y - s), (x + s * .7, y), (x, y + s), (x - s * .7, y)], fill=GOLD_PALE + (255,))
    save(down(glow(img, 1.2)), "NexusRing")


def nexus_glow():
    size = 128
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - size / 2 + .5, y - size / 2 + .5) / (size / 2)
            a = max(0, 1 - r) ** 2
            px[x, y] = GOLD_LIGHT + (int(255 * a),)
    save(img, "NexusGlow")


# ── Cube de données : planche 4x4, un quart de tour (boucle sans raccord) ────
def project(p, yaw, pitch, scale, c):
    x, y, z = p
    x, z = x * math.cos(yaw) - z * math.sin(yaw), x * math.sin(yaw) + z * math.cos(yaw)
    y, z = y * math.cos(pitch) - z * math.sin(pitch), y * math.sin(pitch) + z * math.cos(pitch)
    return (c + x * scale, c + y * scale), z


def data_cube():
    frame, cols = 128, 4
    sheet = Image.new("RGBA", (frame * cols, frame * cols), (0, 0, 0, 0))
    verts = [(x, y, z) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    faces = [(0, 1, 3, 2), (4, 5, 7, 6), (0, 1, 5, 4), (2, 3, 7, 6), (0, 2, 6, 4), (1, 3, 7, 5)]
    edges = [(a, b) for a in range(8) for b in range(a + 1, 8) if sum(verts[a][k] != verts[b][k] for k in range(3)) == 1]
    for i in range(16):
        img = canvas(frame)
        d = ImageDraw.Draw(img)
        c = frame * SS / 2
        yaw, pitch = math.radians(i * 90 / 16 + 20), math.radians(-28)
        pts = [project(v, yaw, pitch, frame * SS * .24, c) for v in verts]
        for f in sorted(faces, key=lambda f: -sum(pts[k][1] for k in f)):
            d.polygon([pts[k][0] for k in f], fill=BRONZE_DARK + (95,))
            # Lignes de données sur la face.
            p0, p1, p2, p3 = (pts[k][0] for k in f)
            for t in (.25, .5, .75):
                a = (p0[0] + (p3[0] - p0[0]) * t, p0[1] + (p3[1] - p0[1]) * t)
                b = (p1[0] + (p2[0] - p1[0]) * t, p1[1] + (p2[1] - p1[1]) * t)
                d.line([a, b], fill=BRONZE + (70,), width=SS)
        for a, b in edges:
            d.line([pts[a][0], pts[b][0]], fill=GOLD_LIGHT + (255,), width=3 * SS)
        for p, _ in pts:
            d.ellipse([p[0] - 2.5 * SS, p[1] - 2.5 * SS, p[0] + 2.5 * SS, p[1] + 2.5 * SS], fill=GOLD_PALE + (255,))
        sheet.alpha_composite(down(glow(img, 2)), ((i % cols) * frame, (i // cols) * frame))
    save(sheet, "DataCube")


def data_shard():
    size = 64
    img = canvas(size)
    d = ImageDraw.Draw(img)
    s = size * SS
    poly = [(s * .5, s * .08), (s * .82, s * .78), (s * .22, s * .9)]
    d.polygon(poly, fill=BRONZE_DARK + (220,), outline=GOLD_LIGHT + (255,), width=2 * SS)
    d.line([poly[0], (s * .5, s * .6)], fill=BRONZE + (200,), width=SS)
    save(down(glow(img, 1.5)), "DataShard")


# ── Cercle de données : cadre fixe + anneau segmenté (tourne) ────────────────
def data_frame():
    size = 128
    img = canvas(size)
    d = ImageDraw.Draw(img)
    c = size * SS / 2
    ring(d, c, c * .98, c * .90, GOLD_DARK + (255,))
    ring(d, c, c * .965, c * .915, GOLD_LIGHT + (255,))
    for i in range(4):
        a = math.radians(45 + i * 90)
        x, y, s = c + c * .94 * math.cos(a), c + c * .94 * math.sin(a), c * .06
        d.polygon([(x, y - s), (x + s, y), (x, y + s), (x - s, y)], fill=GOLD_PALE + (255,))
    save(down(img), "DataFrame")


def data_ring():
    size = 128
    img = canvas(size)
    d = ImageDraw.Draw(img)
    s = size * SS
    box = [s * .08, s * .08, s * .92, s * .92]
    for i in range(12):
        start = i * 30 + 3
        col = GOLD_LIGHT if i in (0, 5) else BRONZE
        d.arc(box, start, start + (24 if i % 4 else 12), fill=col + (235,), width=int(s * .045))
    inner = [s * .17, s * .17, s * .83, s * .83]
    for i in range(36):
        if i % 3:
            d.arc(inner, i * 10, i * 10 + 4, fill=BRONZE_DARK + (200,), width=int(s * .02))
    save(down(glow(img, 1)), "DataRing")


# ── Flux de données : se répète horizontalement sans raccord ─────────────────
def data_stream():
    w, h = 256, 64
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    W, H = w * SS, h * SS
    for _ in range(70):
        y = random.uniform(.12, .88) * H
        length = random.uniform(.04, .3) * W
        x = random.uniform(0, W)
        col = GOLD_LIGHT if random.random() < .15 else BRONZE if random.random() < .5 else BRONZE_DARK
        a = random.randint(60, 190)
        for dx in (0, -W):  # tracé enroulé : pas de raccord visible
            d.line([x + dx, y, x + dx + length, y], fill=col + (a,), width=random.choice((SS, 2 * SS)))
    for _ in range(90):
        x, y = random.uniform(0, W), random.uniform(.1, .9) * H
        col = GOLD_PALE if random.random() < .2 else BRONZE
        for dx in (0, -W):
            d.rectangle([x + dx, y, x + dx + 2 * SS, y + 2 * SS], fill=col + (200,))
    small = down(img)
    # Fondu vertical : plus dense au centre de la bande.
    px = small.load()
    for yy in range(h):
        f = 1 - abs(yy - h / 2 + .5) / (h / 2)
        for xx in range(w):
            r, g, b, a = px[xx, yy]
            px[xx, yy] = (r, g, b, int(a * min(1, f * 1.6)))
    save(small, "DataStream")


nexus_pixels()
nexus_ring()
nexus_glow()
data_cube()
data_shard()
data_frame()
data_ring()
data_stream()
