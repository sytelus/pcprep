#!/bin/bash

# Script to move the WSL user's home directory to a new location based on script argument

# Check if an argument was provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <new_home_base_path>"
    exit 1
fi

# The new home base directory is the first script argument
NEW_HOME_BASE="$1"

# Exit immediately if a command exits with a non-zero status
set -e

# Automatically get the current username, UID, and GID
USERNAME=$(whoami)
USER_UID=$(id -u $USERNAME)
USER_GID=$(id -g $USERNAME)

# Define new home directory path
NEW_HOME_DIR="${NEW_HOME_BASE}/${USERNAME}"

# Create new home directory with appropriate permissions
echo "Creating new home directory at ${NEW_HOME_DIR}"
sudo mkdir -p "${NEW_HOME_DIR}"
sudo chown $USER_UID:$USER_GID "${NEW_HOME_DIR}"
chmod 755 "${NEW_HOME_DIR}"

# Copy old home to new home
echo "Copying old home directory to ${NEW_HOME_DIR}"
sudo rsync -aHAXxv /home/$USERNAME/ "${NEW_HOME_DIR}/" --exclude "${NEW_HOME_DIR}"

# Update /etc/passwd to reflect the new home directory
echo "Updating /etc/passwd to reflect the new home directory"
sudo usermod -d "${NEW_HOME_DIR}" $USERNAME

# Inform the user to restart WSL
echo "Please restart to complete the process."
