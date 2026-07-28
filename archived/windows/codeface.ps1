#Requires -Version 5.1

<#
.SYNOPSIS
Installs selected programming fonts from the Codeface collection for all users.

.DESCRIPTION
Downloads the pinned Codeface font archive, verifies its SHA-256 hash, and
installs its .ttf and .otf files through the Windows Fonts shell namespace.
Existing files with the same name are skipped.

Codeface is a gallery of third-party programming fonts, not a Windows or
developer-tool prerequisite. Its current archive contains 237 font files and
was last updated in September 2020. Run this only if you want to compare many
fonts or explicitly select families with -Family. For normal setup, installing
one actively maintained font directly from its publisher is preferable.

The archive contains fonts under different licenses. Review the Codeface
gallery and each family's license before redistribution or commercial use:
https://github.com/chrissimpkins/codeface

Installation changes the all-users Windows font collection and requires an
elevated PowerShell session. Running applications may need to be restarted to
see newly installed fonts. This script does not uninstall fonts.

.PARAMETER Family
One or more Codeface family-directory names or wildcard patterns. The default
is '*', which selects the entire collection.

.PARAMETER ArchivePath
Uses an already-downloaded Codeface ZIP instead of downloading it. The archive
must match the pinned SHA-256 hash.

.PARAMETER ListFamilies
Lists available family-directory names without installing fonts.

.EXAMPLE
.\codeface.ps1 -ListFamilies

.EXAMPLE
.\codeface.ps1 -Family 'fira-code', 'hack' -WhatIf

.EXAMPLE
.\codeface.ps1 -Family 'fira-code', 'hack'

.EXAMPLE
.\codeface.ps1 -Confirm:$false
Installs the entire pinned collection without the high-impact confirmation.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateNotNullOrEmpty()]
    [string[]] $Family = @('*'),

    [ValidateNotNullOrEmpty()]
    [string] $ArchivePath,

    [switch] $ListFamilies
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$archiveUrl = 'https://github.com/chrissimpkins/codeface/releases/download/font-collection/codeface-fonts.zip'
$expectedSha256 = 'E411A456C6CEBB5D9B4F565205BA035E4E5DF5D03A5836C2A6D8E825CC495D61'
$fontsShellFolderId = 0x14
$shellCopyFlags = 0x14 # Silent and do not ask for overwrite confirmation.

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-FamilySelected {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FamilyName,

        [Parameter(Mandatory = $true)]
        [string[]] $Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($FamilyName -like $pattern) {
            return $true
        }
    }

    return $false
}

function Get-InstalledFontFileNames {
    $fileNames = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )

    $fontDirectories = @(
        (Join-Path $env:WINDIR 'Fonts'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts')
    )

    foreach ($directory in $fontDirectories) {
        if (Test-Path -LiteralPath $directory) {
            foreach ($file in Get-ChildItem -LiteralPath $directory -File -ErrorAction Stop) {
                [void] $fileNames.Add($file.Name)
            }
        }
    }

    return ,$fileNames
}

function Test-FontFileInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FileName
    )

    $systemPath = Join-Path (Join-Path $env:WINDIR 'Fonts') $FileName
    $userPath = Join-Path (
        Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    ) $FileName

    return (Test-Path -LiteralPath $systemPath) -or (Test-Path -LiteralPath $userPath)
}

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = [IO.Path]::GetFullPath(
    (Join-Path $tempBase ("pcprep-codeface-{0}" -f [guid]::NewGuid().ToString('N')))
)
$normalizedTempBase = $tempBase.TrimEnd('\') + '\'
if (-not $tempRoot.StartsWith($normalizedTempBase, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use unexpected temporary path '$tempRoot'."
}

$shell = $null
$fontsShellFolder = $null
$requestedWhatIf = $WhatIfPreference

try {
    # WhatIf protects the system-wide installation below. Staging still needs to
    # run so that the archive can be verified and the selected files counted.
    $WhatIfPreference = $false
    New-Item -Path $tempRoot -ItemType Directory -ErrorAction Stop -WhatIf:$false | Out-Null

    if ($PSBoundParameters.ContainsKey('ArchivePath')) {
        $resolvedArchivePath = (
            Resolve-Path -LiteralPath $ArchivePath -ErrorAction Stop
        ).Path
    }
    else {
        $resolvedArchivePath = Join-Path $tempRoot 'codeface-fonts.zip'
        Write-Verbose "Downloading $archiveUrl"
        Invoke-WebRequest -UseBasicParsing -Uri $archiveUrl -OutFile $resolvedArchivePath
    }

    $actualHash = (Get-FileHash -LiteralPath $resolvedArchivePath -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedSha256) {
        throw "Codeface archive hash mismatch. Expected $expectedSha256 but received $actualHash."
    }

    $extractPath = Join-Path $tempRoot 'archive'
    Expand-Archive `
        -LiteralPath $resolvedArchivePath `
        -DestinationPath $extractPath `
        -Force `
        -WhatIf:$false

    $fontsRoot = Join-Path $extractPath 'fonts'
    if (-not (Test-Path -LiteralPath $fontsRoot -PathType Container)) {
        throw "The verified archive does not contain the expected 'fonts' directory."
    }

    $availableFamilies = @(
        Get-ChildItem -LiteralPath $fontsRoot -Directory |
            Sort-Object Name |
            Select-Object -ExpandProperty Name
    )

    if ($ListFamilies) {
        $availableFamilies
        return
    }

    $fontFiles = @(
        foreach ($familyDirectory in Get-ChildItem -LiteralPath $fontsRoot -Directory) {
            if (Test-FamilySelected -FamilyName $familyDirectory.Name -Patterns $Family) {
                Get-ChildItem -LiteralPath $familyDirectory.FullName -Recurse -File |
                    Where-Object Extension -in '.ttf', '.otf'
            }
        }
    )

    if ($fontFiles.Count -eq 0) {
        throw "No fonts matched: $($Family -join ', '). Use -ListFamilies to see valid names."
    }

    $WhatIfPreference = $requestedWhatIf
    $operation = "Install $($fontFiles.Count) Codeface font files for all Windows users"
    $target = "Windows Fonts from Codeface families: $($Family -join ', ')"
    if (-not $PSCmdlet.ShouldProcess($target, $operation)) {
        return
    }

    if (-not (Test-IsAdministrator)) {
        throw 'Font installation requires an elevated PowerShell session.'
    }

    $shell = New-Object -ComObject Shell.Application
    $fontsShellFolder = $shell.Namespace($fontsShellFolderId)
    if ($null -eq $fontsShellFolder) {
        throw 'Windows did not provide the Fonts shell namespace.'
    }

    $installedFileNames = Get-InstalledFontFileNames
    $installedCount = 0
    $skippedCount = 0

    foreach ($font in $fontFiles) {
        if ($installedFileNames.Contains($font.Name)) {
            Write-Output "SKIP: $($font.Name) is already installed."
            $skippedCount++
            continue
        }

        Write-Output "INST: $($font.FullName)"
        $fontsShellFolder.CopyHere($font.FullName, $shellCopyFlags)

        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        while (-not (Test-FontFileInstalled -FileName $font.Name) -and
            [DateTime]::UtcNow -lt $deadline) {
            Start-Sleep -Milliseconds 100
        }

        if (-not (Test-FontFileInstalled -FileName $font.Name)) {
            throw "Windows did not confirm installation of '$($font.Name)'."
        }

        [void] $installedFileNames.Add($font.Name)
        $installedCount++
    }

    Write-Output "Codeface installation complete: $installedCount installed, $skippedCount skipped."
}
finally {
    $WhatIfPreference = $false
    if ($null -ne $fontsShellFolder) {
        [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($fontsShellFolder)
    }
    if ($null -ne $shell) {
        [void] [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
    }

    if ((Test-Path -LiteralPath $tempRoot) -and
        $tempRoot.StartsWith($normalizedTempBase, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -WhatIf:$false
    }
    $WhatIfPreference = $requestedWhatIf
}
