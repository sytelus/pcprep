@echo off
setlocal EnableExtensions DisableDelayedExpansion

REM Installs and configures the Windows tools in this directory.
REM
REM Run from a normal Command Prompt or PowerShell window. The script requests
REM one administrator phase for the steps that actually require elevation.
REM Use --yes to skip the confirmation prompt; errors still stop the script.

set "SCRIPT_DIR=%~dp0"
set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "WINGET_ARGS=--exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity"
set "FAILED_STEP=initialization"

pushd "%SCRIPT_DIR%" >nul || (
    echo ERROR: Could not open the script directory: %SCRIPT_DIR%
    exit /b 1
)

if /i "%~1"=="--admin-phase" goto :AdminPhase
if /i "%~1"=="--help" goto :Usage
if /i "%~1"=="/?" goto :Usage
if /i "%~1"=="--yes" (
    set "ASSUME_YES=1"
) else if not "%~1"=="" (
    echo ERROR: Unknown option: %~1
    echo.
    goto :UsageError
)

call :Preflight || goto :Failed

echo.
echo This script will:
echo   - Install or update Git and Visual Studio Code with WinGet.
echo   - Install Codex CLI and Claude Code with WinGet when no working copy exists.
echo   - Install or update the utilities listed in utilities.bat.
echo   - Configure command aliases, Git, File Explorer Gallery, Miniconda, and Python packages.
echo   - Expose selected power settings without changing the active power plan or its values.
echo.
echo The system-wide phase requests administrator access once. A package installer may
echo display an additional Windows confirmation if its own installer requires one.
echo Dell services are intentionally not disabled because Alienware and Dell features depend on them.
echo.
echo Manual or optional installs not handled here include Dropbox, Visual Studio, Teams,
echo OneNote, Beyond Compare, GitHub Desktop, Camtasia, and ThrottleStop.

if not defined ASSUME_YES (
    choice /C YN /N /M "Continue? [Y/N] "
    if errorlevel 2 goto :Cancelled
)

set "FAILED_STEP=installing or updating Git"
call :EnsureWingetPackage "Git.Git" || goto :Failed

set "FAILED_STEP=installing or updating Visual Studio Code"
call :EnsureWingetPackage "Microsoft.VisualStudioCode" || goto :Failed

set "FAILED_STEP=installing or updating Codex CLI"
call :EnsureWingetCliOrExistingCommand "OpenAI.Codex" "codex.exe" "Codex CLI" || goto :Failed

set "FAILED_STEP=installing or updating Claude Code"
call :EnsureWingetCliOrExistingCommand "Anthropic.ClaudeCode" "claude.exe" "Claude Code" || goto :Failed

REM WinGet can update persistent PATH entries, but this process keeps its old PATH.
set "FAILED_STEP=refreshing tool paths after WinGet setup"
call :AddCurrentProcessToolPaths || goto :Failed

set "FAILED_STEP=running administrator-only setup"
call :RunAdminPhase || goto :Failed

set "FAILED_STEP=configuring Command Prompt aliases"
call "%SCRIPT_DIR%aliases.reg.bat" || goto :Failed

set "FAILED_STEP=configuring Git"
call "%SCRIPT_DIR%gitconfig.bat" || goto :Failed

set "FAILED_STEP=hiding File Explorer Gallery"
call "%SCRIPT_DIR%hide_gallery.bat" || goto :Failed

set "FAILED_STEP=installing or updating Miniconda"
"%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install_miniconda.ps1"
if errorlevel 1 goto :Failed

set "FAILED_STEP=installing or updating Python packages"
"%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install_pip_packages.ps1"
if errorlevel 1 goto :Failed

echo.
echo Windows setup completed successfully.
echo Open a new terminal so all PATH and Conda initialization changes take effect.
popd
endlocal
exit /b 0

:Preflight
where winget.exe >nul 2>&1 || (
    echo ERROR: WinGet is required but was not found. Install or update App Installer first.
    exit /b 1
)

if not exist "%POWERSHELL%" (
    echo ERROR: Windows PowerShell was not found at %POWERSHELL%.
    exit /b 1
)

for %%F in (
    "aliases.reg.bat"
    "aliases.doskey"
    "gitconfig.bat"
    "hide_gallery.bat"
    "utilities.bat"
    "processor_performance_boost_mode.reg"
    "enable_hidden_power.ps1"
    "install_miniconda.ps1"
    "install_pip_packages.ps1"
) do (
    if not exist "%SCRIPT_DIR%%%~F" (
        echo ERROR: Required file is missing: %SCRIPT_DIR%%%~F
        exit /b 1
    )
)
exit /b 0

:EnsureWingetPackage
echo.
echo Ensuring %~1 is installed and current...
winget install --id "%~1" %WINGET_ARGS%
if errorlevel 1 (
    echo ERROR: WinGet could not install or update %~1.
    exit /b 1
)
exit /b 0

:EnsureWingetCliOrExistingCommand
winget list --id "%~1" --exact --source winget --accept-source-agreements --disable-interactivity >nul 2>&1
if not errorlevel 1 (
    call :EnsureWingetPackage "%~1"
    if errorlevel 1 exit /b 1
    exit /b 0
)

where.exe "%~2" >nul 2>&1
if not errorlevel 1 (
    echo.
    echo %~3 is already available outside WinGet; preserving it to avoid a duplicate installation.
    where.exe "%~2"
    "%~2" --version
    if errorlevel 1 (
        echo ERROR: The existing %~3 command did not pass its version check.
        exit /b 1
    )
    exit /b 0
)

call :EnsureWingetPackage "%~1"
if errorlevel 1 exit /b 1
exit /b 0

:AddCurrentProcessToolPaths
if exist "%ProgramFiles%\Git\cmd\git.exe" set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
if exist "%LocalAppData%\Programs\Microsoft VS Code\bin\code.cmd" set "PATH=%LocalAppData%\Programs\Microsoft VS Code\bin;%PATH%"
if exist "%ProgramFiles%\Microsoft VS Code\bin\code.cmd" set "PATH=%ProgramFiles%\Microsoft VS Code\bin;%PATH%"

where git.exe >nul 2>&1 || (
    echo ERROR: Git was installed, but git.exe could not be located in the current process.
    exit /b 1
)
exit /b 0

:RunAdminPhase
REM Avoid another UAC prompt if the caller is already elevated.
fltmc.exe >nul 2>&1
if not errorlevel 1 (
    call "%~f0" --admin-phase
    if errorlevel 1 exit /b 1
    exit /b 0
)

set "PCPREP_INSTALL_ALL=%~f0"
"%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop'; $q = [char]34; $arguments = '/d /s /c {0}{0}{1}{0} --admin-phase{0}' -f $q, $env:PCPREP_INSTALL_ALL; $process = Start-Process -FilePath $env:ComSpec -ArgumentList $arguments -Verb RunAs -Wait -PassThru; exit $process.ExitCode"
set "ADMIN_EXIT=%ERRORLEVEL%"
set "PCPREP_INSTALL_ALL="
if not "%ADMIN_EXIT%"=="0" (
    echo ERROR: Administrator-only setup failed or the elevation request was cancelled.
    exit /b %ADMIN_EXIT%
)
exit /b 0

:AdminPhase
fltmc.exe >nul 2>&1 || (
    echo ERROR: The administrator-only phase is not elevated.
    goto :AdminFailed
)

echo.
echo ===== Administrator-only setup =====

call :EnsureWingetPackage "Chocolatey.Chocolatey" || goto :AdminFailed
if exist "%ProgramData%\chocolatey\bin\choco.exe" set "PATH=%ProgramData%\chocolatey\bin;%PATH%"
where choco.exe >nul 2>&1 || (
    echo ERROR: Chocolatey was installed, but choco.exe could not be located.
    goto :AdminFailed
)

call "%SCRIPT_DIR%utilities.bat" || goto :AdminFailed

reg.exe import "%SCRIPT_DIR%processor_performance_boost_mode.reg" >nul
if errorlevel 1 (
    echo ERROR: Could not expose the Processor performance boost mode setting.
    goto :AdminFailed
)
echo Exposed the Processor performance boost mode setting.

"%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%enable_hidden_power.ps1"
if errorlevel 1 goto :AdminFailed

echo ===== Administrator-only setup completed =====
popd
endlocal
exit /b 0

:AdminFailed
echo.
echo ERROR: Administrator-only setup did not complete.
popd
endlocal
exit /b 1

:Cancelled
echo.
echo Setup cancelled; no setup steps were started.
popd
endlocal
exit /b 0

:Usage
echo Usage: %~nx0 [--yes]
echo.
echo   --yes    Run without the confirmation prompt.
echo            Git identity can still prompt unless user_name and user_email are set.
popd
endlocal
exit /b 0

:UsageError
popd
endlocal
exit /b 2

:Failed
set "FAILURE_EXIT=%ERRORLEVEL%"
if "%FAILURE_EXIT%"=="0" set "FAILURE_EXIT=1"
echo.
echo ERROR: Setup stopped while %FAILED_STEP%.
echo Exit code: %FAILURE_EXIT%
popd
endlocal & exit /b %FAILURE_EXIT%
