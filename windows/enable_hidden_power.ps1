#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
Shows a conservative allowlist of useful advanced power settings.

.DESCRIPTION
Changes only the visibility attribute of selected power settings. It does not
change a power plan, activate a plan, or change any AC/DC setting value.

Use -WhatIf to preview the changes. Use -Undo to hide the same allowlisted
settings again.

.PARAMETER Undo
Hides the allowlisted settings instead of showing them.

.EXAMPLE
.\enable_hidden_power.ps1 -WhatIf

.EXAMPLE
.\enable_hidden_power.ps1

.EXAMPLE
.\enable_hidden_power.ps1 -Undo
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [switch] $Undo
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$powerCfgPath = Join-Path $env:SystemRoot 'System32\powercfg.exe'

# These settings were selected for this PC after checking its supported sleep
# states and hardware. Deliberately excluded are S3/hybrid-sleep, battery, lid,
# presence-sensor, internal-brightness, storage-driver tuning, and most low-level
# processor/OEM tuning settings. Processor boost mode is included because it is
# a useful high-level control and was previously exposed by a separate .reg file.
$settings = @(
    [pscustomobject]@{
        Name                  = 'Require a password on wakeup'
        SubgroupGuid          = 'fea3413e-7e05-4911-9a71-700331f1c294'
        SettingGuid           = '0e796bdb-100d-47d6-a2d5-f7d2daa51f51'
        RequiresModernStandby = $false
    }
    [pscustomobject]@{
        Name                  = 'Device idle policy'
        SubgroupGuid          = 'fea3413e-7e05-4911-9a71-700331f1c294'
        SettingGuid           = '4faab71a-92e5-4726-b531-224559672d19'
        RequiresModernStandby = $false
    }
    [pscustomobject]@{
        Name                  = 'Disconnected Standby Mode'
        SubgroupGuid          = 'fea3413e-7e05-4911-9a71-700331f1c294'
        SettingGuid           = '68afb2d9-ee95-47a8-8f50-4115088073b1'
        RequiresModernStandby = $true
    }
    [pscustomobject]@{
        Name                  = 'Networking connectivity in Standby'
        SubgroupGuid          = 'fea3413e-7e05-4911-9a71-700331f1c294'
        SettingGuid           = 'f15576e8-98b7-4186-b944-eafa664402d9'
        RequiresModernStandby = $true
    }
    [pscustomobject]@{
        Name                  = 'Adaptive display'
        SubgroupGuid          = '7516b95f-f776-4464-8c53-06167f40cc99'
        SettingGuid           = '90959d22-d6a1-49b9-af93-bce885ad335b'
        RequiresModernStandby = $false
    }
    [pscustomobject]@{
        Name                  = 'Allow display required policy'
        SubgroupGuid          = '7516b95f-f776-4464-8c53-06167f40cc99'
        SettingGuid           = 'a9ceb8da-cd46-44fb-a98b-02af69de4623'
        RequiresModernStandby = $false
    }
    [pscustomobject]@{
        Name                  = 'Console lock display off timeout'
        SubgroupGuid          = '7516b95f-f776-4464-8c53-06167f40cc99'
        SettingGuid           = '8ec4b3a5-6868-48c2-be75-4f3044be88a7'
        RequiresModernStandby = $false
    }
    [pscustomobject]@{
        Name                  = 'Power button action'
        SubgroupGuid          = '4f971e89-eebd-4455-a8de-9e59040e7347'
        SettingGuid           = '7648efa3-dd9c-4e3e-b566-50f929386280'
        RequiresModernStandby = $false
    }
    [pscustomobject]@{
        Name                  = 'Processor performance boost mode'
        SubgroupGuid          = '54533251-82be-4824-96c1-47b60b740d00'
        SettingGuid           = 'be337238-0d82-4146-a960-4f3749d470c7'
        RequiresModernStandby = $false
    }
    [pscustomobject]@{
        Name                  = 'Allow system required policy'
        SubgroupGuid          = '238c9fa8-0aad-41ed-83f4-97be242c8f20'
        SettingGuid           = 'a4b195f5-8225-47d8-8012-9d41369786e2'
        RequiresModernStandby = $false
    }
    [pscustomobject]@{
        Name                  = 'Allow sleep with remote opens'
        SubgroupGuid          = '238c9fa8-0aad-41ed-83f4-97be242c8f20'
        SettingGuid           = 'd4c1d4c8-d5cc-43d3-b83e-fc51215cb04d'
        RequiresModernStandby = $false
    }
    [pscustomobject]@{
        Name                  = 'USB 3 Link Power Management'
        SubgroupGuid          = '2a737441-1930-4402-8d77-b2bebba308a3'
        SettingGuid           = 'd4e98f31-5ffe-4ce1-be31-1b38b384c009'
        RequiresModernStandby = $false
    }
)

function Invoke-PowerCfg {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    $output = & $powerCfgPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $message = ($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
        throw "powercfg.exe failed with exit code $exitCode.$([Environment]::NewLine)$message"
    }

    return $output
}

function Test-SettingIsVisible {
    param(
        [Parameter(Mandatory = $true)]
        [string] $PowerCfgQueryOutput,

        [Parameter(Mandatory = $true)]
        [string] $SettingGuid
    )

    return $PowerCfgQueryOutput.IndexOf($SettingGuid, [StringComparison]::OrdinalIgnoreCase) -ge 0
}

$sleepStateOutput = (Invoke-PowerCfg -Arguments @('/availablesleepstates')) -join [Environment]::NewLine
$hasModernStandby = $sleepStateOutput -match 'Standby \(S0 Low Power Idle\)'
$allSettingsQueryOutput = (Invoke-PowerCfg -Arguments @('/qh')) -join [Environment]::NewLine
$initialQueryOutput = (Invoke-PowerCfg -Arguments @('/query')) -join [Environment]::NewLine
$attributeAction = if ($Undo) { '+ATTRIB_HIDE' } else { '-ATTRIB_HIDE' }
$desiredState = if ($Undo) { 'Hidden' } else { 'Visible' }
$results = [System.Collections.Generic.List[object]]::new()
$changedSettings = [System.Collections.Generic.List[object]]::new()

foreach ($setting in $settings) {
    $isInstalled = $allSettingsQueryOutput.IndexOf(
        $setting.SettingGuid,
        [StringComparison]::OrdinalIgnoreCase
    ) -ge 0
    if (-not $isInstalled) {
        $results.Add([pscustomobject]@{
            Setting = $setting.Name
            Result  = 'Skipped: setting is not installed'
        })
        continue
    }

    if ($setting.RequiresModernStandby -and -not $hasModernStandby) {
        $results.Add([pscustomobject]@{
            Setting = $setting.Name
            Result  = 'Skipped: Modern Standby is not available'
        })
        continue
    }

    $isVisible = Test-SettingIsVisible `
        -PowerCfgQueryOutput $initialQueryOutput `
        -SettingGuid $setting.SettingGuid

    if (($isVisible -and -not $Undo) -or (-not $isVisible -and $Undo)) {
        $results.Add([pscustomobject]@{
            Setting = $setting.Name
            Result  = "Already $($desiredState.ToLowerInvariant())"
        })
        continue
    }

    $target = "$($setting.Name) [$($setting.SettingGuid)]"
    $operation = "Make advanced power setting $($desiredState.ToLowerInvariant())"
    if ($PSCmdlet.ShouldProcess($target, $operation)) {
        Invoke-PowerCfg -Arguments @(
            '-attributes',
            $setting.SubgroupGuid,
            $setting.SettingGuid,
            $attributeAction
        ) | Out-Null

        $changedSettings.Add($setting)
        $results.Add([pscustomobject]@{
            Setting = $setting.Name
            Result  = "Changed to $desiredState"
        })
    }
    else {
        $results.Add([pscustomobject]@{
            Setting = $setting.Name
            Result  = "Preview: would change to $desiredState"
        })
    }
}

if ($changedSettings.Count -gt 0) {
    $finalQueryOutput = (Invoke-PowerCfg -Arguments @('/query')) -join [Environment]::NewLine
    foreach ($setting in $changedSettings) {
        $isVisible = Test-SettingIsVisible `
            -PowerCfgQueryOutput $finalQueryOutput `
            -SettingGuid $setting.SettingGuid

        $verified = if ($Undo) { -not $isVisible } else { $isVisible }
        if (-not $verified) {
            throw "Visibility verification failed for '$($setting.Name)'."
        }
    }
}

$results
