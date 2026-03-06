import numpy as np
import tritonclient.grpc as grpcclient
from tritonclient.utils import np_to_triton_dtype
from config import settings

class TritonClient:
    def __init__(self):
        self.client = grpcclient.InferenceServerClient(url=settings.TRITON_URL)

    def is_ready(self) -> bool:
        try:
            return self.client.is_server_ready()
        except:
            return False

    def infer_nsfw(self, pixel_values: np.ndarray) -> np.ndarray:
        inputs = [grpcclient.InferInput("pixel_values", pixel_values.shape, np_to_triton_dtype(pixel_values.dtype))]
        inputs[0].set_data_from_numpy(pixel_values)
        outputs = [grpcclient.InferRequestedOutput("logits")]
        response = self.client.infer(model_name="nsfw_detector", inputs=inputs, outputs=outputs)
        return response.as_numpy("logits")

    def infer_clip_vision(self, pixel_values: np.ndarray) -> np.ndarray:
        inputs = [grpcclient.InferInput("pixel_values", pixel_values.shape, np_to_triton_dtype(pixel_values.dtype))]
        inputs[0].set_data_from_numpy(pixel_values)
        outputs = [grpcclient.InferRequestedOutput("image_embeds")]
        response = self.client.infer(model_name="clip_vision", inputs=inputs, outputs=outputs)
        return response.as_numpy("image_embeds")

    def infer_clip_text(self, input_ids: np.ndarray, attention_mask: np.ndarray) -> np.ndarray:
        inputs = [
            grpcclient.InferInput("input_ids", input_ids.shape, np_to_triton_dtype(input_ids.dtype)),
            grpcclient.InferInput("attention_mask", attention_mask.shape, np_to_triton_dtype(attention_mask.dtype))
        ]
        inputs[0].set_data_from_numpy(input_ids)
        inputs[1].set_data_from_numpy(attention_mask)
        outputs = [grpcclient.InferRequestedOutput("text_embeds")]
        response = self.client.infer(model_name="clip_text", inputs=inputs, outputs=outputs)
        return response.as_numpy("text_embeds")

    def infer_toxicity(self, input_ids: np.ndarray, attention_mask: np.ndarray) -> np.ndarray:
        inputs = [
            grpcclient.InferInput("input_ids", input_ids.shape, np_to_triton_dtype(input_ids.dtype)),
            grpcclient.InferInput("attention_mask", attention_mask.shape, np_to_triton_dtype(attention_mask.dtype))
        ]
        inputs[0].set_data_from_numpy(input_ids)
        inputs[1].set_data_from_numpy(attention_mask)
        outputs = [grpcclient.InferRequestedOutput("logits")]
        response = self.client.infer(model_name="text_toxicity", inputs=inputs, outputs=outputs)
        return response.as_numpy("logits")

triton_client = TritonClient()
