PAUSE Make sure to run from admin command!

PAUSE Manual installs: Git, Chrome, Dropbox, VSCode, VS2019, Teams, OneNote, Beyond Compare
PAUSE Manual installs: GitHub Desktop, Camtasia
REM Optional: https://www.techpowerup.com/download/techpowerup-throttlestop/

call install_gsudo.bat
call install_choco.bat
call gitconfig.bat
call utilities.bat

regedit /s aliases.reg
regedit /s LongPathEnabled.reg
regedit /s processor_performance_boost_mode.reg

call install_anaconda.bat
call install_python.bat
call install_ml.bat
call install_rl.bat
call gitclones.bat

REM install code face fonts
powershell -Command "&{ Start-Process powershell -ArgumentList '-File codeface.ps1' -Verb RunAs}"
PAUSE