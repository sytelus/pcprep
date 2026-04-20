# Managed by pcprep — sourced by the managed zsh fragment after Homebrew's
# Powerlevel10k theme is loaded.
#
# Goal: keep the prompt compact but high-signal for daily development.
# - Left side: current directory and git status
# - Right side: only transient/high-value status data
# - Layout: two lines, with the command prompt isolated on the second line
# - History readability: transient prompt collapses old prompts after command run

typeset -g POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
typeset -g POWERLEVEL9K_MODE=nerdfont-complete

# Keep the command entry area visually clean after a command finishes.
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always
typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false

# Compact, information-dense layout.
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  dir
  vcs
  newline
  prompt_char
)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  status
  command_execution_time
  background_jobs
  virtualenv
  kubecontext
  context
  time
)

# Show just enough path information to stay oriented without burning columns.
typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last
typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=2
typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=48

# Only show status segments when they carry useful information.
typeset -g POWERLEVEL9K_STATUS_OK=false
typeset -g POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE=false
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=0

# Keep environment/context noise low unless it matters.
typeset -g POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION=false
typeset -g POWERLEVEL9K_CONTEXT_DEFAULT_CONTENT_EXPANSION=
typeset -g POWERLEVEL9K_CONTEXT_ROOT_CONTENT_EXPANSION='%n@%m'
typeset -g POWERLEVEL9K_CONTEXT_SUDO_CONTENT_EXPANSION='%n@%m'
typeset -g POWERLEVEL9K_KUBECONTEXT_SHOW_DEFAULT_NAMESPACE=false
typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M}'
typeset -g POWERLEVEL9K_TIME_UPDATE_ON_COMMAND=true
