from fastapi import FastAPI
from api_router import router

app = FastAPI(title="ONNX Detoxify API (custom tokenizer)")

app.include_router(router)
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
