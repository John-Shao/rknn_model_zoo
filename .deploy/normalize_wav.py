#!/usr/bin/env python3
# Peak-normalize a 16-bit mono wav to a target peak, write out, for ASR testing.
import sys, wave, array
src, dst = sys.argv[1], sys.argv[2]
target = float(sys.argv[3]) if len(sys.argv) > 3 else 0.85  # target peak fraction
w = wave.open(src, 'rb'); p = w.getparams(); data = w.readframes(w.getnframes()); w.close()
a = array.array('h'); a.frombytes(data)
peak = max((abs(x) for x in a), default=1) or 1
gain = (target * 32767) / peak
out = array.array('h', (max(-32768, min(32767, int(x * gain))) for x in a))
ww = wave.open(dst, 'wb'); ww.setparams(p); ww.writeframes(out.tobytes()); ww.close()
print(f"gain={gain:.2f}x  old_peak={peak}  new_peak={int(peak*gain)}")
