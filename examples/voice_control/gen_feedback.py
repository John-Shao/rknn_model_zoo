#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# Pre-generate the FIXED Chinese feedback wav clips on the PC (run on host,
# NOT on the board). Produces 16-bit / mono / 16 kHz wavs that aplay can play
# directly on RV1126B.
#
# This uses Microsoft Edge TTS (online, free, good Mandarin quality). Install:
#     pip install edge-tts
#
# If you have no internet on the host, just record the phrases yourself or use
# any other TTS; only the resulting wav files matter. Keep the basenames the
# same as referenced in voice_control.sh (light_on / light_off / not_understood).
# ---------------------------------------------------------------------------
import asyncio
import os
import subprocess

# basename -> Chinese phrase to synthesize
PHRASES = {
    "light_on":        "灯已打开",
    "light_off":       "灯已关闭",
    "not_understood":  "抱歉，没有听清",
}

VOICE = "zh-CN-XiaoxiaoNeural"
OUT_DIR = os.path.join(os.path.dirname(__file__), "feedback")


async def synth(text, mp3_path):
    import edge_tts
    await edge_tts.Communicate(text, VOICE).save(mp3_path)


def to_board_wav(mp3_path, wav_path):
    # 16-bit PCM, mono, 16 kHz — matches what aplay on the board expects
    subprocess.run(
        ["ffmpeg", "-y", "-i", mp3_path, "-ar", "16000", "-ac", "1",
         "-sample_fmt", "s16", wav_path],
        check=True,
    )


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, text in PHRASES.items():
        mp3 = os.path.join(OUT_DIR, name + ".mp3")
        wav = os.path.join(OUT_DIR, name + ".wav")
        print(f"[tts] {name}: {text}")
        asyncio.run(synth(text, mp3))
        to_board_wav(mp3, wav)
        os.remove(mp3)
        print(f"      -> {wav}")
    print(f"\nDone. Push '{OUT_DIR}' to the board at /data/voice_control/feedback/")


if __name__ == "__main__":
    main()
