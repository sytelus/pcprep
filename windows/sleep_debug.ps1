# Collect-SleepDiagnostics.ps1
# Gathers all info needed to diagnose why "Sleep" is missing from Windows power menus.

[CmdletBinding()]
param(
  [switch]$Deep   # Adds powercfg energy/systemsleepdiagnostics (slower)
)

$ErrorActionPreference = 'Continue'

# ---------- Helpers ----------
function Save-Text {
  param([string]$File, [string]$Text)
  $FilePath = Join-Path $root $File
  $Text | Out-File -FilePath $FilePath -Encoding UTF8 -Force
}

function Save-Command {
  param([string]$File, [string]$Cmd, [string]$Args)
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $Cmd
  $psi.Arguments = $Args
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute        = $false
  $p = [System.Diagnostics.Process]::Start($psi)
  $p.WaitForExit()
  $out = $p.StandardOutput.ReadToEnd()
  $err = $p.StandardError.ReadToEnd()
  Save-Text $File ($out + "`r`n`r`n--- STDERR ---`r`n" + $err)
}

function Get-RegValue {
  param([string]$Path, [string]$Name)
  try {
    $item = Get-ItemProperty -Path $Path -ErrorAction Stop
    [pscustomobject]@{
      Path    = $Path
      Name    = $Name
      Present = $true
      Value   = $item.$Name
    }
  } catch {
    [pscustomobject]@{
      Path    = $Path
      Name    = $Name
      Present = $false
      Value   = $null
    }
  }
}

# ---------- Setup ----------
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$root = Join-Path $env:USERPROFILE "Desktop\SleepDiagnostics_$($env:COMPUTERNAME)_$timestamp"
New-Item -ItemType Directory -Path $root -Force | Out-Null

$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).
  IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
Save-Text 'admin.txt' ("IsAdministrator=$IsAdmin")

Start-Transcript -Path (Join-Path $root 'console_transcript.txt') -Force | Out-Null

# ---------- System & OS ----------
$os   = Get-CimInstance Win32_OperatingSystem
$cs   = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$cpu  = Get-CimInstance Win32_Processor
$gpu  = Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, DriverDate, PNPDeviceID

$sys = [pscustomobject]@{
  ComputerName     = $env:COMPUTERNAME
  Manufacturer     = $cs.Manufacturer
  Model            = $cs.Model
  SystemType       = $cs.SystemType
  PartOfDomain     = $cs.PartOfDomain
  Domain           = $cs.Domain
  BIOS_Version     = $bios.SMBIOSBIOSVersion
  BIOS_ReleaseDate = $bios.ReleaseDate
  OS_Caption       = $os.Caption
  OS_Version       = $os.Version
  OS_Build         = $os.BuildNumber
  OS_InstallDate   = $os.InstallDate
  TotalMemoryGB    = [Math]::Round($cs.TotalPhysicalMemory/1GB,2)
  BatteryPresent   = [bool](Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
  IsRdpSession     = ($env:SESSIONNAME -like 'RDP*')
  IsVirtualMachine = ($cs.Model -match 'Virtual|VMware|Hyper-V|KVM|VirtualBox')
}
$sys | ConvertTo-Json -Depth 4 | Out-File -Encoding UTF8 (Join-Path $root 'system_info.json')
$gpu | Format-Table -AutoSize | Out-String | Save-Text 'gpus.txt'

# ---------- Quick environment signals ----------
# Hyper-V/WSL presence + hypervisor launch mode
try {
  $hv  = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
  $wsl = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
  $bcd = (cmd /c 'bcdedit /enum {current}') 2>&1
  $hvLaunch = if ($bcd -match '(?i)hypervisorlaunchtype\s+(\S+)') { $Matches[1] } else { 'NotPresent' }
  Save-Text 'virtualization_status.txt' ("HyperVFeatureState=$($hv.State)`r`nWSLFeatureState=$($wsl.State)`r`nHypervisorLaunchType=$hvLaunch")
} catch {
  Save-Text 'virtualization_status.txt' "Error retrieving virtualization/WSL/BCD info: $($_.Exception.Message)"
}

# Domain/AAD/MDM footprint (if available)
Save-Command 'dsregcmd_status.txt' 'cmd.exe' '/c dsregcmd /status'

# Group Policy footprint (can include domain objects)
Save-Command 'gpresult_user.txt'     'cmd.exe' '/c gpresult /scope user /v'
Save-Command 'gpresult_computer.txt' 'cmd.exe' '/c gpresult /scope computer /v'

# ---------- powercfg core ----------
Save-Command 'powercfg_a.txt'               'cmd.exe' '/c powercfg /a'
Save-Command 'powercfg_requests.txt'        'cmd.exe' '/c powercfg -requests'
Save-Command 'powercfg_wake_armed.txt'      'cmd.exe' '/c powercfg -devicequery wake_armed'
Save-Command 'powercfg_wake_programmable.txt' 'cmd.exe' '/c powercfg -devicequery wake_programmable'
Save-Command 'powercfg_sleep_subgroup.txt'  'cmd.exe' '/c powercfg -q scheme_current sub_sleep'

if ($IsAdmin -and $Deep) {
  # Optional deeper diagnostics; these can take 60-120 seconds and may not be available on all systems
  Save-Command 'powercfg_energy_report.html' 'cmd.exe' "/c powercfg /energy /duration 60 /output `"$($root)\energy_report.html`""
  Save-Command 'powercfg_systemsleepdiagnostics.html' 'cmd.exe' "/c powercfg /systemsleepdiagnostics /output `"$($root)\systemsleepdiagnostics.html`""
}

# SleepStudy (works only on Modern Standby platforms)
if ($IsAdmin) {
  Save-Command 'powercfg_sleepstudy.html' 'cmd.exe' "/c powercfg /sleepstudy /output `"$($root)\sleepstudy.html`""
}

# ---------- Registry & Policy checks that affect Sleep visibility ----------
$regQueries = @(
  # Explorer flyout toggles
  @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'; Name='ShowSleepOption' }
  @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'; Name='ShowHibernateOption' }

  # Explorer policy overrides (GPO: File Explorer > Show Sleep/Hibernate in power menu)
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name='ShowSleepOption' }
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name='ShowHibernateOption' }

  # Remove/Hide power options policies
  @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='HidePowerOptions' } # Computer scope
  @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='NoClose' }         # User scope

  # MDM/Policy CSP "Start" items that can hide Sleep/Power
  @{ Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start\HideSleep';        Name='value' }
  @{ Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start\HideSleep'; Name='value' }
  @{ Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\current\Start\HideSleep';        Name='value' }        # some builds use this
  @{ Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start\HidePowerButton';        Name='value' }
  @{ Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start\HidePowerButton'; Name='value' }

  # “Allow standby states (S1-S3) when sleeping” policy (AC/DC) - disabling this blocks legacy sleep
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\abfc2519-3608-4c2a-94ea-171b0ed546ab'; Name='ACSettingIndex' }
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\abfc2519-3608-4c2a-94ea-171b0ed546ab'; Name='DCSettingIndex' }

  # Hybrid sleep policy toggles (AC/DC)
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\94ac6d29-73ce-41a6-809f-6363ba21b47e'; Name='ACSettingIndex' }
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\94ac6d29-73ce-41a6-809f-6363ba21b47e'; Name='DCSettingIndex' }

  # Core power keys
  @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name='HibernateEnabled' }
  @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name='HiberbootEnabled' }
  @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name='CsEnabled' }            # legacy toggle (ignored on newer builds, but record)
  @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name='PlatformAoAcOverride' } # Modern Standby override flag (presence/value matters)
)

$regResults = foreach ($q in $regQueries) { Get-RegValue -Path $q.Path -Name $q.Name }
$regResults | ConvertTo-Json -Depth 5 | Out-File -Encoding UTF8 (Join-Path $root 'registry_checks.json')
$regResults | Sort-Object Path, Name | Format-Table -AutoSize | Out-String | Save-Text 'registry_checks.txt'

# ---------- System logs (recent power-related) ----------
try {
  $start = (Get-Date).AddDays(-7)
  $ev = Get-WinEvent -FilterHashtable @{
    LogName='System'
    ProviderName=@('Microsoft-Windows-Kernel-Power','Microsoft-Windows-Power-Troubleshooter')
    StartTime=$start
  } -ErrorAction SilentlyContinue | Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message
  $ev | Format-Table -AutoSize | Out-String | Save-Text 'recent_power_events.txt'
} catch {
  Save-Text 'recent_power_events.txt' "Error reading events: $($_.Exception.Message)"
}

# ---------- Parse a short human summary ----------
function Parse-PowerCfgA {
  param([string[]]$Lines)
  $summary = [ordered]@{
    Available   = @()
    NotAvailable= @()
    Raw         = ($Lines -join "`n")
  }
  $section = ''
  foreach ($line in $Lines) {
    if ($line -match 'The following sleep states are available') { $section = 'avail'; continue }
    if ($line -match 'The following sleep states are not available') { $section = 'notavail'; continue }
    if ($line.Trim().Length -eq 0) { continue }
    if ($section -eq 'avail')    { if ($line -match '^\s*(.+?)\s+($|:)') { $summary.Available += $Matches[1].Trim() } }
    if ($section -eq 'notavail') {
      if ($line -match '^\s*(.+?)\s+($|:)') {
        $state = $Matches[1].Trim()
        # capture following indented reasons
        $reasons = @()
        continue
      }
    }
  }
  return $summary
}

try {
  $powa = (cmd /c 'powercfg /a') 2>&1
  $pSummary = Parse-PowerCfgA -Lines $powa
} catch {
  $pSummary = @{ Available=@(); NotAvailable=@(); Raw="(error running powercfg /a)" }
}

# High-level booleans from registry/policy
function AsBool($v) { if ($null -eq $v) { $null } else { [int]$v -ne 0 } }
$map = $regResults | Group-Object Path,Name -AsHashTable -AsString
$summary = [ordered]@{
  Machine              = $sys.ComputerName
  OS_Build             = $sys.OS_Build
  IsRdpSession         = $sys.IsRdpSession
  DomainJoined         = $sys.PartOfDomain
  BatteryPresent       = $sys.BatteryPresent
  SleepMenuHidden_PolicyCSP  = (AsBool ($map['HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start\HideSleep, value'].Value))
  SleepMenuHidden_ExplorerGP = (AsBool ($map['HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer, ShowSleepOption'].Value) -eq $false)
  HidePowerOptions_All        = (AsBool ($map['HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer, HidePowerOptions'].Value)) -or
                                (AsBool ($map['HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer, NoClose'].Value))
  PlatformAoAcOverride  = $map['HKLM:\SYSTEM\CurrentControlSet\Control\Power, PlatformAoAcOverride'].Value
  CsEnabled             = $map['HKLM:\SYSTEM\CurrentControlSet\Control\Power, CsEnabled'].Value
  HibernateEnabled      = $map['HKLM:\SYSTEM\CurrentControlSet\Control\Power, HibernateEnabled'].Value
  AllowStandby_AC_Policy = $map['HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\abfc2519-3608-4c2a-94ea-171b0ed546ab, ACSettingIndex'].Value
  AllowStandby_DC_Policy = $map['HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\abfc2519-3608-4c2a-94ea-171b0ed546ab, DCSettingIndex'].Value
  PowerCfg_Available    = $pSummary.Available
}
$summary | ConvertTo-Json -Depth 5 | Out-File -Encoding UTF8 (Join-Path $root 'SUMMARY.json')

# A small human-readable summary
$lines = @()
$lines += "Sleep Diagnostics Summary for $($sys.ComputerName)  ($([DateTime]::Now))"
$lines += "OS: $($sys.OS_Caption) build $($sys.OS_Build)   Model: $($sys.Manufacturer) $($sys.Model)"
$lines += "DomainJoined: $($sys.PartOfDomain)   RDP: $($sys.IsRdpSession)   BatteryPresent: $($sys.BatteryPresent)"
$lines += ""
$lines += "Policy/Registry flags that can HIDE Sleep:"
$lines += "  Policy CSP Start/HideSleep (device): $($summary.SleepMenuHidden_PolicyCSP)"
$lines += "  Explorer policy ShowSleepOption (HKLM\\...\\Policies\\...\\Explorer): $($map['HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer, ShowSleepOption'].Value)"
$lines += "  System/User HidePowerOptions/NoClose: $($summary.HidePowerOptions_All)"
$lines += ""
$lines += "Allow standby (S1-S3) policy (disabling blocks legacy sleep):"
$lines += "  ACSettingIndex=$($summary.AllowStandby_AC_Policy)   DCSettingIndex=$($summary.AllowStandby_DC_Policy)"
$lines += ""
$lines += "Modern Standby (S0) toggles:"
$lines += "  PlatformAoAcOverride=$($summary.PlatformAoAcOverride)   CsEnabled=$($summary.CsEnabled)"
$lines += "  HibernateEnabled=$($summary.HibernateEnabled)"
$lines += ""
$lines += "powercfg /a - Available states:"
$lines += ("  " + ($summary.PowerCfg_Available -join ', '))
$lines += ""
$lines += "See raw files in this folder for details."
Save-Text 'SUMMARY.txt' ($lines -join "`r`n")

# ---------- Systeminfo (includes Hyper-V hints) ----------
Save-Command 'systeminfo.txt' 'cmd.exe' '/c systeminfo'

# ---------- Wrap up ----------
Stop-Transcript | Out-Null
$zip = Join-Path $env:USERPROFILE "Desktop\SleepDiagnostics_$($env:COMPUTERNAME)_$timestamp.zip"
Compress-Archive -Path "$root\*" -DestinationPath $zip -Force
Write-Host "`nDone. Folder:`n$root`nZIP:`n$zip"
