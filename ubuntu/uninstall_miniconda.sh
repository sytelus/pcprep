#!/bin/bash

# Script to completely uninstall Miniconda from Ubuntu (home directory installation)

echo "Starting Miniconda uninstallation process..."

# Step 1: Remove the Miniconda installation directory
if [ -d "$HOME/miniconda3" ]; then
    echo "Removing Miniconda installation directory at $HOME/miniconda3..."
    rm -rf "$HOME/miniconda3"
    echo "Miniconda installation directory removed."
else
    echo "Miniconda installation directory not found at $HOME/miniconda3. Skipping this step."
fi

# Step 2: Remove Conda initialization from .bashrc or .zshrc
if [ -f "$HOME/.bashrc" ]; then
    echo "Removing Conda initialization from .bashrc..."
    sed -i '/# >>> conda initialize >>>/,/# <<< conda initialize <<</d' "$HOME/.bashrc"
    echo "Conda initialization removed from .bashrc."
fi

if [ -f "$HOME/.zshrc" ]; then
    echo "Removing Conda initialization from .zshrc..."
    sed -i '/# >>> conda initialize >>>/,/# <<< conda initialize <<</d' "$HOME/.zshrc"
    echo "Conda initialization removed from .zshrc."
fi

# Step 3: Remove Conda-related configuration and cache directories
echo "Removing Conda-related configuration and cache files..."
rm -rf "$HOME/.conda" "$HOME/.continuum"
echo "Configuration and cache files removed."

# Step 4: Reload the shell configuration
if [ -n "$BASH_VERSION" ]; then
    echo "Reloading .bashrc..."
    source "$HOME/.bashrc"
elif [ -n "$ZSH_VERSION" ]; then
    echo "Reloading .zshrc..."
    source "$HOME/.zshrc"
else
    echo "Could not reload shell configuration. Please manually reload your shell or restart the terminal."
fi

echo "Miniconda uninstallation completed!"
