@echo off
setlocal EnableExtensions DisableDelayedExpansion

REM External helper for prepapre_new_box.bat.
REM Keeping reusable operations in a separate batch file avoids internal
REM CALL :label and GOTO :label behavior in LF-only batch files.

if "%~1"=="" (
    echo ERROR: prepare_new_box_helper.bat requires an action.
    exit /b 2
)

if /i "%~1"=="preflight" (
    where winget.exe >nul 2>&1 || (
        echo ERROR: WinGet is required but was not found. Install or update App Installer first.
        exit /b 1
    )

    if not exist "%~3" (
        echo ERROR: Windows PowerShell was not found at %~3.
        exit /b 1
    )

    for %%F in (
        "aliases.reg.bat"
        "aliases.doskey"
        "gitconfig.bat"
        "hide_gallery.bat"
        "utilities.bat"
        "utilities_helper.bat"
        "prepare_new_box_helper.bat"
        "processor_performance_boost_mode.reg"
        "enable_hidden_power.ps1"
        "install_rust_prerequisites.ps1"
        "configure_rust.ps1"
        "install_miniconda.ps1"
        "install_pip_packages.ps1"
    ) do (
        if not exist "%~2%%~F" (
            echo ERROR: Required file is missing: %~2%%~F
            exit /b 1
        )
    )
    exit /b 0
)

if /i "%~1"=="winget" (
    if "%~2"=="" (
        echo ERROR: The winget action requires a package ID.
        exit /b 2
    )
    call "%~dp0utilities_helper.bat" winget "%~2"
    if errorlevel 1 exit /b 1
    exit /b 0
)

if /i "%~1"=="winget-cli" (
    if "%~4"=="" (
        echo ERROR: The winget-cli action requires a package ID, command, and display name.
        exit /b 2
    )

    winget list --id "%~2" --exact --source winget --accept-source-agreements --disable-interactivity >nul 2>&1
    if not errorlevel 1 (
        call "%~dp0utilities_helper.bat" winget "%~2"
        if errorlevel 1 exit /b 1
        exit /b 0
    )

    where.exe "%~3" >nul 2>&1
    if not errorlevel 1 (
        echo.
        echo %~4 is already available outside WinGet; preserving it to avoid a duplicate installation.
        where.exe "%~3"
        "%~3" --version
        if errorlevel 1 (
            echo ERROR: The existing %~4 command did not pass its version check.
            exit /b 1
        )
        exit /b 0
    )

    call "%~dp0utilities_helper.bat" winget "%~2"
    if errorlevel 1 exit /b 1
    exit /b 0
)

if /i "%~1"=="run-admin-phase" (
    if "%~3"=="" (
        echo ERROR: The run-admin-phase action requires the setup script and PowerShell paths.
        exit /b 2
    )

    REM Avoid another UAC prompt if the caller is already elevated.
    fltmc.exe >nul 2>&1
    if not errorlevel 1 (
        call "%~2" --admin-phase
        if errorlevel 1 exit /b 1
        exit /b 0
    )

    set "PCPREP_INSTALL_ALL=%~2"
    "%~3" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
        "$ErrorActionPreference = 'Stop'; $q = [char]34; $arguments = '/d /s /c {0}{0}{1}{0} --admin-phase{0}' -f $q, $env:PCPREP_INSTALL_ALL; $process = Start-Process -FilePath $env:ComSpec -ArgumentList $arguments -Verb RunAs -Wait -PassThru; exit $process.ExitCode"
    if errorlevel 1 (
        echo ERROR: Administrator-only setup failed or the elevation request was cancelled.
        exit /b 1
    )
    exit /b 0
)

if /i "%~1"=="admin-phase" (
    if "%~3"=="" (
        echo ERROR: The admin-phase action requires the script directory and PowerShell paths.
        exit /b 2
    )

    fltmc.exe >nul 2>&1 || (
        echo ERROR: The administrator-only phase is not elevated.
        exit /b 1
    )

    echo.
    echo ===== Administrator-only setup =====

    REM A direct Chocolatey installation is not registered as a WinGet package.
    REM Detect its standard executable before asking WinGet to install it again.
    if not exist "%ProgramData%\chocolatey\bin\choco.exe" (
        call "%~dp0utilities_helper.bat" winget "Chocolatey.Chocolatey"
        if errorlevel 1 (
            echo ERROR: Administrator-only setup did not complete.
            exit /b 1
        )
    )

    if exist "%ProgramData%\chocolatey\bin\choco.exe" set "PATH=%ProgramData%\chocolatey\bin;%PATH%"
    where choco.exe >nul 2>&1 || (
        echo ERROR: Chocolatey was installed, but choco.exe could not be located.
        echo ERROR: Administrator-only setup did not complete.
        exit /b 1
    )

    "%~3" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~2install_rust_prerequisites.ps1"
    if errorlevel 1 (
        echo ERROR: Could not install or verify the Visual C++ prerequisites for Rust.
        echo ERROR: Administrator-only setup did not complete.
        exit /b 1
    )

    call "%~2utilities.bat"
    if errorlevel 1 (
        echo ERROR: Administrator-only setup did not complete.
        exit /b 1
    )

    reg.exe import "%~2processor_performance_boost_mode.reg" >nul
    if errorlevel 1 (
        echo ERROR: Could not expose the Processor performance boost mode setting.
        echo ERROR: Administrator-only setup did not complete.
        exit /b 1
    )
    echo Exposed the Processor performance boost mode setting.

    "%~3" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~2enable_hidden_power.ps1"
    if errorlevel 1 (
        echo ERROR: Administrator-only setup did not complete.
        exit /b 1
    )

    echo ===== Administrator-only setup completed =====
    exit /b 0
)

echo ERROR: Unknown prepare_new_box_helper.bat action: %~1
exit /b 2
