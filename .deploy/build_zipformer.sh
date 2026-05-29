#!/bin/bash
# Cross-compile zipformer demo for RV1126B (aarch64) using the prebuilt gcc-arm 10.3 toolchain.
set -e
cd ~/rknn_model_zoo
TC=~/atk-dlrv1126b-sdk/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu
export GCC_COMPILER="$TC/bin/aarch64-none-linux-gnu"

echo "=== compiler ==="
"${GCC_COMPILER}-gcc" --version | head -1

echo "=== build ==="
chmod +x ./build-linux.sh 2>/dev/null || true
bash ./build-linux.sh -t rv1126b -a aarch64 -d zipformer

echo "=== install dir listing ==="
D=install/rv1126b_linux_aarch64/rknn_zipformer_demo
ls -la "$D"
echo "--- lib ---"; ls -la "$D/lib"
echo "--- model ---"; ls -la "$D/model"
echo "--- binary file type ---"; file "$D/rknn_zipformer_demo"
echo BUILD_DONE
