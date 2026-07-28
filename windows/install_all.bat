@echo off
echo ****** System Perf Optimizations ********
echo Turn off Delivery Optimization peer sharing
echo Turn off Optional diagnostic data and Personalized offers under Settings → Privacy & security → Diagnostics & feedback
echo Stop all dell Windows services, LogiSyncStub services, debugregsvc  and set them as disabled
echo
echo Manual installs: Git, Chrome, Dropbox, VSCode, VS2019, Teams, OneNote, Beyond Compare, GitHub Desktop, Camtasia
echo Optional: https://www.techpowerup.com/download/techpowerup-throttlestop/
echo
echo create new bookmark and copy code from "copy with title bookmarklet.js" in URL

@echo on

PAUSE Make sure to run from admin command!

REM install codex and claude
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
powershell -ExecutionPolicy ByPass -c "irm https://claude.ai/install.ps1 | iex"

call aliases.reg.bat
call install_choco.bat
call gitconfig.bat
call utilities.bat
call hide_gallery.bat

regedit /s processor_performance_boost_mode.reg

powershell -Command "&{ Start-Process powershell -ArgumentList '-File enable_hidden_power.ps1' -Verb RunAs}"
powershell -Command "&{ Start-Process powershell -ArgumentList '-File install_miniconda.ps1' -Verb RunAs}"
powershell -Command "&{ Start-Process powershell -ArgumentList '-File install_pip_packages.ps1' -Verb RunAs}"

