from fastapi import FastAPI
from api_router import router

app = FastAPI(title="ONNX Detoxify API (custom tokenizer)")

app.include_router(router)
