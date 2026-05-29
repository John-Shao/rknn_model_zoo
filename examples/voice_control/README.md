# Voice Control on RV1126B (shell validation)

Closed loop: **speak a command → zipformer ASR recognizes it → match keyword →
run an action → play a fixed Chinese feedback clip**.

```
mic (arecord) ─► zipformer ASR ─► keyword match ─► action (GPIO/serial/API)
                                              └─► aplay fixed feedback wav
```

This is the **quick-validation** form. Feedback phrases are a fixed set, so no
on-device Chinese TTS is needed — we pre-generate the clips on the PC. The
`mms_tts` model is **not** used in this phase (reserve it for later dynamic
playback in a resident C++ process).

## Two machines, clear split

| Step | Where | Notes |
|------|-------|-------|
| Convert onnx → rknn (`convert.py`) | PC (x86) | RKNN-Toolkit2 **2.3.2** (match board runtime) |
| Cross-compile demo (`build-linux.sh`) | PC | aarch64 toolchain |
| Generate fixed feedback wavs | PC | `gen_feedback.py` |
| Push artifacts | PC → board | `adb push` or `scp` |
| Run the loop | **board** | `voice_control.sh` |

## 1. PC: build the ASR demo for RV1126B

```sh
# convert zipformer (3 models)
cd examples/zipformer/model && ./download_model.sh && cd ../python
python convert.py ../model/encoder-epoch-99-avg-1.onnx rv1126b
python convert.py ../model/decoder-epoch-99-avg-1.onnx rv1126b
python convert.py ../model/joiner-epoch-99-avg-1.onnx  rv1126b

# cross-compile
cd ../../../
export GCC_COMPILER=/path/to/aarch64-linux-gnu   # if not already on PATH
./build-linux.sh -t rv1126b -a aarch64 -d zipformer
# -> install/rv1126b_linux_aarch64/rknn_zipformer_demo/
```

## 2. PC: generate fixed Chinese feedback clips

```sh
pip install edge-tts          # plus ffmpeg on PATH
cd examples/voice_control
python gen_feedback.py        # writes feedback/*.wav (16-bit mono 16kHz)
```
Edit `PHRASES` in `gen_feedback.py` to change the wording. Keep the basenames
(`light_on`, `light_off`, `not_understood`) in sync with `voice_control.sh`.

## 3. Push everything to the board

```sh
adb push install/rv1126b_linux_aarch64/rknn_zipformer_demo/ /data/
adb push examples/voice_control/feedback/      /data/voice_control/feedback/
adb push examples/voice_control/voice_control.sh /data/voice_control/
```

## 4. Board: check mic / speaker, then run

```sh
# verify ALSA tools and devices exist
which arecord aplay
arecord -l        # capture (mic) devices
aplay   -l        # playback (speaker) devices

# if the default device is wrong, set REC_DEV / PLAY_DEV in voice_control.sh
# e.g. REC_DEV="-D plughw:1,0"

chmod +x /data/voice_control/voice_control.sh
/data/voice_control/voice_control.sh
```

Press Enter, speak "开灯" / "关灯", and the board should run the action and play
the matching Chinese feedback.

## Wiring the real action

In `voice_control.sh`, `do_action()` currently just prints. Replace the lines
with your real control, e.g.:

```sh
light_on)  echo 1 > /sys/class/leds/your_led/brightness ;;
light_off) echo 0 > /sys/class/leds/your_led/brightness ;;
```
(or a `gpioset` / serial `echo > /dev/ttySx` / HTTP call).

## Next step (later): dynamic Chinese TTS

For arbitrary spoken feedback (numbers, time, free text) you need a resident
C++ process that keeps models loaded and uses a Chinese TTS. The bundled
`mms_tts` is English-only and its C++ tokenizer is hardcoded for English
(`process.cc: read_vocab/preprocess_input`), so a Chinese path requires porting
`mms-tts-cmn` (new vocab + uroman romanization + re-exported onnx). Out of scope
for this validation phase.
