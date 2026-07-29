#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
Installs and updates the selected Windows utility applications.

.DESCRIPTION
Uses WinGet for applications and Microsoft Store for Blender. WinGet's install
command is intentionally idempotent: it installs missing packages, upgrades
older packages, and leaves current packages unchanged.

Adobe and Foxit update services are disabled after installation by explicit
user preference. Those applications must therefore be updated periodically by
rerunning this script or using another trusted update mechanism.

Fira Code and Cascadia Code use Chocolatey because they are not available from
this machine's configured WinGet catalogs. If Chocolatey is unavailable, only
the fonts are skipped.

.EXAMPLE
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
.\utilities.ps1

Runs from an elevated PowerShell window after allowing local scripts for only
the current PowerShell process.

.EXAMPLE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\utilities.ps1"

Runs from an elevated Command Prompt after changing to this script's directory.

.NOTES
Run from an elevated PowerShell window or elevated Command Prompt. See README.md
for package rationale, background-process notes, and intentionally excluded
applications.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$winget = (Get-Command winget.exe -CommandType Application -ErrorAction Stop |
    Select-Object -First 1).Source

function Install-WinGetPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PackageId,

        [string] $DisplayName = $PackageId,

        [ValidateSet('winget', 'msstore')]
        [string] $Source = 'winget'
    )

    Write-Host ''
    Write-Host "Ensuring $DisplayName [$PackageId] is installed and current from $Source..."
    $arguments = @(
        'install', '--id', $PackageId,
        '--source', $Source, '--silent',
        '--accept-package-agreements', '--accept-source-agreements',
        '--disable-interactivity'
    )
    if ($Source -eq 'winget') {
        $arguments += '--exact'
    }

    & $winget @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "WinGet could not install or update $DisplayName [$PackageId] from $Source (exit code $LASTEXITCODE)."
    }
}

function Disable-OptionalUpdateService {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ServiceName,

        [Parameter(Mandatory = $true)]
        [string] $DisplayName
    )

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Host "INFO: $DisplayName [$ServiceName] is not installed; nothing to disable."
        return
    }

    Set-Service -Name $ServiceName -StartupType Disabled
    if ($service.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Stopped) {
        try {
            Stop-Service -Name $ServiceName -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "$DisplayName was disabled but could not be stopped now: $($_.Exception.Message)"
        }
    }
    Write-Host "Disabled $DisplayName [$ServiceName]."
}

# Hardware diagnostics. Avoid running multiple low-level sensor tools at once.
# HWiNFO and GPU-Z can load signed hardware-access drivers while running.
$wingetPackages = @(
    'REALiX.HWiNFO'
    'CrystalDewWorld.CrystalDiskInfo'
    'TechPowerUp.GPU-Z'
    'JAMSoftware.HeavyLoad'
    'JAMSoftware.UltraSearch'
    'Microsoft.Sysinternals.Suite'
    'dotPDN.PaintDotNet'
    'Adobe.Acrobat.Reader.64-bit'
    '7zip.7zip'
    'VideoLAN.VLC'
    'Foxit.FoxitReader'
    'GIMP.GIMP.3'
    'JernejSimoncic.Wget'
    'GoLang.Go'
    'IrfanSkiljan.IrfanView'
    'Rufus.Rufus'
    'OpenJS.NodeJS.LTS'
    'Kitware.CMake'
    'Inkscape.Inkscape'
    'PuTTY.PuTTY'
)

$updateServicesByPackage = @{
    'Adobe.Acrobat.Reader.64-bit' = [pscustomobject]@{
        ServiceName = 'AdobeARMservice'
        DisplayName = 'Adobe Acrobat Update Service'
    }
    'Foxit.FoxitReader' = [pscustomobject]@{
        ServiceName = 'FoxitReaderUpdateService'
        DisplayName = 'Foxit PDF Reader Update Service'
    }
}

foreach ($packageId in $wingetPackages) {
    Install-WinGetPackage -PackageId $packageId
    if ($updateServicesByPackage.ContainsKey($packageId)) {
        $service = $updateServicesByPackage[$packageId]
        Disable-OptionalUpdateService -ServiceName $service.ServiceName `
            -DisplayName $service.DisplayName
    }
}

# The community manifest currently receives a Cloudflare challenge from
# download.blender.org. The official Microsoft Store listing avoids that URL.
Install-WinGetPackage -PackageId '9PP3C07GTVRH' -DisplayName 'Blender' -Source 'msstore'

$chocolatey = Join-Path $env:ProgramData 'chocolatey\bin\choco.exe'
if (-not (Test-Path -LiteralPath $chocolatey -PathType Leaf)) {
    Write-Host 'INFO: Skipping Fira Code and Cascadia Code because Chocolatey could not be located.'
    return
}

Write-Host ''
Write-Host 'Ensuring Chocolatey font packages are installed and current: firacode cascadiacode'
# `choco upgrade` installs missing packages as well. Pin the public source so a
# machine-specific source with the same package names cannot be selected here.
& $chocolatey upgrade firacode cascadiacode --yes `
    --source 'https://community.chocolatey.org/api/v2'
$chocolateyExitCode = $LASTEXITCODE
if ($chocolateyExitCode -notin @(0, 2, 1641, 3010)) {
    throw "Chocolatey font installation failed with exit code $chocolateyExitCode."
}
if ($chocolateyExitCode -eq 1641) {
    Write-Host 'INFO: Chocolatey completed successfully and initiated a reboot.'
}
elseif ($chocolateyExitCode -eq 3010) {
    Write-Host 'INFO: Chocolatey completed successfully; a reboot is required.'
}
