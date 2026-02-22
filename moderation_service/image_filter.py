import numpy as np
from PIL import Image
from transformers import AutoImageProcessor, PreTrainedTokenizerFast
import onnxruntime as ort
from tools import softmax
from constants import LABELS

# NSFW модель
nsfw_processor = AutoImageProcessor.from_pretrained("nsfw_processor/preprocessor_config.json")
nsfw_ort_session = ort.InferenceSession("models/image_filter/nsfw_model/nsfw_image_detection.onnx")

# CLIP модель
clip_image_processor = AutoImageProcessor.from_pretrained("clip_processor/processor_config.json")
clip_ort_image_session = ort.InferenceSession("models/image_filter/clip_model/clip_vision_model.onnx")
clip_tokenizer = PreTrainedTokenizerFast(tokenizer_file="clip_processor/tokenizer.json")
clip_ort_text_session = ort.InferenceSession("models/image_filter/clip_model/clip_text_model.onnx")
if clip_tokenizer.pad_token is None:
    clip_tokenizer.add_special_tokens({'pad_token': '<|endoftext|>'})

def nsfw_predict(image: Image.Image):
    inputs = nsfw_processor(images=image, return_tensors="pt")
    ort_inputs = {"pixel_values": inputs["pixel_values"].numpy()}
    logits = nsfw_ort_session.run(None, ort_inputs)[0][0]
    probs = softmax(logits)
    return probs[1]

def clip_predict(image: Image.Image, texts=LABELS):
    vision_inputs = clip_image_processor(images=image, return_tensors="pt")
    ort_inputs = {"pixel_values": vision_inputs["pixel_values"].numpy().astype(np.float32)}
    image_features = clip_ort_image_session.run(None, ort_inputs)[0]

    text_features_list = []
    for i in range(len(texts)):
        batch_texts = texts[i:i+1]
        text_inputs = clip_tokenizer(text=batch_texts, return_tensors="np", padding=True, truncation=True)
        ort_inputs_text = {
            "input_ids": text_inputs["input_ids"].astype(np.int64),
            "attention_mask": text_inputs["attention_mask"].astype(np.int64)
        }
        batch_emb = clip_ort_text_session.run(None, ort_inputs_text)[0]
        text_features_list.append(batch_emb)

    text_features = np.vstack(text_features_list)
    logit_scale = 100
    logits = (image_features @ text_features.T) * logit_scale
    probs = softmax(logits[0])

    return {LABELS[i]: float(probs[i]) for i in range(len(LABELS))}