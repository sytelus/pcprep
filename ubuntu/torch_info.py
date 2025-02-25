#!/usr/bin/env python3
"""
This script dumps extensive PyTorch configuration and system information.
It works on systems where PyTorch is supported (CPU-only, CUDA, HIP, etc.).
"""

import io
import os
import sys
import platform
import contextlib
import torch


def dump_pytorch_config() -> None:
    print("=== PyTorch Version Info ===")
    print("PyTorch Version: ", torch.__version__)
    print("Git Version:     ", torch.version.git_version)
    # Check for HIP version (for AMD) if available.
    if hasattr(torch.version, "hip"):
        print("HIP Version:     ", torch.version.hip)
    print("CUDA Runtime Version: ", torch.version.cuda)
    print("cuDNN Version:        ", torch.backends.cudnn.version())

    print("\n=== Build Configuration ===")
    # torch.__config__.show() prints directly; capture its output.
    with io.StringIO() as buf, contextlib.redirect_stdout(buf):
        torch.__config__.show()
        build_config = buf.getvalue()
    print(build_config.strip())

    print("=== Torch Backends ===")
    # Quantization engine is available across platforms.
    print("Quantized Engine:     ", torch.backends.quantized.engine)
    # MKL backend might not be available in all builds.
    if hasattr(torch.backends, "mkl"):
        try:
            mkl_available = torch.backends.mkl.is_available()
        except Exception:
            mkl_available = "Unknown"
        print("MKL Available:        ", mkl_available)
    else:
        print("MKL Available:        N/A")

    # Distributed support check.
    print("\n=== Distributed Support ===")
    print("torch.distributed.is_available():", torch.distributed.is_available())

    print("\n=== CUDA Devices Info ===")
    if torch.cuda.is_available():
        num_devices = torch.cuda.device_count()
        print("CUDA is available; Number of devices: ", num_devices)
        for idx in range(num_devices):
            try:
                device_name = torch.cuda.get_device_name(idx)
            except Exception as e:
                device_name = f"Error retrieving name: {e}"
            print(f"\nDevice {idx}: {device_name}")
            try:
                cap = torch.cuda.get_device_capability(idx)
                print("  Compute Capability: ", cap)
            except Exception as e:
                print("  Compute Capability: Error:", e)
            try:
                current_device = torch.cuda.current_device()
                print("  Current Device Index: ", current_device)
            except Exception as e:
                print("  Current Device Index: Error:", e)
            # Memory details (only meaningful if device is in use)
            try:
                mem_alloc = torch.cuda.memory_allocated(idx)
                mem_reserved = torch.cuda.memory_reserved(idx)
                print("  Memory Allocated: ", mem_alloc)
                print("  Memory Reserved:  ", mem_reserved)
            except Exception:
                pass
    else:
        print("CUDA is not available on this system.")

    print("\n=== Threading Information ===")
    print("torch.get_num_threads():         ", torch.get_num_threads())
    print("torch.get_num_interop_threads(): ", torch.get_num_interop_threads())

    print("\n=== System and Python Info ===")
    print("Python Version: ", sys.version.replace("\n", " "))
    print("Platform:       ", platform.platform())
    print("System:         ", platform.system())
    print("Machine:        ", platform.machine())
    print("Processor:      ", platform.processor())
    print("Node Name:      ", platform.node())

    print("\n=== Selected Environment Variables ===")
    # Display environment variables relevant to PyTorch and CUDA.
    env_vars = {k: v for k, v in os.environ.items() if "TORCH" in k.upper() or "CUDA" in k.upper()}
    if env_vars:
        for key in sorted(env_vars):
            print(f"{key}: {env_vars[key]}")
    else:
        print("No TORCH/CUDA related environment variables found.")

    if torch.cuda.is_available():
        print("\n=== CUDA Memory Summary ===")
        try:
            # Provides a summary of current GPU memory usage.
            print(torch.cuda.memory_summary())
        except Exception as e:
            print("Error obtaining CUDA memory summary:", e)


if __name__ == "__main__":
    dump_pytorch_config()
