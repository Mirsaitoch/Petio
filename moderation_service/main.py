from fastapi import FastAPI, APIRouter, File, UploadFile
from pydantic import BaseModel
from PIL import Image
import io
import numpy as np
from contextlib import asynccontextmanager

from triton_client import triton_client
from preprocessing import get_image_preprocessor, get_text_preprocessor
from constants import LABELS, CLASSES_NAME
from tools import softmax

# --- Кэш для label features ---
cached_label_features = None

def get_label_features() -> np.ndarray:
    """Возвращает кэшированные embeddings для LABELS"""
    global cached_label_features
    
    if cached_label_features is None:
        preprocessor = get_text_preprocessor()
        input_ids, attention_mask = preprocessor.preprocess_clip_texts(LABELS)
        cached_label_features = triton_client.infer_clip_text(input_ids, attention_mask)
        print(f"Label features cached: shape {cached_label_features.shape}")
    
    return cached_label_features

# --- Lifespan: предзагрузка при старте ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: кэшируем label features
    print("Precomputing label features...")
    get_label_features()
    print("Ready!")
    yield
    # Shutdown: очистка если нужно
    print("Shutting down...")

app = FastAPI(title="ONNX Detoxify API via Triton", lifespan=lifespan)

router = APIRouter()

# --- Text request ---
class TextRequest(BaseModel):
    text: str

@router.post("/texts_scores")
async def texts_scores(request: TextRequest):
    preprocessor = get_text_preprocessor()
    input_ids, attention_mask = preprocessor.preprocess_toxicity(request.text)
    
    logits = triton_client.infer_toxicity(input_ids, attention_mask)
    outputs = {name: round(float(prob) * 100, 2) for name, prob in zip(CLASSES_NAME, softmax(logits[0]))}
    return outputs

# --- Image request ---
@router.post("/images_scores")
async def images_scores(image: UploadFile = File(...)):
    if not image.content_type.startswith("image/"):
        return {"error": "File is not an image"}

    image_bytes = await image.read()
    pil_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")

    img_preproc = get_image_preprocessor()

    # NSFW
    nsfw_input = img_preproc.preprocess_nsfw(pil_image)
    nsfw_logits = triton_client.infer_nsfw(nsfw_input)
    nsfw_score = float(softmax(nsfw_logits[0])[1])

    # CLIP vision
    clip_input = img_preproc.preprocess_clip(pil_image)
    image_features = triton_client.infer_clip_vision(clip_input)

    # CLIP text - ИСПОЛЬЗУЕМ КЭШ
    text_features = get_label_features()  # <-- Теперь из кэша!


    logit_scale = 100
    logits = (image_features @ text_features.T) * logit_scale
    probs = softmax(logits[0])
    clip_result = {LABELS[i]: float(probs[i]) for i in range(len(LABELS))}


    porn_score = (
        clip_result.get("pornographic image", 0) +
        clip_result.get("explicit sexual content", 0) +
        clip_result.get("bestiality", 0)
    )

    violence_score = (
        clip_result.get("graphic violence with blood", 0) +
        clip_result.get("dead animal", 0)
    )

    abuse_score = (
        clip_result.get("animal abuse", 0) +
        clip_result.get("a person hurting an animal", 0) +
        clip_result.get("animal fight", 0)
    )

    decision = {
        "nsfw_score": nsfw_score,
        "porn_score": porn_score,
        "violence_score": violence_score,
        "abuse_score": abuse_score,
        "block": False,
        "reason": None
    }

    if nsfw_score > 0.7 or porn_score > 0.6:
        decision["block"] = True
        decision["reason"] = "pornographic_content"
    elif violence_score > 0.55:
        decision["block"] = True
        decision["reason"] = "graphic_violence"
    elif abuse_score > 0.5:
        decision["block"] = True
        decision["reason"] = "animal_abuse"

    return decision

# --- Register router ---
app.include_router(router)