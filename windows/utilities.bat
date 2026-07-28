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

REM Hardware diagnostics. Avoid running multiple low-level sensor tools simultaneously.
REM DRIVER: HWiNFO loads a signed hardware-access driver while it is running; it does
REM not require a continuously running monitoring service with its default settings.
winget install --id REALiX.HWiNFO %WINGET_ARGS% || exit /b 1

REM TRUST: CrystalDiskInfo is an open-source MIT-licensed SMART/disk-health tool.
REM It has no persistent service by default; its optional resident mode must be enabled manually.
winget install --id CrystalDewWorld.CrystalDiskInfo %WINGET_ARGS% || exit /b 1

REM PORTABLE/DRIVER: GPU-Z may not appear in Windows Installed apps. It can load a
REM hardware-access driver while running, but does not run continuously by default.
winget install --id TechPowerUp.GPU-Z %WINGET_ARGS% || exit /b 1

REM REMOVE/SECURITY HISTORY: HWMonitor duplicates HWiNFO. CPUID's website redirected
REM HWMonitor downloads to trojanized installers during an April 2026 compromise.
REM The legitimate HWMonitor application was not itself malware.
REM winget install --id CPUID.HWMonitor %WINGET_ARGS%

REM CAUTION: HeavyLoad intentionally places the CPU/GPU/storage under sustained load.
REM Monitor temperatures and stop it if temperatures or system behavior become abnormal.
winget install --id JAMSoftware.HeavyLoad %WINGET_ARGS% || exit /b 1

REM UltraSearch reads the NTFS file table on demand and does not require an indexing service.
winget install --id JAMSoftware.UltraSearch %WINGET_ARGS% || exit /b 1

REM PORTABLE: The suite may not appear as one entry in Windows Installed apps.
REM Some Sysinternals tools can create drivers/services when explicitly run or configured.
winget install --id Microsoft.Sysinternals.Suite %WINGET_ARGS% || exit /b 1

winget install --id dotPDN.PaintDotNet %WINGET_ARGS% || exit /b 1

REM BACKGROUND: Adobe Reader installs AdobeARMservice for automatic updates.
REM SECURITY: Because that service is disabled below, update Reader regularly with WinGet.
winget install --id Adobe.Acrobat.Reader.64-bit %WINGET_ARGS% || exit /b 1
call :DisableService "AdobeARMservice" "Adobe Acrobat Update Service" || exit /b 1

winget install --id 7zip.7zip %WINGET_ARGS% || exit /b 1
winget install --id VideoLAN.VLC %WINGET_ARGS% || exit /b 1

REM BACKGROUND: Foxit installs FoxitReaderUpdateService for automatic updates.
REM SECURITY: Because that service is disabled below, update Foxit regularly with WinGet.
winget install --id Foxit.FoxitReader %WINGET_ARGS% || exit /b 1
call :DisableService "FoxitReaderUpdateService" "Foxit PDF Reader Update Service" || exit /b 1

winget install --id GIMP.GIMP.3 %WINGET_ARGS% || exit /b 1
winget install --id JernejSimoncic.Wget %WINGET_ARGS% || exit /b 1
winget install --id GoLang.Go %WINGET_ARGS% || exit /b 1
winget install --id IrfanSkiljan.IrfanView %WINGET_ARGS% || exit /b 1

REM PORTABLE: Rufus may not appear in Windows Installed apps and has no background service.
winget install --id Rufus.Rufus %WINGET_ARGS% || exit /b 1

winget install --id OpenJS.NodeJS.LTS %WINGET_ARGS% || exit /b 1
winget install --id Kitware.CMake %WINGET_ARGS% || exit /b 1
winget install --id Inkscape.Inkscape %WINGET_ARGS% || exit /b 1
winget install --id PuTTY.PuTTY %WINGET_ARGS% || exit /b 1
winget install --id BlenderFoundation.Blender %WINGET_ARGS% || exit /b 1

REM FALLBACK: Fira Code and Cascadia Code are not currently in the stable WinGet
REM application catalog. Install them with Chocolatey only when Chocolatey is available.
where choco.exe >nul 2>&1
if errorlevel 1 (
    echo INFO: Skipping Fira Code and Cascadia Code because Chocolatey is not installed.
) else (
    choco install -y firacode cascadiacode || exit /b 1
)

REM Optional applications retained from the previous script.

REM OPTIONAL: Audacity does not normally add a persistent service.
REM winget install --id Audacity.Audacity %WINGET_ARGS%

REM DISABLED/BACKGROUND: TortoiseSVN runs TSVNCache.exe for Explorer status overlays.
REM winget install --id TortoiseSVN.TortoiseSVN %WINGET_ARGS%

REM DISABLED/BACKGROUND: Evernote can run at startup and installs updater/background components.
REM winget install --id Evernote.Evernote %WINGET_ARGS%

REM OPTIONAL: No persistent service, but redundant if VS Code is the primary editor.
REM winget install --id Notepad++.Notepad++ %WINGET_ARGS%

REM OPTIONAL: FreeCAD does not normally add a persistent service.
REM winget install --id FreeCAD.FreeCAD %WINGET_ARGS%

REM REMOVE: ConEmu is generally redundant when Windows Terminal is already configured.
REM winget install --id Maximus5.ConEmu %WINGET_ARGS%

REM REMOVE: Rapid Environment Editor is redundant with Windows Settings and PowerShell.
REM winget install --id OlegDanilov.RapidEnvironmentEditor %WINGET_ARGS%

REM BACKGROUND/DRIVERS: VirtualBox installs kernel, USB, and network drivers plus
REM supporting processes. Enable only when VirtualBox VMs are actually required.
REM winget install --id Oracle.VirtualBox %WINGET_ARGS%

REM OPTIONAL: WinSCP does not normally install a persistent service.
REM winget install --id WinSCP.WinSCP %WINGET_ARGS%

REM REMOVE: Java 8 is a legacy runtime and should only be installed for a confirmed dependency.
REM winget install --id EclipseAdoptium.Temurin.8.JRE %WINGET_ARGS%

REM REMOVE: Windows already includes curl.exe; do not install a duplicate copy.
REM winget install --id cURL.cURL %WINGET_ARGS%

endlocal
exit /b 0

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
