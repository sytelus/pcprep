#!/bin/bash
#fail if any errors
set -e
set -o xtrace

if [ -z "$1" ]; then
    echo "Error: No submodule specified. Usage: $0 <submodule>" >&2
    exit 1
fi

read -p "Are you sure you want to permanently delete submodule '$1'? This action cannot be undone (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deletion cancelled."
    exit 1
fi

git submodule sync --recursive
git submodule deinit -f $1
rm -rf .git/modules/$1
git config --remove-section submodule.$1
git clean -fd
git rm --cached $1
git submodule update --init --recursive