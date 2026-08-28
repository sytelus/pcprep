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
grep -Fq 'https://repo.anaconda.com/pkgs/main' "$SCRIPT_DIR/install_miniconda.sh"
grep -Fq 'https://repo.anaconda.com/pkgs/r' "$SCRIPT_DIR/install_miniconda.sh"
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
grep -Fq 'Defaults timestamp_timeout=$timeout_minutes' "$SCRIPT_DIR/prepare_new_box.sh"
grep -Fq '153722867280912930' "$SCRIPT_DIR/prepare_new_box.sh"
grep -Fq '/etc/sudoers.d/99-pcprep-wsl-timestamp-timeout' "$SCRIPT_DIR/prepare_new_box.sh"
grep -Fq 'sudo visudo -cf "$sudoers_candidate"' "$SCRIPT_DIR/prepare_new_box.sh"
grep -Fq 'PCPREP_AUDIT_DIR:-$HOME/.pcprep' "$SCRIPT_DIR/prepare_new_box.sh"
grep -Fq 'prepare_new_box.latest.log' "$SCRIPT_DIR/prepare_new_box.sh"
grep -Fq 'event=run_started' "$SCRIPT_DIR/prepare_new_box.sh"
grep -Fq 'event=run_finished' "$SCRIPT_DIR/prepare_new_box.sh"
grep -Fq 'chmod 0600 -- "$PCPREP_AUDIT_LOG"' "$SCRIPT_DIR/prepare_new_box.sh"
grep -Fq "trap 'audit_run_finished" "$SCRIPT_DIR/prepare_new_box.sh"
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

grep -q '^collect_git_identity()' "$SCRIPT_DIR/prepare_new_box.sh"
grep -q '^collect_bootstrap_inputs()' "$SCRIPT_DIR/prepare_new_box.sh"
startup_input_line=$(grep -n '^collect_bootstrap_inputs$' "$SCRIPT_DIR/prepare_new_box.sh" | cut -d: -f1)
sudo_validation_line=$(grep -n '^sudo -v ' "$SCRIPT_DIR/prepare_new_box.sh" | cut -d: -f1)
gitconfig_line=$(grep -n '^bash gitconfig.sh$' "$SCRIPT_DIR/prepare_new_box.sh" | cut -d: -f1)
[[ -n $startup_input_line && -n $sudo_validation_line && -n $gitconfig_line ]]
(( startup_input_line < sudo_validation_line && startup_input_line < gitconfig_line ))

# Exercise the startup identity collector without sourcing the orchestrator's
# executable main section. Blank answers accept existing global Git values.
# Explicit environment values must also support a completely closed stdin.
# shellcheck disable=SC1090
source <(sed -n '/^bootstrap_value_is_valid()/,/^configure_wsl_sudo_timeout()/p' \
  "$SCRIPT_DIR/prepare_new_box.sh" | sed '$d')
identity_home="$TEST_ROOT/identity-home"
mkdir -p "$identity_home"
HOME="$identity_home" git config --global user.name 'Existing User'
HOME="$identity_home" git config --global user.email 'existing@example.invalid'
(
  export HOME="$identity_home"
  user_name=
  user_email=
  collect_git_identity
  [[ $user_name == 'Existing User' ]]
  [[ $user_email == 'existing@example.invalid' ]]
) <<< $'\n\n'
(
  user_name='Automated User'
  user_email='automated@example.invalid'
  IS_WSL=0
  NO_NET=1
  collect_bootstrap_inputs </dev/null
  [[ $user_name == 'Automated User' ]]
  [[ $user_email == 'automated@example.invalid' ]]
) >/dev/null
if (user_name=; prompt_required_bootstrap_value user_name 'Git user name' '' </dev/null) \
    >/dev/null 2>&1; then
  echo "Startup input collector accepted an unavailable required value." >&2
  exit 1
fi
if (user_name=$'invalid\nname'; prompt_required_bootstrap_value user_name 'Git user name' '' </dev/null) \
    >/dev/null 2>&1; then
  echo "Startup input collector accepted a multiline environment value." >&2
  exit 1
fi

miniconda_home="$TEST_ROOT/miniconda-home"
miniconda_calls="$TEST_ROOT/miniconda-conda-calls"
miniconda_installer_calls="$TEST_ROOT/miniconda-installer-calls"
miniconda_python_upgraded="$TEST_ROOT/miniconda-python-upgraded"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'prefix=' \
  'while (( $# )); do' \
  '  case $1 in' \
  '    -p) prefix=$2; shift 2 ;;' \
  '    *) shift ;;' \
  '  esac' \
  'done' \
  '[[ -n $prefix ]]' \
  'printf "%s\n" "$prefix" >> "$PCPREP_TEST_INSTALLER_CALLS"' \
  'install -D -m 0755 "$PCPREP_TEST_CONDA_TEMPLATE" "$prefix/bin/conda"' \
  'install -D -m 0755 "$PCPREP_TEST_PYTHON_TEMPLATE" "$prefix/bin/python"' \
  > "$TEST_ROOT/miniconda-installer.sh"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "%s\n" "$*" >> "$PCPREP_TEST_CONDA_CALLS"' \
  'if [[ ${1:-} == install ]]; then' \
  '  : > "$PCPREP_TEST_PYTHON_UPGRADED"' \
  'fi' \
  > "$TEST_ROOT/miniconda-conda-template"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [[ -e $PCPREP_TEST_PYTHON_UPGRADED ]]; then' \
  '  version=3.14.0' \
  'else' \
  '  version=3.13.14' \
  'fi' \
  'if [[ ${1:-} == -c ]]; then' \
  '  printf "%s\n" "$version"' \
  'else' \
  '  printf "Python %s\n" "$version"' \
  'fi' \
  > "$TEST_ROOT/miniconda-python-template"

run_miniconda_fixture() {
  local fixture_home=$1
  local fixture_calls=$2
  local fixture_installer_calls=$3
  local fixture_python_upgraded=$4

  HOME="$fixture_home" \
    NO_NET=0 \
    MINICONDA_FILE="$TEST_ROOT/miniconda-installer.sh" \
    PCPREP_TEST_CONDA_CALLS="$fixture_calls" \
    PCPREP_TEST_INSTALLER_CALLS="$fixture_installer_calls" \
    PCPREP_TEST_CONDA_TEMPLATE="$TEST_ROOT/miniconda-conda-template" \
    PCPREP_TEST_PYTHON_TEMPLATE="$TEST_ROOT/miniconda-python-template" \
    PCPREP_TEST_PYTHON_UPGRADED="$fixture_python_upgraded" \
    bash "$SCRIPT_DIR/install_miniconda.sh" >/dev/null
}

# The first invocation starts without a Miniconda prefix; the second verifies a
# normal rerun after the first invocation completed successfully.
[[ ! -e $miniconda_home/miniconda3 ]]
run_miniconda_fixture "$miniconda_home" "$miniconda_calls" \
  "$miniconda_installer_calls" "$miniconda_python_upgraded"
[[ -x $miniconda_home/miniconda3/bin/conda ]]
[[ -x $miniconda_home/miniconda3/bin/python ]]
[[ -e $miniconda_python_upgraded ]]
run_miniconda_fixture "$miniconda_home" "$miniconda_calls" \
  "$miniconda_installer_calls" "$miniconda_python_upgraded"

mapfile -t miniconda_conda_calls < "$miniconda_calls"
expected_miniconda_calls=(
  'tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main'
  'tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r'
  'install --yes --solver classic python=3.14 pip'
  'tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main'
  'tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r'
  '--version'
)
[[ ${#miniconda_conda_calls[@]} -eq 13 ]]
for expected_call_index in "${!expected_miniconda_calls[@]}"; do
  [[ ${miniconda_conda_calls[$expected_call_index]} == \
    "${expected_miniconda_calls[$expected_call_index]}" ]]
  rerun_call_index=$((expected_call_index + 7))
  [[ ${miniconda_conda_calls[$rerun_call_index]} == \
    "${expected_miniconda_calls[$expected_call_index]}" ]]
done
[[ ${miniconda_conda_calls[6]} == '--version' ]]
[[ $(wc -l < "$miniconda_installer_calls") -eq 1 ]]
grep -Fqx "$miniconda_home/miniconda3" "$miniconda_installer_calls"

# Model the reported failure point separately: the installer has created a
# Python 3.13 prefix, but the first ToS-gated transaction has not run.
partial_home="$TEST_ROOT/miniconda-partial-home"
partial_calls="$TEST_ROOT/miniconda-partial-conda-calls"
partial_installer_calls="$TEST_ROOT/miniconda-partial-installer-calls"
partial_python_upgraded="$TEST_ROOT/miniconda-partial-python-upgraded"
PCPREP_TEST_INSTALLER_CALLS="$partial_installer_calls" \
  PCPREP_TEST_CONDA_TEMPLATE="$TEST_ROOT/miniconda-conda-template" \
  PCPREP_TEST_PYTHON_TEMPLATE="$TEST_ROOT/miniconda-python-template" \
  bash "$TEST_ROOT/miniconda-installer.sh" -b -u \
    -p "$partial_home/miniconda3"
[[ -x $partial_home/miniconda3/bin/conda ]]
[[ ! -e $partial_python_upgraded ]]
run_miniconda_fixture "$partial_home" "$partial_calls" \
  "$partial_installer_calls" "$partial_python_upgraded"
[[ -e $partial_python_upgraded ]]
mapfile -t partial_conda_calls < "$partial_calls"
[[ ${#partial_conda_calls[@]} -eq 7 ]]
[[ ${partial_conda_calls[0]} == '--version' ]]
for expected_call_index in "${!expected_miniconda_calls[@]}"; do
  partial_call_index=$((expected_call_index + 1))
  [[ ${partial_conda_calls[$partial_call_index]} == \
    "${expected_miniconda_calls[$expected_call_index]}" ]]
done
[[ $(wc -l < "$partial_installer_calls") -eq 1 ]]
grep -Fqx "$partial_home/miniconda3" "$partial_installer_calls"

run_audit_failure_fixture() (
  set -Eeuo pipefail
  # Source only the audit helpers; sourcing the entire orchestrator would start
  # the real bootstrap. The final sed removes the is_wsl_environment signature.
  # shellcheck disable=SC1090
  source <(sed -n '/^audit_timestamp()/,/^is_wsl_environment()/p' \
    "$SCRIPT_DIR/prepare_new_box.sh" | sed '$d')

  export HOME="$TEST_ROOT/audit-home"
  mkdir -p "$HOME"
  INVOCATION_DIR="$TEST_ROOT/invocation"
  IS_WSL=1
  NO_NET=""
  INSTALL_CUDA=0
  CUDA_VERSION=13.2
  INSTALL_PYTORCH=1
  PYTHON_VERSION=3.14
  PYTORCH_VERSION=2.13.0
  TORCHVISION_VERSION=0.28.0

  start_run_audit
  printf 'isolated-audit-test-marker\n'
  exit 7
)

audit_fixture_status=0
if run_audit_failure_fixture >/dev/null 2>&1; then
  echo "Audit failure fixture unexpectedly succeeded." >&2
  exit 1
else
  audit_fixture_status=$?
fi
[[ $audit_fixture_status -eq 7 ]]
audit_dir="$TEST_ROOT/audit-home/.pcprep"
audit_logs=("$audit_dir"/prepare_new_box.*Z.*.log)
[[ ${#audit_logs[@]} -eq 1 && -f ${audit_logs[0]} ]]
audit_log=${audit_logs[0]}
[[ $(stat -c '%a' "$audit_dir") == 700 ]]
[[ $(stat -c '%a' "$audit_log") == 600 ]]
[[ -L $audit_dir/prepare_new_box.latest.log ]]
[[ $(readlink "$audit_dir/prepare_new_box.latest.log") == "$(basename "$audit_log")" ]]
grep -Fqx 'event=run_started' "$audit_log"
grep -Fqx 'isolated-audit-test-marker' "$audit_log"
grep -Fqx 'event=run_finished' "$audit_log"
grep -Fqx 'result=failed' "$audit_log"
grep -Fqx 'exit_status=7' "$audit_log"

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
  export HOME="$TEST_ROOT/agent-home"
  mkdir -p "$HOME/.local/bin"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    '[[ $# -eq 5 ]]' \
    '[[ $1 == --dangerously-skip-permissions ]]' \
    '[[ $2 == --remote-control= ]]' \
    '[[ $3 == --model ]]' \
    '[[ $4 == "opus test" ]]' \
    '[[ $5 == "prompt words" ]]' \
    > "$HOME/.local/bin/claude"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    '[[ $# -eq 4 ]]' \
    '[[ $1 == --yolo ]]' \
    '[[ $2 == --model ]]' \
    '[[ $3 == "gpt test" ]]' \
    '[[ $4 == "prompt words" ]]' \
    > "$HOME/.local/bin/codex"
  chmod +x "$HOME/.local/bin/claude" "$HOME/.local/bin/codex"
  # The alias file starts by removing this name; seed it so that cleanup also
  # succeeds while this test suite has errexit enabled.
  alias pcprep_unalias=true
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.bash_aliases"
  claudeyolo --model "opus test" "prompt words"
  codexyolo --model "gpt test" "prompt words"

  chmod -x "$HOME/.local/bin/claude" "$HOME/.local/bin/codex"
  if claudeyolo 2>"$TEST_ROOT/missing-claude"; then
    echo "claudeyolo accepted a missing native executable" >&2
    exit 1
  else
    [[ $? -eq 127 ]]
  fi
  grep -Fqx "Native Claude executable not found: $HOME/.local/bin/claude" \
    "$TEST_ROOT/missing-claude"
  if codexyolo 2>"$TEST_ROOT/missing-codex"; then
    echo "codexyolo accepted a missing native executable" >&2
    exit 1
  else
    [[ $? -eq 127 ]]
  fi
  grep -Fqx "Native Codex executable not found: $HOME/.local/bin/codex" \
    "$TEST_ROOT/missing-codex"
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
