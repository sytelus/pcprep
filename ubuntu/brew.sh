#!/bin/bash
#fail if any errors
set -e
set -o xtrace

sudo apt install -y linuxbrew-wrapper
yes '' | brew tap
FILE=~/.bashrc
LINE='export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"'
grep -q "$LINE" "$FILE" || echo "$LINE" >> "$FILE" || eval $LINE
LINE='export MANPATH="/home/linuxbrew/.linuxbrew/share/man:$MANPATH"'
grep -q "$LINE" "$FILE" || echo "$LINE" >> "$FILE" || eval $LINE
LINE='export INFOPATH="/home/linuxbrew/.linuxbrew/share/info:$INFOPATH"'
grep -q "$LINE" "$FILE" || echo "$LINE" >> "$FILE" || eval $LINE
