from fastapi import APIRouter, File, UploadFile
from pydantic import BaseModel
from PIL import Image
import io

from text_filter import predict_text
from image_filter import nsfw_predict, clip_predict

router = APIRouter()


class TextRequest(BaseModel):
    text: str


@router.post("/texts_scores")
async def texts_scores(request: TextRequest):
    return predict_text(request.text)


@router.post("/images_scores")
async def images_scores(image: UploadFile = File(...)):
    if not image.content_type.startswith("image/"):
        return {"error": "File is not an image"}

    image_bytes = await image.read()
    pil_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")

    nsfw_score = float(nsfw_predict(pil_image))
    clip_result = clip_predict(pil_image)

    porn_score = (
        clip_result["pornographic image"] +
        clip_result["explicit sexual content"] +
        clip_result["bestiality"]
    )

    violence_score = (
        clip_result["graphic violence with blood"] +
        clip_result["dead animal"]
    )

    abuse_score = (
        clip_result["animal abuse"] +
        clip_result["a person hurting an animal"] +
        clip_result["animal fight"]
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