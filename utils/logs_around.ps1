param(
    [datetime]$EventTime = (Get-Date "2/24/2025 3:10:23 AM"),
    [int]$TargetEventId = 1074,
    [int]$WindowMinutes = 2
)

$startTime = $EventTime.AddMinutes(-$WindowMinutes)
$endTime   = $EventTime.AddMinutes($WindowMinutes)

Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    StartTime = $startTime
    EndTime   = $endTime
} |
Where-Object {
    $_.LevelDisplayName -eq "Error" -or $_.Id -eq $TargetEventId
} |
Format-List TimeCreated, Id, LevelDisplayName, Message
