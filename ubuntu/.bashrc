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
if [ -f /.dockerenv ]; then
    export IS_IN_DOCKER=true
else
    export IS_IN_DOCKER=false
fi

# Then use it to set the prompt
if [ "$color_prompt" = yes ]; then
    if [ "$IS_IN_DOCKER" = true ]; then
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

is_wsl() {
    case "$(uname -r)" in
    *microsoft* ) true ;; # WSL 2
    *Microsoft* ) true ;; # WSL 1
    * ) false;;
    esac
}

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

    start_agent() {
        echo "Initializing new SSH agent..."
        ssh-agent -a "$CUSTOM_SSH_AUTH_SOCK" | sed 's/^echo/#echo/' > "${SSH_ENV}"
        chmod 600 "${SSH_ENV}"
        . "${SSH_ENV}" > /dev/null
    }

    if [ -S "$SSH_AUTH_SOCK" ]; then
        # SSH agent is already running
        case "$SSH_AUTH_SOCK" in
            "$CUSTOM_SSH_AUTH_SOCK")
                # Our custom socket is already in use
                ;;
            *)
                # Different socket in use, link our custom socket to it
                ln -sf "$SSH_AUTH_SOCK" "$CUSTOM_SSH_AUTH_SOCK"
                export SSH_AUTH_SOCK="$CUSTOM_SSH_AUTH_SOCK"
                ;;
        esac
    elif [ -f "${SSH_ENV}" ]; then
        . "${SSH_ENV}" > /dev/null
        if ! ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null; then
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


# Use local CUDA version instead of one in /usr/bin
# If below is not done then nvcc will be found in /usr/bin which is older
# Flash Attention won't install because it will detect wrong nvcc
# Set CUDA paths if directories exist
[ -d "/usr/local/cuda/bin" ] && export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
[ -d "/usr/local/cuda/lib64" ] && export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
# below is sometime needed to find libstdc++.so.6 used by TensorFlow, matplotlib etc
# Set Conda paths if Conda is active and directory exists
[ -n "$CONDA_PREFIX" ] && [ -d "$CONDA_PREFIX/lib" ] && export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CONDA_PREFIX/lib/
# Use one of below if getting libcudart.so error or want to compile flash-attn
# below is needed because cuda install ends up with 12.3 instead of 12.1 anyway
#export CUDA_HOME=/usr/local/cuda-12.1
# export CUDA_HOME=$CONDA_PREFIX

# set larger history size than default 1000/2000 values
HISTSIZE=10000
HISTFILESIZE=20000

# HuggingFace cache and other locations
export DATA_ROOT=~/data
export CACHE_ROOT=~/caches
export MODELS_ROOT=~/models
export OUT_DIR=~/out_dir
export XDG_CACHE_HOME=$CACHE_ROOT/misc
export TRANSFORMERS_CACHE=$CACHE_ROOT/models
export HF_DATASETS_CACHE=$CACHE_ROOT/datasets
export TIKTOKEN_CACHE_DIR=$CACHE_ROOT/tiktoken_cache
export WANDB_CACHE_DIR=$CACHE_ROOT/wandb_cache
export WANDB_API_KEY=<YOUR_KEY>
export OLLAMA_MODELS=$MODELS_ROOT/ollama

# max threads, leaving out 2 or 1 cores
export NUMEXPR_MAX_THREADS=$([ $(nproc) -le 1 ] && echo 1 || echo $(( $(nproc) <= 2 ? 1 : $(nproc) - 2 )))
export PYTHONHASHSEED=0

echo NUMEXPR_MAX_THREADS=$NUMEXPR_MAX_THREADS
echo DATA_ROOT=$DATA_ROOT
echo OUT_DIR=$OUT_DIR

# sudo chmod 777 /scratch
# sudo mkdir -m 777 -p $DATA_ROOT $XDG_CACHE_HOME $TRANSFORMERS_CACHE $HF_DATASETS_CACHE $TIKTOKEN_CACHE_DIR $WANDB_CACHE_DIR $OLLAMA_MODELS
# chmod 600 ~/.ssh/*



#start-tmux
