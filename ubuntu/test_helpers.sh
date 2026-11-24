#!/usr/bin/env bash
# Offline behavior tests for the Ubuntu bootstrap helpers. Each block runs the
# real script or function against a temporary home with fake installers, and
# checks what it would install, delete or write. Nothing here installs packages
# or needs the network or root. Run: bash ubuntu/test_helpers.sh
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT

# Deletion helpers refuse unsafe targets and remove only the exact directory.
mkdir -p "$TEST_ROOT/home/.vscode-server" "$TEST_ROOT/home/.vscode-serve"
! HOME=/ PCPREP_SKIP_PROCESS_KILL=1 USER="${USER:-pcprep}" \
  bash "$SCRIPT_DIR/kill_vscode_srv.sh" --yes >/dev/null 2>&1
HOME="$TEST_ROOT/home" PCPREP_SKIP_PROCESS_KILL=1 USER="${USER:-pcprep}" \
  bash "$SCRIPT_DIR/kill_vscode_srv.sh" --yes >/dev/null
[[ ! -e $TEST_ROOT/home/.vscode-server ]]
[[ -d $TEST_ROOT/home/.vscode-serve ]]

# Exercise the actual pip and system package selection without installing anything.
(
  unset INSTALL_CUDA INSTALL_AZURE_CLI
  source "$SCRIPT_DIR/bootstrap_options.sh"
  [[ $INSTALL_CUDA == 0 && $INSTALL_AZURE_CLI == 0 ]]
  export PACKAGE_LOG="$TEST_ROOT/packages"
  cat > "$TEST_ROOT/record-python" <<'SH'
#!/usr/bin/env bash
if [[ $1 == -m && $2 == pip && $3 == install ]]; then
  printf '%s\n' "$@" >> "$PACKAGE_LOG"
fi
SH
  chmod +x "$TEST_ROOT/record-python"
  source <(sed -n '/^install_power_and_hardware_packages()/,/^}/p; /^install_azure_cli()/,/^}/p' "$SCRIPT_DIR/min_system.sh")
  source <(sed -n '/^install_filesystems()/,/^}/p' "$SCRIPT_DIR/extra_install.sh")
  install_pkg() { printf '%s\n' "$@" >> "$PACKAGE_LOG"; }
  install_packages() { install_pkg "$@"; }
  log() { :; }
  skip() { :; }
  warn() { echo "$*" >&2; }
  azure_cli_configured_suite() { :; }
  azure_cli_repo_has_package() { install_pkg azure-repo-probe; }
  run_azure_cli_installer() { install_pkg azure-cli; }
  IS_WSL=0 ARCH=x86_64
  for flag in 0 1; do
    export INSTALL_CUDA=$flag
    for torch in 0 1; do
      : > "$PACKAGE_LOG"
      INSTALL_PYTORCH=$torch NO_NET=0 PYTORCH_ACCELERATOR=cpu PYTHON="$TEST_ROOT/record-python" \
        bash "$SCRIPT_DIR/install_dl_frameworks.sh"
      install_power_and_hardware_packages
      install_filesystems
      grep -Fxq pandas "$PACKAGE_LOG"
      for package in jupyter tensorboard transformers tlp tlp-rdw nvtop nvidia-prime nfs-common cifs-utils; do
        if [[ $flag == 1 ]]; then
          grep -Fxq "$package" "$PACKAGE_LOG"
        elif grep -Fxq "$package" "$PACKAGE_LOG"; then
          echo "Disabled package requested: $package" >&2
          exit 1
        fi
      done
      if [[ $flag == 1 && $torch == 1 ]]; then
        grep -Fxq accelerate "$PACKAGE_LOG"
      elif grep -Fxq accelerate "$PACKAGE_LOG"; then
        exit 1
      fi
      if [[ $torch == 1 ]]; then
        grep -Fxq https://download.pytorch.org/whl/cpu "$PACKAGE_LOG"
      elif grep -Fq 'torch==' "$PACKAGE_LOG"; then
        exit 1
      fi
    done
    # Azure is independent of the CUDA switch, including its repository probe.
    INSTALL_AZURE_CLI=$((1 - flag))
    : > "$PACKAGE_LOG"
    (bash() { install_pkg "$@"; }; install_azure_cli)
    if [[ $INSTALL_AZURE_CLI == 0 ]]; then
      [[ ! -s $PACKAGE_LOG ]]
    else
      for operation in azure-repo-probe azure-cli install_azcopy.sh; do
        grep -Fxq "$operation" "$PACKAGE_LOG"
      done
    fi
  done
)

# Workstation-only packages follow INSTALL_WORKSTATION_PACKAGES; server tools stay.
(
  unset INSTALL_WORKSTATION_PACKAGES
  source "$SCRIPT_DIR/bootstrap_options.sh"
  [[ $INSTALL_WORKSTATION_PACKAGES == 1 ]]
  export PACKAGE_LOG="$TEST_ROOT/workstation-packages"
  source <(sed -n '/^install_workstation_packages()/,/^}/p; /^install_power_and_hardware_packages()/,/^}/p' "$SCRIPT_DIR/min_system.sh")
  source <(sed -n '/^install_system_hw()/,/^}/p; /^install_networking()/,/^}/p; /^install_filesystems()/,/^}/p; /^install_editors_shell()/,/^}/p; /^install_media_docs()/,/^}/p' "$SCRIPT_DIR/extra_install.sh")
  install_pkg() { printf '%s\n' "$@" >> "$PACKAGE_LOG"; }
  install_packages() { install_pkg "$@"; }
  install_first_available() { install_pkg "$1"; }
  apt_has_pkg() { return 0; }
  log() { :; }
  skip() { :; }
  IS_WSL=0 ARCH=x86_64 ARCH_DEB=amd64 INSTALL_CUDA=0
  workstation=(xclip libopencv-dev mercurial libx11-dev powertop nvme-cli lm-sensors smartmontools
               nmap ntfs-3g sshfs mergerfs fonts-firacode ffmpeg ghostscript pdftk-java)
  server=(btop linux-tools-generic tcpdump lsof psmisc starship)
  for flag in 0 1; do
    : > "$PACKAGE_LOG"
    INSTALL_WORKSTATION_PACKAGES=$flag
    install_workstation_packages
    install_power_and_hardware_packages
    install_system_hw
    install_networking
    install_filesystems
    install_editors_shell
    install_media_docs
    for package in "${server[@]}"; do grep -Fxq "$package" "$PACKAGE_LOG"; done
    for package in "${workstation[@]}"; do
      if [[ $flag == 1 ]]; then
        grep -Fxq "$package" "$PACKAGE_LOG"
      elif grep -Fxq "$package" "$PACKAGE_LOG"; then
        echo "Workstation package requested on a server: $package" >&2
        exit 1
      fi
    done
  done
)

# Exercise an existing npm install and an existing .bash_aliases using only a
# temporary home and a fake downloaded installer.
(
  export HOME="$TEST_ROOT/codex-migration" XDG_CONFIG_HOME="$TEST_ROOT/codex-config"
  export NVM_BIN="$HOME/.nvm/versions/node/v24.0.0/bin"
  prefix=${NVM_BIN%/bin}
  mkdir -p "$NVM_BIN" "$prefix/lib/node_modules/@openai/codex/bin"
  touch "$prefix/lib/node_modules/@openai/codex/bin/codex.js"
  ln -s ../lib/node_modules/@openai/codex/bin/codex.js "$NVM_BIN/codex"
  printf '%s\n' '#!/bin/sh' 'echo "$@" >> "$HOME/npm-calls"' > "$NVM_BIN/npm"
  chmod +x "$NVM_BIN/npm"
  printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' > "$HOME/.bashrc"
  printf '%s\n' 'codexupdate() {' '  npm install -g @openai/codex@latest' '}' 'alias mine=true' > "$HOME/.bash_aliases"
  cd "$SCRIPT_DIR"
  INSTALL_CUDA=0 bash cp_dotfiles.sh > "$TEST_ROOT/dotfiles.log" 2>&1
  [[ ! -e $HOME/.local/bin/mount_cifs.sh && -x $HOME/.local/bin/install_codex.sh ]]
  grep -Fxq '  "$HOME/.local/bin/install_codex.sh"' "$HOME/.bash_aliases"
  grep -Fxq 'alias mine=true' "$HOME/.bash_aliases"

  curl() {
    [[ ${!#} == https://chatgpt.com/codex/install.sh ]] || return 1
    while [[ $# -gt 1 && $1 != -o ]]; do shift; done
    [[ $1 == -o ]] || return 1
    cat > "$2" <<'INSTALLER'
set -eu
test "$CODEX_NON_INTERACTIVE" = true
test "$CODEX_INSTALL_DIR" = "$HOME/.local/bin"
printf '%s\n' '#!/bin/sh' 'test "$1" = --version' > "$CODEX_INSTALL_DIR/codex"
chmod +x "$CODEX_INSTALL_DIR/codex"
INSTALLER
  }
  export -f curl
  source "$HOME/.bash_aliases"
  codexupdate
  grep -Fxq "uninstall --global --prefix $prefix --ignore-scripts @openai/codex" "$HOME/npm-calls"
  "$HOME/.local/bin/codex" --version

  curl() { return 22; }
  export -f curl
  if codexupdate; then
    echo "Codex update accepted a failed download." >&2
    exit 1
  fi
  [[ $(wc -l < "$HOME/npm-calls") -eq 1 ]]
  printf '%s\n' 'codexupdate() {' '  npm install -g @openai/codex@latest' '  echo customized' '}' > "$HOME/.bash_aliases"
  cp "$HOME/.bash_aliases" "$TEST_ROOT/custom.aliases"
  INSTALL_CUDA=1 bash cp_dotfiles.sh >> "$TEST_ROOT/dotfiles.log" 2>&1
  cmp "$TEST_ROOT/custom.aliases" "$HOME/.bash_aliases"
  [[ -x $HOME/.local/bin/mount_cifs.sh ]]
)

# Resolve release-specific native CUDA defaults without touching the network.
cuda_fixture_bin="$TEST_ROOT/cuda-fixture-bin"
cuda_fixture_packages="$TEST_ROOT/cuda-Packages.gz"
mkdir -p "$cuda_fixture_bin"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'url=${!#}' \
  'case $url in' \
  '  */Packages.gz) cat "$PCPREP_TEST_CUDA_PACKAGES" ;;' \
  '  *) exit 0 ;;' \
  'esac' \
  > "$cuda_fixture_bin/curl"
chmod +x "$cuda_fixture_bin/curl"
printf 'Package: cuda-toolkit-13-2\n\nPackage: cuda-toolkit-13-3\n' \
  | gzip -c > "$cuda_fixture_packages"
printf 'ID=ubuntu\nVERSION_ID=24.04\n' > "$TEST_ROOT/os-release-24.04"
printf 'ID=ubuntu\nVERSION_ID=26.04\n' > "$TEST_ROOT/os-release-26.04"
cuda_24_output=$(PATH="$cuda_fixture_bin:$PATH" \
  PCPREP_TEST_CUDA_PACKAGES="$cuda_fixture_packages" \
  PCPREP_OS_RELEASE_FILE="$TEST_ROOT/os-release-24.04" PCPREP_ARCH=x86_64 \
  bash "$SCRIPT_DIR/install_cuda.sh" --check)
grep -Fq 'cuda-toolkit-13-2' <<< "$cuda_24_output"
cuda_26_output=$(PATH="$cuda_fixture_bin:$PATH" \
  PCPREP_TEST_CUDA_PACKAGES="$cuda_fixture_packages" \
  PCPREP_OS_RELEASE_FILE="$TEST_ROOT/os-release-26.04" PCPREP_ARCH=x86_64 \
  bash "$SCRIPT_DIR/install_cuda.sh" --check)
grep -Fq 'cuda-toolkit-13-3' <<< "$cuda_26_output"

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
  collect_git_identity <<< $'\n\n'
  [[ $user_name == 'Existing User' ]]
  [[ $user_email == 'existing@example.invalid' ]]
)
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
  INSTALL_AZURE_CLI=0
  INSTALL_WORKSTATION_PACKAGES=1
  CUDA_VERSION=13.2
  INSTALL_PYTORCH=1
  PYTHON_VERSION=3.14
  PYTORCH_VERSION=2.13.0
  TORCHVISION_VERSION=0.28.0
  ALLOW_UNSUPPORTED_AZURE_CLI=0
  AZURE_CLI_FALLBACK_SUITE=noble
  INSTALL_TOOLCHAIN_TEST_PPA=0
  REMOVE_LEGACY_TOOLCHAIN_TEST_PPA=0

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
grep -Fqx 'config.INSTALL_AZURE_CLI=0' "$audit_log"
grep -Fqx 'config.INSTALL_WORKSTATION_PACKAGES=1' "$audit_log"
grep -Fqx 'isolated-audit-test-marker' "$audit_log"
grep -Fqx 'event=run_finished' "$audit_log"
grep -Fqx 'result=failed' "$audit_log"
grep -Fqx 'exit_status=7' "$audit_log"

# Mount helpers refuse to mount over or unmount the filesystem root.
! AZMOUNT_POINT=/ bash "$SCRIPT_DIR/azmount.sh" >/dev/null 2>&1
! AZMOUNT_POINT=/ bash "$SCRIPT_DIR/azunmount.sh" >/dev/null 2>&1
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
