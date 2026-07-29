#Requires -Version 5.1

<#
.SYNOPSIS
Installs and configures the supported Windows development environment.

.DESCRIPTION
Coordinates the scripts in this directory. User-scoped work runs in the current
process; machine-scoped work runs once in an elevated child process. Package
steps are idempotent: WinGet installs missing packages, upgrades older packages,
and leaves current packages unchanged.

Run this script from a normal Command Prompt or PowerShell window. Exact
commands for both shells are shown in the examples below and by -Help.

.PARAMETER Yes
Skips the confirmation prompt. Errors still stop the setup.

.PARAMETER AdminPhase
Internal switch used by the elevated child process. Do not invoke it manually.

.PARAMETER Help
Displays usage information without performing setup.

.EXAMPLE
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
.\prepare_new_box.ps1

Runs from PowerShell after allowing local scripts for only the current
PowerShell process.

.EXAMPLE
.\prepare_new_box.ps1 -Yes

Runs from PowerShell without the confirmation prompt. The current PowerShell
process must already permit local scripts.

.EXAMPLE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\prepare_new_box.ps1"

Runs from Command Prompt after changing to this script's directory.

.EXAMPLE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\prepare_new_box.ps1" -Yes

Runs from Command Prompt without the confirmation prompt.
#>

[CmdletBinding()]
param(
    [switch] $Yes,
    [switch] $AdminPhase,
    [switch] $Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDirectory = $PSScriptRoot
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$winget = $null
$currentStep = 'initialization'

function Show-Usage {
    Write-Host 'PowerShell (from this script directory):'
    Write-Host '  Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned'
    Write-Host '  .\prepare_new_box.ps1 [-Yes | -Help]'
    Write-Host ''
    Write-Host 'Command Prompt:'
    Write-Host ('  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "{0}" [-Yes | -Help]' -f $PSCommandPath)
    Write-Host ''
    Write-Host '  -Yes     Run without the confirmation prompt.'
    Write-Host '           Git identity can still prompt unless user_name and user_email are set.'
    Write-Host '  -Help    Show this help without starting setup.'
}

function Test-IsAdministrator {
    $principal = [Security.Principal.WindowsPrincipal]::new(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Add-ProcessPathEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Directory
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        return
    }

    $normalizedDirectory = $Directory.TrimEnd('\')
    $alreadyPresent = @($env:Path -split ';') | Where-Object {
        [string]::Equals($_.TrimEnd('\'), $normalizedDirectory,
            [StringComparison]::OrdinalIgnoreCase)
    }
    if (-not $alreadyPresent) {
        $env:Path = "$normalizedDirectory;$env:Path"
    }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [Parameter(Mandatory = $true)]
        [string[]] $ArgumentList,

        [Parameter(Mandatory = $true)]
        [string] $Description
    )

    & $FilePath @ArgumentList
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "$Description failed with exit code $exitCode."
    }
}

function Invoke-BatchScript {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [Parameter(Mandatory = $true)]
        [string] $Description
    )

    # /d prevents unrelated Command Processor AutoRun entries from affecting a
    # deterministic setup step. CALL ensures the batch exit code is returned.
    $commandLine = 'call "{0}"' -f $FilePath
    Invoke-NativeCommand -FilePath $env:ComSpec `
        -ArgumentList @('/d', '/c', $commandLine) `
        -Description $Description
}

function Install-WinGetPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PackageId
    )

    Write-Host ''
    Write-Host "Ensuring $PackageId is installed and current..."
    Invoke-NativeCommand -FilePath $winget `
        -ArgumentList @(
            'install', '--id', $PackageId,
            '--exact', '--source', 'winget', '--silent',
            '--accept-package-agreements', '--accept-source-agreements',
            '--disable-interactivity'
        ) `
        -Description "Installing or updating $PackageId"
}

function Install-WinGetCliOrPreserveExisting {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PackageId,

        [Parameter(Mandatory = $true)]
        [string] $CommandName,

        [Parameter(Mandatory = $true)]
        [string] $DisplayName
    )

    & $winget list --id $PackageId --exact --source winget `
        --accept-source-agreements --disable-interactivity *> $null
    if ($LASTEXITCODE -eq 0) {
        Install-WinGetPackage -PackageId $PackageId
        return
    }

    $existingCommand = Get-Command $CommandName -CommandType Application `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($existingCommand) {
        Write-Host ''
        Write-Host "$DisplayName is already available outside WinGet; preserving it to avoid a duplicate installation."
        Write-Host "Command: $($existingCommand.Source)"
        Invoke-NativeCommand -FilePath $existingCommand.Source `
            -ArgumentList @('--version') `
            -Description "$DisplayName version check"
        return
    }

    Install-WinGetPackage -PackageId $PackageId
}

function Assert-CommandAvailable {
    param(
        [Parameter(Mandatory = $true)]
        [string] $CommandName,

        [Parameter(Mandatory = $true)]
        [string] $DisplayName
    )

    $command = Get-Command $CommandName -CommandType Application `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $command) {
        throw "$DisplayName was installed, but $CommandName could not be located in the current process."
    }
    return $command
}

function Invoke-AdministratorPhase {
    if (-not (Test-IsAdministrator)) {
        throw 'The administrator-only phase is not elevated.'
    }

    Write-Host ''
    Write-Host '===== Administrator-only setup ====='

    $chocolatey = Join-Path $env:ProgramData 'chocolatey\bin\choco.exe'
    if (-not (Test-Path -LiteralPath $chocolatey -PathType Leaf)) {
        Install-WinGetPackage -PackageId 'Chocolatey.Chocolatey'
    }
    Add-ProcessPathEntry -Directory (Split-Path -Parent $chocolatey)
    if (-not (Test-Path -LiteralPath $chocolatey -PathType Leaf)) {
        throw "Chocolatey was installed, but its executable was not found: $chocolatey"
    }
    Invoke-NativeCommand -FilePath $chocolatey -ArgumentList @('--version') `
        -Description 'Chocolatey version check'

    & (Join-Path $scriptDirectory 'install_rust_prerequisites.ps1')
    & (Join-Path $scriptDirectory 'utilities.ps1')
    & (Join-Path $scriptDirectory 'enable_hidden_power.ps1')

    Write-Host '===== Administrator-only setup completed ====='
}

try {
    if ($Help) {
        Show-Usage
        exit 0
    }

    if (-not [Environment]::Is64BitOperatingSystem) {
        throw 'This setup supports only 64-bit Windows.'
    }
    if (-not (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf)) {
        throw "Windows PowerShell was not found: $windowsPowerShell"
    }

    $wingetCommand = Get-Command winget.exe -CommandType Application `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $wingetCommand) {
        throw 'WinGet is required. Install or update Microsoft App Installer first.'
    }
    $winget = $wingetCommand.Source

    $requiredFiles = @(
        'utilities.ps1'
        'enable_hidden_power.ps1'
        'install_rust_prerequisites.ps1'
    )
    if (-not $AdminPhase) {
        $requiredFiles += @(
            'aliases.reg.bat'
            'aliases.doskey'
            'gitconfig.bat'
            'hide_gallery.bat'
            'configure_rust.ps1'
            'install_miniconda.ps1'
            'install_pip_packages.ps1'
        )
    }
    foreach ($fileName in $requiredFiles) {
        $requiredPath = Join-Path $scriptDirectory $fileName
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "Required file is missing: $requiredPath"
        }
    }

    if ($AdminPhase) {
        $currentStep = 'running administrator-only setup'
        Invoke-AdministratorPhase
        exit 0
    }

    Write-Host ''
    Write-Host 'This script will:'
    Write-Host '  - Install or update Git, GitHub CLI, and Visual Studio Code with WinGet.'
    Write-Host '  - Install Codex CLI and Claude Code with WinGet when no working copy exists.'
    Write-Host '  - Install Visual C++ Build Tools, the MSVC linker, and a Windows SDK for Rust.'
    Write-Host '  - Install or update Rustup and the stable x64 MSVC Rust toolchain.'
    Write-Host '  - Install or update the applications listed in utilities.ps1.'
    Write-Host '  - Configure aliases, Git, File Explorer, Miniconda, Python packages, and power-setting visibility.'
    Write-Host ''
    Write-Host 'Machine-scoped work requests administrator access once.'
    Write-Host 'Individual package installers may show their own confirmation.'
    Write-Host 'Dell services are intentionally left unchanged because Alienware and Dell features depend on them.'
    Write-Host ''
    Write-Host 'Manual or optional installs include Dropbox, the Visual Studio IDE, Teams, OneNote, Beyond Compare,'
    Write-Host 'GitHub Desktop, Camtasia, and ThrottleStop.'

    if (-not $Yes) {
        $response = Read-Host 'Continue? [y/N]'
        if ($response -notmatch '^(?i:y|yes)$') {
            Write-Host 'Setup cancelled; no setup steps were started.'
            exit 0
        }
    }

    $currentStep = 'installing or updating Git'
    Install-WinGetPackage -PackageId 'Git.Git'

    $currentStep = 'installing or updating Visual Studio Code'
    Install-WinGetPackage -PackageId 'Microsoft.VisualStudioCode'

    $currentStep = 'installing or updating GitHub CLI'
    Install-WinGetCliOrPreserveExisting -PackageId 'GitHub.cli' `
        -CommandName 'gh.exe' -DisplayName 'GitHub CLI'

    $currentStep = 'installing or updating Codex CLI'
    Install-WinGetCliOrPreserveExisting -PackageId 'OpenAI.Codex' `
        -CommandName 'codex.exe' -DisplayName 'Codex CLI'

    $currentStep = 'installing or updating Claude Code'
    Install-WinGetCliOrPreserveExisting -PackageId 'Anthropic.ClaudeCode' `
        -CommandName 'claude.exe' -DisplayName 'Claude Code'

    $currentStep = 'refreshing tool paths after WinGet setup'
    Add-ProcessPathEntry -Directory (Join-Path $env:ProgramFiles 'Git\cmd')
    Add-ProcessPathEntry -Directory (Join-Path $env:ProgramFiles 'Microsoft VS Code\bin')
    Add-ProcessPathEntry -Directory (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin')
    Add-ProcessPathEntry -Directory (Join-Path $env:ProgramFiles 'GitHub CLI')

    $git = Assert-CommandAvailable -CommandName 'git.exe' -DisplayName 'Git'
    $gh = Assert-CommandAvailable -CommandName 'gh.exe' -DisplayName 'GitHub CLI'
    Invoke-NativeCommand -FilePath $git.Source -ArgumentList @('--version') `
        -Description 'Git version check'
    Invoke-NativeCommand -FilePath $gh.Source -ArgumentList @('--version') `
        -Description 'GitHub CLI version check'

    $currentStep = 'running administrator-only setup'
    if (Test-IsAdministrator) {
        Write-Warning (
            'The full setup is elevated. User-scoped tools will be configured for the current account.'
        )
        Invoke-AdministratorPhase
    }
    else {
        $elevatedArguments = (
            '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "{0}" -AdminPhase' -f
                $PSCommandPath
        )
        $elevatedProcess = Start-Process -FilePath $windowsPowerShell `
            -ArgumentList $elevatedArguments `
            -WorkingDirectory $scriptDirectory `
            -Verb RunAs -Wait -PassThru
        if ($elevatedProcess.ExitCode -ne 0) {
            throw "Administrator-only setup failed with exit code $($elevatedProcess.ExitCode)."
        }
    }

    # Rustup runs after the elevated phase so its unattended setup sees the
    # compiler, linker, and Windows SDK prerequisites already installed.
    $currentStep = 'installing or updating Rustup'
    Install-WinGetPackage -PackageId 'Rustlang.Rustup'
    Add-ProcessPathEntry -Directory (Join-Path $env:USERPROFILE '.cargo\bin')
    $null = Assert-CommandAvailable -CommandName 'rustup.exe' -DisplayName 'Rustup'

    $currentStep = 'configuring and verifying the stable Rust MSVC toolchain'
    & (Join-Path $scriptDirectory 'configure_rust.ps1')

    $currentStep = 'configuring Command Prompt aliases'
    Invoke-BatchScript -FilePath (Join-Path $scriptDirectory 'aliases.reg.bat') `
        -Description 'Configuring Command Prompt aliases'

    $currentStep = 'configuring Git'
    Invoke-BatchScript -FilePath (Join-Path $scriptDirectory 'gitconfig.bat') `
        -Description 'Configuring Git'

    $currentStep = 'hiding File Explorer Gallery'
    Invoke-BatchScript -FilePath (Join-Path $scriptDirectory 'hide_gallery.bat') `
        -Description 'Hiding File Explorer Gallery'

    $currentStep = 'installing or updating Miniconda'
    & (Join-Path $scriptDirectory 'install_miniconda.ps1')

    $currentStep = 'installing or updating Python packages'
    & (Join-Path $scriptDirectory 'install_pip_packages.ps1')

    Write-Host ''
    Write-Host 'Windows setup completed successfully.'
    Write-Host 'Close all terminal windows and open a new one so PATH and Conda profile changes take effect.'
    exit 0
}
catch {
    [Console]::Error.WriteLine('')
    [Console]::Error.WriteLine("ERROR: Setup stopped while $currentStep.")
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
