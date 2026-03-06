FROM nvcr.io/nvidia/tritonserver:24.01-py3

WORKDIR /opt/tritonserver

RUN pip install boto3

COPY model_repository /models
COPY download_models.py /opt/tritonserver/
COPY entrypoint.sh /opt/tritonserver/
RUN chmod +x /opt/tritonserver/entrypoint.sh

EXPOSE 8000 8001 8002

ENTRYPOINT ["/opt/tritonserver/entrypoint.sh"]
