#Requires -Version 5.1

<#
.SYNOPSIS
Configures and smoke-tests the stable 64-bit Rust MSVC toolchain.

.DESCRIPTION
Updates the stable x86_64-pc-windows-msvc toolchain, makes it the default, and
compiles and runs a small temporary program. The compile test verifies that
rustc can find the MSVC linker and Windows SDK installed by the elevated phase.

This script is invoked by prepare_new_box.ps1 after Rustup is installed and the
native prerequisites have been verified.

.EXAMPLE
.\configure_rust.ps1

Runs from a normal PowerShell window after Rustup and the native prerequisites
have been installed.

.EXAMPLE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\configure_rust.ps1"

Runs from a normal Command Prompt after changing to this script's directory.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not [Environment]::Is64BitOperatingSystem) {
    throw 'The x64 Rust MSVC toolchain requires 64-bit Windows.'
}

$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
if (($env:Path -split ';') -notcontains $cargoBin) {
    $env:Path = "$cargoBin;$env:Path"
}

$rustup = (Get-Command rustup.exe -CommandType Application -ErrorAction Stop |
    Select-Object -First 1).Source
$toolchain = 'stable-x86_64-pc-windows-msvc'

function Invoke-Rustup {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    & $rustup @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "rustup $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

Write-Host "Installing or updating Rust toolchain: $toolchain"
# `toolchain install` is idempotent and synchronizes an existing channel, so a
# separate `rustup update` would only repeat the same network and update work.
Invoke-Rustup -Arguments @('toolchain', 'install', $toolchain, '--profile', 'default')
Invoke-Rustup -Arguments @('default', $toolchain)

$rustc = (Get-Command rustc.exe -CommandType Application -ErrorAction Stop |
    Select-Object -First 1).Source
$cargo = (Get-Command cargo.exe -CommandType Application -ErrorAction Stop |
    Select-Object -First 1).Source

$rustcDetails = & $rustc -Vv
if ($LASTEXITCODE -ne 0) {
    throw "rustc version check failed with exit code $LASTEXITCODE."
}
if ($rustcDetails -notcontains 'host: x86_64-pc-windows-msvc') {
    throw "The active Rust compiler is not the expected x86_64-pc-windows-msvc host:`n$($rustcDetails -join "`n")"
}

& $cargo --version
if ($LASTEXITCODE -ne 0) {
    throw "cargo version check failed with exit code $LASTEXITCODE."
}

$testDirectory = Join-Path ([IO.Path]::GetTempPath()) ("pcprep-rust-smoke-{0}" -f [guid]::NewGuid().ToString('N'))
try {
    $null = New-Item -ItemType Directory -Path $testDirectory
    $sourcePath = Join-Path $testDirectory 'main.rs'
    $executablePath = Join-Path $testDirectory 'pcprep-rust-smoke.exe'
    'fn main() { println!("pcprep Rust MSVC smoke test passed"); }' |
        Set-Content -LiteralPath $sourcePath -Encoding ascii

    & $rustc --edition 2021 $sourcePath -o $executablePath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
        throw "Rust MSVC compile/link test failed with exit code $LASTEXITCODE."
    }

    & $executablePath
    if ($LASTEXITCODE -ne 0) {
        throw "The compiled Rust smoke-test executable failed with exit code $LASTEXITCODE."
    }
}
finally {
    if (Test-Path -LiteralPath $testDirectory) {
        Remove-Item -LiteralPath $testDirectory -Recurse -Force
    }
}

Write-Host ($rustcDetails -join [Environment]::NewLine)
Write-Host 'Rust stable MSVC toolchain is installed and working.'
