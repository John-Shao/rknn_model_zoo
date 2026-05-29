#!/bin/bash
# Install RKNN-Toolkit2 2.3.2 into a venv on the cross-compile PC (py3.8).
# Minimal deps: enough for ONNX -> RKNN fp conversion (no torch/tensorflow/opencv).
set -e
MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple/"
WHL=~/atk-dlrv1126b-sdk/external/rknn-toolkit2/rknn-toolkit2/packages/x86_64/rknn_toolkit2-2.3.2-cp38-cp38-manylinux_2_17_x86_64.manylinux2014_x86_64.whl

echo "=== wheel exists? ==="; ls -l "$WHL"
echo "=== create venv ==="
python3 -m venv ~/rknnenv
source ~/rknnenv/bin/activate
python -m pip install --upgrade pip -i "$MIRROR"

echo "=== install minimal deps ==="
pip install -i "$MIRROR" \
  "numpy<=1.26.4" "protobuf>=4.21.6,<=4.25.4" psutil "ruamel.yaml>=0.17.4" \
  "scipy>=1.5.4" "tqdm>=4.64.0" "fast-histogram>=0.11" \
  "onnx>=1.16.1" "onnxruntime>=1.10.0"

echo "=== install rknn-toolkit2 wheel (no extra deps) ==="
pip install --no-deps "$WHL"

echo "=== import test ==="
python -c "from rknn.api import RKNN; print('RKNN_IMPORT_OK')"
echo "ALL_DONE"
