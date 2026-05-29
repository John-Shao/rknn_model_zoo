#!/bin/sh
# ---------------------------------------------------------------------------
# Voice command control + fixed voice feedback (shell validation version)
# Target board: RV1126B (Linux, aarch64)
#
# Pipeline:  arecord (mic) -> zipformer ASR -> keyword match -> action
#                                                            -> aplay (fixed feedback wav)
#
# This is the "quick validation" form: simple, no resident process, model is
# reloaded on every recognition. Good enough to prove the closed loop works.
# ---------------------------------------------------------------------------

set -u

# ---- paths (adjust if you put files elsewhere) ----------------------------
ASR_DIR="/data/rknn_zipformer_demo"
ASR_BIN="$ASR_DIR/rknn_zipformer_demo"
ENC="$ASR_DIR/model/encoder-epoch-99-avg-1.rknn"
DEC="$ASR_DIR/model/decoder-epoch-99-avg-1.rknn"
JOIN="$ASR_DIR/model/joiner-epoch-99-avg-1.rknn"

FEEDBACK_DIR="/data/voice_control/feedback"   # holds the pre-generated wav files
NORM_PY="/data/voice_control/normalize_wav.py" # gain stage (boosts quiet recordings)
REC_WAV="/tmp/cmd.wav"
REC_SECONDS=4                                  # how long to record per command

# ALSA devices: leave empty to use defaults, or set e.g. CARD="-D plughw:1,0"
REC_DEV=""      # arecord device, e.g. "-D plughw:1,0"
PLAY_DEV=""     # aplay  device, e.g. "-D plughw:0,0"

export LD_LIBRARY_PATH="$ASR_DIR/lib:${LD_LIBRARY_PATH:-}"

# ---------------------------------------------------------------------------
say() {
    # $1 = feedback wav basename (without .wav)
    f="$FEEDBACK_DIR/$1.wav"
    if [ -f "$f" ]; then
        aplay $PLAY_DEV "$f" >/dev/null 2>&1
    else
        echo "[warn] feedback wav not found: $f"
    fi
}

do_action() {
    # $1 = action name. Replace the echo lines with real GPIO / serial / API calls.
    case "$1" in
        light_on)  echo "[action] turn light ON"  ;; # e.g. echo 1 > /sys/class/leds/xxx/brightness
        light_off) echo "[action] turn light OFF" ;; # e.g. echo 0 > /sys/class/leds/xxx/brightness
        *)         echo "[action] unknown: $1"    ;;
    esac
}

recognize() {
    # record from mic, run ASR, echo the recognized text on stdout
    arecord $REC_DEV -f S16_LE -r 16000 -c 1 -d "$REC_SECONDS" "$REC_WAV" >/dev/null 2>&1
    # The on-board mic records at a low level; boost it so the ASR model gets
    # enough signal energy (peak-normalize to 90%, capped at 12x to avoid
    # over-amplifying pure silence). Falls back to the raw wav if it fails.
    rec_in="$REC_WAV"
    if [ -f "$NORM_PY" ] && python3 "$NORM_PY" "$REC_WAV" "$REC_WAV.norm" 0.9 12 >/dev/null 2>&1; then
        rec_in="$REC_WAV.norm"
    fi
    cd "$ASR_DIR" || return 1
    "$ASR_BIN" "$ENC" "$DEC" "$JOIN" "$rec_in" 2>/dev/null \
        | sed -n 's/^Zipformer output: //p'
}

# ---------------------------------------------------------------------------
echo "=== Voice control demo (RV1126B) ==="
echo "Press Enter to speak a command (Ctrl+C to quit). Recording ${REC_SECONDS}s each time."

while true; do
    printf "\n[ready] press Enter, then speak... "
    read _ || break

    text="$(recognize)"
    echo "[asr] recognized: \"$text\""

    # keyword matching against the recognized Chinese/English text
    case "$text" in
        *开灯*|*打开灯*|*turn*on*)
            do_action light_on;  say light_on ;;
        *关灯*|*关闭灯*|*turn*off*)
            do_action light_off; say light_off ;;
        "")
            say not_understood ;;        # nothing recognized
        *)
            echo "[asr] no matching command"
            say not_understood ;;
    esac
done
