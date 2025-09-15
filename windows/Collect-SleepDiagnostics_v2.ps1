<# 
Collect-SleepDiagnostics_v2.ps1
- Fast, step-timed, timeout-aware collector for "Sleep option missing" diagnosis.
- Outputs a timestamped folder on Desktop + a ZIP, with raw data and summaries.

USAGE EXAMPLES:
  .\Collect-SleepDiagnostics_v2.ps1
  .\Collect-SleepDiagnostics_v2.ps1 -Deep -TimeoutSec 30 -MaxEvents 250

PARAMS:
  -Deep           : also run powercfg /energy and /systemsleepdiagnostics (slower)
  -TimeoutSec     : per external-command timeout (seconds). Default 20.
  -MaxEvents      : cap power-related events read from System log. Default 150.
  -NoZip          : skip final ZIP creation
#>

[CmdletBinding()]
param(
  [switch]$Deep,
  [int]$TimeoutSec = 20,
  [int]$MaxEvents = 150,
  [switch]$NoZip
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

# ----------------------- Paths & transcript -----------------------
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$desktop   = [Environment]::GetFolderPath('Desktop')
$root      = Join-Path $desktop ("SleepDiag_{0}_{1}" -f $env:COMPUTERNAME, $timestamp)
New-Item -ItemType Directory -Path $root -Force | Out-Null

# Simple logger
$logFile = Join-Path $root 'progress.log'
function Write-Log {
  param([string]$Message, [string]$Level = 'INFO')
  $line = "[{0:HH:mm:ss}] [{1}] {2}" -f (Get-Date), $Level, $Message
  Write-Host $line
  Add-Content -Path $logFile -Value $line
}

# Save text/json helpers
function Save-Text { param([string]$File,[string]$Text) $Text | Out-File -FilePath (Join-Path $root $File) -Encoding UTF8 -Force }
function Save-Json { param([string]$File,[object]$Obj) ($Obj | ConvertTo-Json -Depth 6) | Out-File -FilePath (Join-Path $root $File) -Encoding UTF8 -Force }

# Admin?
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
  IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Log "IsAdministrator=$IsAdmin"
Save-Text 'admin.txt' ("IsAdministrator=$IsAdmin")

# Transcript
Start-Transcript -Path (Join-Path $root 'console_transcript.txt') -Force | Out-Null

# Stopwatch for steps
function New-Stopwatch { return [System.Diagnostics.Stopwatch]::StartNew() }

# ----------------------- External command with timeout -----------------------
# Prints the statement, times it, captures stdout/stderr/exitcode, and enforces a timeout.
function Invoke-External {
  param(
    [Parameter(Mandatory)] [string]$Exe,
    [Parameter(Mandatory)] [string]$Args,
    [Parameter(Mandatory)] [string]$OutFile,   # relative to $root
    [int]$Timeout = $TimeoutSec
  )
  $target = Join-Path $root $OutFile
  $sw = New-Stopwatch
  Write-Log "RUN: $Exe $Args (timeout ${Timeout}s)"

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $Exe
  $psi.Arguments = $Args
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi

  $null = $p.Start()
  if (-not $p.WaitForExit($Timeout * 1000)) {
    try { $p.Kill() } catch {}
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $content = @"
# COMMAND: $Exe $Args
# STATUS : TIMED OUT after $Timeout s
# DURATION: {0:n2} s

# ---- STDOUT ----
$stdout

# ---- STDERR ----
$stderr
"@ -f $sw.Elapsed.TotalSeconds
    $content | Out-File -FilePath $target -Encoding UTF8 -Force
    Write-Log "TIMEOUT after ${Timeout}s -> $OutFile" "WARN"
    return @{ ExitCode = $null; TimedOut = $true; Duration = $sw.Elapsed.TotalSeconds; OutFile = $target }
  } else {
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $exit   = $p.ExitCode
    $content = @"
# COMMAND: $Exe $Args
# STATUS : COMPLETED
# EXIT   : $exit
# DURATION: {0:n2} s

# ---- STDOUT ----
$stdout

# ---- STDERR ----
$stderr
"@ -f $sw.Elapsed.TotalSeconds
    $content | Out-File -FilePath $target -Encoding UTF8 -Force
    Write-Log "OK in {0:n2}s -> {1}" -f $sw.Elapsed.TotalSeconds, $OutFile
    return @{ ExitCode = $exit; TimedOut = $false; Duration = $sw.Elapsed.TotalSeconds; OutFile = $target }
  }
}

# ----------------------- Registry helper -----------------------
function Get-RegValue {
  param([string]$Path, [string]$Name)
  try {
    Write-Log "REG READ: Get-ItemProperty -Path '$Path' -Name '$Name'"
    $val = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop | Select-Object -ExpandProperty $Name
    return [pscustomobject]@{ Path=$Path; Name=$Name; Value=$val; Error=$null }
  } catch {
    return [pscustomobject]@{ Path=$Path; Name=$Name; Value=$null; Error=$_.Exception.Message }
  }
}

# ----------------------- STEP 1: System & session basics -----------------------
Write-Log "STEP 1: System & session basics"
$os   = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$cs   = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
$cpu  = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
$gpu  = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object Name, DriverVersion, DriverDate, PNPDeviceID

# RDP detection
$rdpSession = $env:SESSIONNAME -like 'RDP*'

# Battery presence
$batt = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue

$sysInfo = [pscustomobject]@{
  ComputerName  = $env:COMPUTERNAME
  Manufacturer  = $cs.Manufacturer
  Model         = $cs.Model
  SystemType    = $cs.SystemType
  DomainJoined  = $cs.PartOfDomain
  Domain        = $cs.Domain
  BIOS_Version  = $bios.SMBIOSBIOSVersion
  BIOS_Release  = $bios.ReleaseDate
  OS_Caption    = $os.Caption
  OS_Version    = $os.Version
  OS_Build      = $os.BuildNumber
  CPU_Name      = $cpu.Name
  RdpSession    = $rdpSession
  BatteryPresent= [bool]$batt
}
Save-Json 'system_info.json' $sysInfo
$sysInfo | Format-List | Out-String | Save-Text 'system_info.txt'

# ----------------------- STEP 2: UI & Policy toggles that hide Sleep -----------------------
Write-Log "STEP 2: Policy/UI toggles that can hide Sleep (Start/Explorer/MDM)"
$policyChecks = @(
  # Explorer ADMX-backed policy: Show sleep in the power options menu
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name='ShowSleepOption' }

  # Explorer FlyoutMenuSettings (user choice / some 3rd-party menus read this)
  @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'; Name='ShowSleepOption' }
  @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'; Name='ShowHibernateOption' }
  @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'; Name='ShowLockOption' }

  # MDM/Policy CSP Start: HideSleep (device policy)
  @{ Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start'; Name='HideSleep' }
  @{ Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start';          Name='HideSleep' }

  # Legacy "hide power" policies that nuke power menu
  @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='HidePowerOptions' } # if 1, hides power options
  @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='HidePowerOptions' }
  @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='NoClose' } # also affects shutdown UI
  @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='NoClose' }
)

$policyResults = foreach ($q in $policyChecks) { Get-RegValue @q }
Save-Json 'policy_ui_checks.json' $policyResults
$policyResults | Sort-Object Path,Name | Format-Table -AutoSize | Out-String | Save-Text 'policy_ui_checks.txt'

# ----------------------- STEP 3: Power policy: AllowStandby & Hybrid sleep -----------------------
Write-Log "STEP 3: Power policy (ALLOWSTANDBY S1–S3 & HybridSleep) via registry-backed policies"
$powerPolicyChecks = @(
  # AllowStandby S1-S3 policy (AC/DC) -> GUID abfc2519-3608-4c2a-94ea-171b0ed546ab
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\abfc2519-3608-4c2a-94ea-171b0ed546ab'; Name='ACSettingIndex' }
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\abfc2519-3608-4c2a-94ea-171b0ed546ab'; Name='DCSettingIndex' }

  # Hybrid Sleep policy (AC/DC) -> GUID 94ac6d29-73ce-41a6-809f-6363ba21b47e
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\94ac6d29-73ce-41a6-809f-6363ba21b47e'; Name='ACSettingIndex' }
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\94ac6d29-73ce-41a6-809f-6363ba21b47e'; Name='DCSettingIndex' }

  # Core power flags
  @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name='HibernateEnabled' }
  @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name='HiberbootEnabled' }
  # Modern Standby related flags (note: CsEnabled is ignored on newer builds but record for completeness)
  @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name='CsEnabled' }
  @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name='PlatformAoAcOverride' }
)
$powerPolicyResults = foreach ($q in $powerPolicyChecks) { Get-RegValue @q }
Save-Json 'power_policy_registry.json' $powerPolicyResults
$powerPolicyResults | Sort-Object Path,Name | Format-Table -AutoSize | Out-String | Save-Text 'power_policy_registry.txt'

# ----------------------- STEP 4: powercfg core queries -----------------------
Write-Log "STEP 4: powercfg queries"
Invoke-External -Exe 'cmd.exe' -Args '/c powercfg /a'                         -OutFile 'powercfg_a.txt'            | Out-Null
Invoke-External -Exe 'cmd.exe' -Args '/c powercfg -requests'                  -OutFile 'powercfg_requests.txt'     | Out-Null
Invoke-External -Exe 'cmd.exe' -Args '/c powercfg -devicequery wake_armed'    -OutFile 'powercfg_wake_armed.txt'   | Out-Null
Invoke-External -Exe 'cmd.exe' -Args '/c powercfg -devicequery wake_programmable' -OutFile 'powercfg_wake_programmable.txt' | Out-Null
Invoke-External -Exe 'cmd.exe' -Args '/c powercfg -q scheme_current sub_sleep' -OutFile 'powercfg_sub_sleep.txt'   | Out-Null

if ($IsAdmin -and $Deep) {
  # These are slow by design; shorten duration a bit for speed
  Invoke-External -Exe 'cmd.exe' -Args "/c powercfg /energy /duration 45 /output `"$($root)\energy_report.html`"" `
    -OutFile 'powercfg_energy_command_output.txt' | Out-Null
  Invoke-External -Exe 'cmd.exe' -Args "/c powercfg /systemsleepdiagnostics /output `"$($root)\systemsleepdiagnostics.html`"" `
    -OutFile 'powercfg_systemsleepdiag_command_output.txt' | Out-Null
}

# ----------------------- STEP 5: Virtualization / Hyper-V / Device Guard hints -----------------------
Write-Log "STEP 5: Virtualization/Hyper-V/Device Guard footprint"
# Hyper-V launch mode (bcdedit), often influences S3 on some platforms
Invoke-External -Exe 'cmd.exe' -Args '/c bcdedit /enum {current}' -OutFile 'bcdedit_current.txt' | Out-Null

# Optional features can be slow; keep a timeout
try {
  Write-Log "RUN: Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All (timeout $TimeoutSec s)"
  $sw = New-Stopwatch
  $hv = $null
  $job = Start-Job -ScriptBlock { Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue }
  if (Wait-Job $job -Timeout $TimeoutSec) {
    $hv = Receive-Job $job
  } else {
    Stop-Job $job -Force | Out-Null
    Write-Log "Get-WindowsOptionalFeature timed out" "WARN"
  }
  $wsl = $null
  $job2 = Start-Job -ScriptBlock { Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue }
  if (Wait-Job $job2 -Timeout $TimeoutSec) {
    $wsl = Receive-Job $job2
  } else {
    Stop-Job $job2 -Force | Out-Null
    Write-Log "Get-WindowsOptionalFeature (WSL) timed out" "WARN"
  }
  $virt = [pscustomobject]@{
    HyperVFeature = if ($hv) { $hv.State } else { 'Unknown/Timeout' }
    WSLFeature    = if ($wsl){ $wsl.State } else { 'Unknown/Timeout' }
  }
  Save-Json 'virtualization_optional_features.json' $virt
} catch {
  Save-Text 'virtualization_optional_features.txt' "Error: $($_.Exception.Message)"
}

# Device Guard / VBS (can affect sleep states on some systems)
try {
  Write-Log "RUN: Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard"
  $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
  if ($dg) { Save-Json 'deviceguard.json' $dg } else { Save-Text 'deviceguard.txt' 'DeviceGuard info not available' }
} catch {
  Save-Text 'deviceguard.txt' "Error: $($_.Exception.Message)"
}

# ----------------------- STEP 6: AAD/Domain/GPO footprint (timeout-safe) -----------------------
Write-Log "STEP 6: AAD/Domain/GPO footprint (with timeouts)"
Invoke-External -Exe 'cmd.exe' -Args '/c dsregcmd /status'                 -OutFile 'dsregcmd_status.txt'       | Out-Null
Invoke-External -Exe 'cmd.exe' -Args '/c gpresult /scope user /r'          -OutFile 'gpresult_user_r.txt'       | Out-Null
Invoke-External -Exe 'cmd.exe' -Args '/c gpresult /scope computer /r'      -OutFile 'gpresult_computer_r.txt'   | Out-Null
# Deep verbose GP is slow; only if requested
if ($Deep) {
  Invoke-External -Exe 'cmd.exe' -Args '/c gpresult /scope user /v'        -OutFile 'gpresult_user_v.txt'       | Out-Null
  Invoke-External -Exe 'cmd.exe' -Args '/c gpresult /scope computer /v'    -OutFile 'gpresult_computer_v.txt'   | Out-Null
}

# ----------------------- STEP 7: Drivers/Display & third‑party start menus -----------------------
Write-Log "STEP 7: GPU driver + common Start menu replacements"
$display = Get-PnpDevice -Class Display -Status OK -ErrorAction SilentlyContinue |
           Select-Object FriendlyName, Manufacturer, DriverProviderName, DriverVersion, DriverDate
$display | Format-Table -AutoSize | Out-String | Save-Text 'display_adapters.txt'
Save-Json 'display_adapters.json' $display

# Third‑party Start menu products that may control power flyout
$uninstRoots = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$startVendors = 'Stardock','Open-Shell','Classic Shell','StartIsBack','StartAllBack','Start11','Start10'
$apps = foreach ($path in $uninstRoots) {
  Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and ($startVendors | ForEach-Object { $_ }) -contains ($_.Publisher) -or ($startVendors | Where-Object { $_ -and $_ -as [string] } | ForEach-Object { $_ }) -contains $_.DisplayName } |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallLocation
}
if ($apps) {
  Save-Json 'startmenu_thirdparty.json' $apps
  $apps | Format-Table -AutoSize | Out-String | Save-Text 'startmenu_thirdparty.txt'
} else {
  Save-Text 'startmenu_thirdparty.txt' 'No common Start menu replacements detected (vendor heuristic).'
}

# ----------------------- STEP 8: Recent power-related events (bounded) -----------------------
Write-Log "STEP 8: Recent Kernel-Power/Troubleshooter events (bounded)"
try {
  $start = (Get-Date).AddDays(-7)
  $ev = Get-WinEvent -FilterHashtable @{
    LogName='System'
    ProviderName=@('Microsoft-Windows-Kernel-Power','Microsoft-Windows-Power-Troubleshooter')
    StartTime=$start
  } -ErrorAction SilentlyContinue -MaxEvents $MaxEvents |
  Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message
  if ($ev) {
    $ev | Format-Table -AutoSize | Out-String | Save-Text 'recent_power_events.txt'
  } else {
    Save-Text 'recent_power_events.txt' "No matching events in last 7 days (MaxEvents=$MaxEvents)."
  }
} catch {
  Save-Text 'recent_power_events.txt' "Error reading events: $($_.Exception.Message)"
}

# ----------------------- STEP 9: Parse powercfg /a for summary hints -----------------------
Write-Log "STEP 9: Parse powercfg /a for availability & blockers"
$pcA = Get-Content (Join-Path $root 'powercfg_a.txt') -ErrorAction SilentlyContinue
$available = @()
$blocked   = @()
if ($pcA) {
  $mode = ''
  foreach ($line in $pcA) {
    if ($line -match 'The following sleep states are available on this system:') { $mode='avail'; continue }
    if ($line -match 'The following sleep states are not available on this system:') { $mode='na'; continue }
    if ($mode -eq 'avail' -and $line.Trim()) { $available += $line.Trim() }
    if ($mode -eq 'na' -and $line.Trim())   { $blocked   += $line.Trim() }
  }
}

# ----------------------- STEP 10: Build human summary -----------------------
Write-Log "STEP 10: Build SUMMARY files"
$policyMap = @{}
foreach ($r in $policyResults) { $policyMap["$($r.Path)|$($r.Name)"] = $r.Value }

$powerMap = @{}
foreach ($r in $powerPolicyResults) { $powerMap["$($r.Path)|$($r.Name)"] = $r.Value }

$summary = [pscustomobject]@{
  Computer            = $sysInfo.ComputerName
  OS                  = "$($sysInfo.OS_Caption) ($($sysInfo.OS_Build))"
  Model               = "$($sysInfo.Manufacturer) $($sysInfo.Model)"
  RdpSession          = $sysInfo.RdpSession
  BatteryPresent      = $sysInfo.BatteryPresent
  Policies = [pscustomobject]@{
    Explorer_ShowSleepOption_HKLM = $policyMap['HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer|ShowSleepOption']
    Explorer_Flyout_ShowSleep     = $policyMap['HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings|ShowSleepOption']
    StartCSP_HideSleep_current    = $policyMap['HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start|HideSleep']
    StartCSP_HideSleep_default    = $policyMap['HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start|HideSleep']
    HidePowerOptions_All          = @(
      $policyMap['HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer|HidePowerOptions'],
      $policyMap['HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer|HidePowerOptions'],
      $policyMap['HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer|NoClose'],
      $policyMap['HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer|NoClose']
    ) -join ';'
  }
  PowerPolicy = [pscustomobject]@{
    AllowStandby_AC = $powerMap['HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\abfc2519-3608-4c2a-94ea-171b0ed546ab|ACSettingIndex']
    AllowStandby_DC = $powerMap['HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\abfc2519-3608-4c2a-94ea-171b0ed546ab|DCSettingIndex']
    HybridSleep_AC  = $powerMap['HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\94ac6d29-73ce-41a6-809f-6363ba21b47e|ACSettingIndex']
    HybridSleep_DC  = $powerMap['HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\94ac6d29-73ce-41a6-809f-6363ba21b47e|DCSettingIndex']
    HibernateEnabled= $powerMap['HKLM:\SYSTEM\CurrentControlSet\Control\Power|HibernateEnabled']
    HiberbootEnabled= $powerMap['HKLM:\SYSTEM\CurrentControlSet\Control\Power|HiberbootEnabled']
    CsEnabled       = $powerMap['HKLM:\SYSTEM\CurrentControlSet\Control\Power|CsEnabled']
    PlatformAoAcOverride = $powerMap['HKLM:\SYSTEM\CurrentControlSet\Control\Power|PlatformAoAcOverride']
  }
  PowerCfgAvailable = $available
  PowerCfgBlocked   = $blocked
}
Save-Json 'SUMMARY.json' $summary

# Human-readable guidance
$lines = @()
$lines += "Sleep Diagnostics Summary for $($summary.Computer)  ($([DateTime]::Now))"
$lines += "OS: $($summary.OS)   Model: $($summary.Model)"
$lines += "RDP Session: $($summary.RdpSession)   BatteryPresent: $($summary.BatteryPresent)"
$lines += ""
$lines += "Possible Hiding Toggles (policy/UI):"
$lines += "  Explorer policy ShowSleepOption (HKLM\\...\\Policies\\Microsoft\\Windows\\Explorer) = $($summary.Policies.Explorer_ShowSleepOption_HKLM)"
$lines += "  Explorer FlyoutMenuSettings ShowSleepOption (HKLM\\...\\Explorer\\FlyoutMenuSettings) = $($summary.Policies.Explorer_Flyout_ShowSleep)"
$lines += "  Start CSP HideSleep (device) current/default = $($summary.Policies.StartCSP_HideSleep_current) / $($summary.Policies.StartCSP_HideSleep_default)"
$lines += "  HidePowerOptions/NoClose (system/user) = $($summary.Policies.HidePowerOptions_All)"
$lines += ""
$lines += "AllowStandby (S1–S3) policy indices (1=Enabled, 0=Disabled)  [GUID abfc2519-3608-4c2a-94ea-171b0ed546ab]:"
$lines += "  AC=$($summary.PowerPolicy.AllowStandby_AC)   DC=$($summary.PowerPolicy.AllowStandby_DC)"
$lines += "HybridSleep policy indices (1=On, 0=Off) [GUID 94ac6d29-73ce-41a6-809f-6363ba21b47e]:"
$lines += "  AC=$($summary.PowerPolicy.HybridSleep_AC)   DC=$($summary.PowerPolicy.HybridSleep_DC)"
$lines += ""
$lines += "Modern Standby toggles (note: CsEnabled ignored on newer builds):"
$lines += "  PlatformAoAcOverride=$($summary.PowerPolicy.PlatformAoAcOverride)   CsEnabled=$($summary.PowerPolicy.CsEnabled)"
$lines += "  HibernateEnabled=$($summary.PowerPolicy.HibernateEnabled)  HiberbootEnabled=$($summary.PowerPolicy.HiberbootEnabled)"
$lines += ""
$lines += "powercfg /a — Available states:"
$lines += ("  " + (($summary.PowerCfgAvailable) -join ', '))
$lines += ""
$lines += "powercfg /a — Not available (with reasons):"
$lines += ("  " + (($summary.PowerCfgBlocked) -join ' | '))
$lines += ""
$lines += "See raw files for details in: $root"
$lines -join "`r`n" | Out-File -FilePath (Join-Path $root 'SUMMARY.md') -Encoding UTF8 -Force

# ----------------------- STEP 11: systeminfo (quick) -----------------------
Write-Log "STEP 11: systeminfo"
Invoke-External -Exe 'cmd.exe' -Args '/c systeminfo' -OutFile 'systeminfo.txt' | Out-Null

# ----------------------- Wrap up -----------------------
Stop-Transcript | Out-Null
if (-not $NoZip) {
  $zip = Join-Path $desktop ("{0}.zip" -f (Split-Path $root -Leaf))
  Write-Log "Creating ZIP: $zip"
  try {
    Compress-Archive -Path "$root\*" -DestinationPath $zip -Force
    Write-Log "ZIP created: $zip"
  } catch {
    Write-Log "ZIP failed: $($_.Exception.Message)" "WARN"
  }
}

Write-Host "`nDONE."
Write-Host "Folder: $root"
if (-not $NoZip) { Write-Host "ZIP   : $(Join-Path $desktop ((Split-Path $root -Leaf) + '.zip'))" }
