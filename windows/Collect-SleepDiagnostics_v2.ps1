<#
Collect-SleepDiagnostics_v2.ps1
- Fast, step-timed collector for "Sleep option missing" diagnosis.
- Produces a single Markdown report under C:\temp.

USAGE EXAMPLES:
  .\Collect-SleepDiagnostics_v2.ps1
  .\Collect-SleepDiagnostics_v2.ps1 -Deep -TimeoutSec 30 -MaxEvents 250

PARAMS:
  -Deep           : also run extended diagnostics (powercfg /energy etc.). Skipped in single-file mode.
  -TimeoutSec     : per external-command timeout (seconds). Default 20.
  -MaxEvents      : cap power-related events read from System log. Default 150.
  -NoZip          : retained for backward compatibility; ignored.
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

$outputDir = 'C:\temp'
if (-not (Test-Path $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}
$timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportPath = Join-Path $outputDir ("SleepDiag_{0}_{1}.md" -f $env:COMPUTERNAME, $timestamp)
$script:LogEntries = [System.Collections.Generic.List[string]]::new()

function Write-Log {
  param([string]$Message, [string]$Level = 'INFO')
  $line = "[{0:HH:mm:ss}] [{1}] {2}" -f (Get-Date), $Level, $Message
  Write-Host $line
  $script:LogEntries.Add($line) | Out-Null
}

function New-Stopwatch {
  [System.Diagnostics.Stopwatch]::StartNew()
}

function Invoke-External {
  param(
    [Parameter(Mandatory)] [string]$Exe,
    [Parameter(Mandatory)] [string]$Args,
    [int]$Timeout = $TimeoutSec
  )

  $sw = New-Stopwatch
  Write-Log "RUN: $Exe $Args (timeout ${Timeout}s)"

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $Exe
  $psi.Arguments = $Args
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true

  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi

  $null = $proc.Start()
  if (-not $proc.WaitForExit($Timeout * 1000)) {
    try { $proc.Kill() } catch {}
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    Write-Log ("TIMEOUT after {0}s" -f $Timeout) 'WARN'
    return [pscustomobject]@{
      Command  = "$Exe $Args"
      ExitCode = $null
      TimedOut = $true
      Duration = $sw.Elapsed.TotalSeconds
      StdOut   = $stdout
      StdErr   = $stderr
    }
  }

  $stdout = $proc.StandardOutput.ReadToEnd()
  $stderr = $proc.StandardError.ReadToEnd()
  $exit   = $proc.ExitCode
  Write-Log ("OK in {0:n2}s (exit {1})" -f $sw.Elapsed.TotalSeconds, $exit)
  return [pscustomobject]@{
    Command  = "$Exe $Args"
    ExitCode = $exit
    TimedOut = $false
    Duration = $sw.Elapsed.TotalSeconds
    StdOut   = $stdout
    StdErr   = $stderr
  }
}

function Get-RegValue {
  param([string]$Path, [string]$Name)
  try {
    Write-Log "REG READ: Get-ItemProperty -Path '$Path' -Name '$Name'"
    $val = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop | Select-Object -ExpandProperty $Name
    [pscustomobject]@{ Path = $Path; Name = $Name; Value = $val; Error = $null }
  } catch {
    [pscustomobject]@{ Path = $Path; Name = $Name; Value = $null; Error = $_.Exception.Message }
  }
}

function Format-MarkdownValue {
  param($Value)
  if ($null -eq $Value) { return '' }
  if ($Value -is [datetime]) { return $Value.ToString('u') }
  if ($Value -is [bool]) { return $Value.ToString().ToLower() }
  if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
    $items = @()
    foreach ($item in $Value) {
      if ($null -ne $item -and ($item -ne '')) {
        $items += (Format-MarkdownValue -Value $item)
      }
    }
    return ($items -join '<br>')
  }
  $text = [string]$Value
  $text = $text -replace '\|', '\\|'
  $text = $text -replace "`r?`n", '<br>'
  return $text
}

function Add-Line {
  param(
    [System.Text.StringBuilder]$Builder,
    [string]$Line
  )
  [void]$Builder.AppendLine($Line)
}

function Add-TableRow {
  param(
    [System.Text.StringBuilder]$Builder,
    [string]$Name,
    $Value,
    [string]$Extra = ''
  )
  $val = Format-MarkdownValue -Value $Value
  $extraVal = if ($Extra) { Format-MarkdownValue -Value $Extra } else { '' }
  if ($extraVal) {
    [void]$Builder.AppendLine("| $Name | $val | $extraVal |")
  } else {
    [void]$Builder.AppendLine("| $Name | $val |")
  }
}

# ----------------------- Data Collection -----------------------
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Log "IsAdministrator=$IsAdmin"

Write-Log "STEP 1: System & session basics"
$os   = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$cs   = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
$cpu  = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
$gpu  = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object Name, DriverVersion, DriverDate, PNPDeviceID
$rdpSession = $env:SESSIONNAME -like 'RDP*'
$batt = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue

$sysInfo = [pscustomobject]@{
  ComputerName   = $env:COMPUTERNAME
  Manufacturer   = $cs.Manufacturer
  Model          = $cs.Model
  SystemType     = $cs.SystemType
  DomainJoined   = $cs.PartOfDomain
  Domain         = $cs.Domain
  BIOS_Version   = $bios.SMBIOSBIOSVersion
  BIOS_Release   = $bios.ReleaseDate
  OS_Caption     = $os.Caption
  OS_Version     = $os.Version
  OS_Build       = $os.BuildNumber
  CPU_Name       = $cpu.Name
  RdpSession     = $rdpSession
  BatteryPresent = [bool]$batt
}

Write-Log "STEP 2: Policy/UI toggles that can hide Sleep (Start/Explorer/MDM)"
$policyChecks = @(
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name='ShowSleepOption' },
  @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'; Name='ShowSleepOption' },
  @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'; Name='ShowHibernateOption' },
  @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'; Name='ShowLockOption' },
  @{ Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start'; Name='HideSleep' },
  @{ Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start'; Name='HideSleep' },
  @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='HidePowerOptions' },
  @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='HidePowerOptions' },
  @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='NoClose' },
  @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='NoClose' }
)
$policyResults = foreach ($q in $policyChecks) { Get-RegValue @q }
$policyResultsSorted = $policyResults | Sort-Object Path, Name

Write-Log "STEP 3: Power policy (ALLOWSTANDBY S1-S3 & HybridSleep) via registry-backed policies"
$powerPolicyChecks = @(
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\abfc2519-3608-4c2a-94ea-171b0ed546ab'; Name='ACSettingIndex' },
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\abfc2519-3608-4c2a-94ea-171b0ed546ab'; Name='DCSettingIndex' },
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\94ac6d29-73ce-41a6-809f-6363ba21b47e'; Name='ACSettingIndex' },
  @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\94ac6d29-73ce-41a6-809f-6363ba21b47e'; Name='DCSettingIndex' },
  @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name='HibernateEnabled' },
  @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name='HiberbootEnabled' },
  @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name='CsEnabled' },
  @{ Path='HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name='PlatformAoAcOverride' }
)
$powerPolicyResults = foreach ($q in $powerPolicyChecks) { Get-RegValue @q }
$powerPolicySorted = $powerPolicyResults | Sort-Object Path, Name

Write-Log "STEP 4: powercfg queries"
$commandOutputs = [ordered]@{}
$commandOutputs['powercfg /a']                     = Invoke-External -Exe 'cmd.exe' -Args '/c powercfg /a'
$commandOutputs['powercfg -requests']             = Invoke-External -Exe 'cmd.exe' -Args '/c powercfg -requests'
$commandOutputs['powercfg -devicequery wake_armed']        = Invoke-External -Exe 'cmd.exe' -Args '/c powercfg -devicequery wake_armed'
$commandOutputs['powercfg -devicequery wake_programmable'] = Invoke-External -Exe 'cmd.exe' -Args '/c powercfg -devicequery wake_programmable'
$commandOutputs['powercfg -q scheme_current sub_sleep']    = Invoke-External -Exe 'cmd.exe' -Args '/c powercfg -q scheme_current sub_sleep'

if ($Deep) {
  Write-Log "Deep mode requested but powercfg /energy and /systemsleepdiagnostics outputs are skipped to keep single-file report" 'WARN'
}

Write-Log "STEP 5: Virtualization/Hyper-V/Device Guard footprint"
$hyperVState = 'Unavailable'
$wslState    = 'Unavailable'
try {
  $hvInfo = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction Stop
  $hyperVState = $hvInfo.State
} catch {
  $hyperVState = "Error: $($_.Exception.Message)"
}
try {
  $wslInfo = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction Stop
  $wslState = $wslInfo.State
} catch {
  $wslState = "Error: $($_.Exception.Message)"
}
try {
  $deviceGuard = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction Stop
} catch {
  $deviceGuard = $_.Exception.Message
}

Write-Log "STEP 6: AAD/Domain/GPO footprint (with timeouts)"
$commandOutputs['dsregcmd /status']            = Invoke-External -Exe 'cmd.exe' -Args '/c dsregcmd /status'
$commandOutputs['gpresult /scope user /r']     = Invoke-External -Exe 'cmd.exe' -Args '/c gpresult /scope user /r'
$commandOutputs['gpresult /scope computer /r'] = Invoke-External -Exe 'cmd.exe' -Args '/c gpresult /scope computer /r'

Write-Log "STEP 7: GPU driver + common Start menu replacements"
$displayAdapters = Get-PnpDevice -Class Display -Status OK -ErrorAction SilentlyContinue |
                   Select-Object FriendlyName, Manufacturer, DriverProviderName, DriverVersion, DriverDate
$uninstRoots = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$startVendors = 'Stardock','Open-Shell','Classic Shell','StartIsBack','StartAllBack','Start11','Start10'
$thirdPartyStart = foreach ($path in $uninstRoots) {
  Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
    $displayNameProp    = $_.PSObject.Properties['DisplayName']
    $publisherProp      = $_.PSObject.Properties['Publisher']
    $displayVersionProp = $_.PSObject.Properties['DisplayVersion']
    $installProp        = $_.PSObject.Properties['InstallLocation']

    $displayName    = if ($displayNameProp)    { [string]$displayNameProp.Value }    else { $null }
    $publisher      = if ($publisherProp)      { [string]$publisherProp.Value }      else { $null }
    $displayVersion = if ($displayVersionProp) { [string]$displayVersionProp.Value } else { $null }
    $install        = if ($installProp)        { [string]$installProp.Value }        else { $null }

    if (-not ($displayName -or $publisher)) { return }
    $matchesVendor = ($publisher -and ($startVendors -contains $publisher)) -or
                     ($displayName -and ($startVendors -contains $displayName))
    if (-not $matchesVendor) { return }

    [pscustomobject]@{
      DisplayName     = $displayName
      DisplayVersion  = $displayVersion
      Publisher       = $publisher
      InstallLocation = $install
    }
  }
}
$thirdPartyStart = $thirdPartyStart | Where-Object { $_ }

Write-Log "STEP 8: Recent Kernel-Power/Troubleshooter events (bounded)"
$recentEvents = @()
try {
  $start = (Get-Date).AddDays(-7)
  $recentEvents = Get-WinEvent -FilterHashtable @{
    LogName      = 'System'
    ProviderName = @('Microsoft-Windows-Kernel-Power','Microsoft-Windows-Power-Troubleshooter')
    StartTime    = $start
  } -ErrorAction SilentlyContinue -MaxEvents $MaxEvents |
  Select-Object -Property TimeCreated, Id, LevelDisplayName, ProviderName, Message
} catch {
  Write-Log "Event query failed: $($_.Exception.Message)" 'WARN'
}

Write-Log "STEP 9: Parse powercfg /a for availability & blockers"
$availableStates = @()
$blockedStates   = @()
$pcStdOut = $commandOutputs['powercfg /a'].StdOut
if ($pcStdOut) {
  $mode = 'none'
  foreach ($line in ($pcStdOut -split "`r?`n")) {
    if ($line -match 'The following sleep states are available on this system:') { $mode = 'avail'; continue }
    if ($line -match 'The following sleep states are not available on this system:') { $mode = 'na'; continue }
    if ($mode -eq 'avail' -and $line.Trim()) { $availableStates += $line.Trim() }
    if ($mode -eq 'na' -and $line.Trim())   { $blockedStates   += $line.Trim() }
  }
}

Write-Log "STEP 10: Build summary objects"
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
    AllowStandby_AC        = $powerMap['HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\abfc2519-3608-4c2a-94ea-171b0ed546ab|ACSettingIndex']
    AllowStandby_DC        = $powerMap['HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\abfc2519-3608-4c2a-94ea-171b0ed546ab|DCSettingIndex']
    HybridSleep_AC         = $powerMap['HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\94ac6d29-73ce-41a6-809f-6363ba21b47e|ACSettingIndex']
    HybridSleep_DC         = $powerMap['HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\94ac6d29-73ce-41a6-809f-6363ba21b47e|DCSettingIndex']
    HibernateEnabled       = $powerMap['HKLM:\SYSTEM\CurrentControlSet\Control\Power|HibernateEnabled']
    HiberbootEnabled       = $powerMap['HKLM:\SYSTEM\CurrentControlSet\Control\Power|HiberbootEnabled']
    CsEnabled              = $powerMap['HKLM:\SYSTEM\CurrentControlSet\Control\Power|CsEnabled']
    PlatformAoAcOverride   = $powerMap['HKLM:\SYSTEM\CurrentControlSet\Control\Power|PlatformAoAcOverride']
  }
  PowerCfgAvailable = $availableStates
  PowerCfgBlocked   = $blockedStates
}

Write-Log "STEP 11: systeminfo"
$commandOutputs['systeminfo'] = Invoke-External -Exe 'cmd.exe' -Args '/c systeminfo'

# ----------------------- Markdown generation -----------------------
$sb = New-Object System.Text.StringBuilder
Add-Line $sb "# Sleep Diagnostics Report"
Add-Line $sb ""
Add-Line $sb "*Generated:* $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Line $sb "*Computer:* $($summary.Computer)"
Add-Line $sb "*Report Path:* $reportPath"
Add-Line $sb ""

Add-Line $sb "## System & Session"
Add-Line $sb "| Property | Value |"
Add-Line $sb "| --- | --- |"
Add-TableRow $sb 'Manufacturer' $sysInfo.Manufacturer
Add-TableRow $sb 'Model' $sysInfo.Model
Add-TableRow $sb 'System Type' $sysInfo.SystemType
Add-TableRow $sb 'Domain Joined' $sysInfo.DomainJoined
Add-TableRow $sb 'Domain' $sysInfo.Domain
Add-TableRow $sb 'BIOS Version' $sysInfo.BIOS_Version
Add-TableRow $sb 'BIOS Release' $sysInfo.BIOS_Release
Add-TableRow $sb 'OS' $summary.OS
Add-TableRow $sb 'CPU' $sysInfo.CPU_Name
Add-TableRow $sb 'RDP Session' $sysInfo.RdpSession
Add-TableRow $sb 'Battery Present' $sysInfo.BatteryPresent
Add-Line $sb ""

Add-Line $sb "## Policy / UI Toggles"
Add-Line $sb "| Registry Path | Name | Value | Error |"
Add-Line $sb "| --- | --- | --- | --- |"
foreach ($item in $policyResultsSorted) {
  $valueText = if ($null -ne $item.Value) { Format-MarkdownValue $item.Value } else { '' }
  $errorText = if ($item.Error) { Format-MarkdownValue $item.Error } else { '' }
  Add-Line $sb "| $(Format-MarkdownValue $item.Path) | $(Format-MarkdownValue $item.Name) | $valueText | $errorText |"
}
Add-Line $sb ""

Add-Line $sb "## Power Policy"
Add-Line $sb "| Registry Path | Name | Value | Error |"
Add-Line $sb "| --- | --- | --- | --- |"
foreach ($item in $powerPolicySorted) {
  $valueText = if ($null -ne $item.Value) { Format-MarkdownValue $item.Value } else { '' }
  $errorText = if ($item.Error) { Format-MarkdownValue $item.Error } else { '' }
  Add-Line $sb "| $(Format-MarkdownValue $item.Path) | $(Format-MarkdownValue $item.Name) | $valueText | $errorText |"
}
Add-Line $sb ""

Add-Line $sb "## Powercfg Availability"
Add-Line $sb "### Available sleep states"
if ($availableStates.Count) {
  foreach ($state in $availableStates) { Add-Line $sb "- $state" }
} else {
  Add-Line $sb "- (none reported)"
}
Add-Line $sb ""
Add-Line $sb "### Unavailable sleep states"
if ($blockedStates.Count) {
  foreach ($state in $blockedStates) { Add-Line $sb "- $state" }
} else {
  Add-Line $sb "- (none reported)"
}
Add-Line $sb ""

Add-Line $sb "## Display Adapters"
if ($displayAdapters) {
  Add-Line $sb "| Friendly Name | Manufacturer | Driver Provider | Driver Version | Driver Date |"
  Add-Line $sb "| --- | --- | --- | --- | --- |"
  foreach ($adapter in $displayAdapters) {
    Add-Line $sb "| $(Format-MarkdownValue $adapter.FriendlyName) | $(Format-MarkdownValue $adapter.Manufacturer) | $(Format-MarkdownValue $adapter.DriverProviderName) | $(Format-MarkdownValue $adapter.DriverVersion) | $(Format-MarkdownValue $adapter.DriverDate) |"
  }
} else {
  Add-Line $sb "No display adapters reported (query may require elevation)."
}
Add-Line $sb ""

Add-Line $sb "## Third-party Start Menu Products"
if ($thirdPartyStart -and $thirdPartyStart.Count) {
  Add-Line $sb "| Display Name | Version | Publisher | Install Location |"
  Add-Line $sb "| --- | --- | --- | --- |"
  foreach ($app in $thirdPartyStart) {
    Add-Line $sb "| $(Format-MarkdownValue $app.DisplayName) | $(Format-MarkdownValue $app.DisplayVersion) | $(Format-MarkdownValue $app.Publisher) | $(Format-MarkdownValue $app.InstallLocation) |"
  }
} else {
  Add-Line $sb "No common Start menu replacements detected."
}
Add-Line $sb ""

Add-Line $sb "## Virtualization Features"
Add-Line $sb "| Feature | State |"
Add-Line $sb "| --- | --- |"
Add-TableRow $sb 'Microsoft-Hyper-V-All' $hyperVState
Add-TableRow $sb 'Microsoft-Windows-Subsystem-Linux' $wslState
Add-Line $sb ""

Add-Line $sb "## Device Guard / Virtualization Based Security"
if ($deviceGuard -is [string]) {
  Add-Line $sb $deviceGuard
} elseif ($null -ne $deviceGuard) {
  Add-Line $sb "| Property | Value |"
  Add-Line $sb "| --- | --- |"
  foreach ($prop in $deviceGuard.PSObject.Properties) {
    Add-TableRow $sb $prop.Name $prop.Value
  }
} else {
  Add-Line $sb "DeviceGuard info not available."
}
Add-Line $sb ""

Add-Line $sb "## Recent Power-related Events"
if ($recentEvents -and $recentEvents.Count) {
  $topEvents = $recentEvents | Select-Object -First 10
  Add-Line $sb "| TimeCreated | Id | Level | Provider | Message |"
  Add-Line $sb "| --- | --- | --- | --- | --- |"
  foreach ($evt in $topEvents) {
    Add-Line $sb "| $(Format-MarkdownValue $evt.TimeCreated) | $(Format-MarkdownValue $evt.Id) | $(Format-MarkdownValue $evt.LevelDisplayName) | $(Format-MarkdownValue $evt.ProviderName) | $(Format-MarkdownValue ($evt.Message -replace '\s+',' ')) |"
  }
  if ($recentEvents.Count -gt 10) {
    Add-Line $sb ""
    Add-Line $sb "_Showing first 10 of $($recentEvents.Count) events_"
  }
} else {
  Add-Line $sb "No matching events in the last 7 days (MaxEvents=$MaxEvents) or access denied."
}
Add-Line $sb ""

Add-Line $sb "## Summary Snapshot"
Add-Line $sb "| Item | Value |"
Add-Line $sb "| --- | --- |"
Add-TableRow $sb 'AllowStandby AC/DC' ("AC=$($summary.PowerPolicy.AllowStandby_AC) / DC=$($summary.PowerPolicy.AllowStandby_DC)")
Add-TableRow $sb 'HybridSleep AC/DC' ("AC=$($summary.PowerPolicy.HybridSleep_AC) / DC=$($summary.PowerPolicy.HybridSleep_DC)")
Add-TableRow $sb 'HibernateEnabled' $summary.PowerPolicy.HibernateEnabled
Add-TableRow $sb 'HiberbootEnabled' $summary.PowerPolicy.HiberbootEnabled
Add-TableRow $sb 'CsEnabled' $summary.PowerPolicy.CsEnabled
Add-TableRow $sb 'PlatformAoAcOverride' $summary.PowerPolicy.PlatformAoAcOverride
Add-Line $sb ""

Add-Line $sb "## Command Outputs"
foreach ($entry in $commandOutputs.GetEnumerator()) {
  Add-Line $sb "### $($entry.Key)"
  if ($entry.Value.TimedOut) {
    Add-Line $sb ("> Timed out after {0}s" -f $TimeoutSec)
  } else {
    Add-Line $sb ("> Exit code: {0} (duration {1:n2}s)" -f $entry.Value.ExitCode, $entry.Value.Duration)
  }
  if ($entry.Value.StdOut) {
    Add-Line $sb "```"
    foreach ($line in ($entry.Value.StdOut -split "`r?`n")) {
      Add-Line $sb $line
    }
    Add-Line $sb "```"
  }
  if ($entry.Value.StdErr) {
    Add-Line $sb "_STDERR:_"
    Add-Line $sb "```"
    foreach ($line in ($entry.Value.StdErr -split "`r?`n")) {
      Add-Line $sb $line
    }
    Add-Line $sb "```"
  }
  Add-Line $sb ""
}

Add-Line $sb "## Execution Log"
foreach ($entry in $LogEntries) {
  Add-Line $sb "- $entry"
}
Add-Line $sb ""

$markdown = $sb.ToString().TrimEnd() + "`r`n"
Set-Content -Path $reportPath -Value $markdown -Encoding utf8

Write-Host "`nReport written to: $reportPath"
