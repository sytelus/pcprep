import os
import shutil
import subprocess

# The managed Python 3.14 environment intentionally excludes TensorFlow. Keras
# uses the installed PyTorch package as its backend.
os.environ.setdefault("KERAS_BACKEND", "torch")

import keras
import torch
import torchvision

print("Python framework smoke test")
print("Keras version", keras.__version__)
print("Keras backend", keras.backend.backend())
print("PyTorch version", torch.__version__)
print("TorchVision version", torchvision.__version__)

if keras.backend.backend() != "torch":
    raise SystemExit("Keras is not using the PyTorch backend")

cpu_result = torch.tensor([[1.0, 2.0], [3.0, 4.0]]) @ torch.eye(2)
print("PyTorch CPU tensor test", cpu_result.tolist())

print("PyTorch CUDA available", torch.cuda.is_available())
print("PyTorch CUDA device count", torch.cuda.device_count())
if torch.cuda.is_available():
    device = torch.device("cuda")
    gpu_result = torch.ones((2, 2), device=device) @ torch.ones((2, 2), device=device)
    torch.cuda.synchronize()
    print("PyTorch CUDA device", torch.cuda.get_device_name(0))
    print("PyTorch CUDA tensor test", gpu_result.cpu().tolist())
else:
    print("SKIP: no CUDA device is available to PyTorch")

for command in (("nvidia-smi",), ("nvcc", "--version")):
    if shutil.which(command[0]):
        subprocess.run(command, check=True)
    else:
        print(f"SKIP: {command[0]} is not installed")
