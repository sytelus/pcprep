import torch

# Check if an NVIDIA GPU is available
if not torch.cuda.is_available():
    raise RuntimeError("NVIDIA GPU not available. Please install an NVIDIA GPU to proceed.")

# Move tensors to the GPU
device = torch.device("cuda:0")

# Matrix dimensions for large matrix multiplication
n = 8192

for dtype in (torch.float32, torch.float16): #, torch.int32, torch.int16, torch.int8):
    # Create large random matrices on the GPU
    if str(dtype).startswith("torch.int"):
        a = torch.randint(low=0, high=8, size=(n, n), device=device, dtype=dtype)
        b = torch.randint(low=0, high=8, size=(n, n), device=device, dtype=dtype)
    else:
        a = torch.rand(n, n, device=device, dtype=dtype)
        b = torch.rand(n, n, device=device, dtype=dtype)

    # Warm up the GPU
    for _ in range(5):
        _ = torch.matmul(a, b)

    # Create CUDA events for precise timing
    start_event = torch.cuda.Event(enable_timing=True)
    end_event = torch.cuda.Event(enable_timing=True)

    # Time the matrix multiplication operations
    num_iterations = 10
    start_event.record()
    for _ in range(num_iterations):
        c = torch.matmul(a, b)
    torch.cuda.synchronize()
    end_event.record()

    # Wait for the events to complete and calculate the elapsed time
    torch.cuda.synchronize()
    elapsed_time = start_event.elapsed_time(end_event)  # Time in milliseconds

    # Calculate the number of FLOPs
    flops = 2 * n**3 * num_iterations / (elapsed_time * 1e-3) * 1e-9

    print(f"Max {dtype} FLOPs: {flops:.2f} GFLOPs")
