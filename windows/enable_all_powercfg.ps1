# Get all power settings including hidden ones
$powerSettings = powercfg /qh

# Regular expression to capture GUIDs
$guidRegex = '(?<=\s\s)([\da-fA-F]{8}-(?:[\da-fA-F]{4}-){3}[\da-fA-F]{12})(?=\:)'

# Find all matches
$guidMatches = [regex]::Matches($powerSettings, $guidRegex)

# Loop through each GUID and unhide the setting
foreach ($match in $guidMatches) {
    $guid = $match.Value
    # Use powercfg to unhide the setting
    powercfg -attributes $guid -ATTRIB_HIDE
}

# Output to the user
Write-Output "All power settings are now visible in Advanced Power Options."
