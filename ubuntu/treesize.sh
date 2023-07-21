# list largest folders
du -a --max-depth=2 --human-readable --time --exclude=.* "${1:-/}" 2>/dev/null | sort --human-numeric-sort --reverse | head -n 15
