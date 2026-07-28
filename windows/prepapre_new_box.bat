@echo off
setlocal EnableExtensions DisableDelayedExpansion

REM Installs and configures the Windows tools in this directory.
REM
REM Run from a normal Command Prompt or PowerShell window. The script requests
REM one administrator phase for the steps that actually require elevation.
REM Use --yes to skip the confirmation prompt; errors still stop the script.
REM
REM This file intentionally avoids internal CALL :label and GOTO :label control
REM flow so it works reliably with the repository's LF-only line endings.

set "SCRIPT_DIR=%~dp0"
set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "HELPER=%~dp0prepare_new_box_helper.bat"
set "FAILED_STEP=initialization"

pushd "%SCRIPT_DIR%" >nul || (
    echo ERROR: Could not open the script directory: %SCRIPT_DIR%
    exit /b 1
)

if not exist "%HELPER%" (
    echo ERROR: Required helper script was not found: %HELPER%
    popd
    endlocal
    exit /b 1
)

if /i "%~1"=="--admin-phase" (
    call "%HELPER%" admin-phase "%SCRIPT_DIR%" "%POWERSHELL%"
    if errorlevel 1 (
        popd
        endlocal
        exit /b 1
    )
    popd
    endlocal
    exit /b 0
)

if /i "%~1"=="--help" (
    echo Usage: %~nx0 [--yes]
    echo.
    echo   --yes    Run without the confirmation prompt.
    echo            Git identity can still prompt unless user_name and user_email are set.
    popd
    endlocal
    exit /b 0
)

if /i "%~1"=="/?" (
    echo Usage: %~nx0 [--yes]
    echo.
    echo   --yes    Run without the confirmation prompt.
    echo            Git identity can still prompt unless user_name and user_email are set.
    popd
    endlocal
    exit /b 0
)

if /i "%~1"=="--yes" (
    set "ASSUME_YES=1"
) else if not "%~1"=="" (
    echo ERROR: Unknown option: %~1
    echo.
    echo Usage: %~nx0 [--yes]
    echo.
    echo   --yes    Run without the confirmation prompt.
    echo            Git identity can still prompt unless user_name and user_email are set.
    popd
    endlocal
    exit /b 2
)

call "%HELPER%" preflight "%SCRIPT_DIR%" "%POWERSHELL%"
if errorlevel 1 (
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

echo.
echo This script will:
echo   - Install or update Git, GitHub CLI, and Visual Studio Code with WinGet.
echo   - Install Codex CLI and Claude Code with WinGet when no working copy exists.
echo   - Install the Visual C++ Build Tools, MSVC linker, and Windows SDK needed by Rust.
echo   - Install or update Rustup and the stable x64 MSVC Rust toolchain.
echo   - Install or update the utilities listed in utilities.bat.
echo   - Configure command aliases, Git, File Explorer Gallery, Miniconda, and Python packages.
echo   - Expose selected power settings without changing the active power plan or its values.
echo.
echo The system-wide phase requests administrator access once. A package installer may
echo display an additional Windows confirmation if its own installer requires one.
echo Dell services are intentionally not disabled because Alienware and Dell features depend on them.
echo.
echo Manual or optional installs not handled here include Dropbox, the Visual Studio IDE, Teams,
echo OneNote, Beyond Compare, GitHub Desktop, Camtasia, and ThrottleStop.

if not defined ASSUME_YES (
    choice /C YN /N /M "Continue? [Y/N] "
    if errorlevel 2 (
        echo.
        echo Setup cancelled; no setup steps were started.
        popd
        endlocal
        exit /b 0
    )
)

set "FAILED_STEP=installing or updating Git"
call "%HELPER%" winget "Git.Git"
if errorlevel 1 (
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

set "FAILED_STEP=installing or updating Visual Studio Code"
call "%HELPER%" winget "Microsoft.VisualStudioCode"
if errorlevel 1 (
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

set "FAILED_STEP=installing or updating GitHub CLI"
call "%HELPER%" winget-cli "GitHub.cli" "gh.exe" "GitHub CLI"
if errorlevel 1 (
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

set "FAILED_STEP=installing or updating Codex CLI"
call "%HELPER%" winget-cli "OpenAI.Codex" "codex.exe" "Codex CLI"
if errorlevel 1 (
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

set "FAILED_STEP=installing or updating Claude Code"
call "%HELPER%" winget-cli "Anthropic.ClaudeCode" "claude.exe" "Claude Code"
if errorlevel 1 (
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

REM WinGet can update persistent PATH entries, but this process keeps its old PATH.
set "FAILED_STEP=refreshing tool paths after WinGet setup"
if exist "%ProgramFiles%\Git\cmd\git.exe" set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
if exist "%LocalAppData%\Programs\Microsoft VS Code\bin\code.cmd" set "PATH=%LocalAppData%\Programs\Microsoft VS Code\bin;%PATH%"
if exist "%ProgramFiles%\Microsoft VS Code\bin\code.cmd" set "PATH=%ProgramFiles%\Microsoft VS Code\bin;%PATH%"
if exist "%ProgramFiles%\GitHub CLI\gh.exe" set "PATH=%ProgramFiles%\GitHub CLI;%PATH%"
where git.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: Git was installed, but git.exe could not be located in the current process.
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)
where gh.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: GitHub CLI was installed, but gh.exe could not be located in the current process.
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)
gh.exe --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: GitHub CLI was located, but its version check failed.
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

set "FAILED_STEP=running administrator-only setup"
call "%HELPER%" run-admin-phase "%~f0" "%POWERSHELL%"
if errorlevel 1 (
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

REM Rustup is installed after the administrator phase so its unattended setup
REM sees the MSVC compiler/linker and Windows SDK prerequisites already present.
set "FAILED_STEP=installing or updating Rustup"
call "%HELPER%" winget "Rustlang.Rustup"
if errorlevel 1 (
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

if exist "%USERPROFILE%\.cargo\bin\rustup.exe" set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"
where rustup.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: Rustup was installed, but rustup.exe could not be located in the current process.
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

set "FAILED_STEP=configuring and verifying the stable Rust MSVC toolchain"
"%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%configure_rust.ps1"
if errorlevel 1 (
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

set "FAILED_STEP=configuring Command Prompt aliases"
call "%SCRIPT_DIR%aliases.reg.bat"
if errorlevel 1 (
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

set "FAILED_STEP=configuring Git"
call "%SCRIPT_DIR%gitconfig.bat"
if errorlevel 1 (
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

set "FAILED_STEP=hiding File Explorer Gallery"
call "%SCRIPT_DIR%hide_gallery.bat"
if errorlevel 1 (
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

set "FAILED_STEP=installing or updating Miniconda"
"%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install_miniconda.ps1"
if errorlevel 1 (
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

set "FAILED_STEP=installing or updating Python packages"
"%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install_pip_packages.ps1"
if errorlevel 1 (
    echo.
    echo ERROR: Setup stopped while %FAILED_STEP%.
    popd
    endlocal
    exit /b 1
)

echo.
echo Windows setup completed successfully.
echo Open a new terminal so all PATH and Conda initialization changes take effect.
popd
endlocal
exit /b 0
