#!/usr/bin/env bash
#fail if any errors
set -Eeuo pipefail # -o xtrace # fail if any command fails

INVOCATION_DIR=$PWD
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"

export NO_NET=${NO_NET:-}
export user_name=${user_name:-}
export user_email=${user_email:-}
export INSTALL_CUDA=${INSTALL_CUDA:-0}
export CUDA_VERSION=${CUDA_VERSION:-13.2}
export INSTALL_PYTORCH=${INSTALL_PYTORCH:-1}
export PYTHON_VERSION=${PYTHON_VERSION:-3.14}
export PYTORCH_VERSION=${PYTORCH_VERSION:-2.13.0}
export TORCHVISION_VERSION=${TORCHVISION_VERSION:-0.28.0}
export WSL_DISTRO_NAME=${WSL_DISTRO_NAME:-}
export PCPREP_WIN_GCM_PATH=${PCPREP_WIN_GCM_PATH:-}

audit_timestamp() {
    date --iso-8601=seconds
}

audit_run_finished() {
    local exit_status="${1:-1}"
    local result="failed"
    local duration_seconds=0

    # An EXIT trap must never replace the bootstrap's original exit status.
    set +e
    if [ "$exit_status" -eq 0 ]; then
        result="succeeded"
    fi
    duration_seconds=$((SECONDS - PCPREP_RUN_START_SECONDS))
    printf '\nevent=run_finished\n'
    printf 'finished_at=%s\n' "$(audit_timestamp)"
    printf 'result=%s\n' "$result"
    printf 'exit_status=%s\n' "$exit_status"
    printf 'duration_seconds=%s\n' "$duration_seconds"
    printf 'audit_log=%s\n' "$PCPREP_AUDIT_LOG"
}

audit_signal() {
    local signal_name="$1"
    local exit_status="$2"

    printf '\nevent=signal_received\nsignal=%s\n' "$signal_name"
    trap - "$signal_name"
    exit "$exit_status"
}

start_run_audit() {
    local audit_dir="${PCPREP_AUDIT_DIR:-$HOME/.pcprep}"
    local log_timestamp=""
    local latest_link=""
    local repo_commit="unavailable"
    local repo_state="unavailable"
    local script_sha256="unavailable"

    command -v tee >/dev/null 2>&1 || {
        echo "tee is required to create the pcprep run audit log." >&2
        return 1
    }
    install -d -m 0700 -- "$audit_dir" || {
        echo "Unable to create the private pcprep audit directory: $audit_dir" >&2
        return 1
    }
    chmod 0700 -- "$audit_dir" || {
        echo "Unable to secure the pcprep audit directory: $audit_dir" >&2
        return 1
    }

    log_timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
    PCPREP_AUDIT_LOG=$(mktemp "$audit_dir/prepare_new_box.${log_timestamp}.XXXXXX.log") || {
        echo "Unable to create a pcprep audit log in $audit_dir." >&2
        return 1
    }
    chmod 0600 -- "$PCPREP_AUDIT_LOG"
    latest_link="$audit_dir/prepare_new_box.latest.log"
    PCPREP_RUN_START_SECONDS=$SECONDS
    PCPREP_RUN_STARTED_AT=$(audit_timestamp)
    PCPREP_RUN_ID=$(basename -- "$PCPREP_AUDIT_LOG" .log)
    export PCPREP_AUDIT_LOG PCPREP_RUN_ID PCPREP_RUN_STARTED_AT

    exec > >(tee -a -- "$PCPREP_AUDIT_LOG") 2>&1
    if [ ! -e "$latest_link" ] || [ -L "$latest_link" ]; then
        ln -sfn -- "$(basename -- "$PCPREP_AUDIT_LOG")" "$latest_link"
    else
        echo "Warning: $latest_link is not a symlink; leaving it unchanged." >&2
    fi

    trap 'audit_run_finished "$?"' EXIT
    trap 'audit_signal HUP 129' HUP
    trap 'audit_signal INT 130' INT
    trap 'audit_signal TERM 143' TERM

    if command -v git >/dev/null 2>&1 \
        && git -C "$SCRIPT_DIR/.." rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        repo_commit=$(git -C "$SCRIPT_DIR/.." rev-parse HEAD 2>/dev/null || printf 'unavailable')
        repo_state="clean"
        if [ -n "$(git -C "$SCRIPT_DIR/.." status --porcelain 2>/dev/null)" ]; then
            repo_state="dirty"
        fi
    fi
    if command -v sha256sum >/dev/null 2>&1; then
        script_sha256=$(sha256sum "$SCRIPT_DIR/prepare_new_box.sh" | awk '{print $1}')
    fi

    printf 'event=run_started\n'
    printf 'run_id=%s\n' "$PCPREP_RUN_ID"
    printf 'started_at=%s\n' "$PCPREP_RUN_STARTED_AT"
    printf 'audit_log=%s\n' "$PCPREP_AUDIT_LOG"
    printf 'latest_log=%s\n' "$latest_link"
    printf 'script=%s\n' "$SCRIPT_DIR/prepare_new_box.sh"
    printf 'script_sha256=%s\n' "$script_sha256"
    printf 'repo_commit=%s\n' "$repo_commit"
    printf 'repo_state=%s\n' "$repo_state"
    printf 'invocation_directory=%s\n' "$INVOCATION_DIR"
    printf 'user=%s\n' "$(id -un)"
    printf 'uid=%s\n' "$(id -u)"
    printf 'hostname=%s\n' "$(hostname)"
    printf 'kernel=%s\n' "$(uname -srmo)"
    printf 'wsl=%s\n' "$IS_WSL"
    printf 'config.NO_NET=%s\n' "${NO_NET:-auto}"
    printf 'config.INSTALL_CUDA=%s\n' "$INSTALL_CUDA"
    printf 'config.CUDA_VERSION=%s\n' "$CUDA_VERSION"
    printf 'config.INSTALL_PYTORCH=%s\n' "$INSTALL_PYTORCH"
    printf 'config.PYTHON_VERSION=%s\n' "$PYTHON_VERSION"
    printf 'config.PYTORCH_VERSION=%s\n' "$PYTORCH_VERSION"
    printf 'config.TORCHVISION_VERSION=%s\n\n' "$TORCHVISION_VERSION"
}

is_wsl_environment() {
    [ -n "${WSL_DISTRO_NAME:-}" ] \
        || [ -n "${WSL_INTEROP:-}" ] \
        || grep -qi microsoft /proc/version 2>/dev/null
}

windows_interop_available() {
    command -v cmd.exe >/dev/null 2>&1 \
        && cmd.exe /d /c ver </dev/null >/dev/null 2>&1
}

windows_home_path() {
    local windows_home="" converted_home=""

    if windows_interop_available && command -v wslpath >/dev/null 2>&1; then
        windows_home=$(cmd.exe /d /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r\n') || windows_home=""
        if [[ $windows_home =~ ^[A-Za-z]:[\\/] ]] \
            && converted_home=$(wslpath -u "$windows_home" 2>/dev/null) \
            && [ -d "$converted_home" ]; then
            printf '%s\n' "$converted_home"
            return 0
        fi
    fi

    # Interop can be disabled for an otherwise healthy WSL distro. Preserve
    # the common same-name fallback, but never guess a different Windows user.
    if [ -n "${USER:-}" ] && [ -d "/mnt/c/Users/$USER" ]; then
        printf '/mnt/c/Users/%s\n' "$USER"
        return 0
    fi

    return 1
}

copy_windows_ssh_keys() {
    local windows_home=""

    mkdir -p "$HOME/.ssh"
    if windows_home=$(windows_home_path) && [ -d "$windows_home/.ssh" ]; then
        echo "Copying missing SSH files from $windows_home/.ssh."
        # Do not overwrite Linux-side keys or configuration on repeated runs.
        if cp --help 2>&1 | grep -F -- '--update=UPDATE' >/dev/null; then
            cp -a --update=none "$windows_home/.ssh/." "$HOME/.ssh/"
        else
            cp -an "$windows_home/.ssh/." "$HOME/.ssh/"
        fi
    else
        echo "Windows SSH directory was not found; keeping the WSL SSH directory unchanged."
    fi
}

configure_wsl_git() {
    local win_gcm_path="" helper_path="" windows_home=""
    local -a gcm_candidates=()

    # Make sure we don't check in with CRLFs.
    git config --global core.autocrlf input

    if ! windows_interop_available; then
        echo "Windows interop is unavailable; skipping Windows Git Credential Manager integration."
        return 0
    fi

    [ -n "$PCPREP_WIN_GCM_PATH" ] && gcm_candidates+=("$PCPREP_WIN_GCM_PATH")
    if [[ "$(uname -m)" == "aarch64" || "$(uname -m)" == "arm64" ]]; then
        gcm_candidates+=("/mnt/c/Program Files/Git/clangarm64/bin/git-credential-manager.exe")
    else
        gcm_candidates+=("/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe")
    fi
    if windows_home=$(windows_home_path); then
        gcm_candidates+=("$windows_home/AppData/Local/Programs/Git Credential Manager/git-credential-manager.exe")
    fi

    for candidate in "${gcm_candidates[@]}"; do
        if [ -f "$candidate" ] && "$candidate" --version </dev/null >/dev/null 2>&1; then
            win_gcm_path=$candidate
            break
        fi
    done

    if [ -n "$win_gcm_path" ]; then
        # Git executes credential helpers through a shell, so spaces must be
        # escaped in the stored configuration value. This is the form in the
        # upstream Git Credential Manager WSL documentation.
        printf -v helper_path '%q' "$win_gcm_path"
        git config --global credential.helper "$helper_path"
        echo "Configured Windows Git Credential Manager for WSL."
    else
        echo "A runnable Windows Git Credential Manager was not found; skipping credential helper setup."
    fi

    git config --global credential.useHttpPath true
}

configure_wsl_tailscale() {
    local win_tailscale="/mnt/c/Program Files/Tailscale/tailscale.exe"
    local tailscale_alias='alias tailscale="/mnt/c/Program\ Files/Tailscale/tailscale.exe"'

    if command -v tailscale >/dev/null 2>&1; then
        echo "A native WSL Tailscale CLI is already installed; leaving it unchanged."
        return 0
    fi
    if ! windows_interop_available || [ ! -f "$win_tailscale" ]; then
        return 0
    fi
    if ! "$win_tailscale" version </dev/null >/dev/null 2>&1; then
        echo "Windows Tailscale was found but cannot run through WSL interop; skipping its alias."
        return 0
    fi

    for shell_rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
        touch "$shell_rc"
        grep -qF "$tailscale_alias" "$shell_rc" || printf '%s\n' "$tailscale_alias" >> "$shell_rc"
    done
    echo "Configured the Windows Tailscale CLI alias for new WSL shells."
}

# Robust internet check that works even when ICMP is blocked.
net_ok() {
  # 1) HTTPS probe (most reliable)
  if command -v curl >/dev/null 2>&1; then
    # should return 204 on success
    curl -fsSI --max-time 5 https://clients3.google.com/generate_204 >/dev/null && return 0
    # general HTTPS reachability
    curl -fsSI --max-time 5 https://www.google.com >/dev/null && return 0
    # SNI over a known Google IP (avoids cert mismatch)
    curl -fsSI --max-time 5 --resolve www.google.com:443:142.250.72.14 https://www.google.com >/dev/null 2>&1 && return 0
  fi

  # 2) Raw TCP reachability (no TLS needed)
  if command -v nc >/dev/null 2>&1; then
    nc -zw3 142.250.72.14 443 >/dev/null 2>&1 && return 0  # Google IP:443
    nc -zw3 1.1.1.1 443        >/dev/null 2>&1 && return 0  # Cloudflare:443
    nc -zw3 8.8.8.8 53         >/dev/null 2>&1 && return 0  # DNS UDP/TCP often open
  fi

  # 3) Last resort: public Git over HTTPS
  if command -v git >/dev/null 2>&1; then
    git ls-remote https://github.com >/dev/null 2>&1 && return 0
  fi

  return 1
}

has_cuda_gpu() {
  # Prefer a direct NVIDIA runtime probe if available.
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi -L >/dev/null 2>&1 && return 0
  fi

  # Fall back to PCI device scan.
  if command -v lspci >/dev/null 2>&1; then
    lspci | grep -qi 'nvidia' && return 0
  fi

  # Driver-installed systems expose this path.
  if [ -d /proc/driver/nvidia/gpus ] && [ -n "$(ls -A /proc/driver/nvidia/gpus 2>/dev/null)" ]; then
    return 0
  fi

  return 1
}

has_aligned_cuda_toolkit() {
    local nvcc="/usr/local/cuda-${CUDA_VERSION}/bin/nvcc"

    [ -x "$nvcc" ] || return 1
    "$nvcc" --version 2>/dev/null | grep -Fq "release ${CUDA_VERSION},"
}

activate_nvm_lts() {
    export NVM_DIR="$HOME/.nvm"
    set +u
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    if ! command -v nvm >/dev/null 2>&1; then
        set -u
        echo "NVM is unavailable; cannot activate the current Node.js LTS release." >&2
        return 1
    fi
    nvm use --lts >/dev/null || {
        set -u
        return 1
    }
    set -u
}

bool_is_true() {
    case "${1:-0}" in
        1|y|Y|yes|YES|true|TRUE|on|ON)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

apt_has_candidate() {
    apt-cache policy "$1" 2>/dev/null \
        | awk '/Candidate:/ {print $2}' \
        | grep -vq '(none)'
}

install_wslu_if_available() {
    if [ "$NO_NET" != "0" ]; then
        echo "NO_NET=$NO_NET. Skipping optional WSL Utilities installation."
        return 0
    fi

    # wslu was removed from Ubuntu 26.04 and its upstream PPA does not publish
    # a Resolute suite. Use Ubuntu's package when a supported release has it;
    # Windows interop (cmd.exe/explorer.exe) remains available without wslu.
    if apt_has_candidate wslu; then
        sudo apt-get install -y wslu
    else
        echo "wslu is not available in this Ubuntu release; skipping it."
    fi
}

bootstrap_value_is_valid() {
    local value="${1:-}"

    [[ $value != *$'\n'* && $value != *$'\r'* && $value =~ [^[:space:]] ]]
}

prompt_required_bootstrap_value() {
    local variable_name="$1"
    local label="$2"
    local default_value="${3:-}"
    local value="${!variable_name:-}"

    # Explicit environment values make the entire startup questionnaire
    # automatable. Reject malformed values before any installation starts.
    if [ -n "$value" ]; then
        bootstrap_value_is_valid "$value" || {
            echo "$variable_name must be a nonblank, single-line value." >&2
            return 1
        }
        export "$variable_name"
        return 0
    fi
    if ! bootstrap_value_is_valid "$default_value"; then
        default_value=""
    fi

    while true; do
        if [ -n "$default_value" ]; then
            if ! IFS= read -r -p "$label [$default_value]: " value; then
                echo "Unable to read $label. Set $variable_name before running the bootstrap noninteractively." >&2
                return 1
            fi
            value=${value:-$default_value}
        else
            if ! IFS= read -r -p "$label: " value; then
                echo "Unable to read $label. Set $variable_name before running the bootstrap noninteractively." >&2
                return 1
            fi
        fi

        if bootstrap_value_is_valid "$value"; then
            printf -v "$variable_name" '%s' "$value"
            export "$variable_name"
            return 0
        fi
        echo "$label must be a nonblank, single-line value." >&2
    done
}

collect_git_identity() {
    local existing_name=""
    local existing_email=""

    if command -v git >/dev/null 2>&1; then
        existing_name=$(git config --global --get user.name 2>/dev/null || true)
        existing_email=$(git config --global --get user.email 2>/dev/null || true)
    fi

    prompt_required_bootstrap_value user_name "Git user name" "$existing_name"
    prompt_required_bootstrap_value user_email "Git email" "$existing_email"
}

collect_bootstrap_inputs() {
    local response=""

    echo "Collecting startup configuration before installation begins..."
    if [ "$IS_WSL" = "1" ]; then
        IFS= read -r -p "Make sure to follow manual steps in wsl_prep.md. Proceed? (y/N): " response \
            && [[ $response =~ ^[Yy]$ ]] || { echo "Exiting."; return 1; }
    fi

    collect_git_identity

    # Check if NO_NET is not set and test internet connectivity now, so an
    # offline confirmation can never interrupt a later installation phase.
    if [ -z "$NO_NET" ]; then
        echo "Checking Internet connection..."
        export NO_NET=0

        if ! net_ok; then
            echo "Internet connectivity test failed."
            response=""
            IFS= read -r -p "No internet detected. Continue offline? (y/N): " response || response=""
            if ! [[ $response =~ ^[Yy]$ ]]; then
                echo "Aborting."
                return 1
            fi
            export NO_NET=1
        fi
    fi

    echo "Startup configuration collected."
}

configure_wsl_sudo_timeout() {
    local timeout_minutes="153722867280912930"
    local sudoers_file="/etc/sudoers.d/99-pcprep-wsl-timestamp-timeout"
    local sudoers_candidate=""

    # sudo-rs, the Ubuntu 26.04 default, rejects the traditional -1 value for
    # "never expire". This is floor(INT64_MAX / 60), the largest whole-minute
    # timeout its signed-seconds timestamp arithmetic can safely represent
    # (about 292 billion years). Timestamp records are still invalid after a
    # reboot, and sudo's normal per-terminal scoping remains in effect.
    sudoers_candidate=$(mktemp) || {
        echo "Unable to create a temporary sudoers policy." >&2
        return 1
    }
    if ! printf '%s\n' \
        '# Managed by pcprep/ubuntu/prepare_new_box.sh.' \
        '# System-wide maximum sudo timestamp timeout for this WSL distro.' \
        "Defaults timestamp_timeout=$timeout_minutes" \
        > "$sudoers_candidate"; then
        rm -f -- "$sudoers_candidate"
        echo "Unable to prepare the sudo timestamp policy." >&2
        return 1
    fi

    # Validate the candidate before placing it under /etc. Install through a
    # temporary name and rename atomically so interruption cannot leave a
    # partially written sudoers file.
    if ! sudo visudo -cf "$sudoers_candidate" >/dev/null; then
        rm -f -- "$sudoers_candidate"
        echo "Refusing to install an invalid sudo timestamp policy." >&2
        return 1
    fi
    if ! sudo install -o root -g root -m 0440 \
        "$sudoers_candidate" "$sudoers_file.pcprep-new"; then
        rm -f -- "$sudoers_candidate"
        echo "Unable to stage $sudoers_file." >&2
        return 1
    fi
    rm -f -- "$sudoers_candidate"
    if ! sudo mv -f -- "$sudoers_file.pcprep-new" "$sudoers_file"; then
        sudo rm -f -- "$sudoers_file.pcprep-new" || true
        echo "Unable to install $sudoers_file." >&2
        return 1
    fi
    sudo visudo -cf /etc/sudoers >/dev/null || {
        echo "The aggregate sudoers policy failed validation after installing $sudoers_file." >&2
        return 1
    }

    echo "Configured the system-wide WSL sudo timestamp timeout to $timeout_minutes minutes."
}

IS_WSL=0
if is_wsl_environment; then
    IS_WSL=1
fi

# This orchestrator installs system packages with sudo but configures the
# invoking user's home, Git settings, shells, and Conda. Running the whole
# script as root would silently configure /root instead.
if [ "$(id -u)" -eq 0 ]; then
    echo "Run prepare_new_box.sh as your regular Linux user, without sudo; it will request sudo when needed." >&2
    exit 1
fi

start_run_audit
collect_bootstrap_inputs

# Acquire elevation once, visibly, before any child installer starts. Child
# scripts also validate sudo independently so standalone use fails closed.
command -v sudo >/dev/null 2>&1 || { echo "sudo is required for system setup." >&2; exit 1; }
echo "Validating sudo access for system package and configuration steps..."
sudo -v || { echo "Unable to acquire sudo; no setup steps were started." >&2; exit 1; }
export PCPREP_SUDO_READY=1
echo "Startup authorization complete; beginning unattended setup."

if [ "$IS_WSL" = "1" ]; then
    configure_wsl_sudo_timeout
    copy_windows_ssh_keys
fi

bash cp_dotfiles.sh
if [ "$IS_WSL" = "1" ]; then
    bash ssh_perms.sh
fi
bash min_system.sh

if [ "$IS_WSL" = "1" ]; then
    configure_wsl_git
    configure_wsl_tailscale
    install_wslu_if_available
else
    if ! bool_is_true "$INSTALL_CUDA"; then
        echo "CUDA installation is disabled. Set INSTALL_CUDA=1 to enable it."
    elif [ "$NO_NET" != "0" ]; then
        echo "NO_NET=$NO_NET. Skipping CUDA installation."
    elif ! has_cuda_gpu; then
        echo "No CUDA-capable GPU detected. Skipping CUDA installation."
    elif has_aligned_cuda_toolkit; then
        echo "CUDA Toolkit $CUDA_VERSION is already installed."
    # PyTorch 2.13's newest stable Linux wheel uses CUDA 13.2. NVIDIA does not
    # publish every older toolkit in every newer Ubuntu repository (notably,
    # CUDA 13.2 is absent from Ubuntu 26.04). Skip instead of installing an
    # unreviewed cross-release package or a toolkit that does not match PyTorch.
    elif ! CUDA_VERSION="$CUDA_VERSION" bash install_cuda.sh --check; then
        echo "CUDA Toolkit $CUDA_VERSION is unavailable for this Ubuntu release/architecture; skipping it."
        echo "The PyTorch cu132 wheel includes its own CUDA runtime and only needs a compatible NVIDIA driver."
    else
        echo "CUDA not found. Installing CUDA Toolkit $CUDA_VERSION."
        sudo --preserve-env=CUDA_VERSION bash install_cuda.sh
    fi
fi

bash gitconfig.sh
#bash install_fzf.sh
bash extra_install.sh

bash install_miniconda.sh

if [ "$NO_NET" = "0" ]; then
    # Initialize future Bash shells, then activate this process without making
    # the user reopen the terminal during the remaining setup steps.
    "$HOME/miniconda3/bin/conda" init bash
    . "$HOME/miniconda3/etc/profile.d/conda.sh"
    conda activate base

    # install Poetry
    #curl -sSL https://install.python-poetry.org | python3 -

    # pip installs
    "$HOME/miniconda3/bin/python" -m pip install -q --upgrade nvitop rich pytest

    PYTHON="$HOME/miniconda3/bin/python" bash install_dl_frameworks.sh

    # install Claude Code
    curl -fsSL https://claude.ai/install.sh | bash

    # min_system.sh runs as a child process, so load its NVM installation in
    # this shell before installing Node-based tools. This avoids Ubuntu's older
    # system npm and keeps the global package in the user's NVM tree.
    activate_nvm_lts
    npm install -g @openai/codex@latest
fi

required_commands=(git curl npm node)
if [ "$NO_NET" = "0" ]; then
    required_commands+=("$HOME/miniconda3/bin/conda" "$HOME/miniconda3/bin/python")
fi
missing_commands=()
for required in "${required_commands[@]}"; do
    if [[ $required == */* ]]; then
        [[ -x $required ]] || missing_commands+=("$required")
    elif ! command -v "$required" >/dev/null 2>&1; then
        missing_commands+=("$required")
    fi
done
if (( ${#missing_commands[@]} )); then
    printf 'Bootstrap verification failed; required tools are missing:\n' >&2
    printf '  - %s\n' "${missing_commands[@]}" >&2
    exit 1
fi

echo "Your new box is ready! Please restart your terminal."
