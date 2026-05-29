#!/usr/bin/env python3
# Peak-normalize a 16-bit mono wav so the ASR model gets enough signal energy.
# The on-board mic records at a low level (~20% peak); zipformer returns empty
# unless the speech is boosted. Usage:
#   normalize_wav.py <in.wav> <out.wav> [target_peak=0.9] [max_gain=12]
# max_gain caps amplification so near-silence is not blown up into noise.
import sys, wave, array

src, dst = sys.argv[1], sys.argv[2]
target = float(sys.argv[3]) if len(sys.argv) > 3 else 0.9
max_gain = float(sys.argv[4]) if len(sys.argv) > 4 else 12.0

w = wave.open(src, 'rb'); p = w.getparams(); data = w.readframes(w.getnframes()); w.close()
a = array.array('h'); a.frombytes(data)
peak = max((abs(x) for x in a), default=1) or 1
gain = min(max_gain, (target * 32767) / peak)
out = array.array('h', (max(-32768, min(32767, int(x * gain))) for x in a))
ww = wave.open(dst, 'wb'); ww.setparams(p); ww.writeframes(out.tobytes()); ww.close()
print(f"gain={gain:.2f}x old_peak={peak} new_peak={int(min(32767, peak*gain))}")
