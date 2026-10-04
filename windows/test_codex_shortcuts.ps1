# Offline PowerShell shortcut tests. Run in a disposable process:
#   powershell.exe -NoProfile -File ./test_codex_shortcuts.ps1
# Mocks throw if help tries to invoke Codex or read an English request.
# No model calls or destructive actions are performed.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/codex-shortcuts.ps1"

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function codex { throw 'FAIL: help invoked Codex.' }
function Read-Host { throw 'FAIL: help attempted to read a request.' }

$oldOpenAI = [Environment]::GetEnvironmentVariable('OPENAI_API_KEY', 'Process')
$oldCodex = [Environment]::GetEnvironmentVariable('CODEX_API_KEY', 'Process')
$cases = 0
try {
    $env:OPENAI_API_KEY = 'test-api-marker'
    $env:CODEX_API_KEY = 'test-codex-marker'
    foreach ($mode in @('ask', 'act')) {
        foreach ($flag in @('--help', '-h')) {
            foreach ($prefix in @('', '--host', '-HostAccess')) {
                # Keep a one-element result as an array when splatting it.
                $words = @(if ($prefix) { $prefix; $flag } else { $flag })
                $global:LASTEXITCODE = 91
                $text = (& $mode @words | Out-String)
                Assert-True ($LASTEXITCODE -eq 0) "$mode $words returned a failure status."
                foreach ($section in @('USAGE', 'EXAMPLES', 'PERMISSIONS', 'OPTIONS',
                                        'INPUT AND QUOTING', 'RAW INPUT', 'SETUP',
                                        'POWERSHELL HELP', 'OUTPUT AND STATUS')) {
                    Assert-True ($text.Contains($section)) "Missing $section for $mode $words."
                }
                Assert-True ($text.StartsWith("$mode - ")) 'Wrong mode in help heading.'
                $cases++
            }
        }
    }
    Push-Location Env:
    try {
        foreach ($mode in @('ask', 'act')) {
            $text = (& $mode --help | Out-String)
            Assert-True ($LASTEXITCODE -eq 0) "Help failed from Env: for $mode."
            Assert-True ($text.Contains('USAGE')) "Missing help from Env: for $mode."
            $cases++
        }
    }
    finally { Pop-Location }

    foreach ($mode in @('ask', 'act')) {
        $text = (Get-Help $mode -Detailed | Out-String)
        Assert-True ($text.Contains('one-shot English request') -or
                     $text.Contains('one-shot English')) "Comment help not found for $mode."
        Assert-True ($text.Contains('ChatGPT')) "Missing authentication note for $mode."
        Assert-True ($text.Contains('--help')) "Missing usage example for $mode."
        $cases++
    }
    Assert-True ($env:OPENAI_API_KEY -eq 'test-api-marker') 'Help changed OPENAI_API_KEY.'
    Assert-True ($env:CODEX_API_KEY -eq 'test-codex-marker') 'Help changed CODEX_API_KEY.'
    $text = (act --help empty ./temp | Out-String)
    Assert-True ($LASTEXITCODE -eq 0 -and $text.Contains('USAGE')) 'Help executed task text.'
    $cases++
    Write-Host "PASS: $cases help checks; no Codex invocation or input prompt."

    # Capture the real wrapper's arguments and stdin without starting Codex.
    function codex {
        $script:capturedWords = @($args)
        $script:capturedPrompt = $input | Out-String
        Assert-True (-not $env:OPENAI_API_KEY -and -not $env:CODEX_API_KEY) 'Credentials leaked to Codex.'
        $global:LASTEXITCODE = 17
    }
    foreach ($mode in @('ask', 'act')) {
        & $mode rename 'old report.txt' to 'new report.txt'
        Assert-True ($LASTEXITCODE -eq 17) 'Codex status was not preserved.'
        $sandboxIndex = [array]::IndexOf($script:capturedWords, '--sandbox')
        $expectedSandbox = if ($mode -eq 'ask') { 'read-only' } else { 'danger-full-access' }
        Assert-True ($script:capturedWords[$sandboxIndex + 1] -eq $expectedSandbox) 'Wrong sandbox.'
        $requestWords = (($script:capturedPrompt -split "Request:\r?\n", 2)[1] | ConvertFrom-Json)
        Assert-True ($requestWords.Count -eq 4 -and $requestWords[1] -eq 'old report.txt' -and $requestWords[3] -eq 'new report.txt') 'Grouped arguments were lost.'
        Assert-True ($env:OPENAI_API_KEY -eq 'test-api-marker' -and $env:CODEX_API_KEY -eq 'test-codex-marker') 'Credentials were not restored.'
    }
    ask --host inspect processes
    $sandboxIndex = [array]::IndexOf($script:capturedWords, '--sandbox')
    Assert-True ($script:capturedWords[$sandboxIndex + 1] -eq 'danger-full-access') '--host was not forwarded.'
    # PowerShell may consume a typed -- itself; pass the literal token as data.
    Invoke-CodexShortcut -Mode ask -Words @('--', '--help')
    Assert-True ($LASTEXITCODE -eq 17 -and $script:capturedPrompt.Contains('["--help"]')) 'Literal help became wrapper help.'
    function Read-Host { 'inspect "my folder"; $(this is text)' }
    ask
    Assert-True ($script:capturedPrompt.Contains('inspect "my folder"; $(this is text)')) 'Raw input changed.'

    # Test the Command Prompt -File entry point, including a helper path with
    # spaces. A fake codex.cmd consumes stdin and returns a distinct exit code.
    $testDirectory = Join-Path ([IO.Path]::GetTempPath()) ('pcprep shortcuts ' + [guid]::NewGuid())
    $oldPath = $env:PATH
    $oldCapture = $env:PCPREP_SHORTCUT_CAPTURE
    New-Item -ItemType Directory -Path $testDirectory | Out-Null
    try {
        $entry = Join-Path $testDirectory 'codex-shortcuts.ps1'
        Copy-Item -LiteralPath "$PSScriptRoot/codex-shortcuts.ps1" -Destination $entry
        $env:PCPREP_SHORTCUT_CAPTURE = Join-Path $testDirectory 'capture.txt'
        $mock = '@echo off' + "`r`n" + 'more > "%PCPREP_SHORTCUT_CAPTURE%"' + "`r`n" + 'exit /b 17' + "`r`n"
        [IO.File]::WriteAllText((Join-Path $testDirectory 'codex.cmd'), $mock, [Text.Encoding]::ASCII)
        $env:PATH = $testDirectory + ';' + $oldPath
        $powerShellExe = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
        foreach ($mode in @('ask', 'act')) {
            $output = & $powerShellExe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $entry $mode --help
            Assert-True ($LASTEXITCODE -eq 0 -and ($output -join "`n").Contains('USAGE')) '-File help failed.'
            Assert-True (-not (Test-Path -LiteralPath $env:PCPREP_SHORTCUT_CAPTURE)) '-File help invoked Codex.'
        }
        & $powerShellExe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $entry ask rename 'old report.txt' to 'new report.txt' '$(throw BAD); literal'
        Assert-True ($LASTEXITCODE -eq 17) '-File lost the Codex exit code.'
        $captured = [IO.File]::ReadAllText($env:PCPREP_SHORTCUT_CAPTURE)
        $requestWords = (($captured -split "Request:\r?\n", 2)[1] | ConvertFrom-Json)
        Assert-True ($requestWords.Count -eq 5 -and $requestWords[1] -eq 'old report.txt' -and $requestWords[4] -eq '$(throw BAD); literal') '-File interpreted or split request text.'
        Write-Host 'PASS: sandbox, quoting, raw input, credentials, exit status, and Windows -File checks.'
    }
    finally {
        $env:PATH = $oldPath
        $env:PCPREP_SHORTCUT_CAPTURE = $oldCapture
        # Only remove the uniquely named test directory under the OS temp path.
        $resolvedTest = [IO.Path]::GetFullPath($testDirectory)
        $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if (-not $resolvedTest.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected test cleanup path.' }
        Remove-Item -LiteralPath $resolvedTest -Recurse -Force
    }
}
finally {
    [Environment]::SetEnvironmentVariable('OPENAI_API_KEY', $oldOpenAI, 'Process')
    [Environment]::SetEnvironmentVariable('CODEX_API_KEY', $oldCodex, 'Process')
    Remove-Item Function:codex, Function:Read-Host -ErrorAction SilentlyContinue
}
