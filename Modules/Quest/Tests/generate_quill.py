"""Son original de frottement de plume ; aucun enregistrement externe.

Nécessite numpy et soundfile, seulement pour régénérer cet asset.
"""
from pathlib import Path
import numpy as np
import soundfile as sf

rate = 22050
rng = np.random.default_rng(2409)
t = np.arange(int(rate * 1.35)) / rate
noise = rng.normal(size=len(t))
scratch = noise - np.convolve(noise, np.ones(9) / 9, mode="same")
envelope = np.zeros_like(t)
for start, duration, strength in [(0.02, .17, .8), (.24, .12, .5), (.41, .23, 1), (.71, .15, .65), (.94, .26, .7)]:
    phase = np.clip((t - start) / duration, 0, 1)
    envelope += strength * np.sin(np.pi * phase) ** 2
audio = .034 * scratch * envelope * (0.6 + .4 * np.sin(2 * np.pi * 93 * t) ** 2)
output = Path(__file__).resolve().parents[1] / "Media" / "Quill.ogg"
output.parent.mkdir(exist_ok=True)
sf.write(output, audio, rate, format="OGG", subtype="VORBIS")
print(output, sf.info(output))
