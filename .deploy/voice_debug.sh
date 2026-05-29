#!/bin/sh
# Debug one capture: record 4s, play it back, measure level, run ASR.
W=/tmp/dbg.wav
ASR_DIR=/data/rknn_zipformer_demo
export LD_LIBRARY_PATH=$ASR_DIR/lib

echo ">>> Get ready..."
sleep 1
echo ">>> GO! Speak NOW (loud, mouth close to mic): 开灯"
arecord -f S16_LE -r 16000 -c 1 -d 4 "$W" 2>/dev/null
echo
echo ">>> Playing back what was recorded (you should hear your own voice):"
aplay "$W" 2>/dev/null
echo
echo ">>> Recorded level:"
python3 /data/analyze_wav.py "$W"
echo
echo ">>> ASR recognized:"
(cd "$ASR_DIR" && ./rknn_zipformer_demo \
    model/encoder-epoch-99-avg-1.rknn \
    model/decoder-epoch-99-avg-1.rknn \
    model/joiner-epoch-99-avg-1.rknn \
    "$W" 2>/dev/null | grep 'Zipformer output:')
echo ">>> (wav saved at $W)"
