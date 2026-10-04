#Requires -Version 5.1

<#
.SYNOPSIS
Summarizes Git status for each immediate child directory.
.DESCRIPTION
Requires Git on PATH. Ahead and Behind compare HEAD with the locally cached
upstream branch. No fetch, commit, push, or index refresh is performed.
.EXAMPLE
.\git-status.ps1 D:\GitHubSrc
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Path = '.',
    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$gitExecutable = (Get-Command git.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$parent = Get-Item -LiteralPath $Path -ErrorAction Stop
if (-not $parent.PSIsContainer -or $parent.PSProvider.Name -ne 'FileSystem') {
    throw "Not a filesystem directory: $Path"
}

function Invoke-StatusGit {
    param([string] $Directory, [string[]] $Arguments)
    # Windows PowerShell represents native stderr as error records. Collect
    # them with stdout and use Git's exit code to distinguish real failures.
    $ErrorActionPreference = 'Continue'
    $output = @(& $gitExecutable --no-optional-locks -C $Directory @Arguments 2>&1)
    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Lines = @($output | ForEach-Object { $_.ToString() })
    }
}

$hadErrors = $false
$rows = @(foreach ($folder in Get-ChildItem -LiteralPath $parent.FullName -Directory -Force | Sort-Object Name) {
    $row = [ordered]@{
        Folder = $folder.Name
        Branch = ''
        Changes = $null
        Ahead = $null
        Behind = $null
        Status = 'Not a Git repo'
    }

    if (Test-Path -LiteralPath (Join-Path $folder.FullName '.git')) {
        # A .git directory or file identifies this child as a working repo,
        # including linked worktrees. Do not inherit the parent's repository.
        $result = Invoke-StatusGit $folder.FullName @('status', '--porcelain=v2', '--branch', '--ahead-behind', '--untracked-files=normal')
        if ($result.ExitCode -ne 0) {
            $hadErrors = $true
            $row.Status = 'Error: ' + ($result.Lines -join ' ')
        }
        else {
            $row.Changes = 0
            $hasUpstream = $false
            $hasCommits = $true
            foreach ($line in $result.Lines) {
                if ($line -eq '# branch.oid (initial)') {
                    $hasCommits = $false
                }
                elseif ($line -match '^# branch.head (.+)$') {
                    $row.Branch = $Matches[1]
                }
                elseif ($line -match '^# branch.upstream ') {
                    $hasUpstream = $true
                }
                elseif ($line -match '^# branch.ab \+(\d+) -(\d+)$') {
                    $row.Ahead = [int] $Matches[1]
                    $row.Behind = [int] $Matches[2]
                }
                elseif ($line -match '^[12u?] ') {
                    $row.Changes++
                }
            }

            $labels = @()
            if ($row.Changes -gt 0) { $labels += 'Uncommitted' }
            if (-not $hasCommits) { $labels += 'No commits' }
            elseif ($row.Branch -eq '(detached)') { $labels += 'Detached HEAD' }
            elseif (-not $hasUpstream) { $labels += 'No upstream' }
            elseif ($null -eq $row.Ahead) { $labels += 'Upstream unavailable' }
            else {
                if ($row.Ahead -gt 0) { $labels += 'Unpushed' }
                if ($row.Behind -gt 0) { $labels += 'Behind' }
                if ($labels.Count -eq 0) { $labels += 'Synced' }
            }
            $row.Status = $labels -join ', '
        }
    }
    elseif ((Test-Path -LiteralPath (Join-Path $folder.FullName 'HEAD') -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $folder.FullName 'objects') -PathType Container)) {
        $result = Invoke-StatusGit $folder.FullName @('rev-parse', '--is-bare-repository')
        if ($result.ExitCode -eq 0 -and $result.Lines -contains 'true') {
            $row.Status = 'Bare repository'
        }
    }
    [pscustomobject] $row
})

if ($PassThru) {
    $rows
}
else {
    Write-Host "Git status of immediate subfolders in $($parent.FullName)"
    Write-Host 'Ahead/Behind use locally cached upstream refs; no fetch is performed.'
    if ($rows.Count -eq 0) { Write-Host 'No immediate subdirectories found.' }
    else { $rows | Format-Table Folder, Branch, Changes, Ahead, Behind, Status -AutoSize -Wrap }
}
if ($hadErrors) { exit 1 }
