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
if [ "$color_prompt" = yes ]; then
    #PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    #PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
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

# #enable arrow up/down for partial search
# bind '"\e[A": history-search-backward'
# bind '"\e[B": history-search-forward'

# #cycle through tab completion
# [[ $- = *i* ]] && bind '"TAB": menu-complete'
# [[ $- = *i* ]] && bind '"\e[Z":menu-complete-backward'

# display one column with tab completion matches

# if not already running tmux and in SSH session then start tmux
# if [[ -z "$TMUX" ]] && [ "$SSH_CONNECTION" != "" ]; then
#     tmux attach-session -t ssh_tmux || tmux new-session -s ssh_tmux

#     # LS_COLORS='rs=0:di=1;35:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.lz>    # export LS_COLORS
# fi

# Turn on ../**/*.ext pattern matching
shopt -q -s extglob


# if [[ ! -z "$WSL_DISTRO_NAME" ]]; then
#     if [[ ! grep -Fxq "nameserver 10.50.10.50" /etc/resolv.conf ]]; then
#         sudo mv /etc/resolv.conf /etc/resolv.conf.bak
#         sudo bash -c "cat /etc/resolv.conf.bak > /etc/resolv.conf"
#         sudo bash -c "echo nameserver 10.50.10.50 >> /etc/resolv.conf"
#     fi
# fi


if [[ ! "$(uname -s)" == "Darwin" ]]; then
  # Set GPG TTY
  export GPG_TTY=$(tty)

  # Start the gpg-agent if not already running
  if ! pgrep -x -u "${USER}" gpg-agent >/dev/null 2>&1; then
    gpg-agent --daemon --enable-ssh-support --write-env-file "${HOME}/.gpg-agent-info"
  fi
fi

if [ -f "${HOME}/.gpg-agent-info" ]; then
  . "${HOME}/.gpg-agent-info"
  export GPG_AGENT_INFO
  export SSH_AUTH_SOCK
fi

# run ssh-add once per reboot
if [ ! -S ~/.ssh/ssh_auth_sock ]; then
  eval `ssh-agent`
  ln -sf "$SSH_AUTH_SOCK" ~/.ssh/ssh_auth_sock
fi
export SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock
ssh-add -l > /dev/null || ssh-add ~/.ssh/sb_github_rsa

# Use local CUDA version instead of one in /usr/bin
# If below is not done then nvcc will be found in /usr/bin which is older
# Flash Attention won't install because it will detect wrong nvcc
export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
# below is sometime needed to find libstdc++.so.6 used by TensorFlow, matplotlib etc
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CONDA_PREFIX/lib/

# HuggingFace cache and other locations
# export DATA_ROOT=/scratch/data
# export XDG_CACHE_HOME=$DATA_ROOT/misc
# export TRANSFORMERS_CACHE=$DATA_ROOT/models
# export HF_DATASETS_CACHE=$DATA_ROOT/datasets
# export TIKTOKEN_CACHE_DIR=$DATA_ROOT/tiktoken_cache
# export WANDB_CACHE_DIR=$DATA_ROOT/wandb_cache
# export OUT_DIR=$DATA_ROOT/out_dir
# export WANDB_API_KEY=<YOUR_KEY>

# Use one of below if getting libcudart.so error
# export CUDA_HOME=/usr/local/cuda-12.1
# export CUDA_HOME=$CONDA_PREFIX

echo NUMEXPR_MAX_THREADS=$NUMEXPR_MAX_THREADS
echo DATA_ROOT=$DATA_ROOT
echo OUT_DIR=$OUT_DIR


# max threads, leaving out 2 or 1 cores
export NUMEXPR_MAX_THREADS=$([ $(nproc) -le 1 ] && echo 1 || echo $(( $(nproc) <= 2 ? 1 : $(nproc) - 2 )))
export PYTHONHASHSEED=0

# sudo mkdir -m 777 -p $DATA_ROOT $XDG_CACHE_HOME $TRANSFORMERS_CACHE $HF_DATASETS_CACHE $TIKTOKEN_CACHE_DIR $WANDB_CACHE_DIR

