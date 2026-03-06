import numpy as np
from PIL import Image
from transformers import AutoImageProcessor, PreTrainedTokenizerFast
from config import settings
import os

class ImagePreprocessor:
    def __init__(self):
        self.nsfw_processor = AutoImageProcessor.from_pretrained(
            os.path.join(settings.TOKENIZERS_PATH, "nsfw_processor"))
        self.clip_processor = AutoImageProcessor.from_pretrained(
            os.path.join(settings.TOKENIZERS_PATH, "clip_processor"))

    def preprocess_nsfw(self, image: Image.Image) -> np.ndarray:
        inputs = self.nsfw_processor(images=image, return_tensors="np")
        return inputs["pixel_values"].astype(np.float32)

    def preprocess_clip(self, image: Image.Image) -> np.ndarray:
        inputs = self.clip_processor(images=image, return_tensors="np")
        return inputs["pixel_values"].astype(np.float32)

class TextPreprocessor:
    def __init__(self):
        self.toxicity_tokenizer = PreTrainedTokenizerFast(
            tokenizer_file=os.path.join(settings.TOKENIZERS_PATH, "toxicity_tokenizer", "tokenizer.json"))
        if self.toxicity_tokenizer.pad_token is None:
            self.toxicity_tokenizer.add_special_tokens({'pad_token': '<pad>'})
        self.clip_tokenizer = PreTrainedTokenizerFast(
            tokenizer_file=os.path.join(settings.TOKENIZERS_PATH, "clip_tokenizer", "tokenizer.json"))
        if self.clip_tokenizer.pad_token is None:
            self.clip_tokenizer.add_special_tokens({'pad_token': '<|endoftext|>'})

    def preprocess_toxicity(self, text: str):
        inputs = self.toxicity_tokenizer([text], return_tensors="np", padding=True, truncation=True)
        return inputs["input_ids"].astype(np.int64), inputs["attention_mask"].astype(np.int64)

    def preprocess_clip_texts(self, texts: list):
        inputs = self.clip_tokenizer(texts, return_tensors="np", padding=True, truncation=True)
        return inputs["input_ids"].astype(np.int64), inputs["attention_mask"].astype(np.int64)

_image_preprocessor = None
_text_preprocessor = None

def get_image_preprocessor():
    global _image_preprocessor
    if _image_preprocessor is None:
        _image_preprocessor = ImagePreprocessor()
    return _image_preprocessor

def get_text_preprocessor():
    global _text_preprocessor
    if _text_preprocessor is None:
        _text_preprocessor = TextPreprocessor()
    return _text_preprocessor
