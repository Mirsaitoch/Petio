#!/bin/bash
set -e

echo "Downloading models from S3..."
python /opt/tritonserver/download_models.py
echo "Starting Triton Inference Server..."
tritonserver \
    --model-repository=/models \
    --http-port=8000 \
    --grpc-port=8001 \
    --metrics-port=8002 \
    --strict-model-config=false
