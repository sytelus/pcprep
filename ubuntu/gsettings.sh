#!/bin/bash
#fail if any errors
set -e
set -o xtrace

# Gtk Theme
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gconftool-2 --set /apps/metacity/general/theme --type string "Adwaita-dark"
gsettings set org.gnome.desktop.interface icon-theme "ubuntu-mono-dark"

# Cursor
gsettings set org.gnome.desktop.interface cursor-theme "DMZ-White"
gconftool-2 --set /desktop/gnome/peripherals/mouse/cursor_size --type int 48

# taskbar etc
gsettings set org.gnome.shell.extensions.dash-to-dock isolate-monitors true
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
gsettings set org.gnome.desktop.lockdown disable-lock-screen true
gconftool-2 -s /apps/gnome-terminal/profiles/Default/scrollback_lines --type=int 8192

#setup nautilus
gconftool-2 --type=Boolean --set /apps/nautilus/preferences/always_use_location_entry true
gsettings set org.gnome.nautilus.preferences always-use-location-entry true
#gconftool-2 --type string --set /apps/nautilus/preferences/show_icon_text "never"
gconftool-2 --type bool --set  /apps/nautilus/desktop/computer_icon_visible "true"
gconftool-2 --type bool --set  /apps/nautilus/desktop/home_icon_visible "true"
gconftool-2 --type bool --set  /apps/nautilus/desktop/trash_icon_visible "true"
gconftool --set /apps/nautilus/desktop/volumes_visible --type bool true
gconftool-2 --type string --set /apps/nautilus/preferences/date_format "iso"
gsettings set org.gnome.nautilus.list-view use-tree-view true
gconftool-2 --set /apps/nautilus/preferences/sort_directories_first --type boolean true
gconftool-2 --set /apps/nautilus/preferences/start_with_sidebar --type boolean true
gconftool-2 --set /apps/nautilus/preferences/start_with_status_bar --type boolean true
gconftool-2 --set /apps/nautilus/preferences/start_with_toolbar --type boolean true

# /apps/gedit
gconftool-2 --type bool --set /apps/gedit-2/preferences/editor/auto_indent/auto_indent "true" # auto-indent on
gconftool-2 --type bool --set /apps/gedit-2/preferences/editor/current_line/highlight_current_line "true" # add highlight for current line
#gconftool-2 --type bool --set /apps/gedit-2/preferences/editor/font/use_default_font "false" # turn off default font settings
gconftool-2 --type bool --set /apps/gedit-2/preferences/editor/line_numbers/display_line_numbers "true" # show line numbers
gconftool-2 --type bool --set /apps/gedit-2/preferences/editor/save/auto_save "false" # turn off auto saving
gconftool-2 --type bool --set /apps/gedit-2/preferences/editor/save/create_backup_copy "false" # turn off backups
gconftool-2 --type int --set /apps/gedit-2/preferences/editor/tabs/tabs_size "4" # tab size of 4 spaces
gconftool-2 --type string --set /apps/gedit-2/preferences/editor/colors/scheme "oblivion" # change theme to oblivion
#gconftool-2 --type string --set /apps/gedit-2/preferences/editor/wrap_mode/wrap_mode "GTK_WRAP_WORD" # text wrap on

# Terminal
gconftool-2 --set /apps/gnome-terminal/global/use_menu_accelerators --type boolean true
gconftool-2 --set /apps/gnome-terminal/profiles/Default/scrollback_unlimited --type boolean true

# increase number watches so VS Code doesn't complain
FILE=/etc/sysctl.conf
LINE='fs.inotify.max_user_watches=524288'
set +e # for some reason below gets permission denied
sudo grep -q "$LINE" "$FILE" || sudo echo "$LINE" >> "$FILE"
set -e