# alias airros='cd ~/vso/msresearch/Theseus/catkin_ws/src/air_ros/src/'
# alias airmain='cd ~/vso/msresearch/Theseus/main/'
# alias airrt='cd ~/vso/msresearch/Theseus/'
# alias airrosmak='pushd . && cd ~/vso/msresearch/Theseus/catkin_ws/ && catkin_make --pkg air_ros && popd'
# alias aircat='cd ~/vso/msresearch/Theseus/catkin_ws/'
# alias airsim='cd ~/GitHubSrc/AirSim'
# alias unreal='cd ~/GitHubSrc/UnrealEngine'
# alias blocks='cd ~/GitHubSrc/AirSim/Unreal/Environments/Blocks'
# alias catmak='pushd . && cd ~/vso/msresearch/Theseus/catkin_ws/ && catkin_make && popd'

# git aliases
alias grevertall='git reset --hard && git reset --hard origin/master && git clean -f -d'
function grevertfile {
  git checkout -- "$1"
}
alias gdiff='git diff'
alias gstat='git status'
alias gstatall='mgitstatus -e'
alias gpush='git push'
alias gpull='git pull'
function gcommit {
  git add -A
  git commit -m "$1"
}
alias gpullr='git pull --rebase'
function gtag {
  git tag -a "$1" -m "$2"
  git push --tags
}
alias glog='git log --pretty=oneline -n 5'
alias gcln='git clean -fdx'
function gbra {
  git checkout -b "$1"
}
function gdelbra {
  git push origin -delete "$1" && git branch -d "$1"
}
alias gconf='git diff --name-only --diff-filter=U'
alias grem='git remote -v'
alias gchk='git checkout'

# WSL root
alias bashrt='cd /mnt/c/Users/$USER/AppData/Local/lxss/rootfs'
# alias ue4='~/GitHubSrc/UnrealEngine/Engine/Binaries/Linux/UE4Editor'

function findstr {
  eval grep -ri --include=\*.{"$1"} "$2" ./
}

alias clshard='reset; stty sane; tput rs1; setterm -reset; tput rmcup; tput reset'
alias cls='tput reset'
alias pu='pushd .'
alias po='popd'

alias start-tmux='[[ -z "$TMUX" ]] && [ "$SSH_CONNECTION" != "" ] && (tmux attach-session -t ssh_tmux || tmux new-session -s ssh_tmux)'
alias tmuxx=start-tmux
alias ipconfig='nmcli dev show'

# NVIDIA driver reset (useful after driver crash)
alias nvreset='sudo rmmod nvidia_uvm;sudo rmmod nvidia;sudo modprobe nvidia;sudo modprobe nvidia_uvm;'

# move files and remove source
function smv {
  rsync -az --remove-source-files "$@"
}

## Docker aliases
alias dockerclean='docker rm $(docker ps --filter status=exited -q) ; docker rm $(docker ps --filter status=created -q)'
alias dockerls='docker container ls'
alias dockersize='docker ps --all --size'
unalias version 2>/dev/null
function version {
  echo "=== Distribution ==="
  if command -v lsb_release >/dev/null 2>&1; then
    lsb_release -a
  else
    echo "lsb_release not found"
  fi

  echo

  local py_exe=""
  if command -v python >/dev/null 2>&1; then
    py_exe=$(command -v python)
  elif command -v python3 >/dev/null 2>&1; then
    py_exe=$(command -v python3)
  fi

  if [ -n "$py_exe" ]; then
    local python_ver
    python_ver=$("$py_exe" --version 2>&1)
    echo "Python: $python_ver ($py_exe)"
  else
    echo "Python: not found"
  fi

  if [ -n "$py_exe" ]; then
    if "$py_exe" -c "import torch" >/dev/null 2>&1; then
      local torch_ver
      torch_ver=$("$py_exe" -c "import torch; print(torch.__version__)")
      echo "PyTorch: $torch_ver"
      local torch_cuda
      torch_cuda=$("$py_exe" -c "import torch; print(torch.version.cuda or 'CPU only')")
      echo "PyTorch CUDA: $torch_cuda"
    else
      echo "PyTorch: not installed for $py_exe"
    fi
  else
    echo "PyTorch: Python interpreter not available"
  fi

  if command -v nvidia-smi >/dev/null 2>&1; then
    local driver_ver
    driver_ver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)
    if [ -n "$driver_ver" ]; then
      echo "NVIDIA Driver: $driver_ver"
    else
      echo "NVIDIA Driver: detected but version unavailable"
    fi
  else
    echo "NVIDIA Driver: nvidia-smi not found"
  fi

  if command -v nvcc >/dev/null 2>&1; then
    local nvcc_path cuda_ver
    nvcc_path=$(command -v nvcc)
    cuda_ver=$(nvcc --version 2>/dev/null | awk -F'release ' '/release/ {print $2}' | awk '{print $1}' | head -n1)
    if [ -z "$cuda_ver" ]; then
      cuda_ver="unknown"
    fi
    echo "CUDA Toolkit: version $cuda_ver (nvcc: $nvcc_path)"
  else
    echo "CUDA Toolkit: nvcc not found"
  fi

  if command -v ldconfig >/dev/null 2>&1; then
    local cudnn_line
    cudnn_line=$(ldconfig -p 2>/dev/null | grep --max-count=1 libcudnn.so)
    if [ -n "$cudnn_line" ]; then
      local cudnn_path cudnn_ver=""
      cudnn_path=$(printf "%s" "$cudnn_line" | sed -E "s/.*=>[[:space:]]*//")
      if [ -n "$cudnn_path" ]; then
        cudnn_ver=$(printf "%s" "$cudnn_path" | grep -o "libcudnn\.so\.[0-9.]*" | cut -d'.' -f3-)
        if [ -z "$cudnn_ver" ] && command -v strings >/dev/null 2>&1 && [ -f "$cudnn_path" ]; then
          local cudnn_major cudnn_minor cudnn_patch
          cudnn_major=$(strings "$cudnn_path" 2>/dev/null | grep -m1 -Eo "CUDNN_MAJOR[[:space:]]*=[[:space:]]*[0-9]+" | sed -E "s/.*=//; s/[[:space:]]//g")
          cudnn_minor=$(strings "$cudnn_path" 2>/dev/null | grep -m1 -Eo "CUDNN_MINOR[[:space:]]*=[[:space:]]*[0-9]+" | sed -E "s/.*=//; s/[[:space:]]//g")
          cudnn_patch=$(strings "$cudnn_path" 2>/dev/null | grep -m1 -Eo "CUDNN_PATCHLEVEL[[:space:]]*=[[:space:]]*[0-9]+" | sed -E "s/.*=//; s/[[:space:]]//g")
          if [ -n "$cudnn_major" ]; then
            cudnn_ver=$cudnn_major
            if [ -n "$cudnn_minor" ]; then
              cudnn_ver="$cudnn_ver.$cudnn_minor"
              if [ -n "$cudnn_patch" ]; then
                cudnn_ver="$cudnn_ver.$cudnn_patch"
              fi
            fi
          fi
        fi
      fi
      if [ -n "$cudnn_ver" ]; then
        echo "cuDNN: version $cudnn_ver ($cudnn_path)"
      else
        echo "cuDNN: detected at $cudnn_path (version unknown)"
      fi
    else
      echo "cuDNN: not found via ldconfig"
    fi
  else
    echo "cuDNN: ldconfig not available"
  fi
}
alias freespace="df -h | grep -vE '^Filesystem|tmpfs|cdrom' | sort -k4hr"
alias drives='df -hT 2>/dev/null | sort -k 3 --human-numeric-sort --reverse'
alias disks=drives
# Displays a full, hierarchical snapshot of all running processes.
alias psex='ps -ef f'
alias pmy='ps -u $USER -U $USER u'
function realview {
  less +F "$1"
}
alias cpx='rsync -avh --info=progress2'
# cpz ~/dir1/ user@myserver.com:~/dir2/
alias cpz='rsync -avhz --info=progress2'
alias mvx='rsync -avh --remove-source-files --info=progress2'
# show torch version
alias torchver="python -c 'import torch; print(torch.__version__)';nvcc --version"
# remove pass phrase from ssh keys
alias removepass='find ~/.ssh -type f \( -name 'id_*' -o -name 'sb_*' \) ! -name '*.pub' -exec sh -c 'ssh-keygen -l -f "{}" >/dev/null 2>&1 && echo "Processing: {}" && ssh-keygen -p -f "{}"' \;'
function treesize {
  local target="${1:-.}"
  du -a --max-depth=1 --human-readable --time --exclude='.*' -- "$target" \
    | sort --human-numeric-sort --reverse
}


alias claudeyolo="claude --dangerously-skip-permissions"
alias z="zellij a #"

#### slurm #####
# drained nodes in slurm with reason
alias sdrained='scontrol show --json node | jq -r '"'"'.nodes[] | select(any(.state[]; . == "DRAIN")) | [.hostname, .reason] | join("\t")'"'"''
# all nodes in slurm with reason
alias sreason='scontrol show --json node | jq -r '"'"'.nodes[] | select(.reason != "") | [.hostname, (.state | join(",")), .reason] | join("\t")'"'"''
alias salljobs='squeue -o "%.18i %.8u %.6D %.16S %.8P"'
alias sjobs='squeue -o "%.7i %.9P %.8j %.8u %.2t %.10M %.6D %R" -u $USER'
function skill {
  if [ -n "$1" ]; then
    job_id=$1
  else
    job_id=$(squeue -u "$USER" -h -o %A | head -n1)
  fi

  if [ -n "$job_id" ] && scancel "$job_id"; then
    echo "Cancelled job $job_id"
  else
    echo "No job found or cancellation failed"
  fi
}
alias skillall='read -p "Are you sure you want to cancel all Slurm jobs? (y/N) " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] && scancel -u $USER && echo "All Slurm jobs for user $USER have been cancelled" || echo "Operation cancelled or no jobs found for user $USER"'
function sresr {
  squeue --reservation="$1"
}

#### kubectl #####
alias kpods='kubectl get pods -L created-by-name,submitter'
alias kquota='kubectl describe resourcequota bonete61-compute-quota'
function knodes {
    kubectl get nodes --no-headers | awk '{print $2}' | sort | uniq -c
}

alias kjobsall='kubectl get vcjob -L created-by-name,submitter'
function k {
    kubectl "$@"
}

function kpod {
    kubectl describe pod "$@"
}

function kdel {
    kubectl delete vcjob "$@"
}

function klog {
    kubectl logs -f "$@"
}

function kpods {
    kubectl get pods -L created-by-name,submitter | grep ${USERNAME}
}

function kjob {
    kubectl get vcjob --show-labels "$@"
    kubectl get pods -l volcano.sh/job-name="$@"
}

function rclone_du {
  rclone size "$@"
}
alias rclone-du=rclone_du

kjobs() {
  local current_time=$(date +%s)

  # Fetch structured data
  local JSONPATH='{range .items[*]}{.metadata.name}|{.status.state.phase}|{.metadata.labels.created-by-name}|{.metadata.labels.submitter}|{.spec.tasks[*].template.spec.priorityClassName}|{.metadata.creationTimestamp}|{.status.state.lastTransitionTime}|{range .spec.tasks[*]}R:{.replicas} Q:{range .template.spec.containers[*]}{.resources.requests.nvidia\.com/gpu},{end};{end}{"\n"}{end}'

  kubectl get vcjob -o jsonpath="$JSONPATH" "$@" | \
  TZ=UTC awk -v now="$current_time" -F "|" '

    function to_epoch(time_str) {
        if (time_str == "") return 0
        gsub(/[-:TZ]/, " ", time_str)
        return mktime(time_str)
    }

    BEGIN {
       # Rank 0 ensures Header is always top
       print "0|NAME|STATUS|USER|PRIORITY|GPUS|SUBMITTED_HR_AGO|RUNNING_SINCE_HR"
       run_sum = 0
       pend_sum = 0
    }

    $2 ~ /Pending|Running/ {

      # --- 1. User Logic ---
      user = $4; if (user == "") user = $3; if (user == "") user = "<none>"

      # --- 2. Priority Logic (Pick first value) ---
      raw_prio = $5
      gsub(" ", ",", raw_prio)
      split(raw_prio, p_arr, ",")
      priority = p_arr[1]
      if (priority == "") priority = "<none>"

      # --- 3. Time Calculations ---
      submitted_fmt = "N/A"
      if ($6 != "") submitted_fmt = sprintf("%.1fh", (now - to_epoch($6)) / 3600)

      running_fmt = "-"
      if ($2 == "Running" && $7 != "") running_fmt = sprintf("%.1fh", (now - to_epoch($7)) / 3600)

      # --- 4. GPU Calculation ---
      raw_tasks = $8
      total_gpus = 0
      split(raw_tasks, tasks, ";")

      for (i in tasks) {
         if (tasks[i] == "") continue

         # Default Replicas to 0 (Handles "ghost" workers correctly)
         reps = 0
         if (match(tasks[i], /R:([0-9]+)/, r_match)) reps = r_match[1]

         # Parse GPU Request
         pod_gpus = 0
         if (match(tasks[i], /Q:([^;]*)/, q_match)) {
             split(q_match[1], gpus, ",")
             for (j in gpus) pod_gpus += (gpus[j] + 0)
         }

         if (reps > 0) total_gpus += (reps * pod_gpus)
      }

      # --- Accumulate Totals ---
      if ($2 == "Running") run_sum += total_gpus
      else pend_sum += total_gpus

      # --- 5. Sorting Logic ---
      # Priority Rank: high=1, medium=2, low=3, <none>=4
      if (priority == "high") p_rank = 1
      else if (priority == "medium") p_rank = 2
      else if (priority == "low") p_rank = 3
      else p_rank = 4

      # Status Rank: Running=1, Pending=2
      if ($2 == "Running") s_rank = 1
      else s_rank = 2

      # Combined Rank
      sort_key = p_rank * 10 + s_rank

      print sort_key "|" $1 "|" $2 "|" user "|" priority "|" total_gpus "|" submitted_fmt "|" running_fmt
    }

    END {
       # Print Summary Rows (Rank 99 sorts to bottom)
       print "98|---|---|---|---|---|---|---"
       print "99|TOTAL_RUNNING|Running|-|-|" run_sum "|- |-"
       print "99|TOTAL_PENDING|Pending|-|-|" pend_sum "|- |-"
    }
  ' | \
  sort -t "|" -n -k1 | \
  cut -d "|" -f2- | \
  column -t -s "|" | \
  sed -e 's/.*Running.*/\x1b[32m&\x1b[0m/' -e 's/.*Pending.*/\x1b[31m&\x1b[0m/'
}