import onnx
import os

MODEL_DIR = "/models"  # путь к твоему model repository

def convert_model_to_ir9(model_path: str):
    print(f"Converting {model_path} to IR9...")
    model = onnx.load(model_path)
    onnx.version_converter.convert_version(model, 9)
    onnx.save(model, model_path)
    print(f"Converted {model_path} successfully.")

def main():
    for root, dirs, files in os.walk(MODEL_DIR):
        for file in files:
            if file.endswith(".onnx"):
                full_path = os.path.join(root, file)
                convert_model_to_ir9(full_path)

if __name__ == "__main__":
    main()