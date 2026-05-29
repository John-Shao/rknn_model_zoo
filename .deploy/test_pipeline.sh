#!/bin/sh
# Non-interactive pipeline test: feed a wav file through ASR -> match -> action -> feedback.
# Mirrors voice_control.sh exactly, but reads a wav instead of recording from mic.
ASR_DIR="/data/rknn_zipformer_demo"
FEEDBACK_DIR="/data/voice_control/feedback"
export LD_LIBRARY_PATH="$ASR_DIR/lib"
WAV="$1"

text=$(cd "$ASR_DIR" && ./rknn_zipformer_demo \
    model/encoder-epoch-99-avg-1.rknn \
    model/decoder-epoch-99-avg-1.rknn \
    model/joiner-epoch-99-avg-1.rknn \
    "$WAV" 2>/dev/null | sed -n 's/^Zipformer output: //p')

echo "[asr] recognized: \"$text\""
case "$text" in
    *开灯*|*打开灯*) echo "[action] turn light ON";  aplay "$FEEDBACK_DIR/light_on.wav"  2>/dev/null ;;
    *关灯*|*关闭灯*) echo "[action] turn light OFF"; aplay "$FEEDBACK_DIR/light_off.wav" 2>/dev/null ;;
    "")              echo "[no speech]";              aplay "$FEEDBACK_DIR/not_understood.wav" 2>/dev/null ;;
    *)               echo "[no matching command]";    aplay "$FEEDBACK_DIR/not_understood.wav" 2>/dev/null ;;
esac
echo "[done]"
