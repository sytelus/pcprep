<#
.SYNOPSIS
Installs or verifies the native Windows build tools required by Rust's MSVC target.

.DESCRIPTION
Rust's x64 MSVC toolchain needs the Visual C++ compiler and linker plus Windows
SDK libraries. This script accepts any existing Visual Studio edition that has
the required components. Otherwise it installs or modifies Visual Studio Build
Tools 2022 through WinGet with the Desktop development with C++ workload and its
recommended components.

This script is invoked by prepapre_new_box.bat during its elevated phase.

References:
https://rust-lang.github.io/rustup/installation/windows-msvc.html
https://learn.microsoft.com/visualstudio/install/workload-component-id-vs-build-tools
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$principal = [Security.Principal.WindowsPrincipal]::new(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Visual C++ Build Tools installation requires an elevated administrator process.'
}

$packageId = 'Microsoft.VisualStudio.2022.BuildTools'
$workloadId = 'Microsoft.VisualStudio.Workload.VCTools'
$vcToolsComponent = 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
$windowsSdkComponent = 'Microsoft.VisualStudio.Component.Windows11SDK.26100'
$vsWherePath = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'

function Get-CompatibleVisualStudioInstance {
    if (-not (Test-Path -LiteralPath $vsWherePath -PathType Leaf)) {
        return $null
    }

    $result = & $vsWherePath `
        -latest `
        -products '*' `
        -requires $vcToolsComponent $windowsSdkComponent `
        -property installationPath 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "vswhere.exe failed with exit code $LASTEXITCODE."
    }

    $match = $result | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
    if ($match) {
        return $match.Trim()
    }
    return $null
}

$compatibleInstance = Get-CompatibleVisualStudioInstance
if ($compatibleInstance) {
    Write-Host "Visual C++ compiler/linker and Windows SDK are already installed: $compatibleInstance"
    exit 0
}

$winget = (Get-Command winget.exe -ErrorAction Stop).Source
$installerOverride = @(
    '--wait'
    '--passive'
    '--norestart'
    "--add $workloadId;includeRecommended"
    "--add $vcToolsComponent"
    "--add $windowsSdkComponent"
    '--addProductLang En-us'
) -join ' '

Write-Host 'Installing Visual Studio Build Tools with the C++ workload, MSVC linker, and Windows SDK...'
$wingetArguments = @(
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
& $winget @wingetArguments
if ($LASTEXITCODE -ne 0) {
    throw "WinGet could not install the Rust MSVC prerequisites (exit code $LASTEXITCODE)."
}

$compatibleInstance = Get-CompatibleVisualStudioInstance
if (-not $compatibleInstance) {
    throw 'Visual Studio setup completed, but the required MSVC x64/x86 tools and Windows 11 SDK were not detected.'
}

Write-Host "Verified Visual C++ compiler/linker and Windows SDK: $compatibleInstance"
exit 0
