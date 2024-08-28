#!/bin/bash

# Install fzf
if ! command -v fzf &> /dev/null; then
    echo "Installing fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --all
else
    echo "fzf is already installed."
fi

# Add fzf configuration to .bashrc
if ! grep -q "FZF configuration" ~/.bashrc; then
    echo "Adding fzf configuration to .bashrc..."
    cat << 'EOF' >> ~/.bashrc

# FZF configuration
if [ -f ~/.fzf.bash ]; then
    source ~/.fzf.bash
fi

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
EOF
else
    echo "fzf configuration already exists in .bashrc."
fi

echo "Setup complete. Please restart your terminal or run 'source ~/.bashrc' to apply changes."