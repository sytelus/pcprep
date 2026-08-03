#!/usr/bin/env bash
set -Eeuo pipefail

NO_NET=${NO_NET:-0}
INSTALL_PYTORCH=${INSTALL_PYTORCH:-1}
PYTORCH_ACCELERATOR=${PYTORCH_ACCELERATOR:-auto}
PYTORCH_VERSION=${PYTORCH_VERSION:-2.13.0}
TORCHVISION_VERSION=${TORCHVISION_VERSION:-0.28.0}
PYTHON=${PYTHON:-}

[[ $NO_NET = 0 ]] || { echo "NO_NET=$NO_NET; skipping DL framework installation."; exit 0; }
if [[ -z $PYTHON ]]; then
  PYTHON=$(command -v python3 || command -v python || true)
fi
[[ -n $PYTHON ]] || { echo "Python is required." >&2; exit 1; }
[[ -x $PYTHON ]] || { echo "Python is not executable: $PYTHON" >&2; exit 1; }

case $(uname -m) in
  x86_64|amd64) ARCH=x86_64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

"$PYTHON" -m pip install -q --upgrade pip setuptools wheel
"$PYTHON" -m pip install -q --upgrade \
  pandas scikit-learn matplotlib jupyter tensorboard

# TensorFlow 2.21 does not publish Python 3.14 wheels. Remove old variants so
# the latest stable Python environment has one coherent Keras/PyTorch backend.
"$PYTHON" -m pip uninstall -q -y \
  tensorflow tensorflow-cpu tensorflow-intel tf-nightly || true

bool_is_true() {
  case ${1:-0} in 1|y|Y|yes|YES|true|TRUE|on|ON) return 0 ;; *) return 1 ;; esac
}

version_ge() {
  printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

detect_driver_cuda() {
  command -v nvidia-smi >/dev/null 2>&1 || return 1
  nvidia-smi | sed -n 's/.*CUDA Version: \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n1
}

select_accelerator() {
  local reported_cuda=$1
  if [[ $PYTORCH_ACCELERATOR != auto ]]; then
    printf '%s\n' "$PYTORCH_ACCELERATOR"
    return
  fi
  if [[ -z $reported_cuda ]]; then
    printf 'cpu\n'
  elif version_ge "$reported_cuda" 13.2; then
    printf 'cu132\n'
  elif version_ge "$reported_cuda" 13.0; then
    printf 'cu130\n'
  elif version_ge "$reported_cuda" 12.6; then
    printf 'cu126\n'
  else
    echo "NVIDIA driver reports CUDA $reported_cuda, below the supported cu126 wheel." >&2
    echo "Upgrade the driver or set PYTORCH_ACCELERATOR=cpu explicitly." >&2
    return 1
  fi
}

if bool_is_true "$INSTALL_PYTORCH"; then
  DRIVER_CUDA=$(detect_driver_cuda || true)
  ACCELERATOR=$(select_accelerator "$DRIVER_CUDA")
  case $ACCELERATOR in
    cpu|cu126|cu130|cu132) ;;
    *) echo "Unsupported PYTORCH_ACCELERATOR=$ACCELERATOR" >&2; exit 2 ;;
  esac
  if [[ $ACCELERATOR == cu* ]]; then
    [[ -n $DRIVER_CUDA ]] || { echo "A CUDA wheel requires a working NVIDIA driver." >&2; exit 1; }
    case $ACCELERATOR in cu126) MIN_DRIVER_CUDA=12.6 ;; cu130) MIN_DRIVER_CUDA=13.0 ;; cu132) MIN_DRIVER_CUDA=13.2 ;; esac
    version_ge "$DRIVER_CUDA" "$MIN_DRIVER_CUDA" \
      || { echo "Driver supports CUDA $DRIVER_CUDA, below $ACCELERATOR." >&2; exit 1; }
  fi

  INDEX_URL="https://download.pytorch.org/whl/$ACCELERATOR"
  echo "Installing PyTorch $PYTORCH_VERSION/$TORCHVISION_VERSION from $INDEX_URL"
  "$PYTHON" -m pip install -q \
    "torch==$PYTORCH_VERSION" "torchvision==$TORCHVISION_VERSION" \
    --index-url "$INDEX_URL"
  "$PYTHON" -m pip install -q --upgrade keras

  EXPECT_CUDA=0
  [[ $ACCELERATOR == cu* ]] && EXPECT_CUDA=1
  EXPECT_CUDA=$EXPECT_CUDA "$PYTHON" - <<'PY'
import json
import os
from pathlib import Path

keras_home = Path(os.environ.get("KERAS_HOME", Path.home() / ".keras"))
keras_config = keras_home / "keras.json"
config = {}
if keras_config.exists():
    config = json.loads(keras_config.read_text(encoding="utf-8-sig"))
    if not isinstance(config, dict):
        raise SystemExit(f"Expected a JSON object in {keras_config}")
if config.get("backend") != "torch":
    config["backend"] = "torch"
    keras_home.mkdir(parents=True, exist_ok=True)
    temporary_config = keras_config.with_suffix(".json.tmp")
    temporary_config.write_text(json.dumps(config, indent=4) + "\n", encoding="utf-8")
    temporary_config.replace(keras_config)

os.environ["KERAS_BACKEND"] = "torch"
import keras
import torch
import torchvision

expected = os.environ["EXPECT_CUDA"] == "1"
if keras.backend.backend() != "torch":
    raise SystemExit(f"Keras selected unexpected backend: {keras.backend.backend()}")
if expected and not torch.cuda.is_available():
    raise SystemExit("CUDA wheel installed but torch.cuda.is_available() is false")
device = "cuda" if expected else "cpu"
a = torch.tensor([[1.0, 2.0], [3.0, 4.0]], device=device)
b = a @ a
if b.shape != (2, 2) or float(b[0, 0].cpu()) != 7.0:
    raise SystemExit("PyTorch tensor verification failed")
if expected:
    torch.cuda.synchronize()
print(f"Keras {keras.__version__} using the PyTorch backend")
print(f"PyTorch {torch.__version__}/TorchVision {torchvision.__version__} verified on {device}")
PY
else
  echo "INSTALL_PYTORCH=$INSTALL_PYTORCH; skipping PyTorch."
fi

"$PYTHON" -m pip install -q --upgrade \
  transformers datasets wandb accelerate einops tokenizers sentencepiece
if bool_is_true "$INSTALL_PYTORCH"; then
  "$PYTHON" -m pip install -q --upgrade lightning
fi

"$PYTHON" -m pip check
