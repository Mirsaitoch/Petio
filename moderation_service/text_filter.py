import numpy as np
from transformers import PreTrainedTokenizerFast
import onnxruntime as ort
from scipy.special import expit
from constants import CLASSES_NAME
from tools import softmax

# Загрузка токенизатора и модели
tokenizer = PreTrainedTokenizerFast(tokenizer_file="models/text_filter/tokenizer/tokenizer.json")
if tokenizer.pad_token is None:
    tokenizer.add_special_tokens({'pad_token': '<pad>'})

text_filter_ort_session = ort.InferenceSession("models/text_filter/detoxify_multilingual.onnx")

def predict_text(text: str):
    inputs = tokenizer(
        [text],
        return_tensors="np",
        padding=True,
        truncation=True
    )
    ort_inputs = {
        "input_ids": inputs["input_ids"].astype(np.int64),
        "attention_mask": inputs["attention_mask"].astype(np.int64)
    }
    outputs = {name: round(float(prob) * 100, 2) 
               for name, prob in zip(CLASSES_NAME, expit(text_filter_ort_session.run(None, ort_inputs)[0][0]))}
    return outputs