@echo off
setlocal

set "HELPER=%~dp0utilities_helper.bat"
if not exist "%HELPER%" (
    echo ERROR: Required helper script was not found: %HELPER%
    exit /b 1
)

where winget.exe >nul 2>&1 || (
    echo ERROR: WinGet is required but was not found.
    exit /b 1
)

fltmc.exe >nul 2>&1 || (
    echo ERROR: Run this script from an Administrator terminal.
    exit /b 1
)

REM The helper uses "winget install" intentionally. Without --no-upgrade,
REM WinGet installs a missing package, skips it when current, or upgrades it when older.

REM Hardware diagnostics. Avoid running multiple low-level sensor tools simultaneously.
REM DRIVER: HWiNFO loads a signed hardware-access driver while it is running; it does
REM not require a continuously running monitoring service with its default settings.
call "%HELPER%" winget "REALiX.HWiNFO" || exit /b 1

REM TRUST: CrystalDiskInfo is an open-source MIT-licensed SMART/disk-health tool.
REM It has no persistent service by default; its optional resident mode must be enabled manually.
call "%HELPER%" winget "CrystalDewWorld.CrystalDiskInfo" || exit /b 1

REM PORTABLE/DRIVER: GPU-Z may not appear in Windows Installed apps. It can load a
REM hardware-access driver while running, but does not run continuously by default.
call "%HELPER%" winget "TechPowerUp.GPU-Z" || exit /b 1

REM REMOVE/SECURITY HISTORY: HWMonitor duplicates HWiNFO. CPUID's website redirected
REM HWMonitor downloads to trojanized installers during an April 2026 compromise.
REM The legitimate HWMonitor application was not itself malware.
REM call "%HELPER%" winget "CPUID.HWMonitor"

REM CAUTION: HeavyLoad intentionally places the CPU/GPU/storage under sustained load.
REM Monitor temperatures and stop it if temperatures or system behavior become abnormal.
call "%HELPER%" winget "JAMSoftware.HeavyLoad" || exit /b 1

REM UltraSearch reads the NTFS file table on demand and does not require an indexing service.
call "%HELPER%" winget "JAMSoftware.UltraSearch" || exit /b 1

REM PORTABLE: The suite may not appear as one entry in Windows Installed apps.
REM Some Sysinternals tools can create drivers/services when explicitly run or configured.
call "%HELPER%" winget "Microsoft.Sysinternals.Suite" || exit /b 1

call "%HELPER%" winget "dotPDN.PaintDotNet" || exit /b 1

REM BACKGROUND: Adobe Reader installs AdobeARMservice for automatic updates.
REM SECURITY: Because that service is disabled below, update Reader regularly with WinGet.
call "%HELPER%" winget "Adobe.Acrobat.Reader.64-bit" || exit /b 1
call "%HELPER%" disable-service "AdobeARMservice" "Adobe Acrobat Update Service" || exit /b 1

call "%HELPER%" winget "7zip.7zip" || exit /b 1
call "%HELPER%" winget "VideoLAN.VLC" || exit /b 1

REM BACKGROUND: Foxit installs FoxitReaderUpdateService for automatic updates.
REM SECURITY: Because that service is disabled below, update Foxit regularly with WinGet.
call "%HELPER%" winget "Foxit.FoxitReader" || exit /b 1
call "%HELPER%" disable-service "FoxitReaderUpdateService" "Foxit PDF Reader Update Service" || exit /b 1

call "%HELPER%" winget "GIMP.GIMP.3" || exit /b 1
call "%HELPER%" winget "JernejSimoncic.Wget" || exit /b 1
call "%HELPER%" winget "GoLang.Go" || exit /b 1
call "%HELPER%" winget "IrfanSkiljan.IrfanView" || exit /b 1

REM PORTABLE: Rufus may not appear in Windows Installed apps and has no background service.
call "%HELPER%" winget "Rufus.Rufus" || exit /b 1

call "%HELPER%" winget "OpenJS.NodeJS.LTS" || exit /b 1
call "%HELPER%" winget "Kitware.CMake" || exit /b 1
call "%HELPER%" winget "Inkscape.Inkscape" || exit /b 1
call "%HELPER%" winget "PuTTY.PuTTY" || exit /b 1
REM The community package currently receives a Cloudflare challenge from
REM download.blender.org. The official Microsoft Store listing avoids that URL.
call "%HELPER%" winget-store "9PP3C07GTVRH" "Blender" || exit /b 1

REM FALLBACK: Fira Code and Cascadia Code are not currently in the stable WinGet
REM application catalog. Install them with Chocolatey only when Chocolatey is available.
if exist "%ProgramData%\chocolatey\bin\choco.exe" set "PATH=%ProgramData%\chocolatey\bin;%PATH%"
where choco.exe >nul 2>&1
if errorlevel 1 (
    echo INFO: Skipping Fira Code and Cascadia Code because Chocolatey could not be located.
) else (
    call "%HELPER%" chocolatey firacode cascadiacode || exit /b 1
)

REM Optional applications retained from the previous script.

REM OPTIONAL: Audacity does not normally add a persistent service.
REM call "%HELPER%" winget "Audacity.Audacity"

REM DISABLED/BACKGROUND: TortoiseSVN runs TSVNCache.exe for Explorer status overlays.
REM call "%HELPER%" winget "TortoiseSVN.TortoiseSVN"

REM DISABLED/BACKGROUND: Evernote can run at startup and installs updater/background components.
REM call "%HELPER%" winget "Evernote.Evernote"

REM OPTIONAL: No persistent service, but redundant if VS Code is the primary editor.
REM call "%HELPER%" winget "Notepad++.Notepad++"

REM OPTIONAL: FreeCAD does not normally add a persistent service.
REM call "%HELPER%" winget "FreeCAD.FreeCAD"

REM REMOVE: ConEmu is generally redundant when Windows Terminal is already configured.
REM call "%HELPER%" winget "Maximus5.ConEmu"

REM REMOVE: Rapid Environment Editor is redundant with Windows Settings and PowerShell.
REM call "%HELPER%" winget "OlegDanilov.RapidEnvironmentEditor"

REM BACKGROUND/DRIVERS: VirtualBox installs kernel, USB, and network drivers plus
REM supporting processes. Enable only when VirtualBox VMs are actually required.
REM call "%HELPER%" winget "Oracle.VirtualBox"

REM OPTIONAL: WinSCP does not normally install a persistent service.
REM call "%HELPER%" winget "WinSCP.WinSCP"

REM REMOVE: Java 8 is a legacy runtime and should only be installed for a confirmed dependency.
REM call "%HELPER%" winget "EclipseAdoptium.Temurin.8.JRE"

REM REMOVE: Windows already includes curl.exe; do not install a duplicate copy.
REM call "%HELPER%" winget "cURL.cURL"

endlocal
exit /b 0
