@echo off
setlocal EnableExtensions EnableDelayedExpansion

if /i "%~1"=="winget" (
    if "%~2"=="" (
        echo ERROR: utilities_helper.bat winget requires a package ID.
        exit /b 2
    )

    echo.
    echo Ensuring %~2 is installed and current...
    winget install --id "%~2" --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if errorlevel 1 (
        echo ERROR: WinGet could not install or update %~2.
        exit /b 1
    )
    exit /b 0
)

if /i "%~1"=="winget-store" (
    if "%~2"=="" (
        echo ERROR: utilities_helper.bat winget-store requires a Store product ID.
        exit /b 2
    )

    echo.
    echo Ensuring %~3 [%~2] is installed and current from Microsoft Store...
    winget install --id "%~2" --source msstore --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if errorlevel 1 (
        echo ERROR: WinGet could not install or update %~3 [%~2] from Microsoft Store.
        exit /b 1
    )
    exit /b 0
)

if /i "%~1"=="chocolatey" (
    if "%~2"=="" (
        echo ERROR: utilities_helper.bat chocolatey requires two package names.
        exit /b 2
    )
    if "%~3"=="" (
        echo ERROR: utilities_helper.bat chocolatey requires two package names.
        exit /b 2
    )

    echo.
    echo Ensuring Chocolatey packages are installed and current: %~2 %~3
    choco upgrade --yes --install-if-not-installed "%~2" "%~3"
    set "CHOCO_EXIT=!ERRORLEVEL!"
    if "!CHOCO_EXIT!"=="0" exit /b 0
    if "!CHOCO_EXIT!"=="2" exit /b 0
    if "!CHOCO_EXIT!"=="1641" (
        echo INFO: Chocolatey completed successfully and initiated a reboot.
        exit /b 0
    )
    if "!CHOCO_EXIT!"=="3010" (
        echo INFO: Chocolatey completed successfully; a reboot is required.
        exit /b 0
    )
    echo ERROR: Chocolatey install or upgrade failed with exit code !CHOCO_EXIT!.
    exit /b 1
)

if /i "%~1"=="disable-service" (
    if "%~2"=="" (
        echo ERROR: utilities_helper.bat disable-service requires a service name.
        exit /b 2
    )

    sc.exe query "%~2" >nul 2>&1
    if errorlevel 1 (
        echo INFO: %~3 [%~2] was not installed; nothing to disable.
        exit /b 0
    )

    REM Stopping an already-stopped service can return an error, so only configuration failure is fatal.
    sc.exe stop "%~2" >nul 2>&1
    sc.exe config "%~2" start= disabled >nul 2>&1
    if errorlevel 1 (
        echo ERROR: Could not disable %~3 [%~2].
        exit /b 1
    )

    echo Disabled %~3 [%~2].
    exit /b 0
)

echo ERROR: Unknown utilities helper action: %~1
exit /b 2
