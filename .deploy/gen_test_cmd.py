#!/usr/bin/env python3
# Generate synthetic spoken-command wavs (16k mono s16) to test the ASR+match
# pipeline end-to-end without a live microphone.
import asyncio, os, subprocess
import edge_tts

CMDS = {"cmd_kaideng": "开灯", "cmd_guandeng": "关灯"}
VOICE = "zh-CN-YunxiNeural"   # a different voice than feedback, more natural male
OUT = "/tmp/cmdtest"

async def synth(text, mp3):
    await edge_tts.Communicate(text, VOICE).save(mp3)

def main():
    os.makedirs(OUT, exist_ok=True)
    for name, text in CMDS.items():
        mp3 = f"{OUT}/{name}.mp3"; wav = f"{OUT}/{name}.wav"
        asyncio.run(synth(text, mp3))
        subprocess.run(["ffmpeg","-y","-i",mp3,"-ar","16000","-ac","1","-sample_fmt","s16",wav],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        os.remove(mp3)
        print(f"{name}: {text} -> {wav}")
    print("CMD_GEN_DONE")

if __name__ == "__main__":
    main()
