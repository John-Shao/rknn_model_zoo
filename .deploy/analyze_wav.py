#!/usr/bin/env python3
import sys, wave, struct
w = wave.open(sys.argv[1], 'rb')
n = w.getnframes(); ch = w.getnchannels(); sw = w.getsampwidth(); sr = w.getframerate()
data = w.readframes(n); w.close()
if sw != 2:
    print("not 16-bit"); sys.exit(0)
import array
a = array.array('h'); a.frombytes(data)
if ch == 2:
    a = a[0::2]
peak = max((abs(x) for x in a), default=0)
rms = (sum(x*x for x in a)/len(a))**0.5 if a else 0
print(f"frames={n} ch={ch} sr={sr} dur={n/sr:.2f}s")
print(f"peak={peak}/32767 ({100*peak/32767:.1f}%)  rms={rms:.0f}")
print("VERDICT:", "SILENT/too low (mic not capturing)" if peak < 500 else
                  "weak" if peak < 3000 else "OK signal present")
