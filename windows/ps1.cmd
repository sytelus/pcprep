@echo off
setlocal EnableExtensions DisableDelayedExpansion

REM Runs the .ps1 file with the same path and base name as the first argument.
REM A PowerShell helper forwards all remaining arguments without an LF-sensitive
REM batch label loop.

if "%~1"=="" (
    echo Usage: %~nx0 path-to-command-file [arguments...]
    exit /b 2
)

if not exist "%~dp0ps1_runner.ps1" (
    echo ERROR: Required helper script was not found: %~dp0ps1_runner.ps1
    exit /b 1
)

PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ps1_runner.ps1" %*
exit /b %ERRORLEVEL%
