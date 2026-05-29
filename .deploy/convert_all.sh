#!/bin/bash
# Download zipformer onnx + convert all 3 models to rknn (rv1126b, fp).
set -e
source ~/rknnenv/bin/activate
cd ~/rknn_model_zoo/examples/zipformer

echo "=== rknn import check ==="
python -c "from rknn.api import RKNN; print('RKNN_READY')"

echo "=== download onnx ==="
cd model
bash download_model.sh
echo "--- onnx files ---"
ls -la *.onnx

echo "=== convert encoder ==="
cd ../python
python convert.py ../model/encoder-epoch-99-avg-1.onnx rv1126b
echo "=== convert decoder ==="
python convert.py ../model/decoder-epoch-99-avg-1.onnx rv1126b
echo "=== convert joiner ==="
python convert.py ../model/joiner-epoch-99-avg-1.onnx rv1126b

echo "=== resulting rknn files ==="
ls -la ../model/*.rknn
echo "CONVERT_ALL_DONE"
