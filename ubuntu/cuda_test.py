import torch

# Function to check CUDA and cuDNN installation
def check_cuda_cudnn():
    # Check for CUDA availability
    if torch.cuda.is_available():
        print(f"CUDA is available: Yes")
        print(f"CUDA version: {torch.version.cuda}")

        # Print the cuDNN version
        print(f"cuDNN version: {torch.backends.cudnn.version()}")

        # Attempt a simple tensor operation on GPU to ensure CUDA and cuDNN are working
        try:
            x = torch.tensor([1.0, 2.0, 3.0], device="cuda")
            y = x * x
            print("Successfully performed a tensor operation on GPU:", y)
        except Exception as e:
            print("Failed to perform a tensor operation on GPU. Potential issue with CUDA/cuDNN installation.")
            print(f"Error: {e}")
    else:
        print("CUDA is not available. Check your PyTorch installation and if your system has a CUDA-capable GPU.")
        # Common issues and troubleshooting tips
        print("Common installation issues:")
        print("- The GPU is not supported by the installed CUDA version.")
        print("- Missing or incompatible NVIDIA driver.")
        print("- PyTorch not installed with CUDA support. Consider installing the CUDA version of PyTorch.")

# Print PyTorch version
print(f"PyTorch version: {torch.__version__}")

# Check CUDA and cuDNN installation
check_cuda_cudnn()
