FROM nvcr.io/nvidia/tritonserver:25.03-py3

WORKDIR /opt/tritonserver

RUN pip install boto3 onnx

RUN ln -sf /usr/bin/python3 /usr/bin/python

COPY download_models.py /opt/tritonserver/

COPY model_repository /models
COPY entrypoint.sh /opt/tritonserver/




RUN chmod +x /opt/tritonserver/entrypoint.sh

EXPOSE 8000 8001 8002

ENTRYPOINT ["/opt/tritonserver/entrypoint.sh"]