"""Build Omega's original synthesized cues. Requires numpy and imageio-ffmpeg.

No sampled recordings. Only OGG outputs are kept; PCM passes through stdin.
"""
import json
import math
from pathlib import Path
import subprocess
import numpy as np
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'Music'
RATE = 44100
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
FAMILIES = [
    ('desert', 'Désert / Moyen-Orient', 'Oud et souffle de ney', 146.83),
    ('asie', 'Asiatique', 'Cordes pincées et flûte', 293.66),
    ('bambou', 'Bambou / Bois', 'Bambou creux et bois', 392.00),
    ('cordes', 'Cordes / Médiéval', 'Luth et lyre', 196.00),
    ('tambours', 'Tambours / Percussions', 'Peaux et résonances', 82.41),
    ('foret', 'Forêt / Nature', 'Feuillage et chant bref', 440.00),
    ('montagne', 'Montagne / Neige', 'Vent froid et clochette', 220.00),
    ('mer', 'Mer / Port', 'Vague et cloche de port', 164.81),
    ('magie', 'Magie / Sanctuaire', 'Cristal et halo harmonique', 440.00),
    ('ruines', 'Ruines / Sombre', 'Pierre et corde frottée', 110.00),
    ('ville', 'Ville / Auberge', 'Luth chaleureux et clochette', 246.94),
    ('danger', 'Danger / Combat', 'Tambour et tension métallique', 73.42),
]
MOODS = [('paisible', 'Paisible', [0, 7, 12], 1.0),
         ('mysterieux', 'Mystérieux', [0, 3, 10], .89),
         ('menacant', 'Menaçant', [0, 1, 7], .67)]

def voice(kind, frequency, duration, rng):
    t = np.arange(int(duration * RATE)) / RATE
    attack = 1 - np.exp(-t * (24 if kind in ('flute', 'bow', 'pad') else 280))
    if kind in ('pluck', 'lute'):
        result = np.zeros(len(t))
        for h in range(1, 9):
            result += np.sin(2*np.pi*frequency*h*t) * np.exp(-t*(2.8+h*.8)) / h**1.5
        result += rng.normal(0, .016, len(t))*np.exp(-t*110)
    elif kind in ('bell', 'crystal', 'metal', 'wood'):
        ratios = {'bell':[1,2.01,2.76,4.07], 'crystal':[1,2,3.997,5.01],
                  'metal':[1,1.47,2.09,3.14], 'wood':[1,2.76,5.40]}[kind]
        decay = 15 if kind=='wood' else 2.6
        result = sum(np.sin(2*np.pi*frequency*r*t)*np.exp(-t*(decay+i*2.5))/(1+i*3)
                     for i,r in enumerate(ratios))
    elif kind == 'drum':
        # Integral of an exponentially falling pitch, plus a soft stick attack.
        phase = 2*np.pi*frequency*(t+.9*(1-np.exp(-t*22))/22)
        result = np.sin(phase)*np.exp(-t*9)+rng.normal(0,.18,len(t))*np.exp(-t*65)
    elif kind == 'flute':
        vibrato = .004*np.sin(2*np.pi*4.3*t)
        phase = 2*np.pi*np.cumsum(frequency*(1+vibrato))/RATE
        result = (np.sin(phase)+.12*np.sin(2*phase)+rng.normal(0,.025,len(t)))*np.exp(-t*2)
    elif kind == 'bow':
        phase = 2*np.pi*frequency*t+.16*np.sin(2*np.pi*4*t)
        result = sum(np.sin(h*phase)/(h**1.6) for h in range(1,7))*np.exp(-t*2.4)
    elif kind == 'pad':
        result = (np.sin(2*np.pi*frequency*t)+.28*np.sin(2*np.pi*frequency*1.501*t))*np.exp(-t*2)
    elif kind == 'bird':
        phase = 2*np.pi*(frequency*3*t+frequency*.9*(1-np.exp(-t*12))/12)
        result = np.sin(phase)*np.sin(np.minimum(t/.22,1)*np.pi)**2*np.exp(-t*8)
    else:
        raise ValueError(kind)
    return result * attack

def render(family, base, mood, steps, pitch, long, seed):
    rng = np.random.default_rng(seed)
    duration = 2.9 if long else 1.25
    n = round(duration*RATE)
    t = np.arange(n)/RATE
    out = np.zeros(n)
    freq = base*pitch
    def add(kind, at, hz, volume, length=1.6):
        start = int(at*RATE)
        data = voice(kind,hz,min(length,duration-at),rng)
        out[start:start+len(data)] += data*volume
    def air(volume, swell=.8):
        noise = rng.normal(0,1,n)
        smooth = np.convolve(noise, np.ones(38)/38, mode='same')
        envelope = np.sin(np.minimum(t/swell,1)*np.pi)**2
        out[:] += smooth*envelope*volume
    instruments = {
        'desert':'lute','asie':'pluck','bambou':'wood','cordes':'lute',
        'tambours':'drum','foret':'wood','montagne':'bell','mer':'bell',
        'magie':'crystal','ruines':'bow','ville':'lute','danger':'drum',
    }
    if family in ('desert','foret','montagne','mer','ruines'): air(.20 if family!='mer' else .65, 1.1 if long else .7)
    offsets = [.12,.49,.91] if long else [.10]
    for j,at in enumerate(offsets):
        note = freq*2**(steps[j]/12)
        add(instruments[family],at,note,.34 if j==0 else .24)
    if family == 'desert': add('flute',.24 if long else .15,freq*2,.12)
    if family == 'asie': add('flute',.32 if long else .17,freq,.15)
    if family == 'bambou': add('wood',.27,freq*.72,.22,.45)
    if family == 'cordes': add('pluck',.14,freq*1.5,.15)
    if family == 'tambours': add('wood',.25,freq*3.1,.13,.3)
    if family == 'foret': add('bird',.30 if long else .17,freq,.17,.4)
    if family == 'montagne': add('pad',.18,freq*.5,.18)
    if family == 'mer': add('wood',.22,freq*.8,.10,.6)
    if family == 'magie': add('pad',.18,freq*.5,.17)
    if family == 'ruines': add('wood',.11,freq*1.4,.28,.7)
    if family == 'ville': add('bell',.22,freq*3,.05)
    if family == 'danger':
        add('metal',.13,freq*4,.19)
        add('bow',.18,freq*2.03,.12)
    if mood == 'menacant': add('pad',.13,freq*.5,.16)
    wet = out.copy()
    for delay,gain in ((.067,.12),(.119,.085),(.191,.06),(.307,.035)):
        shift = int(delay*RATE)
        wet[shift:] += out[:-shift]*gain
    # Smooth fade for sample starts and reverb tails.
    wet *= np.minimum(1,t/.012)*np.sin(np.minimum(1,(duration-t)/.38)*np.pi/2)**2
    wet -= wet.mean()
    wet *= np.minimum(1,t/.005)*np.minimum(1,(duration-t)/.015)
    peak = np.max(np.abs(wet))
    rms = np.sqrt(np.mean(wet**2))
    wet *= min(.52/max(peak,1e-9), .095/max(rms,1e-9))
    return wet.astype('<f4')

def main():
    DEST.mkdir(exist_ok=True)
    catalog = []
    for i,(key,label,instrument,base) in enumerate(FAMILIES):
        for m,(mood,mood_label,steps,pitch) in enumerate(MOODS):
            for long in (False,True):
                filename = f'omega_{key}_{mood}_{"phrase" if long else "accent"}.ogg'
                samples = render(key,base,mood,steps,pitch,long,1024+i*100+m*10+int(long))
                output = DEST/filename
                subprocess.run([FFMPEG,'-v','error','-y','-f','f32le','-ar',str(RATE),'-ac','1','-i','pipe:0',
                                '-c:a','libvorbis','-q:a','3','-map_metadata','-1',str(output)],input=samples.tobytes(),check=True)
                decoded = subprocess.run([FFMPEG,'-v','error','-i',str(output),'-f','f32le','-ac','1','-ar',str(RATE),'pipe:1'],capture_output=True,check=True)
                check = np.frombuffer(decoded.stdout,dtype='<f4')
                assert np.isfinite(check).all() and np.max(np.abs(check)) < .9
                assert np.sqrt(np.mean(check**2)) > .015
                assert abs(len(check)-len(samples)) < RATE*.03
                assert max(np.max(np.abs(check[:100])),np.max(np.abs(check[-100:]))) < .015
                catalog.append({'file':filename,'family':label,'name':mood_label+' — '+('Phrase' if long else 'Accent'),
                                'instrument':instrument,'seconds':round(len(samples)/RATE,2),'bytes':output.stat().st_size})
        print(label, '— 6 OGG checked')
    # Preserve user-added music files when rebuilding the manifest.
    files = sorted(p.name for p in DEST.iterdir() if p.suffix.lower() in ('.ogg','.mp3','.wav'))
    quote = lambda value: json.dumps(value,ensure_ascii=False)
    manifest = '-- Generated by Tools/sound-library.py; includes user music files.\nZoneGateMusicManifest = {\n'
    manifest += ''.join('    '+quote(name)+',\n' for name in files)+'}\nZoneGateSoundCatalog = {\n'
    for entry in catalog:
        manifest += '    ['+quote(entry['file'])+'] = { family = '+quote(entry['family'])+', name = '+quote(entry['name'])+' },\n'
    (DEST/'Manifest.lua').write_text(manifest+'}\n',encoding='utf-8')
    (DEST/'Catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'{len(catalog)} cues; {sum(e["bytes"] for e in catalog)/1048576:.2f} MiB total')

if __name__ == '__main__': main()
