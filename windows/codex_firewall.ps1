<#
.SYNOPSIS
Audits or manages narrowly scoped Windows Firewall rules for Codex CLI login.

.DESCRIPTION
The normal `codex login` browser flow starts a temporary HTTP callback listener
on localhost port 1455. This script can create per-executable inbound rules for
that callback, restricted to IPv4 and IPv6 loopback addresses.

The default mode is Audit and does not change Windows Firewall. Use Apply only
when `codex login` reaches the browser but cannot return to the CLI, and after
confirming that local firewall policy is the cause. OpenAI recommends
`codex login --device-auth` as the preferred workaround when the localhost
callback cannot be used.

This script normally should NOT be run just to install Codex or fix general
connection, streaming, upload, proxy, DNS, TLS-inspection, or WebSocket issues.
Those problems require the relevant OpenAI/ChatGPT domains and WebSocket traffic
to be allowed by the network firewall, proxy, VPN, or security product.

Apply and Remove require an elevated PowerShell session. Audit does not.
VS Code extension and Microsoft Store paths are versioned, so rerun Apply after
an update only if the login callback problem returns.

.PARAMETER Mode
Audit lists discovered Codex binaries, owned firewall rules, and listeners on
the callback port. Apply replaces this script's rules with current, narrowly
scoped rules. Remove deletes only rules in the "Codex Firewall Fix" group.

.PARAMETER Port
Local callback port used by `codex login`. The documented default is 1455.

.PARAMETER CodexPath
Optional explicit path or paths to codex.exe. These are combined with paths
discovered from running processes, PATH, the desktop app, VS Code extensions,
the standalone installer, and a global npm installation.

.PARAMETER AllowOutboundHttps
Also creates a program-specific outbound TCP 443 rule to any remote address.
Do not use this on ordinary Windows configurations, which allow outbound traffic
by default. It is intended only for centrally managed environments whose default
outbound policy is Block. An explicit block rule still overrides this allow rule.

.EXAMPLE
.\codex_firewall.ps1

Audit only; makes no changes and does not require elevation.

.EXAMPLE
.\codex_firewall.ps1 -Mode Apply -WhatIf

Shows the firewall changes that Apply would make.

.EXAMPLE
.\codex_firewall.ps1 -Mode Apply

From an elevated PowerShell session, creates loopback-only inbound callback
rules for each discovered Codex executable.

.EXAMPLE
.\codex_firewall.ps1 -Mode Remove

From an elevated PowerShell session, removes rules owned by this script.

.NOTES
OpenAI Codex authentication documentation:
https://learn.chatgpt.com/docs/auth#login-on-headless-devices

OpenAI network and WebSocket guidance:
https://help.openai.com/en/articles/9247338-network-recommendations-for-chatgpt-errors-on-web-and-apps

Microsoft Windows Firewall rule behavior:
https://learn.microsoft.com/windows/security/operating-system-security/network-security/windows-firewall/rules
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
  [ValidateSet('Audit', 'Apply', 'Remove')]
  [string]$Mode = 'Audit',

  [ValidateRange(1, 65535)]
  [int]$Port = 1455,

  [string[]]$CodexPath,

  [switch]$AllowOutboundHttps
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RuleGroup = 'Codex Firewall Fix'

function Test-IsAdministrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Administrator {
  if (-not (Test-IsAdministrator)) {
    throw 'Apply and Remove must be run from an elevated PowerShell session.'
  }
}

function Get-CodexPaths {
  param([string[]]$ExplicitPath)

  $paths = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)

  function Add-CodexPath {
    param([string]$Candidate)

    if ([string]::IsNullOrWhiteSpace($Candidate)) { return }
    if (-not (Test-Path -LiteralPath $Candidate -PathType Leaf)) { return }

    $resolved = (Resolve-Path -LiteralPath $Candidate).ProviderPath
    if ([IO.Path]::GetFileName($resolved) -ieq 'codex.exe') {
      [void]$paths.Add($resolved)
    }
  }

  foreach ($candidate in @($ExplicitPath)) {
    Add-CodexPath -Candidate $candidate
  }

  Get-Process -Name codex -ErrorAction SilentlyContinue | ForEach-Object {
    $processPath = $null
    try { $processPath = $_.Path } catch {}
    if (-not $processPath) {
      try { $processPath = $_.MainModule.FileName } catch {}
    }
    Add-CodexPath -Candidate $processPath
  }

  Get-Command -Name codex.exe -All -ErrorAction SilentlyContinue | ForEach-Object {
    Add-CodexPath -Candidate $_.Path
  }

  Add-CodexPath -Candidate (Join-Path $env:LOCALAPPDATA 'Programs\OpenAI\Codex\bin\codex.exe')

  Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue | ForEach-Object {
    Add-CodexPath -Candidate (Join-Path $_.InstallLocation 'app\resources\codex.exe')
  }

  $extensionRoots = @(
    (Join-Path $env:USERPROFILE '.vscode\extensions'),
    (Join-Path $env:USERPROFILE '.vscode-insiders\extensions')
  ) | Where-Object { Test-Path -LiteralPath $_ -PathType Container }

  foreach ($root in $extensionRoots) {
    Get-ChildItem -LiteralPath $root -Directory -Filter 'openai.chatgpt-*' -ErrorAction SilentlyContinue |
      ForEach-Object {
        Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Filter 'codex.exe' -ErrorAction SilentlyContinue |
          ForEach-Object { Add-CodexPath -Candidate $_.FullName }
      }
  }

  $npmRoot = Join-Path $env:APPDATA 'npm\node_modules\@openai\codex'
  if (Test-Path -LiteralPath $npmRoot -PathType Container) {
    Get-ChildItem -LiteralPath $npmRoot -Recurse -File -Filter 'codex.exe' -ErrorAction SilentlyContinue |
      ForEach-Object { Add-CodexPath -Candidate $_.FullName }
  }

  return @($paths | Sort-Object)
}

function Get-PathId {
  param([Parameter(Mandatory)][string]$Path)

  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Path.ToLowerInvariant())
    $hash = $sha256.ComputeHash($bytes)
    return ([BitConverter]::ToString($hash).Replace('-', '').Substring(0, 12))
  } finally {
    $sha256.Dispose()
  }
}

function Get-OwnedRules {
  return @(Get-NetFirewallRule -Group $RuleGroup -ErrorAction SilentlyContinue)
}

function Remove-OwnedRules {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param()

  $rules = @(Get-OwnedRules)
  foreach ($rule in $rules) {
    if ($PSCmdlet.ShouldProcess($rule.DisplayName, 'Remove Windows Firewall rule')) {
      Remove-NetFirewallRule -Name $rule.Name -ErrorAction Stop
    }
  }
}

function New-CodexRules {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)][string]$Program,
    [Parameter(Mandatory)][int]$CallbackPort,
    [Parameter(Mandatory)][bool]$IncludeOutboundHttps
  )

  $pathId = Get-PathId -Path $Program
  $description = "Allows only the Codex browser-login callback on localhost:$CallbackPort. Managed by pcprep\windows\codex_firewall.ps1."

  $loopbackRules = @(
    @{ Family = 'IPv4'; Address = '127.0.0.1'; Suffix = 'v4' },
    @{ Family = 'IPv6'; Address = '::1'; Suffix = 'v6' }
  )

  foreach ($definition in $loopbackRules) {
    $name = "PcPrep-Codex-Login-$($definition.Suffix)-$pathId"
    $displayName = "Codex login loopback $($definition.Family) port $CallbackPort [$pathId]"

    if ($PSCmdlet.ShouldProcess($displayName, 'Create Windows Firewall rule')) {
      New-NetFirewallRule `
        -Name $name `
        -DisplayName $displayName `
        -Description $description `
        -Group $RuleGroup `
        -Direction Inbound `
        -Action Allow `
        -Enabled True `
        -Profile Any `
        -Program $Program `
        -Protocol TCP `
        -LocalPort $CallbackPort `
        -LocalAddress $definition.Address `
        -RemoteAddress $definition.Address `
        -EdgeTraversalPolicy Block `
        -ErrorAction Stop | Out-Null
    }
  }

  if ($IncludeOutboundHttps) {
    $name = "PcPrep-Codex-HTTPS-$pathId"
    $displayName = "Codex outbound HTTPS [$pathId]"
    $outboundDescription = 'Allows this Codex executable to connect to any remote address over TCP 443. Use only when default outbound policy is Block.'

    if ($PSCmdlet.ShouldProcess($displayName, 'Create Windows Firewall rule')) {
      New-NetFirewallRule `
        -Name $name `
        -DisplayName $displayName `
        -Description $outboundDescription `
        -Group $RuleGroup `
        -Direction Outbound `
        -Action Allow `
        -Enabled True `
        -Profile Any `
        -Program $Program `
        -Protocol TCP `
        -RemotePort 443 `
        -RemoteAddress Any `
        -ErrorAction Stop | Out-Null
    }
  }
}

function Show-Audit {
  param(
    [string[]]$Programs,
    [int]$CallbackPort
  )

  Write-Host 'Codex executables discovered:' -ForegroundColor Cyan
  if ($Programs.Count -eq 0) {
    Write-Host '  None. Start Codex once or pass -CodexPath explicitly.' -ForegroundColor Yellow
  } else {
    $Programs | ForEach-Object { Write-Host "  $_" }
  }

  Write-Host ''
  Write-Host "Listeners on localhost port ${CallbackPort}:" -ForegroundColor Cyan
  $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $CallbackPort -ErrorAction SilentlyContinue)
  if ($listeners.Count -eq 0) {
    Write-Host '  None. This is normal unless a browser-based Codex login is currently waiting for its callback.'
  } else {
    $listeners | Select-Object LocalAddress, LocalPort, OwningProcess | Format-Table -AutoSize
  }

  Write-Host 'Rules owned by this script:' -ForegroundColor Cyan
  $rules = @(Get-OwnedRules)
  if ($rules.Count -eq 0) {
    Write-Host '  None.'
    return
  }

  $rows = foreach ($rule in $rules) {
    $application = $rule | Get-NetFirewallApplicationFilter
    $ports = $rule | Get-NetFirewallPortFilter
    $addresses = $rule | Get-NetFirewallAddressFilter
    [pscustomobject]@{
      DisplayName = $rule.DisplayName
      Direction = $rule.Direction
      Profile = $rule.Profile
      Program = $application.Program
      Protocol = $ports.Protocol
      LocalPort = $ports.LocalPort
      RemotePort = $ports.RemotePort
      LocalAddress = $addresses.LocalAddress -join ','
      RemoteAddress = $addresses.RemoteAddress -join ','
    }
  }
  $rows | Format-List
}

$codexPaths = Get-CodexPaths -ExplicitPath $CodexPath

switch ($Mode) {
  'Audit' {
    Show-Audit -Programs $codexPaths -CallbackPort $Port
  }

  'Remove' {
    if (-not $WhatIfPreference) { Assert-Administrator }
    Remove-OwnedRules
    if ($WhatIfPreference) {
      Write-Host 'Preview complete; no firewall rules were removed.'
    } else {
      Write-Host 'Codex firewall rules owned by this script were removed.'
    }
  }

  'Apply' {
    if ($codexPaths.Count -eq 0) {
      throw 'No codex.exe was found. Start Codex once or pass -CodexPath explicitly.'
    }
    if (-not $WhatIfPreference) { Assert-Administrator }

    Remove-OwnedRules
    foreach ($program in $codexPaths) {
      New-CodexRules -Program $program -CallbackPort $Port -IncludeOutboundHttps $AllowOutboundHttps.IsPresent
    }

    Write-Host ''
    if ($WhatIfPreference) {
      Write-Host "Previewed loopback-only Codex login rules for $($codexPaths.Count) executable(s); no changes were made."
    } else {
      Write-Host "Configured loopback-only Codex login rules for $($codexPaths.Count) executable(s)."
    }
    if (-not $AllowOutboundHttps) {
      Write-Host 'No outbound rule was created. This is correct for the normal Windows AllowOutbound policy.'
    }
  }
}
