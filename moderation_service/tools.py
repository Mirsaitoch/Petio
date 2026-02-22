import numpy as np
import boto3
import os

# S3_BUCKET = ""
# s3_client = boto3.client("s3", aws_access_key_id="YOUR_KEY", aws_secret_access_key="YOUR_SECRET", region_name="YOUR_REGION")

# def download_from_s3(s3_key: str, local_path: str):
#     """
#     Загружает файл из S3, если он ещё не скачан локально
#     """
#     if not os.path.exists(local_path):
#         os.makedirs(os.path.dirname(local_path), exist_ok=True)
#         s3_client.download_file(S3_BUCKET, s3_key, local_path)
#         print(f"Downloaded {s3_key} to {local_path}")
#     else:
#         print(f"File {local_path} already exists, skipping download")

def softmax(x):
    e_x = np.exp(x - np.max(x))
    return e_x / e_x.sum(axis=0)


