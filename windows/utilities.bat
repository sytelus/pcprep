@echo off
setlocal

where winget.exe >nul 2>&1 || (
    echo ERROR: WinGet is required but was not found.
    exit /b 1
)

fltmc.exe >nul 2>&1 || (
    echo ERROR: Run this script from an Administrator terminal.
    exit /b 1
)

set "WINGET_ARGS=--exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity"

REM EnsureWingetPackage uses "winget install" intentionally. Without --no-upgrade,
REM WinGet installs a missing package, skips it when current, or upgrades it when older.

REM Hardware diagnostics. Avoid running multiple low-level sensor tools simultaneously.
REM DRIVER: HWiNFO loads a signed hardware-access driver while it is running; it does
REM not require a continuously running monitoring service with its default settings.
call :EnsureWingetPackage "REALiX.HWiNFO" || exit /b 1

REM TRUST: CrystalDiskInfo is an open-source MIT-licensed SMART/disk-health tool.
REM It has no persistent service by default; its optional resident mode must be enabled manually.
call :EnsureWingetPackage "CrystalDewWorld.CrystalDiskInfo" || exit /b 1

REM PORTABLE/DRIVER: GPU-Z may not appear in Windows Installed apps. It can load a
REM hardware-access driver while running, but does not run continuously by default.
call :EnsureWingetPackage "TechPowerUp.GPU-Z" || exit /b 1

REM REMOVE/SECURITY HISTORY: HWMonitor duplicates HWiNFO. CPUID's website redirected
REM HWMonitor downloads to trojanized installers during an April 2026 compromise.
REM The legitimate HWMonitor application was not itself malware.
REM call :EnsureWingetPackage "CPUID.HWMonitor"

REM CAUTION: HeavyLoad intentionally places the CPU/GPU/storage under sustained load.
REM Monitor temperatures and stop it if temperatures or system behavior become abnormal.
call :EnsureWingetPackage "JAMSoftware.HeavyLoad" || exit /b 1

REM UltraSearch reads the NTFS file table on demand and does not require an indexing service.
call :EnsureWingetPackage "JAMSoftware.UltraSearch" || exit /b 1

REM PORTABLE: The suite may not appear as one entry in Windows Installed apps.
REM Some Sysinternals tools can create drivers/services when explicitly run or configured.
call :EnsureWingetPackage "Microsoft.Sysinternals.Suite" || exit /b 1

call :EnsureWingetPackage "dotPDN.PaintDotNet" || exit /b 1

REM BACKGROUND: Adobe Reader installs AdobeARMservice for automatic updates.
REM SECURITY: Because that service is disabled below, update Reader regularly with WinGet.
call :EnsureWingetPackage "Adobe.Acrobat.Reader.64-bit" || exit /b 1
call :DisableService "AdobeARMservice" "Adobe Acrobat Update Service" || exit /b 1

call :EnsureWingetPackage "7zip.7zip" || exit /b 1
call :EnsureWingetPackage "VideoLAN.VLC" || exit /b 1

REM BACKGROUND: Foxit installs FoxitReaderUpdateService for automatic updates.
REM SECURITY: Because that service is disabled below, update Foxit regularly with WinGet.
call :EnsureWingetPackage "Foxit.FoxitReader" || exit /b 1
call :DisableService "FoxitReaderUpdateService" "Foxit PDF Reader Update Service" || exit /b 1

call :EnsureWingetPackage "GIMP.GIMP.3" || exit /b 1
call :EnsureWingetPackage "JernejSimoncic.Wget" || exit /b 1
call :EnsureWingetPackage "GoLang.Go" || exit /b 1
call :EnsureWingetPackage "IrfanSkiljan.IrfanView" || exit /b 1

REM PORTABLE: Rufus may not appear in Windows Installed apps and has no background service.
call :EnsureWingetPackage "Rufus.Rufus" || exit /b 1

call :EnsureWingetPackage "OpenJS.NodeJS.LTS" || exit /b 1
call :EnsureWingetPackage "Kitware.CMake" || exit /b 1
call :EnsureWingetPackage "Inkscape.Inkscape" || exit /b 1
call :EnsureWingetPackage "PuTTY.PuTTY" || exit /b 1
call :EnsureWingetPackage "BlenderFoundation.Blender" || exit /b 1

REM FALLBACK: Fira Code and Cascadia Code are not currently in the stable WinGet
REM application catalog. Install them with Chocolatey only when Chocolatey is available.
where choco.exe >nul 2>&1
if errorlevel 1 (
    echo INFO: Skipping Fira Code and Cascadia Code because Chocolatey is not installed.
) else (
    call :EnsureChocolateyPackages firacode cascadiacode || exit /b 1
)

REM Optional applications retained from the previous script.

REM OPTIONAL: Audacity does not normally add a persistent service.
REM call :EnsureWingetPackage "Audacity.Audacity"

REM DISABLED/BACKGROUND: TortoiseSVN runs TSVNCache.exe for Explorer status overlays.
REM call :EnsureWingetPackage "TortoiseSVN.TortoiseSVN"

REM DISABLED/BACKGROUND: Evernote can run at startup and installs updater/background components.
REM call :EnsureWingetPackage "Evernote.Evernote"

REM OPTIONAL: No persistent service, but redundant if VS Code is the primary editor.
REM call :EnsureWingetPackage "Notepad++.Notepad++"

REM OPTIONAL: FreeCAD does not normally add a persistent service.
REM call :EnsureWingetPackage "FreeCAD.FreeCAD"

REM REMOVE: ConEmu is generally redundant when Windows Terminal is already configured.
REM call :EnsureWingetPackage "Maximus5.ConEmu"

REM REMOVE: Rapid Environment Editor is redundant with Windows Settings and PowerShell.
REM call :EnsureWingetPackage "OlegDanilov.RapidEnvironmentEditor"

REM BACKGROUND/DRIVERS: VirtualBox installs kernel, USB, and network drivers plus
REM supporting processes. Enable only when VirtualBox VMs are actually required.
REM call :EnsureWingetPackage "Oracle.VirtualBox"

REM OPTIONAL: WinSCP does not normally install a persistent service.
REM call :EnsureWingetPackage "WinSCP.WinSCP"

REM REMOVE: Java 8 is a legacy runtime and should only be installed for a confirmed dependency.
REM call :EnsureWingetPackage "EclipseAdoptium.Temurin.8.JRE"

REM REMOVE: Windows already includes curl.exe; do not install a duplicate copy.
REM call :EnsureWingetPackage "cURL.cURL"

endlocal
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

:EnsureChocolateyPackages
echo.
echo Ensuring Chocolatey packages are installed and current: %*
choco upgrade --yes --install-if-not-installed %*
set "CHOCO_EXIT=%ERRORLEVEL%"
if "%CHOCO_EXIT%"=="0" exit /b 0
if "%CHOCO_EXIT%"=="2" exit /b 0
if "%CHOCO_EXIT%"=="1641" (
    echo INFO: Chocolatey completed successfully and initiated a reboot.
    exit /b 0
)
if "%CHOCO_EXIT%"=="3010" (
    echo INFO: Chocolatey completed successfully; a reboot is required.
    exit /b 0
)
echo ERROR: Chocolatey install or upgrade failed with exit code %CHOCO_EXIT%.
exit /b 1

:DisableService
sc.exe query "%~1" >nul 2>&1
if errorlevel 1 (
    echo INFO: %~2 [%~1] was not installed; nothing to disable.
    exit /b 0
)

REM Stopping an already-stopped service can return an error, so only configuration failure is fatal.
sc.exe stop "%~1" >nul 2>&1
sc.exe config "%~1" start= disabled >nul 2>&1
if errorlevel 1 (
    echo ERROR: Could not disable %~2 [%~1].
    exit /b 1
)

echo Disabled %~2 [%~1].
exit /b 0
