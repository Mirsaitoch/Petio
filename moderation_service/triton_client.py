import numpy as np
import tritonclient.grpc as grpcclient
from tritonclient.utils import np_to_triton_dtype
from config import settings

class TritonClient:
    def __init__(self):
        self.client = grpcclient.InferenceServerClient(url=settings.TRITON_URL)
        self._cached_label_features = None  # Кэш для лейблов
    
    def get_cached_label_features(self, input_ids: np.ndarray, attention_mask: np.ndarray) -> np.ndarray:
        if self._cached_label_features is None:
            self._cached_label_features = self.infer_clip_text(input_ids, attention_mask)
        return self._cached_label_features

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
        outputs = [grpcclient.InferRequestedOutput("image_features")]
        response = self.client.infer(model_name="clip_vision", inputs=inputs, outputs=outputs)
        return response.as_numpy("image_features")

    def infer_clip_text(self, input_ids: np.ndarray, attention_mask: np.ndarray) -> np.ndarray:
        batch_size = input_ids.shape[0]
        
        if batch_size == 1:
            inputs = [
                grpcclient.InferInput("input_ids", input_ids.shape, np_to_triton_dtype(input_ids.dtype)),
                grpcclient.InferInput("attention_mask", attention_mask.shape, np_to_triton_dtype(attention_mask.dtype))
            ]
            inputs[0].set_data_from_numpy(input_ids)
            inputs[1].set_data_from_numpy(attention_mask)
            outputs = [grpcclient.InferRequestedOutput("text_features")]
            response = self.client.infer(model_name="clip_text", inputs=inputs, outputs=outputs)
            return response.as_numpy("text_features")
        
        results = []
        for i in range(batch_size):
            single_ids = input_ids[i:i+1]
            single_mask = attention_mask[i:i+1]
            
            inputs = [
                grpcclient.InferInput("input_ids", single_ids.shape, np_to_triton_dtype(single_ids.dtype)),
                grpcclient.InferInput("attention_mask", single_mask.shape, np_to_triton_dtype(single_mask.dtype))
            ]
            inputs[0].set_data_from_numpy(single_ids)
            inputs[1].set_data_from_numpy(single_mask)
            outputs = [grpcclient.InferRequestedOutput("text_features")]
            
            response = self.client.infer(model_name="clip_text", inputs=inputs, outputs=outputs)
            results.append(response.as_numpy("text_features"))
        
        return np.concatenate(results, axis=0)

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
