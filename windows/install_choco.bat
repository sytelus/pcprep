@echo off
setlocal EnableExtensions DisableDelayedExpansion

REM Standalone Chocolatey bootstrap. Run from an elevated Command Prompt.
REM The complete pcprep setup uses WinGet instead and does not call this file.
REM This command downloads and executes Chocolatey's current public installer;
REM review https://community.chocolatey.org/install.ps1 before running it.

set "CHOCO_EXE=%ProgramData%\chocolatey\bin\choco.exe"
if not exist "%CHOCO_EXE%" if defined ChocolateyInstall (
    if exist "%ChocolateyInstall%\bin\choco.exe" set "CHOCO_EXE=%ChocolateyInstall%\bin\choco.exe"
)

if not exist "%CHOCO_EXE%" (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" ^
        -NoLogo -NoProfile -NonInteractive -InputFormat None ^
        -ExecutionPolicy Bypass ^
        -Command "[System.Net.ServicePointManager]::SecurityProtocol = 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    if errorlevel 1 (
        echo ERROR: Chocolatey installation failed.
        exit /b 1
    )
)

REM Recheck both supported locations because a previously empty custom
REM ChocolateyInstall directory may have been populated by the installer.
if not exist "%CHOCO_EXE%" if defined ChocolateyInstall (
    if exist "%ChocolateyInstall%\bin\choco.exe" set "CHOCO_EXE=%ChocolateyInstall%\bin\choco.exe"
)
if not exist "%CHOCO_EXE%" set "CHOCO_EXE=%ProgramData%\chocolatey\bin\choco.exe"
if not exist "%CHOCO_EXE%" (
    echo ERROR: Chocolatey setup completed, but choco.exe was not found.
    echo Open a new terminal and check %%ProgramData%%\chocolatey\bin.
    exit /b 1
)

"%CHOCO_EXE%" --version
if errorlevel 1 (
    echo ERROR: Chocolatey was found but failed its version check.
    exit /b 1
)

for %%I in ("%CHOCO_EXE%") do set "CHOCO_BIN=%%~dpI"
endlocal & set "PATH=%CHOCO_BIN%;%PATH%"
echo Chocolatey is installed and available in this Command Prompt.
exit /b 0
