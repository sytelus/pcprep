#!/usr/bin/env python3
import os
import sys
import subprocess
from pathlib import Path

def check_git_status(folder_path):
    """
    Check the Git status of a folder and return its status.
    """
    try:
        # Check if it's a git repository
        result = subprocess.run(['git', 'rev-parse', '--git-dir'],
                              cwd=folder_path,
                              stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE,
                              text=True)

        if result.returncode != 0:
            return "Not a git repo"

        # Check for uncommitted changes
        result = subprocess.run(['git', 'status', '--porcelain'],
                              cwd=folder_path,
                              stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE,
                              text=True)

        if result.stdout.strip():
            return "Uncommitted"

        # Check for unpushed commits
        # First, get the current branch name
        result = subprocess.run(['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                              cwd=folder_path,
                              stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE,
                              text=True)
        current_branch = result.stdout.strip()

        # Check if there's an upstream branch
        result = subprocess.run(['git', 'rev-parse', '--abbrev-ref', f'{current_branch}@{{u}}'],
                              cwd=folder_path,
                              stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE,
                              text=True)

        if result.returncode != 0:
            return "Unpushed (no upstream branch)"

        # Check for differences between local and remote
        result = subprocess.run(['git', 'diff', f'{current_branch}@{{u}}..'],
                              cwd=folder_path,
                              stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE,
                              text=True)

        if result.stdout.strip():
            return "Unpushed"

        return "Synced"

    except subprocess.CalledProcessError:
        return "Error checking git status"

def main():
    if len(sys.argv) != 2:
        print("Usage: python script.py <directory_path>")
        sys.exit(1)

    base_path = Path(sys.argv[1]).resolve()

    if not base_path.is_dir():
        print(f"Error: {base_path} is not a directory")
        sys.exit(1)

    # Get immediate subdirectories
    subdirs = [f for f in base_path.iterdir() if f.is_dir()]

    # Calculate the maximum folder name length for alignment
    max_length = max(len(str(folder.name)) for folder in subdirs)

    print("\nGit Repository Status Check")
    print("=" * 50)

    for folder in sorted(subdirs):
        status = check_git_status(folder)
        print(f"{folder.name:<{max_length}} : {status}")

if __name__ == "__main__":
    main()