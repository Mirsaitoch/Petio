import numpy as np
import boto3
import os
from dotenv import load_dotenv

load_dotenv()

S3_BUCKET = "petio-models"

aws_access_key_id = os.getenv("AWS_ACCESS_KEY_ID")
aws_secret_access_key = os.getenv("AWS_SECRET_ACCESS_KEY")
s3_client = boto3.client("s3", aws_access_key_id=aws_access_key_id, aws_secret_access_key=aws_secret_access_key, endpoint_url="https://storage.yandexcloud.net", region_name="ru-central1")

def download_all_from_s3(prefix: str, local_dir: str):

    paginator = s3_client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=S3_BUCKET, Prefix=prefix):
        for obj in page.get("Contents", []):
            s3_key = obj["Key"]

            if s3_key.endswith("/"):
                continue

            local_path = os.path.join(local_dir, os.path.relpath(s3_key, prefix))
            os.makedirs(os.path.dirname(local_path), exist_ok=True)
            s3_client.download_file(S3_BUCKET, s3_key, local_path)
            print(f"Downloaded {s3_key} → {local_path}")


def softmax(x):
    e_x = np.exp(x - np.max(x))
    return e_x / e_x.sum(axis=0)




