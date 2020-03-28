powershell -NoProfile -ExecutionPolicy Bypass  -Command "&{ Start-Process powershell -NoExit -ArgumentList '-File install_choco.ps' -Verb RunAs}"
pause