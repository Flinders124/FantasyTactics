"""Original offline fantasy score and synthesized Foley. Python 3 + NumPy.
All random sources are local and seeded. Outputs are 48 kHz, PCM16 WAV.
No samples, online services or third-party musical material are used.
"""
from pathlib import Path
import json
import wave
import numpy as np

RATE = 48000
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "clips"
OUT.mkdir(exist_ok=True)
manifest = []


def clock(seconds):
    return np.arange(round(seconds * RATE), dtype=np.float64) / RATE


def noise(n, seed, smoothing=1):
    x = np.random.default_rng(seed).normal(0, 1, n)
    if smoothing > 1:
        x = np.convolve(x, np.ones(smoothing) / smoothing, mode="same")
    return x


def note(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def tone(t, f, decay=5, style="bell"):
    if style == "plucked":
        return sum(np.sin(2 * np.pi * f * k * t) * np.exp(-t * decay * (1 + k * .22)) / k ** 1.7 for k in range(1, 7))
    if style == "flute":
        attack = 1 - np.exp(-t * 30)
        return attack * np.exp(-t * decay) * (np.sin(2 * np.pi * f * t + .025 * np.sin(t * 31)) + .16 * np.sin(4 * np.pi * f * t))
    return sum(np.sin(2 * np.pi * f * k * t) * np.exp(-t * decay * (1 + k * .1)) / a for k, a in [(1, 1), (2.01, 4), (3.97, 9)])


def save(name, x, peak=.52, loop=False):
    # Small DC removal, headroom, no clipped or silent outputs. Endpoints taper.
    x = np.asarray(x)
    x -= x.mean(axis=0)
    if not loop:
        ramp = min(480, len(x) // 8)
        envelope = np.ones(len(x))
        envelope[:ramp] = np.linspace(0, 1, ramp)
        envelope[-ramp:] = np.linspace(1, 0, ramp)
        x *= envelope[:, None] if x.ndim == 2 else envelope
    x *= peak / max(1e-9, float(np.abs(x).max()))
    assert np.isfinite(x).all() and np.sqrt(np.mean(x*x)) > .002
    with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
        f.setnchannels(1 if x.ndim == 1 else x.shape[1])
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((x * 32767).astype("<i2").tobytes())
    manifest.append(dict(id=name, seconds=round(len(x)/RATE, 4), channels=1 if x.ndim == 1 else x.shape[1], peak=round(float(np.abs(x).max()), 4), rms=round(float(np.sqrt(np.mean(x*x))), 4), loop=loop, seam_delta=round(float(np.max(np.abs(x[0]-x[-1]))), 5)))


def foley(kind, variant):
    seed = 1200 + variant * 37 + sum(map(ord, kind))
    seconds = dict(step=.16, armour=.18, swing=.23, impact=.28, mace=.32, bow=.28, arrow=.22, damage=.18, death=.58)[kind]
    t = clock(seconds)
    n = noise(len(t), seed, 8)
    if kind == "step":
        # Stone shoe scrape with two low, damped sole resonances.
        x = .65*n*np.exp(-t*38) + .18*np.sin(2*np.pi*(100+variant*11)*t)*np.exp(-t*44)
        x += noise(len(t), seed+1, 25)*np.exp(-((t-.025)/.018)**2)
    elif kind == "armour":
        x = sum(np.sin(2*np.pi*f*t)*np.exp(-t*(25+i*9))*.12 for i, f in enumerate([1327+variant*23, 2173, 3291]))
        x += .2*n*np.exp(-t*45)
    elif kind == "swing":
        x = noise(len(t),seed,20)*np.sin(np.pi*t/seconds)**2*np.exp(-t*4)
        x += .05*np.sin(2*np.pi*(220*t-230*t*t)) * np.sin(np.pi*t/seconds)**2
    elif kind == "impact":
        x = n*np.exp(-t*35)+.2*np.sin(2*np.pi*140*t)*np.exp(-t*28)
        x += .13*tone(t, 670+variant*18,18)+.05*tone(t,1433,20)
    elif kind == "bow":
        x = .3*tone(t,125+variant*8,18,"plucked") + .2*n*np.exp(-t*35)
        x += .15*tone(t,330,20,"plucked")
    elif kind == "mace":
        x = n*np.exp(-t*30) + .5*np.sin(2*np.pi*85*t)*np.exp(-t*22)
        x += .08*tone(t,270+variant*14,15)
    elif kind == "arrow":
        x = noise(len(t),seed,3)*np.exp(-t*45)*.5 + np.sin(t*2*np.pi*210)*np.exp(-t*40)*.2
    elif kind == "damage":
        x = .5*n*np.exp(-t*30)+.3*np.sin(2*np.pi*(180*t-130*t*t))*np.exp(-t*35)
    else:
        x = noise(len(t),seed,35)*np.exp(-t*10)+.4*np.sin(2*np.pi*(76*t-35*t*t))*np.exp(-t*13)
        x += .07*tone(t,351,14)
    return x


def magic(kind):
    seconds = dict(mend=1.0, slow=.65, expire=.55, power=.55, fireburst=.9, arcane=.4, ui=.09)[kind]
    t = clock(seconds)
    if kind == "mend":
        x = sum(tone(np.maximum(t-d,0),note(m),5)*np.where(t>=d,1,0) for d,m in [(0,74),(.09,77),(.18,81)])
        x += noise(len(t),44,80)*np.exp(-t*5)*.4
    elif kind in ("slow","expire"):
        notes = [78,74,69] if kind=="slow" else [69,74,78]
        x = sum(tone(np.maximum(t-i*.075,0),note(m),9)*np.where(t>=i*.075,1,0) for i,m in enumerate(notes))
    elif kind == "power":
        x = np.zeros(len(t))
        x += noise(len(t),66,15)*np.exp(-t*16) + .5*np.sin(2*np.pi*72*t)*np.exp(-t*13)
        x += .12*tone(t,622,9)
    elif kind == "fireburst":
        # Fast ignition, layered low burst, crackling tail, no long roar masking turns.
        x = .9*noise(len(t),77,35)*(1-np.exp(-t*130))*np.exp(-t*8)
        x += .5*np.sin(2*np.pi*(65*t-18*t*t))*np.exp(-t*12)
        x += .09*noise(len(t),78,2)*np.exp(-t*7)*(np.sin(t*190)**8)
    elif kind == "arcane":
        x = tone(t,440,12)*.3 + .2*np.sin(2*np.pi*(920*t-600*t*t))*np.exp(-t*12)
    else:
        x = tone(t,880,45,"plucked")
    return x


def loop_score(name, bpm, combat=False):
    beat = 60/bpm
    n = round(32*beat*RATE)
    result = np.zeros((n,2))
    progression = [(50,53,57),(46,50,53),(53,57,60),(48,52,55),(43,46,50),(50,53,57),(46,50,53),(45,49,52)]

    def put(x, at, gain, pan):
        index = (np.arange(len(x))+round(at*RATE)) % n
        result[index,0] += x*gain*np.sqrt((1-pan)/2)
        result[index,1] += x*gain*np.sqrt((1+pan)/2)

    for bar,chord in enumerate(progression):
        for step in range(8):
            midi = chord[[0,1,2,1,0,2,1,2][step]]+12
            put(tone(clock(1.3),note(midi),5.5,"plucked"), (bar*4+step*.5)*beat,.11,(-.4 if step%2==0 else .4))
        for pitch in chord:
            put(tone(clock(4*beat+.8),note(pitch),1.1,"flute"),bar*4*beat,.035,0)
        if bar%2==0:
            put(tone(clock(1.7),note(chord[2]+24),2.3,"flute"),(bar*4+1.5)*beat,.055,-.15)
        if combat:
            t=clock(.35)
            drum=np.sin(2*np.pi*(75*t-48*t*t))*np.exp(-t*19)+noise(len(t),bar,20)*np.exp(-t*35)*.3
            for step in [0,2,3.5]: put(drum,(bar*4+step)*beat,.1,0)
    # Very quiet, circular echo: wraps tails instead of cutting loop boundaries.
    result += np.roll(result,round(.27*RATE),axis=0)*.16
    save(name,result,.30,True)


for kind in ["step","armour","swing","impact","mace","bow","arrow","damage","death"]:
    for variant in range(3): save(f"{kind}_{variant}",foley(kind,variant),.46 if kind!="armour" else .28)
for kind in ["mend","slow","expire","power","fireburst","arcane","ui"]:
    save(kind,magic(kind),.52 if kind!="ui" else .24)
for name,notes in [("victory",[62,65,69,74]),("defeat",[62,60,57,50]),("draw",[62,65,60,62])]:
    t=clock(1.6)
    x=np.zeros(len(t))
    for i,m in enumerate(notes):
        delay=i*.14
        x += tone(np.maximum(t-delay,0),note(m),3.5,"plucked")*(t>=delay)
    save(name,x,.38)
loop_score("menu",80)
loop_score("combat",100,True)
t=clock(12)
# Circular filtered noise plus periodic low wind components. No seam discontinuity.
n=len(t)
rng=np.random.default_rng(482)
freq=np.fft.rfftfreq(n,1/RATE)
coeff=(rng.normal(size=len(freq))+1j*rng.normal(size=len(freq)))/(1+(freq/340)**2)
coeff[freq<45]=0
wind=np.fft.irfft(coeff,n=n)
wind/=np.max(np.abs(wind))
ambient=np.stack([wind,np.roll(wind,3491)],axis=1)*(.75+.15*np.sin(2*np.pi*t/12))[:,None]
save("courtyard",ambient,.22,True)
(ROOT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
print(f"Generated {len(manifest)} original audio assets; {sum(x['seconds'] for x in manifest):.1f} seconds")
