#!/bin/bash
# Clone rknn_model_zoo (shallow) and download zipformer onnx models on the PC.
set -e
cd ~
if [ ! -d ~/rknn_model_zoo/.git ]; then
  rm -rf ~/rknn_model_zoo
  git clone --depth 1 https://github.com/airockchip/rknn_model_zoo.git ~/rknn_model_zoo
fi
cd ~/rknn_model_zoo
echo "=== repo head ==="; git log --oneline -1

echo "=== download zipformer onnx ==="
cd examples/zipformer/model
bash download_model.sh
echo "=== model dir ==="
ls -la
echo "ALL_DONE"
