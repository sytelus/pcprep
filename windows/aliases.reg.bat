@echo off
setlocal EnableExtensions DisableDelayedExpansion

REM Install a stable copy outside the repository so moving or deleting the
REM checkout does not leave Command Prompt AutoRun pointing at a stale path.
set "SOURCE_FILE=%~dp0aliases.doskey"
set "INSTALL_DIRECTORY=%LOCALAPPDATA%\pcprep"
set "ALIASES_FILE=%INSTALL_DIRECTORY%\aliases.doskey"
set "AUTORUN_BACKUP=%INSTALL_DIRECTORY%\command-processor-before-pcprep.reg"

if not exist "%SOURCE_FILE%" (
    echo ERROR: Command Prompt aliases file was not found: %SOURCE_FILE%
    exit /b 1
)
if not exist "%INSTALL_DIRECTORY%" mkdir "%INSTALL_DIRECTORY%" >nul 2>&1
if not exist "%INSTALL_DIRECTORY%" (
    echo ERROR: Could not create the aliases directory: %INSTALL_DIRECTORY%
    exit /b 1
)
copy /y "%SOURCE_FILE%" "%ALIASES_FILE%" >nul || (
    echo ERROR: Could not install Command Prompt aliases in %ALIASES_FILE%.
    exit /b 1
)

REM Preserve the original Command Processor settings only once. Repeated setup
REM runs must not overwrite this backup with pcprep's own AutoRun value.
if not exist "%AUTORUN_BACKUP%" reg.exe export ^
    "HKEY_CURRENT_USER\Software\Microsoft\Command Processor" ^
    "%AUTORUN_BACKUP%" /y >nul 2>&1

reg.exe add "HKEY_CURRENT_USER\Software\Microsoft\Command Processor" ^
    /v AutoRun ^
    /t REG_SZ ^
    /d "if exist \"%ALIASES_FILE%\" doskey.exe /macrofile=\"%ALIASES_FILE%\"" ^
    /f >nul
if errorlevel 1 (
    echo ERROR: Could not configure Command Prompt aliases.
    exit /b 1
)

echo Command Prompt aliases now load from: %ALIASES_FILE%
exit /b 0
