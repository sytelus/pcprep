PAUSE Make sure to run from admin command!

PAUSE Manual installs: Git, Chrome, Dropbox, VSCode, VS2019, Teams, OneNote, Beyond Compare
PAUSE Manual installs: GitHub Desktop, Camtasia
REM Optional: https://www.techpowerup.com/download/techpowerup-throttlestop/

REM install codex and claude
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
powershell -ExecutionPolicy ByPass -c "irm https://claude.ai/install.ps1 | iex"

REM call install_gsudo.bat
call install_choco.bat
call gitconfig.bat
call utilities.bat

REM regedit /s aliases.reg
REM regedit /s LongPathEnabled.reg
regedit /s processor_performance_boost_mode.reg

REM call install_anaconda.bat
call install_python.bat
call install_ml.bat
call install_rl.bat
REM call gitclones.bat

REM install code face fonts
powershell -Command "&{ Start-Process powershell -ArgumentList '-File codeface.ps1' -Verb RunAs}"
PAUSE
