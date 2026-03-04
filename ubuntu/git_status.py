#!/usr/bin/env python3
"""
GitStatus.py - quick Git status summary for immediate subdirectories.

Goal:
    Provide a fast, one-line per project overview to spot repositories that
    are dirty or have local commits pending push.

Purpose:
    Scan a parent directory containing multiple Git repositories and classify
    each immediate child directory as one of:
        - Not a git repo
        - Uncommitted
        - Unpushed (no upstream branch)
        - Unpushed
        - Synced

Usage:
    python3 ubuntu/GitStatus.py /path/to/parent

Behavior notes:
    - Only checks immediate subdirectories; it does not recurse.
    - Uses local Git metadata only; it does not run "git fetch".
    - "Unpushed" is based on differences vs the configured upstream.
    - Requires "git" to be available on PATH.

References:
    No in-repo references were found; this script is intended to be run directly.
"""

import os
import sys
import subprocess
from pathlib import Path

def check_git_status(folder_path):
    """
    Return a human-readable Git status label for a directory.

    Statuses:
        - "Not a git repo": The directory is not a Git repository.
        - "Uncommitted": There are staged/unstaged/untracked changes.
        - "Unpushed (no upstream branch)": No upstream is configured.
        - "Unpushed": Local branch differs from its upstream.
        - "Synced": Clean working tree and no local differences vs upstream.
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
    """
    Parse arguments, iterate immediate subdirectories, and print statuses.
    """
    if len(sys.argv) > 2:
        script_name = Path(sys.argv[0]).name
        print(f"Usage: python {script_name} [directory_path]")
        sys.exit(1)

    base_path = Path(sys.argv[1]).resolve() if len(sys.argv) == 2 else Path.cwd()

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
