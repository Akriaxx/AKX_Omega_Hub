"""Original synthesized zone-entry cue; no samples or external dependencies."""
import math
import random
import struct
import wave
from pathlib import Path

rate = 44100
duration = 3.6
rng = random.Random(42)
frames = int(rate * duration)
dry = []
noise_low = 0.0
for i in range(frames):
    t = i / rate
    noise = rng.uniform(-1, 1)
    noise_low += 0.07 * (noise - noise_low)
    breath = noise_low * math.sin(math.pi * min(t / .75, 1)) ** 2 * .34 if t < .75 else 0
    u = max(0, t - .42)
    body = (1 - math.exp(-u * 38)) * math.exp(-u * 2.7)
    bass = .19 * body * (math.sin(2 * math.pi * 110 * u) + .24 * math.sin(2 * math.pi * 220 * u))
    bell = 0.0
    for onset, freq, gain in ((.46, 880, .22), (.55, 1320, .11), (.65, 1760, .055)):
        age = t - onset
        if age >= 0:
            attack = 1 - math.exp(-age * 190)
            bell += gain * attack * (
                math.sin(2 * math.pi * freq * age) * math.exp(-age * 2.1)
                + .22 * math.sin(2 * math.pi * freq * 2.006 * age) * math.exp(-age * 4.7)
                + .065 * math.sin(2 * math.pi * freq * 3.93 * age) * math.exp(-age * 8)
            )
    dry.append(breath + bass + bell)

stereo = []
for i, sample in enumerate(dry):
    channels = []
    for side in range(2):
        value = sample * .84
        for delay, gain in ((.071, .15), (.127, .10), (.193, .075), (.283, .05), (.419, .032)):
            pos = i - int((delay + side * .011) * rate)
            if pos >= 0:
                value += dry[pos] * gain
        # Smoothly close the reverb tail; no hard cut or click.
        fade = min(1, i / (rate * .015)) * min(1, (frames - 1 - i) / (rate * .55))
        channels.append(value * max(0, fade))
    stereo.extend(channels)
peak = max(abs(value) for value in stereo)
gain = .50 / max(peak, .001)  # -6 dBFS peak leaves comfortable headroom.
output = Path(__file__).resolve().parents[1] / 'Media' / 'Sounds' / 'Seuil-de-cristal.wav'
output.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(output), 'wb') as audio:
    audio.setnchannels(2)
    audio.setsampwidth(2)
    audio.setframerate(rate)
    audio.writeframes(b''.join(struct.pack('<h', round(value * gain * 32767)) for value in stereo))
with wave.open(str(output), 'rb') as audio:
    assert audio.getnframes() == frames and audio.getnchannels() == 2
assert stereo[0] == stereo[-1] == 0
print(f'{output}\n{duration:.1f}s, stereo PCM, 44.1 kHz, peak -6 dBFS')
