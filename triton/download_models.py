import boto3
import os

S3_BUCKET = "petio-models"
S3_ENDPOINT = "https://storage.yandexcloud.net"
S3_REGION = "ru-central1"

MODEL_MAPPING = {
    "image_filter/nsfw_model/nsfw_image_detection.onnx": "model_repository/nsfw_detector/1/model.onnx",
    "image_filter/clip_model/clip_vision_model.onnx": "model_repository/clip_vision/1/model.onnx",
    "image_filter/clip_model/clip_text_model.onnx": "model_repository/clip_text/1/model.onnx",
    "text_filter/detoxify_multilingual.onnx": "model_repository/text_toxicity/1/model.onnx",
}

def download_models():
    s3 = boto3.client("s3",
        aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
        endpoint_url=S3_ENDPOINT,
        region_name=S3_REGION
    )
    for s3_key, local_path in MODEL_MAPPING.items():
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        if not os.path.exists(local_path):
            print(f"Downloading {s3_key}")
            s3.download_file(S3_BUCKET, s3_key, local_path)

if __name__ == "__main__":
    download_models()
