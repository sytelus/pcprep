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
function fzf_history() {
    local output
    output=$(history | fzf --tac --tiebreak=index --no-sort --query "$READLINE_LINE" --exact --prompt="History > ")
    READLINE_LINE=$(echo "$output" | sed 's/^ *[0-9]* *//')
    READLINE_POINT=${#READLINE_LINE}
}

# Bind Ctrl+R to fzf history search
bind -x '"\C-r": fzf_history'
EOF
else
    echo "fzf configuration already exists in .bashrc."
fi

echo "Setup complete. Please restart your terminal or run 'source ~/.bashrc' to apply changes."