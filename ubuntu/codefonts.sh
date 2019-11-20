#!/bin/bash
#fail if any errors
set -e
set -o xtrace

temp_dir=~/Downloads/codefonts
wget -P ${temp_dir} https://github.com/chrissimpkins/codeface/releases/download/font-collection/codeface-fonts.zip

if test "$(uname)" = "Darwin" ; then
  # MacOS
  fonts_dir="$HOME/Library/Fonts"
else
  # Linux
  fonts_dir="$HOME/.local/share/fonts"
  mkdir -p $fonts_dir
fi

# -n option avoids overwriting
set +e
unzip -n ${temp_dir}/codeface-fonts.zip "fonts/*.ttf" "fonts/*.otf" "*fonts/.pcf.gz" -d ${temp_dir}
set -e
cp -rnv ${temp_dir}/fonts ${fonts_dir}

if test "$(uname)" = "Darwin" ; then
  # Copy SF Mono for MacOS
  cp /Applications/Utilities/Terminal.app/Contents/Resources/Fonts/*.otf "$fonts_dir/"
fi

# Reset font cache on Linux
if which fc-cache >/dev/null 2>&1 ; then
    echo "Resetting font cache, this may take a moment..."
    fc-cache -f "$fonts_dir"
fi

echo "codefonts installed to $fonts_dir"
