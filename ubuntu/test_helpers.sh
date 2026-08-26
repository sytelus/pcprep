#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
PYTHON=${PCPREP_TEST_PYTHON:-$(command -v python3 || command -v python || true)}
[[ -n $PYTHON ]] || { echo "Set PCPREP_TEST_PYTHON to a Python 3 interpreter." >&2; exit 1; }

mkdir -p "$TEST_ROOT/empty"
"$PYTHON" "$SCRIPT_DIR/git_status.py" "$TEST_ROOT/empty" \
  | grep -q 'No immediate subdirectories found.'

mkdir -p "$TEST_ROOT/home/.vscode-server" "$TEST_ROOT/home/.vscode-serve"
! HOME=/ PCPREP_SKIP_PROCESS_KILL=1 USER="${USER:-pcprep}" \
  bash "$SCRIPT_DIR/kill_vscode_srv.sh" --yes >/dev/null 2>&1
HOME="$TEST_ROOT/home" PCPREP_SKIP_PROCESS_KILL=1 USER="${USER:-pcprep}" \
  bash "$SCRIPT_DIR/kill_vscode_srv.sh" --yes >/dev/null
[[ ! -e $TEST_ROOT/home/.vscode-server ]]
[[ -d $TEST_ROOT/home/.vscode-serve ]]

! grep -Eq 'install[[:space:]]+cuda-toolkit([[:space:]]|$)' "$SCRIPT_DIR/install_cuda12.4.sh"
[[ -f $SCRIPT_DIR/install_cuda.sh && ! -e $SCRIPT_DIR/install_cuda12.8.sh ]]
grep -q '22.04|24.04|26.04' "$SCRIPT_DIR/install_cuda.sh"
grep -q 'aarch64|arm64) CUDA_ARCH=sbsa' "$SCRIPT_DIR/install_cuda.sh"
grep -Fq 'CUDA_VERSION=${CUDA_VERSION:-13.2}' "$SCRIPT_DIR/install_cuda.sh"
grep -Fq 'CUDA_VERSION=${CUDA_VERSION:-13.2}' "$SCRIPT_DIR/prepare_new_box.sh"
grep -Fq 'MINICONDA_VERSION=${MINICONDA_VERSION:-26.5.3-1}' "$SCRIPT_DIR/install_miniconda.sh"
grep -Fq 'PYTHON_VERSION=${PYTHON_VERSION:-3.14}' "$SCRIPT_DIR/install_miniconda.sh"
grep -Fq 'PYTORCH_VERSION=${PYTORCH_VERSION:-2.13.0}' "$SCRIPT_DIR/install_dl_frameworks.sh"
grep -Fq 'TORCHVISION_VERSION=${TORCHVISION_VERSION:-0.28.0}' "$SCRIPT_DIR/install_dl_frameworks.sh"
! grep -Eq 'pip install[^#]*tensorflow' "$SCRIPT_DIR/install_dl_frameworks.sh"
grep -Fq 'NVM_VERSION=${NVM_VERSION:-0.40.6}' "$SCRIPT_DIR/min_system.sh"
grep -Fq 'nvm/v${NVM_VERSION}/install.sh' "$SCRIPT_DIR/min_system.sh"
! grep -Eq '^[[:space:]]*npm nodejs' "$SCRIPT_DIR/min_system.sh"
grep -Fq 'npm install -g @openai/codex@latest' "$SCRIPT_DIR/prepare_new_box.sh"
! grep -Fq 'sudo npm' "$SCRIPT_DIR/prepare_new_box.sh"
! grep -qi 'tensorflow' "$SCRIPT_DIR/../tests/cuda.py"
grep -Fq 'KERAS_BACKEND' "$SCRIPT_DIR/../tests/cuda.py"
! grep -q 'ppa:wslutilities/wslu' "$SCRIPT_DIR/prepare_new_box.sh"
! grep -q 'credential.helper manager-core' "$SCRIPT_DIR/prepare_new_box.sh"
! grep -q '/Applications/Tailscale.app' "$SCRIPT_DIR/prepare_new_box.sh"
grep -q 'grep -qi microsoft /proc/version' "$SCRIPT_DIR/prepare_new_box.sh"
grep -q 'PCPREP_WIN_GCM_PATH' "$SCRIPT_DIR/prepare_new_box.sh"
grep -Fq 'CP_NO_CLOBBER=(--update=none)' "$SCRIPT_DIR/cp_dotfiles.sh"
grep -Fq 'if cp --update=none --version' "$SCRIPT_DIR/cp_dotfiles.sh"
grep -Fq 'cp -vr "${CP_NO_CLOBBER[@]}" .config/' "$SCRIPT_DIR/cp_dotfiles.sh"
grep -Fq 'cp -v "${CP_NO_CLOBBER[@]}" "$helper" "$HOME/.local/bin/$helper"' \
  "$SCRIPT_DIR/cp_dotfiles.sh"
! grep -Eq 'cp[[:space:]]+-[^[:space:]]*n' "$SCRIPT_DIR/cp_dotfiles.sh"
grep -q 'install_first_available 7zip p7zip-full' "$SCRIPT_DIR/extra_install.sh"
grep -q 'install_first_available bind9-dnsutils dnsutils' "$SCRIPT_DIR/extra_install.sh"
grep -q 'install_pkg psmisc' "$SCRIPT_DIR/extra_install.sh"
grep -q 'install_pkg procps' "$SCRIPT_DIR/extra_install.sh"
grep -q 'DIST_CODE=jammy' "$SCRIPT_DIR/min_system.sh"
! grep -q 'newgrp[[:space:]]\+docker' "$SCRIPT_DIR/install_docker.sh"
grep -q 'wsl_prep.md' "$SCRIPT_DIR/prepare_new_box.sh"
! grep -q 'wsl_prep.sh' "$SCRIPT_DIR/prepare_new_box.sh"
grep -A4 'def collect_all' "$SCRIPT_DIR/torch_info.py" | grep -q 'collect_basic_info()'
! grep -q 'chmod +x \*\.sh' "$SCRIPT_DIR/cp_dotfiles.sh"
! grep -q 'is_vscode_Shell' "$SCRIPT_DIR/.bashrc"
! grep -q 'GIT_TEST_ASSUME_ALL_SAFE' "$SCRIPT_DIR/.bashrc"
[[ $(grep -Ec '^[[:space:]]*ssh-agent -s' "$SCRIPT_DIR/.bashrc") -eq 1 ]]
grep -q 'mode:[[:space:]]*msi' "$SCRIPT_DIR/azmount.yaml"
! grep -q 'account-key:' "$SCRIPT_DIR/azmount.yaml"
! AZMOUNT_POINT=/ bash "$SCRIPT_DIR/azmount.sh" >/dev/null 2>&1
! AZMOUNT_POINT=/ bash "$SCRIPT_DIR/azunmount.sh" >/dev/null 2>&1
[[ -f $SCRIPT_DIR/install_tailscale.sh && ! -e $SCRIPT_DIR/install_tailscale.py ]]
[[ -f $SCRIPT_DIR/install_minikube.sh && ! -e $SCRIPT_DIR/minikube-linux-amd64 ]]
grep -Fqx 'claudeyolo=claude --dangerously-skip-permissions --remote-control= $*' \
  "$SCRIPT_DIR/../windows/aliases.doskey"
grep -Fqx 'codexyolo=codex --yolo' "$SCRIPT_DIR/../windows/aliases.doskey"
grep -Fqx 'claudeupdate=claude update' "$SCRIPT_DIR/../windows/aliases.doskey"
grep -Fqx 'codexupdate=powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"' \
  "$SCRIPT_DIR/../windows/aliases.doskey"

(
  export USER=${USER:-pcprep}
  # The alias file starts by removing this name; seed it so that cleanup also
  # succeeds while this test suite has errexit enabled.
  alias pcprep_unalias=true
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.bash_aliases"
  claude() {
    [[ $# -eq 5 ]]
    [[ $1 == --dangerously-skip-permissions ]]
    [[ $2 == --remote-control= ]]
    [[ $3 == --model ]]
    [[ $4 == "opus test" ]]
    [[ $5 == "prompt words" ]]
  }
  codex() {
    [[ $# -eq 4 ]]
    [[ $1 == --yolo ]]
    [[ $2 == --model ]]
    [[ $3 == "gpt test" ]]
    [[ $4 == "prompt words" ]]
  }
  claudeyolo --model "opus test" "prompt words"
  codexyolo --model "gpt test" "prompt words"
)

if bash "$SCRIPT_DIR/mount_cifs.sh" bad/name //server/share user </dev/null >/dev/null 2>&1; then
  echo "mount_cifs accepted an invalid mount name" >&2
  exit 1
fi
if bash "$SCRIPT_DIR/mount_cifs.sh" . //server/share user </dev/null >/dev/null 2>&1; then
  echo "mount_cifs accepted a path-alias mount name" >&2
  exit 1
fi
if bash "$SCRIPT_DIR/mount_cifs.sh" name '//server/share with-space' user </dev/null >/dev/null 2>&1; then
  echo "mount_cifs accepted whitespace in a share" >&2
  exit 1
fi

echo "helper regression tests passed"
