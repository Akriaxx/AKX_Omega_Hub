# Logo du bouton Action : PNG transparent -> Media/EindhillLogo.blp
#   python3 Modules/Character/Tests/logo-blp.py <logo.png>   (Pillow requis)
# Recadre sur le contenu et laisse la marge du bouton (TexCoord .08-.92 +
# masque rond), en 256x256.
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from blp import write_blp

im = Image.open(sys.argv[1]).convert("RGBA")
logo = im.crop(im.getchannel("A").getbbox())
w, h = logo.size
side = int(max(w, h) / (0.84 * 0.90))
canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
canvas.paste(logo, ((side - w) // 2, (side - h) // 2), logo)
write_blp(canvas.resize((256, 256), Image.LANCZOS), "Modules/Character/Media/EindhillLogo.blp")
print("Modules/Character/Media/EindhillLogo.blp")
