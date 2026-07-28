#Requires -Version 5.1

<#
.SYNOPSIS
Installs and configures the latest Miniconda for the current Windows user.

.DESCRIPTION
Downloads the official 64-bit Miniconda installer, verifies its Authenticode
signature, and installs it silently in %USERPROFILE%\miniconda3. Administrator
rights are not required.

The script adds only Miniconda's "condabin" directory to the user PATH. This
makes the conda command available without exposing every program in the base
environment on PATH. It also initializes the Windows PowerShell and PowerShell
profiles so "conda activate" works in newly opened PowerShell windows.

The Anaconda Terms of Service are accepted for the main, r, and msys2 default
channels. Running this script records that acceptance for the current user;
review https://www.anaconda.com/legal before running it.

If Miniconda already exists at the destination, the script preserves it,
updates conda and its TOS plugin, and reapplies the configuration.

.EXAMPLE
cd D:\GitHubSrc\pcprep\windows
.\install_miniconda.ps1

If PowerShell blocks local scripts, first run:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned

.NOTES
Run from a normal PowerShell window, not an administrator window. Open a new
terminal after completion so it receives the updated PATH and profile setup.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$installerUri = 'https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe'
$installDirectory = Join-Path $env:USERPROFILE 'miniconda3'
$condaExecutable = Join-Path $installDirectory 'Scripts\conda.exe'
$condabinDirectory = Join-Path $installDirectory 'condabin'
$tosChannels = @(
    'https://repo.anaconda.com/pkgs/main',
    'https://repo.anaconda.com/pkgs/r',
    'https://repo.anaconda.com/pkgs/msys2'
)

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)]
        [string] $FilePath,

        [Parameter(Mandatory)]
        [string[]] $ArgumentList,

        [Parameter(Mandatory)]
        [string] $Description
    )

    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

function Add-UserPathEntry {
    param(
        [Parameter(Mandatory)]
        [string] $Directory
    )

    $cleanDirectory = $Directory.Trim().TrimEnd('\')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $userEntries = @(
        ([string]$userPath -split ';') |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }
    )

    $alreadyInUserPath = $false
    foreach ($entry in $userEntries) {
        if ([string]::Equals($entry.TrimEnd('\'), $cleanDirectory,
                [StringComparison]::OrdinalIgnoreCase)) {
            $alreadyInUserPath = $true
            break
        }
    }

    if (-not $alreadyInUserPath) {
        $newUserPath = ((@($cleanDirectory) + $userEntries) -join ';')
        [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
        Write-Host "Added to the user PATH: $cleanDirectory"
    }
    else {
        Write-Host "Already present in the user PATH: $cleanDirectory"
    }

    $processEntries = @($env:Path -split ';')
    $alreadyInProcessPath = $processEntries | Where-Object {
        [string]::Equals($_.TrimEnd('\'), $cleanDirectory,
            [StringComparison]::OrdinalIgnoreCase)
    }
    if (-not $alreadyInProcessPath) {
        $env:Path = "$cleanDirectory;$env:Path"
    }
}

function Ensure-TosPlugin {
    & $condaExecutable tos --help *> $null
    if ($LASTEXITCODE -eq 0) {
        return
    }

    Write-Host 'Installing the Anaconda Terms of Service plugin...'
    Invoke-NativeCommand -FilePath $condaExecutable `
        -ArgumentList @('install', '--name', 'base', '--yes', 'conda-anaconda-tos') `
        -Description 'Installing conda-anaconda-tos'
}

function Accept-AnacondaTerms {
    foreach ($channel in $tosChannels) {
        Write-Host "Accepting Anaconda Terms of Service for $channel..."
        Invoke-NativeCommand -FilePath $condaExecutable `
            -ArgumentList @('tos', 'accept', '--override-channels', '--channel', $channel) `
            -Description "Accepting the Terms of Service for $channel"
    }
}

$existingInstallation = Test-Path -LiteralPath $condaExecutable -PathType Leaf

if (-not $existingInstallation) {
    if (Test-Path -LiteralPath $installDirectory) {
        throw "The destination exists but is not a working Miniconda installation: $installDirectory"
    }

    $installerPath = Join-Path ([IO.Path]::GetTempPath()) `
        "Miniconda3-latest-$([guid]::NewGuid().ToString('N')).exe"

    try {
        # Windows PowerShell 5.1 can otherwise negotiate an obsolete TLS version.
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        Write-Host "Downloading the latest Miniconda installer from $installerUri..."
        Invoke-WebRequest -Uri $installerUri -OutFile $installerPath -UseBasicParsing

        $signature = Get-AuthenticodeSignature -LiteralPath $installerPath
        $signerName = if ($signature.SignerCertificate) {
            $signature.SignerCertificate.Subject
        }
        else {
            ''
        }

        if (($signature.Status -ne 'Valid') -or ($signerName -notmatch '(?i)Anaconda')) {
            throw "The downloaded installer does not have a valid Anaconda signature. Status: $($signature.Status); signer: $signerName"
        }

        Write-Host "Installing Miniconda for the current user in $installDirectory..."
        # /D must be the final installer argument.
        Invoke-NativeCommand -FilePath $installerPath `
            -ArgumentList @(
                '/InstallationType=JustMe',
                '/RegisterPython=0',
                '/S',
                "/D=$installDirectory"
            ) `
            -Description 'Installing Miniconda'
    }
    finally {
        if ($installerPath -and (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
            Remove-Item -LiteralPath $installerPath -Force
        }
    }
}
else {
    Write-Host "Miniconda is already installed in $installDirectory; preserving existing environments."
}

if (-not (Test-Path -LiteralPath $condaExecutable -PathType Leaf)) {
    throw "Miniconda installation did not create $condaExecutable."
}

Add-UserPathEntry -Directory $condabinDirectory
Ensure-TosPlugin
Accept-AnacondaTerms

if ($existingInstallation) {
    Write-Host 'Updating conda and its Terms of Service plugin in the base environment...'
    Invoke-NativeCommand -FilePath $condaExecutable `
        -ArgumentList @(
            'update', '--name', 'base', '--yes',
            'conda', 'conda-anaconda-tos'
        ) `
        -Description 'Updating conda'

    # Recheck after updating in case the currently published terms changed.
    Accept-AnacondaTerms
}

Write-Host 'Initializing conda for Windows PowerShell and PowerShell...'
Invoke-NativeCommand -FilePath $condaExecutable `
    -ArgumentList @('init', 'powershell') `
    -Description 'Initializing conda for PowerShell'

$condaVersion = (& $condaExecutable --version | Select-Object -Last 1).Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'The installed conda executable did not pass its version check.'
}

$reportedBase = (& $condaExecutable info --base | Select-Object -Last 1).Trim()
if (($LASTEXITCODE -ne 0) -or
    (-not [string]::Equals($reportedBase.TrimEnd('\'), $installDirectory.TrimEnd('\'),
        [StringComparison]::OrdinalIgnoreCase))) {
    throw "Conda reported an unexpected base directory: $reportedBase"
}

Write-Host ''
Write-Host "Miniconda setup completed successfully: $condaVersion"
Write-Host "Install directory: $reportedBase"
Write-Host 'Open a new PowerShell window, then verify with: conda --version'
