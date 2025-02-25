#!/usr/bin/env python3
"""
PyTorch System and Configuration Information Dumper

This script collects and displays comprehensive information about the PyTorch
installation, system configuration, and available hardware resources.
"""

import sys
import os
import platform
import subprocess
import json
import datetime
import re
from collections import OrderedDict
from typing import Dict, List, Any, Optional, Union

# For Python 3.8+ use importlib.metadata instead of pkg_resources
try:
    import importlib.metadata as importlib_metadata
    USE_IMPORTLIB = True
except ImportError:
    USE_IMPORTLIB = False

# Try to import rich for colorized output
try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich.text import Text
    from rich import box
    from rich.tree import Tree
    from rich.progress import Progress, SpinnerColumn, TextColumn
    from rich.layout import Layout
    from rich.syntax import Syntax
    from rich.rule import Rule
    from rich.style import Style
    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False
    print("Warning: rich is not installed. Output will not be colorized.")
    print("Install with: pip install rich")


try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False
    print("Warning: psutil is not installed. Some system information will be limited.")
    print("Install with: pip install psutil")

try:
    import torch
    TORCH_AVAILABLE = True
except ImportError:
    TORCH_AVAILABLE = False
    print("PyTorch is not available in the current environment.")
    print("Install with: pip install torch")
    sys.exit(1)

# Try to import optional modules
try:
    import numpy as np
    NUMPY_AVAILABLE = True
except ImportError:
    NUMPY_AVAILABLE = False

try:
    import torchvision
    TORCHVISION_AVAILABLE = True
except ImportError:
    TORCHVISION_AVAILABLE = False

try:
    import torchaudio
    TORCHAUDIO_AVAILABLE = True
except ImportError:
    TORCHAUDIO_AVAILABLE = False

try:
    import torchtext
    TORCHTEXT_AVAILABLE = True
except ImportError:
    TORCHTEXT_AVAILABLE = False


class SystemInfoCollector:
    """Collects system information related to PyTorch."""

    def __init__(self):
        self.info = OrderedDict()
        self.collected_datetime = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    def collect_all(self) -> OrderedDict:
        """Collect all available information."""
        self.collect_basic_info()
        self.collect_python_info()
        self.collect_os_info()
        self.collect_cpu_info()
        if PSUTIL_AVAILABLE:
            self.collect_memory_info()
        self.collect_gpu_info()
        self.collect_pytorch_info()
        self.collect_pytorch_config()
        self.collect_pytorch_build_info()
        self.collect_extension_info()
        return self.info

    def collect_basic_info(self) -> None:
        """Collect basic timestamp information."""
        self.info['Basic Information'] = {
            'Timestamp': self.collected_datetime,
            'Script': os.path.abspath(__file__)
        }

    def collect_python_info(self) -> None:
        """Collect Python-related information."""
        python_info = {
            'Version': platform.python_version(),
            'Implementation': platform.python_implementation(),
            'Compiler': platform.python_compiler(),
            'Build Date': platform.python_build()[1],
            'Executable': sys.executable,
        }

        # Collect PyTorch related packages
        related_pkgs = [
            'torch', 'torchvision', 'torchaudio', 'torchtext', 'numpy',
            'pandas', 'scipy', 'pillow', 'matplotlib', 'tensorboard',
            'sklearn', 'onnx', 'cuda', 'pytorch-lightning', 'lightning',
            'torchmetrics', 'transformers'
        ]

        installed_packages = []

        if USE_IMPORTLIB:
            # Use importlib.metadata for Python 3.8+
            packages = [dist.metadata["Name"] for dist in importlib_metadata.distributions()]
            for pkg_name in packages:
                if any(rel in pkg_name.lower() for rel in related_pkgs):
                    try:
                        version = importlib_metadata.version(pkg_name)
                        installed_packages.append(f"{pkg_name}=={version}")
                    except importlib_metadata.PackageNotFoundError:
                        pass
        else:
            # Fallback to using pip list through subprocess
            try:
                pip_list = subprocess.check_output([sys.executable, '-m', 'pip', 'list', '--format=json']).decode('utf-8')
                packages = json.loads(pip_list)
                for pkg in packages:
                    if any(rel in pkg['name'].lower() for rel in related_pkgs):
                        installed_packages.append(f"{pkg['name']}=={pkg['version']}")
            except (subprocess.SubprocessError, json.JSONDecodeError):
                # If pip list fails, use a more basic approach
                try:
                    for rel in related_pkgs:
                        try:
                            module = __import__(rel)
                            if hasattr(module, '__version__'):
                                installed_packages.append(f"{rel}=={module.__version__}")
                        except ImportError:
                            pass
                except Exception:
                    pass

        python_info['Installed Related Packages'] = installed_packages
        self.info['Python Environment'] = python_info

    def collect_os_info(self) -> None:
        """Collect operating system information."""
        os_info = {
            'System': platform.system(),
            'Release': platform.release(),
            'Version': platform.version(),
            'Machine': platform.machine(),
            'Architecture': platform.architecture()[0],
            'Platform': platform.platform(),
            'Node': platform.node()
        }

        # Add Linux-specific information if available
        if platform.system() == 'Linux':
            try:
                with open('/etc/os-release', 'r') as f:
                    os_release = {}
                    for line in f:
                        if '=' in line:
                            key, value = line.rstrip().split('=', 1)
                            os_release[key] = value.strip('"')
                if os_release:
                    os_info['Distribution'] = f"{os_release.get('NAME', 'Unknown')} {os_release.get('VERSION', '')}"
            except (FileNotFoundError, PermissionError):
                pass

        self.info['Operating System'] = os_info

    def collect_cpu_info(self) -> None:
        """Collect CPU information."""
        cpu_info = {}

        if PSUTIL_AVAILABLE:
            cpu_info.update({
                'Physical Cores': psutil.cpu_count(logical=False),
                'Logical Cores': psutil.cpu_count(logical=True),
                'CPU Frequency (Current)': f"{psutil.cpu_freq().current:.2f} MHz" if psutil.cpu_freq() else "Unknown",
                'CPU Usage': f"{psutil.cpu_percent(interval=0.1):.1f}%"
            })
        else:
            # Fallback method
            cpu_info['Logical Cores'] = os.cpu_count()

        # Try to get more detailed CPU info based on platform
        if platform.system() == 'Linux':
            try:
                with open('/proc/cpuinfo', 'r') as f:
                    cpu_lines = f.readlines()

                model_name_lines = [line for line in cpu_lines if 'model name' in line]
                if model_name_lines:
                    model_name = model_name_lines[0].split(':')[1].strip()
                    cpu_info['Model'] = model_name
            except (FileNotFoundError, PermissionError):
                pass
        elif platform.system() == 'Darwin':  # macOS
            try:
                sysctl_output = subprocess.check_output(['sysctl', '-n', 'machdep.cpu.brand_string']).decode('utf-8').strip()
                cpu_info['Model'] = sysctl_output
            except (subprocess.SubprocessError, FileNotFoundError):
                pass
        elif platform.system() == 'Windows':
            try:
                wmic_output = subprocess.check_output('wmic cpu get name', shell=True).decode('utf-8')
                # Extract CPU name (skip header line)
                cpu_name = wmic_output.strip().split('\n')[1].strip()
                cpu_info['Model'] = cpu_name
            except (subprocess.SubprocessError, FileNotFoundError):
                pass

        self.info['CPU Information'] = cpu_info

    def collect_memory_info(self) -> None:
        """Collect system memory information."""
        vm = psutil.virtual_memory()
        memory_info = {
            'Total': f"{vm.total / (1024**3):.2f} GB",
            'Available': f"{vm.available / (1024**3):.2f} GB",
            'Used': f"{vm.used / (1024**3):.2f} GB ({vm.percent}%)",
            'Free': f"{vm.free / (1024**3):.2f} GB"
        }

        # Swap information
        swap = psutil.swap_memory()
        memory_info['Swap Total'] = f"{swap.total / (1024**3):.2f} GB"
        memory_info['Swap Used'] = f"{swap.used / (1024**3):.2f} GB ({swap.percent}%)"

        self.info['Memory Information'] = memory_info

    def collect_gpu_info(self) -> None:
        """Collect GPU-related information if available."""
        gpu_info = {}

        # Check for CUDA availability
        if torch.cuda.is_available():
            gpu_info['CUDA Available'] = True
            gpu_info['CUDA Version'] = torch.version.cuda

            # Try to get cuDNN version
            if hasattr(torch.backends, 'cudnn'):
                gpu_info['cuDNN Enabled'] = torch.backends.cudnn.enabled
                if torch.backends.cudnn.enabled and hasattr(torch.backends.cudnn, 'version'):
                    gpu_info['cuDNN Version'] = torch.backends.cudnn.version()

            gpu_info['GPU Count'] = torch.cuda.device_count()

            # Get information for each GPU
            devices = []
            for i in range(torch.cuda.device_count()):
                device_info = {
                    'Index': i,
                    'Name': torch.cuda.get_device_name(i),
                    'Capability': f"{torch.cuda.get_device_capability(i)[0]}.{torch.cuda.get_device_capability(i)[1]}"
                }

                # Try to get memory information
                try:
                    mem_info = torch.cuda.mem_get_info(i)
                    device_info['Memory Total'] = f"{mem_info[1] / (1024**3):.2f} GB"
                    device_info['Memory Free'] = f"{mem_info[0] / (1024**3):.2f} GB"
                    device_info['Memory Used'] = f"{(mem_info[1] - mem_info[0]) / (1024**3):.2f} GB"
                except (RuntimeError, AttributeError):
                    # mem_get_info not available in older PyTorch versions
                    try:
                        # Alternative: Try to get total memory from device properties
                        props = torch.cuda.get_device_properties(i)
                        total_memory = props.total_memory / (1024**3)
                        device_info['Memory Total'] = f"{total_memory:.2f} GB"
                    except (RuntimeError, AttributeError):
                        pass

                # Try to get device properties
                try:
                    props = torch.cuda.get_device_properties(i)
                    device_info.update({
                        'Multi Processor Count': props.multi_processor_count,
                        'Clock Rate': f"{props.clock_rate / 1000:.0f} MHz",
                        'Is Integrated': props.is_integrated,
                        'Is Multi GPU Board': props.is_multi_gpu_board
                    })
                except (RuntimeError, AttributeError):
                    pass

                devices.append(device_info)

            gpu_info['Devices'] = devices

            # CUDA device current and default
            gpu_info['Current Device'] = torch.cuda.current_device()

            # Get CUDA memory stats
            try:
                memory_stats = torch.cuda.memory_stats()
                if memory_stats:
                    allocated = memory_stats.get('allocated_bytes.all.current', 0)
                    reserved = memory_stats.get('reserved_bytes.all.current', 0)
                    gpu_info['Memory Allocated'] = f"{allocated / (1024**3):.2f} GB"
                    gpu_info['Memory Reserved'] = f"{reserved / (1024**3):.2f} GB"
            except (RuntimeError, AttributeError):
                pass
        else:
            gpu_info['CUDA Available'] = False

        # Check for ROCm/HIP backend
        try:
            if hasattr(torch, 'version') and hasattr(torch.version, 'hip'):
                gpu_info['ROCm/HIP Version'] = torch.version.hip
                if torch.version.hip != None:
                    gpu_info['ROCm Available'] = True
        except Exception:
            pass

        # Check for MPS (Metal Performance Shaders) backend for Apple Silicon
        if hasattr(torch.backends, 'mps'):
            gpu_info['MPS Available'] = torch.backends.mps.is_available()
            if torch.backends.mps.is_available():
                gpu_info['MPS Device Name'] = "Apple Silicon GPU"
                gpu_info['MPS Built'] = torch.backends.mps.is_built()

        self.info['GPU Information'] = gpu_info

    def collect_pytorch_info(self) -> None:
        """Collect PyTorch-related information."""
        pytorch_info = {
            'Version': torch.__version__,
            'Default Dtype': str(torch.get_default_dtype()),
            'Number of Threads': torch.get_num_threads(),
        }

        # Try to get number of interop threads
        try:
            pytorch_info['Number of Interop Threads'] = torch.get_num_interop_threads()
        except AttributeError:
            pass

        # Get available device types
        device_types = ['cpu']
        if torch.cuda.is_available():
            device_types.append('cuda')
        if hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            device_types.append('mps')
        pytorch_info['Available Device Types'] = device_types

        # Get information about torch backends
        pytorch_info['Has CUDA'] = torch.cuda.is_available()
        pytorch_info['Has MKL'] = torch.backends.mkl.is_available() if hasattr(torch.backends, 'mkl') else 'Unknown'
        pytorch_info['Has OpenMP'] = torch.backends.openmp.is_available() if hasattr(torch.backends, 'openmp') else 'Unknown'
        pytorch_info['Has MKL-DNN'] = torch.backends.mkldnn.is_available() if hasattr(torch.backends, 'mkldnn') else 'Unknown'

        # Check for newer oneDNN backend
        if hasattr(torch.backends, 'onednn'):
            pytorch_info['Has oneDNN'] = torch.backends.onednn.is_available()

        # Get supported backends
        backends = {
            'cuDNN': hasattr(torch.backends, 'cudnn') and torch.backends.cudnn.is_available(),
            'MKL-DNN': hasattr(torch.backends, 'mkldnn') and torch.backends.mkldnn.is_available(),
            'oneDNN': hasattr(torch.backends, 'onednn') and torch.backends.onednn.is_available(),
            'OpenMP': hasattr(torch.backends, 'openmp') and torch.backends.openmp.is_available(),
            'MKL': hasattr(torch.backends, 'mkl') and torch.backends.mkl.is_available(),
            'MPS': hasattr(torch.backends, 'mps') and torch.backends.mps.is_available()
        }
        pytorch_info['Supported Backends'] = {k: v for k, v in backends.items() if v}

        # Get autograd engine info
        pytorch_info['Autograd Enabled'] = torch.is_grad_enabled()

        # Check for anomaly detection
        try:
            pytorch_info['Anomaly Detection'] = torch.autograd.anomaly_mode.is_anomaly_check_mode()
        except AttributeError:
            try:
                pytorch_info['Anomaly Detection'] = torch.autograd.anomaly_detection._enabled
            except AttributeError:
                pytorch_info['Anomaly Detection'] = 'Unknown'

        # Check for backward determinism
        try:
            pytorch_info['Deterministic Algorithms'] = torch.are_deterministic_algorithms_enabled()
        except AttributeError:
            pytorch_info['Deterministic Algorithms'] = 'Unknown'

        # Hub related info
        try:
            hub_dir = torch.hub.get_dir()
            pytorch_info['Hub Directory'] = hub_dir
        except (AttributeError, RuntimeError):
            pass

        # Default generator info
        try:
            pytorch_info['Default Generator Device'] = torch.default_generator.device
            pytorch_info['Default Generator Seed'] = torch.default_generator.initial_seed()
        except (AttributeError, RuntimeError):
            pass

        # Get related libraries info
        torch_related = {}

        if NUMPY_AVAILABLE:
            torch_related['NumPy'] = np.__version__

        if TORCHVISION_AVAILABLE:
            torch_related['TorchVision'] = torchvision.__version__

        if TORCHAUDIO_AVAILABLE:
            torch_related['TorchAudio'] = torchaudio.__version__

        if TORCHTEXT_AVAILABLE:
            torch_related['TorchText'] = torchtext.__version__

        # Check for other PyTorch-related libraries
        try:
            import transformers
            torch_related['Transformers'] = transformers.__version__
        except ImportError:
            pass

        try:
            import lightning
            torch_related['Lightning'] = lightning.__version__
        except ImportError:
            try:
                import pytorch_lightning
                torch_related['PyTorch Lightning'] = pytorch_lightning.__version__
            except ImportError:
                pass

        try:
            import fastai
            torch_related['fastai'] = fastai.__version__
        except ImportError:
            pass

        try:
            import timm
            torch_related['TIMM'] = timm.__version__
        except ImportError:
            pass

        pytorch_info['Related Libraries'] = torch_related

        self.info['PyTorch Information'] = pytorch_info

    def collect_pytorch_config(self) -> None:
        """Collect PyTorch configuration settings."""
        config = {}

        # Collect JIT configuration
        jit_config = {}
        if hasattr(torch, 'jit') and hasattr(torch.jit, 'is_scripting'):
            jit_config['Is Scripting'] = torch.jit.is_scripting()

        if hasattr(torch, '_jit_internal'):
            try:
                jit_config['Profiling Mode'] = not torch._C._jit_set_profiling_mode(True)  # Get current value
                torch._C._jit_set_profiling_mode(jit_config['Profiling Mode'])  # Reset to original
            except Exception:
                pass

        # Check for mobile optimizations
        if hasattr(torch, '_C') and hasattr(torch._C, '_mobile_optimizer'):
            jit_config['Mobile Optimizer'] = True

        # ONNX export capability
        if hasattr(torch.onnx, 'export'):
            jit_config['ONNX Export Available'] = True

        config['JIT/TorchScript'] = jit_config

        # Collect CUDA configuration if available
        if torch.cuda.is_available():
            cuda_config = {}

            # CUDA device allocation settings
            cuda_config['Allow Growth'] = os.environ.get('PYTORCH_CUDA_ALLOC_CONF', 'None')

            # cuDNN configuration
            if hasattr(torch.backends, 'cudnn'):
                cudnn_config = {
                    'Enabled': torch.backends.cudnn.enabled,
                    'Benchmark': torch.backends.cudnn.benchmark,
                    'Deterministic': torch.backends.cudnn.deterministic,
                }

                # Check for TF32 support
                if hasattr(torch.backends.cudnn, 'allow_tf32'):
                    cudnn_config['Allow TF32'] = torch.backends.cudnn.allow_tf32

                cuda_config['cuDNN Configuration'] = cudnn_config

            # CUDA matmul configuration
            if hasattr(torch.backends, 'cuda') and hasattr(torch.backends.cuda, 'matmul'):
                if hasattr(torch.backends.cuda.matmul, 'allow_tf32'):
                    cuda_config['Matmul TF32 Allowed'] = torch.backends.cuda.matmul.allow_tf32

            config['CUDA Configuration'] = cuda_config

        # MPS configuration (Apple Silicon)
        if hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            mps_config = {
                'Is Built': torch.backends.mps.is_built(),
                'Is Available': torch.backends.mps.is_available()
            }
            config['MPS Configuration'] = mps_config

        # Collect distributed configuration
        if hasattr(torch, 'distributed') and hasattr(torch.distributed, 'is_available'):
            dist_config = {
                'Available': torch.distributed.is_available(),
                'Backend': None
            }

            # Check initialized backends
            if torch.distributed.is_available():
                backend_available = {}

                for backend in ['nccl', 'gloo', 'mpi']:
                    try:
                        is_available = getattr(torch.distributed, f'is_{backend}_available')()
                        backend_available[backend] = is_available
                    except AttributeError:
                        backend_available[backend] = 'Unknown'

                dist_config['Backends Available'] = backend_available

            config['Distributed'] = dist_config

        # Collect default generator info
        default_generator = {}
        try:
            if hasattr(torch.default_generator, 'device'):
                default_generator['Device'] = str(torch.default_generator.device)
            default_generator['Initial Seed'] = torch.default_generator.initial_seed()
            config['Default Generator'] = default_generator
        except Exception:
            pass

        # Collect dtype defaults
        dtype_defaults = {
            'Default Dtype': str(torch.get_default_dtype()),
        }

        # Check if we can get promotion configurations
        try:
            dtype_defaults['Promote Types'] = torch.get_promote_type_indices != None
        except Exception:
            pass

        # Check floating point configuration
        fp_config = {}

        # Check for AMP (Automatic Mixed Precision)
        if hasattr(torch, 'cuda') and hasattr(torch.cuda, 'amp'):
            fp_config['AMP Available'] = True

            # Check for autocast
            if hasattr(torch.cuda.amp, 'autocast'):
                fp_config['Autocast Available'] = True

        # Check for BFloat16 support
        if hasattr(torch, 'bfloat16'):
            fp_config['BFloat16 Available'] = True

        # Check for Float8 support
        if hasattr(torch, 'float8_e4m3fn') and hasattr(torch, 'float8_e5m2'):
            fp_config['Float8 Available'] = True

        # Check for TF32 support
        if hasattr(torch.backends, 'cuda') and hasattr(torch.backends.cuda, 'matmul'):
            if hasattr(torch.backends.cuda.matmul, 'allow_tf32'):
                fp_config['TF32 Allowed (matmul)'] = torch.backends.cuda.matmul.allow_tf32

            if hasattr(torch.backends.cudnn, 'allow_tf32'):
                fp_config['TF32 Allowed (cudnn)'] = torch.backends.cudnn.allow_tf32

        dtype_defaults['Floating Point'] = fp_config
        config['Dtype Configuration'] = dtype_defaults

        self.info['PyTorch Configuration'] = config

    def collect_pytorch_build_info(self) -> None:
        """Collect PyTorch build information."""
        build_info = {}

        # Get PyTorch version components
        version_parts = torch.__version__.split('.')
        if len(version_parts) >= 2:
            build_info['Major Version'] = version_parts[0]
            build_info['Minor Version'] = version_parts[1]

        # Check for debug information in version
        if '+' in torch.__version__:
            build_variant = torch.__version__.split('+')[1]
            build_info['Build Variant'] = build_variant

        # Get Git commit if available
        if hasattr(torch.version, 'git_version'):
            build_info['Git Commit'] = torch.version.git_version

        # Get CUDA version if available
        if hasattr(torch.version, 'cuda'):
            build_info['CUDA Version'] = torch.version.cuda

        # Check for Hip version (AMD ROCm)
        if hasattr(torch.version, 'hip'):
            build_info['HIP Version'] = torch.version.hip

        # Check build type (debug vs release)
        if hasattr(torch, '_C') and hasattr(torch._C, '_debug_set_autodiff_subgraph_inlining'):
            try:
                # This is a way to check debug mode in some versions
                debug_mode = torch._C._debug_set_autodiff_subgraph_inlining(False)
                torch._C._debug_set_autodiff_subgraph_inlining(debug_mode)  # Set it back
                build_info['Debug Build'] = debug_mode
            except:
                pass

        # Check build with CUDA
        build_info['Built with CUDA'] = torch.cuda.is_available()

        # Check for parallel build options
        parallel_info = {}

        # Check for OpenMP
        if hasattr(torch.backends, 'openmp'):
            parallel_info['OpenMP Available'] = torch.backends.openmp.is_available()

        # Check for MKL
        if hasattr(torch.backends, 'mkl'):
            parallel_info['MKL Available'] = torch.backends.mkl.is_available()

        # Check for MKL-DNN/oneDNN
        if hasattr(torch.backends, 'mkldnn'):
            parallel_info['MKL-DNN Available'] = torch.backends.mkldnn.is_available()

        if hasattr(torch.backends, 'onednn'):
            parallel_info['oneDNN Available'] = torch.backends.onednn.is_available()

        build_info['Parallel Libraries'] = parallel_info

        # Check for available Python bindings
        bindings = {}

        # Check for ONNX export capability
        if hasattr(torch, 'onnx') and hasattr(torch.onnx, 'export'):
            bindings['ONNX'] = True

        # Check for C++ extension support
        if hasattr(torch, 'utils') and hasattr(torch.utils, 'cpp_extension'):
            bindings['C++ Extensions'] = True

        # Check for distributed support
        if hasattr(torch, 'distributed') and torch.distributed.is_available():
            bindings['Distributed'] = True

        build_info['Available Bindings'] = bindings

        # Check if torch was built with CUDA
        build_info['Built with CUDA'] = torch.cuda.is_available()

        # Check if torch was built with ROCm
        if hasattr(torch.version, 'hip') and torch.version.hip:
            build_info['Built with ROCm'] = True

        # Check if torch was built with MPS support
        if hasattr(torch.backends, 'mps'):
            build_info['Built with MPS'] = torch.backends.mps.is_built()

        self.info['PyTorch Build Information'] = build_info

    def collect_extension_info(self) -> None:
        """Collect information about PyTorch extensions."""
        extension_info = {}

        # Check for C++ extension capabilities
        cpp_extension = {}
        if hasattr(torch, 'utils') and hasattr(torch.utils, 'cpp_extension'):
            cpp_extension['Available'] = True

            # Try to get compiler settings
            try:
                from torch.utils.cpp_extension import CUDA_HOME
                cpp_extension['CUDA_HOME'] = CUDA_HOME
            except (ImportError, AttributeError):
                pass

            try:
                from torch.utils.cpp_extension import CXX
                cpp_extension['CXX Compiler'] = CXX
            except (ImportError, AttributeError):
                pass

            try:
                from torch.utils.cpp_extension import PYTORCH_EXTENSION_PATH
                cpp_extension['Extension Path'] = PYTORCH_EXTENSION_PATH
            except (ImportError, AttributeError):
                pass
        else:
            cpp_extension['Available'] = False

        extension_info['C++ Extensions'] = cpp_extension

        # Check for ONNX export capabilities
        onnx_info = {}
        if hasattr(torch, 'onnx'):
            onnx_info['Available'] = True

            # Try to get ONNX version if onnx is installed
            try:
                import onnx
                onnx_info['ONNX Library Version'] = onnx.__version__
            except ImportError:
                onnx_info['ONNX Library'] = 'Not Installed'
        else:
            onnx_info['Available'] = False

        extension_info['ONNX Support'] = onnx_info

        # Check for mobile capabilities
        mobile_info = {}
        if hasattr(torch, '_C') and hasattr(torch._C, '_mobile_optimizer'):
            mobile_info['Available'] = True

            # Check for lite interpreter
            if hasattr(torch, '_C') and hasattr(torch._C, '_jit_logging_levels'):
                mobile_info['Lite Interpreter'] = True
        else:
            mobile_info['Available'] = False

        extension_info['Mobile Support'] = mobile_info

        # Check for quantization support
        quant_info = {}
        if hasattr(torch, 'quantization'):
            quant_info['Available'] = True

            # Check for specific quantization features
            if hasattr(torch.quantization, 'default_qconfig'):
                quant_info['Default QConfig'] = True

            if hasattr(torch.quantization, 'QConfig'):
                quant_info['QConfig Class'] = True

            quant_backends = []
            if hasattr(torch.quantization, 'quantize_jit'):
                quant_backends.append('JIT')
            if hasattr(torch.quantization, 'quantize_dynamic'):
                quant_backends.append('Dynamic')
            if hasattr(torch.quantization, 'quantize_qat'):
                quant_backends.append('QAT')

            quant_info['Supported Modes'] = quant_backends
        else:
            quant_info['Available'] = False

        extension_info['Quantization Support'] = quant_info

        # Check for custom ops registrations capability
        custom_ops = {}
        if hasattr(torch, 'ops') and hasattr(torch.ops, '_OpNamespace'):
            custom_ops['Available'] = True

            # Try to list registered custom ops
            try:
                all_namespaces = dir(torch.ops)
                custom_namespaces = [ns for ns in all_namespaces if not ns.startswith('_')]
                if custom_namespaces:
                    custom_ops['Registered Namespaces'] = custom_namespaces
            except Exception:
                pass
        else:
            custom_ops['Available'] = False

        extension_info['Custom Ops'] = custom_ops

        # Check for TorchServe support
        try:
            import torchserve
            extension_info['TorchServe'] = {'Available': True, 'Version': torchserve.__version__}
        except ImportError:
            extension_info['TorchServe'] = {'Available': False}

        # Check for TorchX support
        try:
            import torchx
            extension_info['TorchX'] = {'Available': True, 'Version': torchx.__version__}
        except ImportError:
            extension_info['TorchX'] = {'Available': False}

        # Check for TorchRec support
        try:
            import torchrec
            extension_info['TorchRec'] = {'Available': True, 'Version': torchrec.__version__}
        except ImportError:
            extension_info['TorchRec'] = {'Available': False}

        self.info['PyTorch Extensions'] = extension_info




class InfoFormatter:
    """Format collected information in a readable format."""

    # Define styles for different importance levels
    STYLES = {
        "critical": Style(color="red", bold=True),
        "warning": Style(color="yellow"),
        "positive": Style(color="green"),
        "highlight": Style(color="bright_cyan", bold=True),
        "info": Style(color="cyan"),
        "neutral": Style(color="white"),
        "section": Style(color="magenta", bold=True),
        "subsection": Style(color="blue", bold=True),
        "key": Style(color="bright_white", italic=True),
        "dim": Style(color="grey70"),
        "header": Style(color="bright_magenta", bold=True, underline=True),
    }

    @staticmethod
    def make_json_serializable(obj):
        """Convert non-serializable objects to serializable types."""
        if obj is None:
            return None
        elif isinstance(obj, (str, int, float, bool)):
            return obj
        elif isinstance(obj, (list, tuple)):
            return [InfoFormatter.make_json_serializable(item) for item in obj]
        elif isinstance(obj, dict):
            return {key: InfoFormatter.make_json_serializable(value) for key, value in obj.items()}
        elif hasattr(obj, 'device'):  # Handle torch.device objects
            return str(obj)
        elif hasattr(obj, '__dict__'):  # Handle general objects
            return str(obj)
        else:
            return str(obj)  # Fall back to string representation

    @staticmethod
    def determine_value_importance(key, value):
        """Determine the importance/color of a value based on key and content."""
        # Keys that indicate critical information
        critical_keys = [
            'error', 'cuda available', 'failure', 'critical',
            'cuda version', 'cudnn version', 'gpu count'
        ]

        # Keys that indicate warnings
        warning_keys = [
            'warning', 'deprecated', 'memory used', 'cpu usage', 'deterministic'
        ]

        # Keys that indicate positive information
        positive_keys = [
            'available', 'supported', 'enabled', 'success', 'capability'
        ]

        # Keys that are important to highlight
        highlight_keys = [
            'version', 'model', 'device', 'capability', 'platform',
            'total memory', 'release'
        ]

        # Convert key to lowercase for case-insensitive matching
        key_lower = str(key).lower()

        # Handle boolean values
        if isinstance(value, bool):
            if value:
                # True values for important keys are highlighted
                for critical in critical_keys:
                    if critical in key_lower:
                        return "positive"
                for positive in positive_keys:
                    if positive in key_lower:
                        return "positive"
                return "positive"
            else:
                # False values for important keys are warnings or critical
                for critical in critical_keys:
                    if critical in key_lower:
                        return "critical"
                for positive in positive_keys:
                    if positive in key_lower:
                        return "warning"
                return "warning"

        # Handle string values
        if isinstance(value, str):
            value_lower = value.lower()

            # Check for critical strings
            if 'error' in value_lower or 'failure' in value_lower or 'not available' in value_lower:
                return "critical"

            # Check for warning strings
            if 'warning' in value_lower or 'deprecated' in value_lower:
                return "warning"

            # Version information is important
            if ('version' in key_lower and len(value) > 0):
                return "highlight"

            if key_lower == 'model' or 'name' in key_lower:
                return "highlight"

        # Memory and resource usage
        if 'memory' in key_lower and 'used' in key_lower and isinstance(value, str):
            # Try to extract percentage
            percentage_match = re.search(r'\((\d+)%\)', value)
            if percentage_match:
                percentage = int(percentage_match.group(1))
                if percentage > 80:
                    return "critical"
                elif percentage > 60:
                    return "warning"
                else:
                    return "positive"

        # Default colors based on key types
        for critical in critical_keys:
            if critical in key_lower:
                return "info"

        for warning in warning_keys:
            if warning in key_lower:
                return "warning"

        for positive in positive_keys:
            if positive in key_lower:
                return "positive"

        for highlight in highlight_keys:
            if highlight in key_lower:
                return "highlight"

        # Default (neutral) color
        return "neutral"

    @staticmethod
    def format_as_tree(tree, data, parent_keys=None):
        """Format nested data as a rich Tree."""
        if parent_keys is None:
            parent_keys = []

        if isinstance(data, dict):
            # Sort keys to match the order in the reference report
            keys = sorted(data.keys(), key=lambda k: (
                # Put these keys first in this order
                k not in ['Version', 'CUDA Available', 'GPU Count', 'Devices', 'Default Dtype',
                         'System', 'Physical Cores', 'Logical Cores', 'Model',
                         'Major Version', 'Minor Version', 'Has CUDA', 'Has MKL',
                         'Python Version', 'Implementation', 'Timestamp', 'Script'],
                # Then sort alphabetically
                k
            ))

            for key in keys:
                value = data[key]
                current_keys = parent_keys + [key]
                key_style = InfoFormatter.STYLES["key"]

                if isinstance(value, dict):
                    # Create a branch for the dictionary
                    branch = tree.add(Text(str(key), style=key_style))
                    InfoFormatter.format_as_tree(branch, value, current_keys)
                elif isinstance(value, list) and value and all(isinstance(item, dict) for item in value):
                    # Create a branch for the list of dictionaries
                    branch = tree.add(Text(str(key), style=key_style))

                    # Add each dict as a separate branch
                    for i, item in enumerate(value):
                        item_text = Text(f"Item {i+1}", style=InfoFormatter.STYLES["subsection"])
                        item_branch = branch.add(item_text)
                        InfoFormatter.format_as_tree(item_branch, item, current_keys)
                else:
                    # Add leaf with styled value
                    importance = InfoFormatter.determine_value_importance(key, value)
                    style = InfoFormatter.STYLES.get(importance, InfoFormatter.STYLES["neutral"])

                    if isinstance(value, list):
                        if not value:
                            value_text = Text("Empty list", style=InfoFormatter.STYLES["dim"])
                        else:
                            value_text = Text(", ".join(str(v) for v in value), style=style)
                    else:
                        value_text = Text(str(value), style=style)

                    tree.add(Text(f"{key}: ", style=key_style) + value_text)
        else:
            # Handle non-dictionary data
            tree.add(Text(str(data)))

        return tree

    @staticmethod
    def format_as_rich(info: Dict[str, Any]) -> None:
        """Format the collected information using rich for colorized output."""
        console = Console()

        # Create a title
        title = Text("PyTorch System and Configuration Information", style=InfoFormatter.STYLES["header"])
        console.print(Rule(title, style="bright_magenta"))
        console.print()

        # Create layout for organized display
        layout = Layout()
        layout.split_column(
            Layout(name="header"),
            Layout(name="content")
        )

        # Process each section
        for section, section_data in info.items():
            # Create a panel title with styled text
            section_text = Text(section, style=InfoFormatter.STYLES["section"])
            console.print(section_text)
            console.print(Rule(style="blue"))

            if isinstance(section_data, dict):
                # For dictionaries, we can use a tree view for better visualization
                if 'Device' in section_data and isinstance(section_data.get('Devices'), list):
                    # Special handling for GPU devices - use tables
                    if 'Devices' in section_data and section_data['Devices']:
                        devices = section_data['Devices']
                        console.print(Text("Devices:", style=InfoFormatter.STYLES["subsection"]))

                        # Create a well-formatted table
                        table = Table(
                            show_header=True,
                            header_style="bold cyan",
                            box=box.ROUNDED,
                            border_style="blue",
                            title=f"Found {len(devices)} GPU devices",
                            title_style="bold cyan"
                        )

                        # Dynamically create columns based on first device
                        if devices:
                            for key in devices[0].keys():
                                table.add_column(str(key))

                            # Add rows for each device
                            for device in devices:
                                row = []
                                for key, value in device.items():
                                    importance = InfoFormatter.determine_value_importance(key, value)
                                    styled_value = Text(str(value), style=InfoFormatter.STYLES[importance])
                                    row.append(styled_value)
                                table.add_row(*row)

                            console.print(table)

                # For other sections, use a tree view
                tree = Tree(
                    Text(f"{section} Details", style=InfoFormatter.STYLES["subsection"]),
                    guide_style="blue"
                )
                InfoFormatter.format_as_tree(tree, section_data)
                console.print(tree)
            else:
                # Just print the value for non-dict entries
                console.print(str(section_data))

            console.print()

    @staticmethod
    def format_as_text(info: Dict[str, Any], indent: int = 4) -> str:
        """Format the collected information as plain text."""
        lines = []
        indent_str = ' ' * indent

        # Add title
        border = "=" * 80
        lines.append(border)
        lines.append("PyTorch System and Configuration Information".center(80))
        lines.append(border)
        lines.append("")

        # Process each section
        for section, section_data in info.items():
            # Section title with clean separator
            section_title = f"  {section}  "
            lines.append(section_title)
            lines.append("=" * len(section_title))

            # Format section data
            if isinstance(section_data, dict):
                for key, value in section_data.items():
                    if isinstance(value, dict):
                        lines.append(f"{indent_str}* {key}:")
                        for sub_key, sub_value in value.items():
                            if isinstance(sub_value, dict):
                                lines.append(f"{indent_str}{indent_str}> {sub_key}:")
                                for sub_sub_key, sub_sub_value in sub_value.items():
                                    lines.append(f"{indent_str}{indent_str}{indent_str}- {sub_sub_key}: {sub_sub_value}")
                            elif isinstance(sub_value, list):
                                lines.append(f"{indent_str}{indent_str}> {sub_key}:")
                                for item in sub_value:
                                    if isinstance(item, dict):
                                        lines.append(f"{indent_str}{indent_str}{indent_str}+ Item:")
                                        for item_key, item_value in item.items():
                                            lines.append(f"{indent_str}{indent_str}{indent_str}  - {item_key}: {item_value}")
                                        lines.append("")
                                    else:
                                        lines.append(f"{indent_str}{indent_str}{indent_str}+ {item}")
                            else:
                                lines.append(f"{indent_str}{indent_str}> {sub_key}: {sub_value}")
                    elif isinstance(value, list):
                        lines.append(f"{indent_str}* {key}:")
                        if all(isinstance(item, dict) for item in value) and value:
                            # Special formatting for list of dictionaries (e.g., GPU devices)
                            for i, item in enumerate(value):
                                lines.append(f"{indent_str}{indent_str}> Item {i+1}:")
                                for item_key, item_value in item.items():
                                    lines.append(f"{indent_str}{indent_str}{indent_str}- {item_key}: {item_value}")
                                lines.append("")
                        else:
                            for item in value:
                                lines.append(f"{indent_str}{indent_str}> {item}")
                    else:
                        # Handle multi-line values
                        if isinstance(value, str) and '\n' in value:
                            lines.append(f"{indent_str}● {key}:")
                            for line in value.split('\n'):
                                lines.append(f"{indent_str}{indent_str}{line}")
                        else:
                            lines.append(f"{indent_str}● {key}: {value}")
            else:
                lines.append(f"{indent_str}{section_data}")

            lines.append("")

        return '\n'.join(lines)

    @staticmethod
    def format_as_json(info: Dict[str, Any]) -> str:
        """Format the collected information as JSON."""
        # Make all objects JSON-serializable first
        serializable_info = InfoFormatter.make_json_serializable(info)
        return json.dumps(serializable_info, indent=2)

    @staticmethod
    def format_as_markdown(info: Dict[str, Any]) -> str:
        """Format the collected information as Markdown."""
        lines = []

        # Add title
        lines.append("# PyTorch System and Configuration Information")
        lines.append("")

        # Process each section
        for section, section_data in info.items():
            lines.append(f"## {section}")
            lines.append("")

            # Format section data
            if isinstance(section_data, dict):
                for key, value in section_data.items():
                    if isinstance(value, dict):
                        lines.append(f"### {key}")
                        lines.append("")
                        lines.append("| Property | Value |")
                        lines.append("| --- | --- |")
                        for sub_key, sub_value in value.items():
                            if isinstance(sub_value, dict):
                                lines.append(f"| **{sub_key}** | |")
                                for sub_sub_key, sub_sub_value in sub_value.items():
                                    lines.append(f"| &nbsp;&nbsp;&nbsp;&nbsp;{sub_sub_key} | {sub_sub_value} |")
                            elif isinstance(sub_value, list):
                                if all(isinstance(item, dict) for item in sub_value) and sub_value:
                                    # Handle lists of dictionaries (like GPU devices)
                                    lines.append(f"#### {sub_key}")
                                    lines.append("")
                                    for i, item in enumerate(sub_value):
                                        lines.append(f"##### Item {i+1}")
                                        lines.append("")
                                        lines.append("| Property | Value |")
                                        lines.append("| --- | --- |")
                                        for item_key, item_value in item.items():
                                            lines.append(f"| {item_key} | {item_value} |")
                                        lines.append("")
                                else:
                                    sub_value_str = ", ".join(str(item) for item in sub_value)
                                    lines.append(f"| {sub_key} | {sub_value_str} |")
                            else:
                                lines.append(f"| {sub_key} | {sub_value} |")
                        lines.append("")
                    elif isinstance(value, list):
                        if all(isinstance(item, dict) for item in value) and value:
                            lines.append(f"### {key}")
                            lines.append("")
                            for i, item in enumerate(value):
                                if len(value) > 1:
                                    lines.append(f"#### Item {i+1}")
                                    lines.append("")
                                lines.append("| Property | Value |")
                                lines.append("| --- | --- |")
                                for item_key, item_value in item.items():
                                    lines.append(f"| {item_key} | {item_value} |")
                                lines.append("")
                        else:
                            value_str = "<br>".join(str(item) for item in value)
                            lines.append(f"**{key}**: {value_str}")
                            lines.append("")
                    else:
                        # Handle multi-line values (like package lists)
                        if isinstance(value, str) and '\n' in value:
                            lines.append(f"### {key}")
                            lines.append("```")
                            lines.append(value)
                            lines.append("```")
                            lines.append("")
                        else:
                            lines.append(f"**{key}**: {value}")
                            lines.append("")
            else:
                lines.append(section_data)
                lines.append("")

        return '\n'.join(lines)


def main():
    # Create console for rich output
    if RICH_AVAILABLE:
        console = Console()

        # Welcome banner with styled text
        console.print()
        title = Text("PyTorch System and Configuration Information Dumper", style="bold cyan")
        console.print(Rule(title, style="cyan"))
        console.print()
    else:
        print("=" * 80)
        print("PyTorch System and Configuration Information Dumper".center(80))
        print("=" * 80)

    # Check if PyTorch is available
    if not TORCH_AVAILABLE:
        if RICH_AVAILABLE:
            console.print(Panel(
                "[bold red]PyTorch is not available in this environment.[/bold red]\n"
                "Install with: [green]pip install torch[/green]",
                title="Error",
                border_style="red"
            ))
        else:
            print("Error: PyTorch is not available in this environment.")
            print("Install with: pip install torch")
        sys.exit(1)

    # Collect system information with progress indicator
    if RICH_AVAILABLE:
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            task = progress.add_task("Collecting system information...", total=1)
            collector = SystemInfoCollector()
            info = collector.collect_all()
            progress.update(task, completed=1)
    else:
        print("\nCollecting system information...")
        collector = SystemInfoCollector()
        info = collector.collect_all()

    # Format and display the information
    if RICH_AVAILABLE:
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            task = progress.add_task("Formatting information...", total=1)
            progress.update(task, completed=1)

        console.print()
        InfoFormatter.format_as_rich(info)
    else:
        print("Formatting information...")
        text_formatter = InfoFormatter()
        text_output = text_formatter.format_as_text(info)
        print("\nPyTorch System Information:")
        print("-" * 80)
        print(text_output)


if __name__ == "__main__":
    main()