import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    TRITON_URL: str = os.getenv("TRITON_URL", "localhost:8001")
    TRITON_HTTP_URL: str = os.getenv("TRITON_HTTP_URL", "http://localhost:8000")
    TOKENIZERS_PATH: str = os.getenv("TOKENIZERS_PATH", "/app/tokenizers")

settings = Settings()
