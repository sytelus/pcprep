<#
.SYNOPSIS
Configures and smoke-tests the stable 64-bit Rust MSVC toolchain.

.DESCRIPTION
Updates the stable x86_64-pc-windows-msvc toolchain, makes it the default, and
compiles and runs a small temporary program. The compile test verifies that
rustc can find the MSVC linker and Windows SDK installed by the elevated phase.

This script is invoked by prepapre_new_box.bat after Rustup is installed.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
if (($env:Path -split ';') -notcontains $cargoBin) {
    $env:Path = "$cargoBin;$env:Path"
}

$rustup = (Get-Command rustup.exe -ErrorAction Stop).Source
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
Invoke-Rustup -Arguments @('toolchain', 'install', $toolchain, '--profile', 'default')
Invoke-Rustup -Arguments @('default', $toolchain)
Invoke-Rustup -Arguments @('update', $toolchain)

$rustc = (Get-Command rustc.exe -ErrorAction Stop).Source
$cargo = (Get-Command cargo.exe -ErrorAction Stop).Source

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
exit 0
