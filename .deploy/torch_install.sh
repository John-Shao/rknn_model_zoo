#!/bin/bash
source ~/rknnenv/bin/activate
pip install "torch==2.4.0" --index-url https://download.pytorch.org/whl/cpu
echo "=== import test ==="
python -c "from rknn.api import RKNN; print('RKNN_IMPORT_OK')"
echo "TORCH_STEP_DONE"
