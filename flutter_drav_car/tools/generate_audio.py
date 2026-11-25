"""Generate original, quiet game sounds. Python standard library only."""
import math, wave, struct
from pathlib import Path
out = Path(__file__).resolve().parents[1] / 'assets/audio'
out.mkdir(parents=True, exist_ok=True)
rate = 22050

def write(name, notes, length, gain=.25):
    data = [0.] * int(rate * length)
    for start, duration, freq, volume in notes:
        for i in range(int(duration * rate)):
            t = i / rate
            index = int(start * rate) + i
            if index >= len(data): break
            envelope = min(1, t / .015) * max(0, 1 - t / duration)**1.8
            tone = math.sin(2 * math.pi * freq * t) + .16 * math.sin(4 * math.pi * freq * t)
            data[index] += tone * envelope * volume * gain
    with wave.open(str(out / (name + '.wav')), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(rate)
        f.writeframes(b''.join(struct.pack('<h', int(max(-.95, min(.95, v))*32767)) for v in data))
write('coin', [(0,.16,880,1),(.08,.25,1320,.8)], .4)
write('bump', [(0,.25,160,.65),(.04,.22,220,.4)], .35)
write('start', [(i*.28,.2,f,.65) for i,f in enumerate([523,659,784])], 1)
write('go', [(0,.35,1046,.7),(.05,.3,1318,.4)], .5)
write('finish', [(i*.16,.6,f,.65) for i,f in enumerate([523,659,784,1046,1318])], 1.5)
melody = [523,0,659,784,659,0,587,0,523,659,784,0,880,784,659,0,587,0,698,880,784,0,659,0,587,659,523,0,392,0,523,0]
notes = [(i*.4,.36,f,.4) for i,f in enumerate(melody) if f]
for i in range(16):
    notes.append((i*.8,.65,[262,220,175,196][i//4],.23))
write('music', notes, 12.8, .19)

# Traditional nursery melodies, newly sequenced and synthesized here (no lyrics/recordings).
# C-major music-box arrangement at a comfortable 108 beats/minute.
pitches = {'C':523.251, 'D':587.330, 'E':659.255, 'F':698.456,
           'G':783.991, 'A':880.000, 'g':391.995}

def nursery(name, phrases):
    beat = 60 / 108
    melody_notes = []
    position = 0.
    for phrase in phrases:
        for pitch, beats in phrase:
            melody_notes.append((position * beat, beats * beat * .94, pitches[pitch], .58))
            position += beats
    # Warm, quiet accompaniment on alternating bass and chord tones.
    for step in range(int(position)):
        bass = [261.626, 174.614, 195.998, 261.626][(step // 4) % 4]
        melody_notes.append((step * beat, beat * .8, bass if step % 2 == 0 else bass * 1.5, .17))
    write(name, melody_notes, position * beat, .30)

nursery('twinkle', [
    [('C',1),('C',1),('G',1),('G',1),('A',1),('A',1),('G',2)],
    [('F',1),('F',1),('E',1),('E',1),('D',1),('D',1),('C',2)],
    [('G',1),('G',1),('F',1),('F',1),('E',1),('E',1),('D',2)],
    [('G',1),('G',1),('F',1),('F',1),('E',1),('E',1),('D',2)],
    [('C',1),('C',1),('G',1),('G',1),('A',1),('A',1),('G',2)],
    [('F',1),('F',1),('E',1),('E',1),('D',1),('D',1),('C',2)],
])
nursery('frere', [
    [('C',1),('D',1),('E',1),('C',1)] * 2,
    [('E',1),('F',1),('G',2)] * 2,
    [('G',.5),('A',.5),('G',.5),('F',.5),('E',1),('C',1)] * 2,
    [('C',1),('g',1),('C',2)] * 2,
])
write('pickup', [(0,.2,659,.65),(.1,.25,880,.6),(.2,.35,1046,.5)], .65)
write('power', [(i*.08,.35,f,.6) for i,f in enumerate([523,659,784,1046])], .7)
write('guard', [(0,.25,392,.4),(.08,.3,587,.5)], .45)
write('horn', [(0,.2,392,.6),(.22,.28,523,.55)], .6)

write('transform', [(i*.09,.5,f,.55) for i,f in enumerate([392,523,659,784,1046])], 1)
write('smash', [(0,.16,110,.55),(.02,.12,175,.4),(.06,.2,262,.3)], .35)


# Layered, seamless vehicle and ambience loops. All samples are generated locally.
def waveform(name, seconds, sample):
    import random
    rng = random.Random(29)
    data = bytearray()
    for i in range(int(rate * seconds)):
        t = i / rate
        value = sample(t, rng)
        data.extend(struct.pack('<h', int(max(-.9, min(.9, value)) * 32767)))
    with wave.open(str(out / (name + '.wav')), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(rate); f.writeframes(data)

def sine(f,t): return math.sin(2*math.pi*f*t)
def pulse(t,period,decay): return math.exp(-(t % period)*decay)
waveform('engine_car',2,lambda t,r: .19*sine(60,t)*(1+.16*sine(8,t))+.06*sine(120,t)+.025*sine(180,t))
waveform('engine_plane',2,lambda t,r: .12*sine(120,t)+.09*sine(36,t)*(1+.4*sine(12,t))+.03*sine(240,t))
waveform('engine_tank',2,lambda t,r: .17*sine(45,t)+.12*pulse(t,.25,28)*sine(130,t)+.035*sine(90,t))
waveform('engine_dinosaur',1.6,lambda t,r: .32*pulse(t,.4,22)*sine(75,t)+.04*sine(150,t)*pulse(t,.4,18))
waveform('engine_peppa',1.6,lambda t,r: .22*pulse(t,.4,30)*sine(175,t)+.08*pulse(t,.8,16)*sine(262,t))
waveform('ambient_grass',4,lambda t,r: .035*sine(92,t)*(1+.4*sine(.25,t))+.025*sine(1600+40*sine(2,t),t)*max(0,sine(.5,t))**12)
waveform('ambient_sea',4,lambda t,r: (r.random()-.5)*.16*(.55+.45*sine(.25,t))+.018*sine(70,t))
waveform('ambient_candy',4,lambda t,r: .06*sine(1046.5,t)*pulse(t,1,7)+.035*sine(1318.5,t)*pulse(t,.5,12))
write('combo',[(i*.08,.35,f,.55) for i,f in enumerate([784,988,1175,1568])],.65)
write('near',[(0,.12,660,.4),(.07,.2,880,.35)],.3)
write('warning',[(0,.17,784,.35),(.2,.22,659,.3)],.5)
write('revert',[(0,.22,784,.45),(.12,.3,523,.45)],.5)
write('dino_voice',[(0,.2,196,.6),(.13,.3,247,.6),(.32,.3,294,.4)],.7)
write('pig_voice',[(0,.16,392,.6),(.16,.18,523,.6),(.32,.22,440,.4)],.65)
