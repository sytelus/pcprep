#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
Installs or verifies the native Windows build tools required by Rust's MSVC target.

.DESCRIPTION
Rust's x64 MSVC toolchain needs the Visual C++ compiler and linker plus Windows
SDK libraries. Any Visual Studio 2017-or-later edition is accepted when it has
the x64/x86 MSVC tools and a usable Windows 10/11 SDK.

If those prerequisites are incomplete, WinGet installs or modifies Visual
Studio Build Tools 2022 with the Desktop development with C++ workload and its
recommended components. The current Windows 11 SDK component is requested
explicitly, while verification accepts any installed SDK containing the x64
Windows API import libraries Rust needs.

This script is invoked by prepare_new_box.ps1 during its elevated phase.

.EXAMPLE
.\install_rust_prerequisites.ps1

Runs from an elevated PowerShell window.

.EXAMPLE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\install_rust_prerequisites.ps1"

Runs from an elevated Command Prompt after changing to this script's directory.

.NOTES
References:
https://rust-lang.github.io/rustup/installation/windows-msvc.html
https://learn.microsoft.com/visualstudio/install/workload-component-id-vs-build-tools
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not [Environment]::Is64BitOperatingSystem) {
    throw 'The x64 Rust MSVC prerequisites require 64-bit Windows.'
}

$packageId = 'Microsoft.VisualStudio.2022.BuildTools'
$workloadId = 'Microsoft.VisualStudio.Workload.VCTools'
$vcToolsComponent = 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
$windowsSdkComponentToInstall = 'Microsoft.VisualStudio.Component.Windows11SDK.26100'
$vsWherePath = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$windowsSdkLibraryRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\Lib'
$windowsSdkIncludeRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\Include'

function Get-LatestUsableWindowsSdk {
    if (-not (Test-Path -LiteralPath $windowsSdkLibraryRoot -PathType Container)) {
        return $null
    }

    $sdkDirectories = Get-ChildItem -LiteralPath $windowsSdkLibraryRoot -Directory
    $candidates = foreach ($directory in $sdkDirectories) {
        $version = $null
        if (-not [version]::TryParse($directory.Name, [ref]$version)) {
            continue
        }

        $kernelLibrary = Join-Path $directory.FullName 'um\x64\kernel32.lib'
        $universalRuntimeLibrary = Join-Path $directory.FullName 'ucrt\x64\ucrt.lib'
        $windowsHeader = Join-Path $windowsSdkIncludeRoot "$($directory.Name)\um\Windows.h"
        if ((Test-Path -LiteralPath $kernelLibrary -PathType Leaf) -and
            (Test-Path -LiteralPath $universalRuntimeLibrary -PathType Leaf) -and
            (Test-Path -LiteralPath $windowsHeader -PathType Leaf)) {
            [pscustomobject]@{
                Version = $version
                Path    = $directory.FullName
            }
        }
    }

    return ($candidates | Sort-Object Version -Descending | Select-Object -First 1)
}

function Get-CompatibleNativeToolchain {
    if (-not (Test-Path -LiteralPath $vsWherePath -PathType Leaf)) {
        return $null
    }

    $installationPaths = & $vsWherePath `
        -all `
        -products '*' `
        -requires $vcToolsComponent `
        -property installationPath 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "vswhere.exe failed with exit code $LASTEXITCODE."
    }

    $windowsSdk = Get-LatestUsableWindowsSdk
    if (-not $windowsSdk) {
        return $null
    }

    foreach ($installationPath in $installationPaths) {
        if ([string]::IsNullOrWhiteSpace($installationPath)) {
            continue
        }
        $installationPath = $installationPath.Trim()

        $toolRoot = Join-Path $installationPath 'VC\Tools\MSVC'
        $toolsets = foreach ($directory in Get-ChildItem -LiteralPath $toolRoot `
                -Directory -ErrorAction SilentlyContinue) {
            $version = $null
            if ([version]::TryParse($directory.Name, [ref]$version)) {
                [pscustomobject]@{
                    Directory = $directory
                    Version   = $version
                }
            }
        }
        $toolset = $toolsets |
            Sort-Object Version -Descending |
            Where-Object {
                $compilerPath = Join-Path $_.Directory.FullName `
                    'bin\Hostx64\x64\cl.exe'
                $linkerPath = Join-Path $_.Directory.FullName `
                    'bin\Hostx64\x64\link.exe'
                (Test-Path -LiteralPath $compilerPath -PathType Leaf) -and
                    (Test-Path -LiteralPath $linkerPath -PathType Leaf)
            } |
            Select-Object -First 1
        if ($toolset) {
            return [pscustomobject]@{
                VisualStudioPath  = $installationPath
                MsvcVersion       = $toolset.Version.ToString()
                WindowsSdkVersion = $windowsSdk.Version.ToString()
            }
        }
    }

    return $null
}

$nativeToolchain = Get-CompatibleNativeToolchain
if ($nativeToolchain) {
    Write-Host "Visual C++ prerequisites are already installed: $($nativeToolchain.VisualStudioPath)"
    Write-Host "MSVC tools: $($nativeToolchain.MsvcVersion); Windows SDK: $($nativeToolchain.WindowsSdkVersion)"
    return
}

$winget = (Get-Command winget.exe -CommandType Application -ErrorAction Stop |
    Select-Object -First 1).Source
$installerOverride = @(
    '--wait'
    '--passive'
    '--norestart'
    "--add $workloadId;includeRecommended"
    "--add $vcToolsComponent"
    "--add $windowsSdkComponentToInstall"
    '--addProductLang En-us'
) -join ' '

Write-Host 'Installing Visual Studio Build Tools with the C++ workload, MSVC linker, and Windows SDK...'
& $winget @(
    'install'
    '--id', $packageId
    '--exact'
    '--source', 'winget'
    '--force'
    '--accept-package-agreements'
    '--accept-source-agreements'
    '--disable-interactivity'
    '--override', $installerOverride
)
if ($LASTEXITCODE -ne 0) {
    throw "WinGet could not install the Rust MSVC prerequisites (exit code $LASTEXITCODE)."
}

$nativeToolchain = Get-CompatibleNativeToolchain
if (-not $nativeToolchain) {
    throw 'Visual Studio setup completed, but a working x64 MSVC compiler/linker and Windows SDK were not detected.'
}

Write-Host "Verified Visual C++ prerequisites: $($nativeToolchain.VisualStudioPath)"
Write-Host "MSVC tools: $($nativeToolchain.MsvcVersion); Windows SDK: $($nativeToolchain.WindowsSdkVersion)"
