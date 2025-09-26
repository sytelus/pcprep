param(
  [int]$Port = 1455
)

$RuleGroup = "Codex Firewall Fix"

function Assert-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Please run this script in an elevated PowerShell (Run as Administrator)."
    exit 1
  }
}

function Get-CodexPaths {
  $paths = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)

  # 1) Running codex.exe (extension-launched)
  try {
    Get-Process -Name codex -ErrorAction SilentlyContinue | ForEach-Object {
      $p = $null
      try { $p = $_.Path } catch {}
      try { if (-not $p) { $p = $_.MainModule.FileName } } catch {}
      if ($p -and (Test-Path $p)) { [void]$paths.Add($p) }
    }
  } catch {}

  # 2) VS Code extension installs
  $extRoots = @(
    "$env:USERPROFILE\.vscode\extensions",
    "$env:USERPROFILE\.vscode-insiders\extensions"
  ) | Where-Object { $_ -and (Test-Path $_) }

  foreach ($root in $extRoots) {
    Get-ChildItem -Path $root -Recurse -Filter "codex.exe" -ErrorAction SilentlyContinue |
      ForEach-Object {
        if ($_.FullName -and (Test-Path $_.FullName)) { [void]$paths.Add($_.FullName) }
      }
  }

  # 3) npm global CLI fallback
  $npmCli = "$env:USERPROFILE\AppData\Roaming\npm\codex.exe"
  if (Test-Path $npmCli) { [void]$paths.Add($npmCli) }

  return [string[]]$paths
}

function Remove-CodexRulesForProgram([string]$program) {
  try {
    # Remove rules created by this script (by Group) for this executable
    $appFilters = Get-NetFirewallApplicationFilter -Program $program -ErrorAction SilentlyContinue
    if ($appFilters) {
      $rules = $appFilters | ForEach-Object {
        Get-NetFirewallRule -AssociatedNetFirewallApplicationFilter $_ -ErrorAction SilentlyContinue
      } | Where-Object { $_ -and $_.Group -eq $RuleGroup }
      if ($rules) {
        $rules | ForEach-Object {
          Write-Host ("Removing existing rule: {0}" -f $_.DisplayName)
          Remove-NetFirewallRule -Name $_.Name -ErrorAction SilentlyContinue
        }
      }
    }
  } catch {}
}

# --- Helper: detect whether IPv6 is enabled at OS level and usable on loopback ---
function Is-IPv6Enabled {
  try {
    # 1) Check common registry knob. If missing or 0 -> IPv6 enabled.
    $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
    $val = (Get-ItemProperty -Path $regPath -Name 'DisabledComponents' -ErrorAction SilentlyContinue).DisabledComponents
    if ($null -ne $val) {
      # 0xFF (255) disables all IPv6 components; other bitmasks may partially disable
      if (($val -band 0xFF) -eq 0xFF) { return $false }
    }

    # 2) Confirm the stack is present and at least one IPv6 interface is up
    $ifUp = Get-NetIPInterface -AddressFamily IPv6 -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceOperationalStatus -eq 'Up' }
    if (-not $ifUp) { return $false }

    # 3) Ensure ::1 actually resolves/configures locally
    $hasLoopback = $false
    try {
      $hasLoopback = [bool](Get-NetIPAddress -AddressFamily IPv6 -IPAddress '::1' -ErrorAction Stop)
    } catch { $hasLoopback = $false }

    return $hasLoopback
  } catch {
    # If anything is ambiguous, err on the safe side (no IPv6 rule).
    return $false
  }
}

# --- Replace your existing Ensure-AllowRules with this IPv6-conditional version ---
function Ensure-AllowRules([string]$program, [int]$port) {
  $digest = (Get-FileHash -Algorithm SHA256 -Path $program).Hash.Substring(0,8)

  # Inbound IPv4 (localhost only) — always create
  $inName4 = "Codex Inbound Loopback IPv4 $port [$digest]"
  Get-NetFirewallRule -DisplayName $inName4 -ErrorAction SilentlyContinue |
    Where-Object { $_.Group -eq $RuleGroup } | Remove-NetFirewallRule -ErrorAction SilentlyContinue

  New-NetFirewallRule -DisplayName $inName4 `
    -Group $RuleGroup -Direction Inbound -Action Allow -Enabled True `
    -Program $program -Protocol TCP -LocalPort $port `
    -LocalAddress '127.0.0.1' -Profile Private,Domain | Out-Null
  Write-Host ('Created inbound allow rule (IPv4) for {0} on 127.0.0.1:{1}' -f $program, $port)

  # Inbound IPv6 (only if OS IPv6 is enabled AND ::1 is usable)
  if (Is-IPv6Enabled) {
    $inName6 = "Codex Inbound Loopback IPv6 $port [$digest]"
    Get-NetFirewallRule -DisplayName $inName6 -ErrorAction SilentlyContinue |
      Where-Object { $_.Group -eq $RuleGroup } | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    try {
      New-NetFirewallRule -DisplayName $inName6 `
        -Group $RuleGroup -Direction Inbound -Action Allow -Enabled True `
        -Program $program -Protocol TCP -LocalPort $port `
        -LocalAddress '::1' -Profile Private,Domain | Out-Null
      Write-Host ('Created inbound allow rule (IPv6) for {0} on ::1:{1}' -f $program, $port)
    } catch {
      Write-Warning ('IPv6 loopback rule skipped (New-NetFirewallRule failed): {0}' -f $_.Exception.Message)
    }
  } else {
    Write-Host 'IPv6 not enabled/usable; skipping IPv6 inbound rule.'
  }

  # Outbound HTTPS (shared for v4/v6)
  $outName = "Codex Outbound HTTPS [$digest]"
  Get-NetFirewallRule -DisplayName $outName -ErrorAction SilentlyContinue |
    Where-Object { $_.Group -eq $RuleGroup } | Remove-NetFirewallRule -ErrorAction SilentlyContinue

  New-NetFirewallRule -DisplayName $outName `
    -Group $RuleGroup -Direction Outbound -Action Allow -Enabled True `
    -Program $program -Protocol TCP -RemotePort 443 `
    -Profile Private,Domain | Out-Null
  Write-Host ('Created outbound HTTPS allow rule for {0}' -f $program)
}

# -------------------- Main --------------------
Assert-Admin

$codexPaths = Get-CodexPaths
if (!$codexPaths -or $codexPaths.Count -eq 0) {
  Write-Warning "No codex.exe found. Open VS Code, trigger Codex so it launches, then re-run."
  Write-Host  ("Common path: {0}\.vscode\extensions\<publisher.codex-*>\bin\codex.exe" -f $env:USERPROFILE)
  exit 2
}

Write-Host "Found Codex binaries:" -ForegroundColor Cyan
$codexPaths | ForEach-Object { Write-Host ("  {0}" -f $_) }

foreach ($p in $codexPaths) {
  Remove-CodexRulesForProgram -program $p
  Ensure-AllowRules -program $p -port $Port
}

Write-Host ''
Write-Host 'Done. Re-run this script any time—it''s safe and idempotent.'
Write-Host 'If Codex still can''t start, try the login again and then run:'
Write-Host ('  netstat -ano | findstr :{0}' -f $Port)
Write-Host ('You should see LISTENING on 127.0.0.1:{0} by codex.exe' -f $Port)
