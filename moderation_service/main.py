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
from moderation import moderate_image, moderate_text


# --- Cache ---
_label_features_cache: np.ndarray | None = None


def get_label_features() -> np.ndarray:
    global _label_features_cache
    
    if _label_features_cache is None:
        preprocessor = get_text_preprocessor()
        input_ids, attention_mask = preprocessor.preprocess_clip_texts(LABELS)
        _label_features_cache = triton_client.infer_clip_text(input_ids, attention_mask)
        print(f"Label features cached: shape {_label_features_cache.shape}")
    
    return _label_features_cache


# --- Lifespan ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("Precomputing label features...")
    get_label_features()
    print("Ready!")
    yield
    print("Shutting down...")


app = FastAPI(title="Content Moderation API", lifespan=lifespan)
router = APIRouter()


# --- Text moderation ---
class TextRequest(BaseModel):
    text: str


@router.post("/texts_scores")
async def texts_scores(request: TextRequest):
    preprocessor = get_text_preprocessor()
    input_ids, attention_mask = preprocessor.preprocess_toxicity(request.text)
    
    logits = triton_client.infer_toxicity(input_ids, attention_mask)
    probs = softmax(logits[0])
    
    scores = {name: float(prob) for name, prob in zip(CLASSES_NAME, probs)}
    
    return moderate_text(scores)


# --- Image moderation ---
@router.post("/images_scores")
async def images_scores(image: UploadFile = File(...)):
    if not image.content_type.startswith("image/"):
        return {"error": "File is not an image"}

    image_bytes = await image.read()
    pil_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")

    img_preproc = get_image_preprocessor()

    # NSFW score
    nsfw_input = img_preproc.preprocess_nsfw(pil_image)
    nsfw_logits = triton_client.infer_nsfw(nsfw_input)
    nsfw_score = float(softmax(nsfw_logits[0])[1])

    # CLIP classification
    clip_input = img_preproc.preprocess_clip(pil_image)
    image_features = triton_client.infer_clip_vision(clip_input)
    text_features = get_label_features()

    logit_scale = 100
    logits = (image_features @ text_features.T) * logit_scale
    probs = softmax(logits[0])
    
    clip_result = {LABELS[i]: float(probs[i]) for i in range(len(LABELS))}

    return moderate_image(nsfw_score, clip_result)


app.include_router(router)