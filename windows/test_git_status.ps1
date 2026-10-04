#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$gitExecutable = (Get-Command git.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('pcprep git status ' + [guid]::NewGuid())
$projects = Join-Path $testRoot 'projects with spaces'
$helper = Join-Path $PSScriptRoot 'git-status.ps1'

function Assert-Status {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-TestGit {
    param([string] $Directory, [string[]] $Arguments)
    $ErrorActionPreference = 'Continue'
    $output = @(& $gitExecutable -c user.name=StatusTest -c user.email=status-test@example.invalid `
        -c commit.gpgsign=false -c core.autocrlf=false -C $Directory @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw ('Git fixture failed: ' + ($output -join ' ')) }
}

function New-TestRepository {
    param([string] $Directory, [switch] $Unborn)
    New-Item -ItemType Directory -Path $Directory | Out-Null
    Invoke-TestGit $Directory @('init', '--quiet', '--initial-branch=main')
    if (-not $Unborn) { Invoke-TestGit $Directory @('commit', '--quiet', '--allow-empty', '-m', 'initial') }
}

New-Item -ItemType Directory -Path $projects | Out-Null
try {
    # All remotes are local temporary directories; no provider is contacted.
    $remote = Join-Path $testRoot 'remote.git'
    Invoke-TestGit $testRoot @('init', '--quiet', '--bare', '--initial-branch=main', $remote)
    $seed = Join-Path $testRoot 'seed'
    New-TestRepository $seed
    Invoke-TestGit $seed @('remote', 'add', 'origin', $remote)
    Invoke-TestGit $seed @('push', '--quiet', '--set-upstream', 'origin', 'main')

    foreach ($name in @('synced', 'ahead', 'dirty-ahead', 'behind', 'diverged', 'detached', 'missing-upstream')) {
        Invoke-TestGit $projects @('clone', '--quiet', $remote, (Join-Path $projects $name))
    }
    foreach ($name in @('ahead', 'dirty-ahead', 'diverged')) {
        # Same-tree commits must still count as unpushed.
        Invoke-TestGit (Join-Path $projects $name) @('commit', '--quiet', '--allow-empty', '-m', 'local commit')
    }
    Invoke-TestGit (Join-Path $projects 'ahead') @('config', 'status.aheadBehind', 'false')
    Set-Content -LiteralPath (Join-Path $projects 'dirty-ahead/status notes.txt') -Value 'untracked change'
    Invoke-TestGit (Join-Path $projects 'detached') @('checkout', '--quiet', '--detach')
    Invoke-TestGit (Join-Path $projects 'missing-upstream') @('update-ref', '-d', 'refs/remotes/origin/main')
    Invoke-TestGit (Join-Path $projects 'ahead') @('worktree', 'add', '--quiet', '--detach', (Join-Path $projects 'linked worktree'))

    Invoke-TestGit $seed @('commit', '--quiet', '--allow-empty', '-m', 'remote commit')
    Invoke-TestGit $seed @('push', '--quiet', 'origin', 'main')
    foreach ($name in @('behind', 'diverged')) {
        Invoke-TestGit (Join-Path $projects $name) @('fetch', '--quiet', 'origin')
    }
    New-TestRepository (Join-Path $projects 'no-upstream')
    New-TestRepository (Join-Path $projects 'unborn') -Unborn
    New-Item -ItemType Directory -Path (Join-Path $projects 'ordinary folder') | Out-Null
    # A normal directory inside a parent repository is still not its own repo.
    Invoke-TestGit $projects @('init', '--quiet', '--initial-branch=main')
    Invoke-TestGit $projects @('init', '--quiet', '--bare', '--initial-branch=main', (Join-Path $projects 'bare.git'))

    $rows = @(& $helper $projects -PassThru)
    $byName = @{}
    foreach ($row in $rows) { $byName[$row.Folder] = $row }
    Assert-Status ($byName['ordinary folder'].Status -eq 'Not a Git repo') 'A plain child inherited the parent Git repo.'
    Assert-Status ($byName['synced'].Status -eq 'Synced') 'A clean synced repository was mislabeled or fetched.'
    Assert-Status ($byName['ahead'].Ahead -eq 1 -and $byName['ahead'].Behind -eq 0) 'A same-tree commit or ahead/behind configuration hid an unpushed commit.'
    Assert-Status ($byName['ahead'].Status -eq 'Unpushed') 'Ahead-only status failed.'
    Assert-Status ($byName['dirty-ahead'].Changes -eq 1 -and $byName['dirty-ahead'].Ahead -eq 1 -and
        $byName['dirty-ahead'].Status -eq 'Uncommitted, Unpushed') 'Dirty status hid unpushed commits.'
    Assert-Status ($byName['behind'].Ahead -eq 0 -and $byName['behind'].Behind -eq 1 -and
        $byName['behind'].Status -eq 'Behind') 'Behind-only commits were reported as unpushed.'
    Assert-Status ($byName['diverged'].Ahead -eq 1 -and $byName['diverged'].Behind -eq 1 -and
        $byName['diverged'].Status -eq 'Unpushed, Behind') 'Diverged branches failed.'
    Assert-Status ($byName['no-upstream'].Status -eq 'No upstream' -and
        $null -eq $byName['no-upstream'].Ahead) 'No-upstream status failed.'
    Assert-Status ($byName['missing-upstream'].Status -eq 'Upstream unavailable' -and
        $null -eq $byName['missing-upstream'].Ahead) 'Missing tracking reference was reported as synced.'
    Assert-Status ($byName['detached'].Status -eq 'Detached HEAD') 'Detached HEAD status failed.'
    Assert-Status ($byName['linked worktree'].Status -eq 'Detached HEAD') 'A .git worktree file was not recognized.'
    Assert-Status ($byName['unborn'].Status -eq 'No commits') 'An unborn repository failed.'
    Assert-Status ($byName['bare.git'].Status -eq 'Bare repository') 'A bare repository was not recognized.'

    Push-Location -LiteralPath $projects
    try {
        $defaultRows = @(& $helper -PassThru)
        Assert-Status ($defaultRows.Count -eq $rows.Count) 'The default path was not the current directory.'
    }
    finally { Pop-Location }

    $empty = Join-Path $testRoot 'empty'
    New-Item -ItemType Directory -Path $empty | Out-Null
    Assert-Status (@(& $helper $empty -PassThru).Count -eq 0) 'An empty parent produced rows.'

    # Execute the actual macro command after DOSKEY's argument substitution,
    # through cmd.exe and Windows PowerShell. Include spaces in both paths.
    $helperDirectory = Join-Path $testRoot 'helper directory'
    New-Item -ItemType Directory -Path $helperDirectory | Out-Null
    Copy-Item -LiteralPath $helper -Destination (Join-Path $helperDirectory 'git-status.ps1')
    $alias = @(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'aliases.doskey') | Where-Object { $_ -like 'gstatall=*' })
    Assert-Status ($alias.Count -eq 1) 'Expected one gstatall macro.'
    $command = ($alias[0] -split '=', 2)[1]
    $oldHelperDirectory = $env:PCPREP_WINDOWS_DIR
    try {
        $env:PCPREP_WINDOWS_DIR = $helperDirectory
        $output = & cmd.exe /d /q /c ($command.Replace('$*', ('"' + $projects + '"')))
        Assert-Status ($LASTEXITCODE -eq 0 -and ($output -join "`n").Contains('Git status of immediate subfolders in ' + $projects)) 'The Command Prompt shortcut failed with spaces in paths.'
        Assert-Status (($output -join "`n").Contains('Unpushed')) 'The shortcut omitted Git status.'
    }
    finally { $env:PCPREP_WINDOWS_DIR = $oldHelperDirectory }

    Write-Host 'PASS: synced, unpushed, dirty, behind, diverged, missing upstream, detached, unborn, worktree, bare, plain folder, empty parent, and Command Prompt checks.'
}
finally {
    $resolvedTest = [IO.Path]::GetFullPath($testRoot)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolvedTest.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Unexpected test cleanup path.'
    }
    Remove-Item -LiteralPath $resolvedTest -Recurse -Force
}
