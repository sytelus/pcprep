# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples


# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

PROMPT_DIRTRIM=1
# First, set the environment variable if we detect Docker
if grep -qE '(docker|kubepods)' /proc/1/cgroup 2>/dev/null; then
    export IS_CONTAINER=true
else
    export IS_CONTAINER=false
fi

# Then use it to set the prompt
if [ "$color_prompt" = yes ]; then
    if [ "$IS_CONTAINER" = true ]; then
        # Show chroot without color and make prompt end green in Docker
        PS1='${debian_chroot:+($debian_chroot)}\[\033[01;34m\]\w\[\033[32m\]\$ \[\033[00m\]'
    else
        PS1='${debian_chroot:+($debian_chroot)}\[\033[01;34m\]\w\[\033[00m\]\$ '
    fi
else
    PS1='${debian_chroot:+($debian_chroot)}\w$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Turn on ../**/*.ext pattern matching
shopt -q -s extglob

# Allow aliases such as ll in sudo
alias sudo='sudo '

# auto complete cycle through by keep pressing tab
bind '"\t":menu-complete'
bind '"\e[Z":menu-complete-backward'

is_wsl() {
    case "$(uname -r)" in
    *microsoft* ) true ;; # WSL 2
    *Microsoft* ) true ;; # WSL 1
    * ) false;;
    esac
}

skip_host_ssh_agent=false
if [ -n "${IS_CONTAINER:-}" ]; then
    skip_host_ssh_agent=true
fi

SSH_DIR="$HOME/.ssh"
if [ "${skip_host_ssh_agent}" = false ]; then
    if ! mkdir -p "${SSH_DIR}" 2>/dev/null; then
        skip_host_ssh_agent=true
    fi
fi

if [ "${skip_host_ssh_agent}" = false ]; then
  # if not OSX
  if [[ ! "$(uname -s)" == "Darwin" ]] && ! is_wsl; then
    # Set GPG TTY, this is the terminal where user will be prompted for passphrase
    export GPG_TTY=$(tty)

    # Start the gpg-agent if not already running
    if ! pgrep -x -u "${USER}" gpg-agent >/dev/null 2>&1; then
      gpg-agent --daemon --enable-ssh-support "${HOME}/.gpg-agent-info"
    fi

    if [ -f "${HOME}/.gpg-agent-info" ]; then
      . "${HOME}/.gpg-agent-info"
      export GPG_AGENT_INFO
      export SSH_AUTH_SOCK
    fi
  fi

  # run ssh-add once per reboot
  # Check if ssh-agent is already running
  ssh_agent_setup() {
      SSH_ENV="$HOME/.ssh/agent.env"
      CUSTOM_SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"

      # First check if any SSH agent is running - use ps instead of pgrep
      EXISTING_AGENT_PID=$(ps -ef | grep "ssh-agent" | grep -v grep | awk '{print $2}')

      if [ -n "$EXISTING_AGENT_PID" ]; then
          # Check if process is actually running
          if kill -0 "$EXISTING_AGENT_PID" 2>/dev/null; then
              # Try to find existing socket using netstat or just check common locations
              if command -v netstat >/dev/null 2>&1; then
                  EXISTING_SOCKET=$(netstat -xl 2>/dev/null | grep "agent" | grep -o '/tmp/ssh-[^[:space:]]*' || true)
              else
                  # Check common socket locations
                  for sock in /tmp/ssh-*/agent.*; do
                      if [ -S "$sock" ]; then
                          EXISTING_SOCKET="$sock"
                          break
                      fi
                  done
              fi

              if [ -n "$EXISTING_SOCKET" ]; then
                  echo "Reusing existing SSH agent (PID: $EXISTING_AGENT_PID)"
                  export SSH_AGENT_PID="$EXISTING_AGENT_PID"
                  export SSH_AUTH_SOCK="$EXISTING_SOCKET"

                  # Create symbolic link to our custom socket location if needed
                  if [ "$EXISTING_SOCKET" != "$CUSTOM_SSH_AUTH_SOCK" ]; then
                      rm -f "$CUSTOM_SSH_AUTH_SOCK"
                      ln -sf "$EXISTING_SOCKET" "$CUSTOM_SSH_AUTH_SOCK"
                  fi

                  # Update the agent environment file
                  ssh-agent -s | sed 's/^echo/#echo/' > "${SSH_ENV}"
                  chmod 600 "${SSH_ENV}"
                  return
              fi
          fi
      fi

      start_agent() {
          echo "Initializing new SSH agent..."
          # Remove existing socket if it exists
          [ -S "$CUSTOM_SSH_AUTH_SOCK" ] && rm -f "$CUSTOM_SSH_AUTH_SOCK"

          ssh-agent -a "$CUSTOM_SSH_AUTH_SOCK" | sed 's/^echo/#echo/' > "${SSH_ENV}"
          chmod 600 "${SSH_ENV}"
          . "${SSH_ENV}" > /dev/null
      }

      # Only start new agent if we couldn't find an existing one
      if [ ! -S "$CUSTOM_SSH_AUTH_SOCK" ]; then
          start_agent
      elif [ -f "${SSH_ENV}" ]; then
          . "${SSH_ENV}" > /dev/null
          # Verify the agent is still running
          if ! kill -0 $SSH_AGENT_PID 2>/dev/null; then
              start_agent
          fi
      else
          start_agent
      fi

      # Add keys if not already added
      for key in ~/.ssh/*; do
          # Skip non-files, public keys, and specific files we don't want to add
          if [[ -f "$key" && "$key" != *.pub && "$key" != *config && "$key" != *known_hosts && "$key" != *.env ]]; then
              if ssh-keygen -lf "$key" &>/dev/null; then
                  if ssh-add -l 2>/dev/null | grep -q "$(ssh-keygen -lf "$key" | awk '{print $2}')" 2>/dev/null; then
                      echo "Key $key already added"
                  else
                      ssh-add "$key" 2>/dev/null && echo "Added key $key" || echo "Failed to add key $key"
                  fi
              else
                  echo "Skipping $key - not a valid key file"
              fi
          fi
      done
  }

  ssh_agent_setup

  # Ensure the custom socket is always used
  export SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"
fi

# Disable terminal mouse tracking (prevents garbage on click over SSH)
printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l' 2>/dev/null

if [ "$IS_CONTAINER" = false ]; then # otherwise use docker settings
    # Use local CUDA version instead of one in /usr/bin
    # If below is not done then nvcc will be found in /usr/bin which is older
    # Flash Attention won't install because it will detect wrong nvcc
    # Set CUDA paths if directories exist
    [ -d "/usr/local/cuda/bin" ] && export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
    [ -d "/usr/local/cuda/lib64" ] && export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
    [ -d "/usr/local/cuda" ] && export CUDA_HOME=/usr/local/cuda
    # below is sometime needed to find libstdc++.so.6 used by TensorFlow, matplotlib etc
    # Set Conda paths if Conda is active and directory exists
    [ -n "$CONDA_PREFIX" ] && [ -d "$CONDA_PREFIX/lib" ] && export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CONDA_PREFIX/lib/
fi

# use fixed seed for python hash generation for reproducibility
export PYTHONHASHSEED=0
# set larger history size than default 1000/2000 values
export HISTCONTROL=ignoredups:erasedups  # Removes duplicate commands
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTTIMEFORMAT="%F %T  "     # Add timestamps (shown by 'history')
shopt -s cmdhist              # save multi-line cmds as one
shopt -s lithist              # keep line breaks and indentation
# assume all dirs to be safe for git
export GIT_TEST_ASSUME_ALL_SAFE=1

mkdir -p ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"

export CLAUDE_CODE_MAX_OUTPUT_TOKENS=65536

# HuggingFace cache and other locations
# links allows to use same paths in docker and host
export DATA_ROOT=$HOME/data
export CACHE_ROOT=$HOME/misc_caches
export MODELS_ROOT=$HOME/models
export OUT_DIR=$HOME/out_dir

#export XDG_CACHE_HOME=$CACHE_ROOT/misc  # don't set this, it interfers in some containers
export HF_HOME=$CACHE_ROOT/hf_home
export HF_DATASETS_CACHE=$CACHE_ROOT/datasets
export TIKTOKEN_CACHE_DIR=$CACHE_ROOT/tiktoken_cache
export WANDB_CACHE_DIR=$CACHE_ROOT/wandb_cache
export OLLAMA_MODELS=$MODELS_ROOT/ollama

# BIG_DISK is where we would like to store large datasets, models etc
export BIG_DISK=__YOUR_BIG_DISK__
# if $BIG_DISK exists
if [ -d "$BIG_DISK" ]; then
    if [ ! -d "$BIG_DISK/data" ]; then
        sudo mkdir -m 777 -p $BIG_DISK/data $BIG_DISK/misc_caches $BIG_DISK/models $BIG_DISK/out_dir
        ln -s $BIG_DISK/data ~/data
        ln -s $BIG_DISK/models ~/models
        ln -s $BIG_DISK/out_dir ~/out_dir
        ln -s $BIG_DISK/misc_caches ~/misc_caches
    fi
fi
echo DATA_ROOT=$DATA_ROOT
echo OUT_DIR=$OUT_DIR

# Enhanced history search with fzf
# Check if fzf is available
if command -v fzf >/dev/null 2>&1; then
  # Define the fzf_history function
  fzf_history() {
    local output
    output=$(history | fzf --tac --no-sort --query "$READLINE_LINE" --select-1 --exit-0)
    READLINE_LINE=${output#*[0-9]*  }
    READLINE_POINT=${#READLINE_LINE}
  }

  # Bind the function to Ctrl+R
  bind -x '"\C-r": fzf_history'
# else
#   # Fallback to default reverse-search-history if fzf is not available
#   bind '"\C-r": reverse-search-history'
fi

bind '"\t":menu-complete'
set show-all-if-ambiguous on
set menu-complete-display-prefix on

# within NVidia docker, everything is installed without conda,
# don't init conda by default or we will pick up wrong torch etc
if [ "${IS_CONTAINER:-false}" = false ]; then
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
# <<< conda initialize <<<
  :
fi

echo "REMEMBER: search for __ in .bashrc to complete setup and remove this message!!"

#-------------------------------------------------------------------------------------------------------------
#------------------------------ below can be customized, do not copy/paste below -----------------------------
#-------------------------------------------------------------------------------------------------------------

export WANDB_API_KEY=__YOUR_KEY__
export WANDB_HOST=__YOUR_HOST__


