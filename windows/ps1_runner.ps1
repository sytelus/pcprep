# Runs the .ps1 file corresponding to the command-file path supplied as the
# first argument by ps1.cmd, forwarding every remaining argument.
param(
    [string] $CommandPath
)

$scriptPath = [System.IO.Path]::ChangeExtension($CommandPath, '.ps1')
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    Write-Error "PowerShell script was not found: $scriptPath"
    exit 1
}

$scriptArguments = @($args)
$powershellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $powershellExe -PathType Leaf)) {
    Write-Error "Windows PowerShell was not found: $powershellExe"
    exit 1
}

& $powershellExe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @ScriptArguments
exit $LASTEXITCODE
