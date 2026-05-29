#!/bin/bash
# Survey the cross-compile environment (run on 192.168.126.129)
SDK=~/atk-dlrv1126b-sdk

echo "===== RKNN-Toolkit2: can python import it? ====="
python3 -c 'from rknn.api import RKNN; print("RKNN_IMPORT_OK", RKNN.__module__)' 2>&1 | tail -5

echo "===== rknn-toolkit2 dir layout ====="
ls "$SDK/external/rknn-toolkit2" 2>/dev/null
echo "--- packages (wheels) ---"
find "$SDK/external/rknn-toolkit2" -maxdepth 4 \( -name '*.whl' -o -name 'requirements*.txt' \) 2>/dev/null | head -20

echo "===== aarch64 toolchain candidates ====="
find / -maxdepth 8 -name 'aarch64-*-gcc' 2>/dev/null | head -20

echo "===== buildroot host toolchain ====="
ls "$SDK"/buildroot/output/*/host/bin/ 2>/dev/null | grep -iE 'gcc|g\+\+' | head

echo "===== prebuilts toolchain ====="
find "$SDK/prebuilts" -maxdepth 4 -name '*aarch64*' -type d 2>/dev/null | head

echo "===== gcc-linaro / arm toolchains in home/opt ====="
ls ~ /opt 2>/dev/null | grep -iE 'gcc|linaro|toolchain|aarch64'

echo "===== free disk ====="
df -h ~ | tail -1
