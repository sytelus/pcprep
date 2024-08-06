@echo off
setlocal enabledelayedexpansion

:: Moves the VHDX file of a WSL distribution to a new location

:: Check for administrative privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo This script requires administrative privileges.
    echo Please run it as an administrator.
    pause
    exit /b 1
)

:: Set variables
set DISTRO_NAME=Ubuntu
set NEW_LOCATION=D:\wsl\%DISTRO_NAME%
set BACKUP_PATH=D:\temp\%DISTRO_NAME%-backup.tar

:: 1. Stop the distribution
wsl --terminate %DISTRO_NAME%
wsl --shutdown

:: 2. Create a backup
wsl --export %DISTRO_NAME% "%BACKUP_PATH%"
if %errorLevel% neq 0 (
    echo Failed to create backup. Exiting.
    pause
    exit /b 1
)

:: 3 & 4. Find the correct registry key
for /f "tokens=*" %%a in ('reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss /s /f DistributionName ^| findstr /i "%DISTRO_NAME%"') do (
    set REGKEY=%%a
)

:: 5 & 6. Get current BasePath and copy VHDX file
for /f "tokens=2*" %%a in ('reg query "!REGKEY!" /v BasePath ^| findstr /i "BasePath"') do (
    set OLDPATH=%%b
)
if not exist "%NEW_LOCATION%" mkdir "%NEW_LOCATION%"
copy "!OLDPATH!\ext4.vhdx" "%NEW_LOCATION%\"
if %errorLevel% neq 0 (
    echo Failed to copy VHDX file. Exiting.
    pause
    exit /b 1
)

:: 7. Update the registry
reg add "!REGKEY!" /v BasePath /t REG_SZ /d "%NEW_LOCATION%" /f
if %errorLevel% neq 0 (
    echo Failed to update registry. Exiting.
    pause
    exit /b 1
)

echo WSL distribution %DISTRO_NAME% has been relocated to %NEW_LOCATION%.
echo You can now start your WSL distribution.
echo If everything works correctly, you can delete the old VHDX file at !OLDPATH!\ext4.vhdx
echo and the backup file at %BACKUP_PATH%

pause
