@echo off
setlocal

set "ALIASES_FILE=%~dp0aliases.doskey"
if not exist "%ALIASES_FILE%" (
    echo ERROR: Command Prompt aliases file was not found: %ALIASES_FILE%
    exit /b 1
)

reg.exe add "HKEY_CURRENT_USER\Software\Microsoft\Command Processor" ^
    /v AutoRun ^
    /t REG_SZ ^
    /d "doskey.exe /macrofile=\"%ALIASES_FILE%\"" ^
    /f >nul
if errorlevel 1 (
    echo ERROR: Could not configure Command Prompt aliases.
    exit /b 1
)

echo Command Prompt aliases now load from: %ALIASES_FILE%
exit /b 0
