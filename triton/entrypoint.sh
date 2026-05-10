#!/bin/bash
set -e

echo "Downloading models from S3..."
python /opt/tritonserver/download_models.py
echo "Cleaning up model directory..."
rm -rf /models/lost+found

echo "Configuring models for single instance..."
for model_dir in /models/*/; do
    model_name=$(basename "$model_dir")
    [ "$model_name" = "lost+found" ] && continue
    if [ ! -f "$model_dir/config.pbtxt" ]; then
        cat > "$model_dir/config.pbtxt" <<EOF
instance_group [{ count: 1, kind: KIND_CPU }]
EOF
        echo "Created config for $model_name (1 instance)"
    fi
done

echo "Starting Triton Inference Server..."
tritonserver \
    --model-repository=/models \
    --http-port=8000 \
    --grpc-port=8001 \
    --metrics-port=8002 \
    --strict-model-config=false