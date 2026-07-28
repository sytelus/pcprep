#Requires -Version 5.1

<#
.SYNOPSIS
Installs the shared Python and machine-learning tools used on this PC.

.DESCRIPTION
The script activates Conda's base environment, upgrades pip, installs the
requested packages, and finishes with dependency and PyTorch tests.

The combined package set currently requires Python 3.10 through 3.13. If Conda
base uses a different Python version, the script preserves base and
automatically creates and uses a small environment named "pcprep-ml" with
Python 3.12.

On Windows, current TensorFlow releases are CPU-only. PyTorch is installed with
CUDA support when a compatible NVIDIA driver is detected; otherwise its CPU
build is installed. The CUDA-enabled PyTorch wheel includes its own runtime, so
the full CUDA Toolkit does not have to be installed separately.

.EXAMPLE
cd D:\GitHubSrc\pcprep\windows
.\pip_installs.ps1

If PowerShell blocks local scripts, allow them only for the current window:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned

.NOTES
Run this from a normal PowerShell window; administrator rights are not needed.
The machine-learning packages are large, so installation can take some time.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Find-CondaExecutable {
    $candidates = @()

    if ($env:CONDA_EXE) {
        $candidates += $env:CONDA_EXE
    }

    $condaOnPath = Get-Command conda.exe -ErrorAction SilentlyContinue
    if ($condaOnPath) {
        $candidates += $condaOnPath.Source
    }

    $candidates += @(
        (Join-Path $env:USERPROFILE 'miniconda3\Scripts\conda.exe'),
        (Join-Path $env:USERPROFILE 'anaconda3\Scripts\conda.exe'),
        (Join-Path $env:ProgramData 'miniconda3\Scripts\conda.exe'),
        (Join-Path $env:ProgramData 'anaconda3\Scripts\conda.exe')
    )

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw 'Conda was not found. Install Miniconda or Anaconda, then run this script again.'
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory)]
        [string] $FilePath,

        [Parameter(Mandatory)]
        [string[]] $ArgumentList,

        [Parameter(Mandatory)]
        [string] $Description
    )

    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

function Get-PythonVersion {
    param(
        [Parameter(Mandatory)]
        [string] $PythonPath
    )

    $versionText = & $PythonPath -c 'import sys; print(".".join(map(str, sys.version_info[:3])))'
    if ($LASTEXITCODE -ne 0) {
        throw "Could not determine the Python version from $PythonPath."
    }

    return [version](($versionText | Select-Object -Last 1).Trim())
}

function Get-NvidiaDriverInfo {
    $nvidiaSmi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    if (-not $nvidiaSmi) {
        return [pscustomobject]@{
            Available   = $false
            GpuName     = $null
            CudaVersion = $null
        }
    }

    $statusText = (& $nvidiaSmi.Source 2>&1 | Out-String)
    if (($LASTEXITCODE -ne 0) -or ($statusText -notmatch 'CUDA Version:\s*(\d+\.\d+)')) {
        return [pscustomobject]@{
            Available   = $false
            GpuName     = $null
            CudaVersion = $null
        }
    }

    $cudaVersion = [version]$Matches[1]
    $gpuName = [string](& $nvidiaSmi.Source --query-gpu=name --format=csv,noheader 2>$null |
        Select-Object -First 1)
    $gpuName = $gpuName.Trim()

    return [pscustomobject]@{
        Available   = $true
        GpuName     = $gpuName
        CudaVersion = $cudaVersion
    }
}

Write-Host 'Locating Conda...'
$condaExe = Find-CondaExecutable
$condaBaseOutput = & $condaExe info --base
if ($LASTEXITCODE -ne 0) {
    throw 'Conda could not report its base directory.'
}

$condaBase = ($condaBaseOutput | Select-Object -Last 1).Trim()
$condaHook = Join-Path $condaBase 'shell\condabin\conda-hook.ps1'
if (-not (Test-Path -LiteralPath $condaHook -PathType Leaf)) {
    throw "Conda's PowerShell activation hook was not found at $condaHook."
}

. $condaHook
conda activate base
if ($env:CONDA_DEFAULT_ENV -ne 'base') {
    throw 'Conda base could not be activated.'
}

$basePython = Join-Path $condaBase 'python.exe'
$basePythonVersion = Get-PythonVersion -PythonPath $basePython
$targetEnvironment = 'base'

# TensorFlow and PyTorch's overlapping supported range determines whether base is usable.
if (($basePythonVersion.Major -ne 3) -or
    ($basePythonVersion.Minor -lt 10) -or
    ($basePythonVersion.Minor -gt 13)) {
    $targetEnvironment = 'pcprep-ml'
    Write-Warning "Conda base uses Python $basePythonVersion, which current TensorFlow does not support."
    Write-Host 'Using the Python 3.12 Conda environment "pcprep-ml" instead.'

    $environmentJson = & $condaExe env list --json
    if ($LASTEXITCODE -ne 0) {
        throw 'Conda could not list its environments.'
    }

    $environmentList = $environmentJson | ConvertFrom-Json
    $environmentExists = @($environmentList.envs | Where-Object {
            (Split-Path -Path $_ -Leaf) -eq $targetEnvironment
        }).Count -gt 0

    if (-not $environmentExists) {
        Invoke-ExternalCommand -FilePath $condaExe `
            -ArgumentList @('create', '--name', $targetEnvironment, '--yes', 'python=3.12', 'pip') `
            -Description "Creating Conda environment $targetEnvironment"
    }

    conda activate $targetEnvironment
    if ($env:CONDA_DEFAULT_ENV -ne $targetEnvironment) {
        throw "Conda environment $targetEnvironment could not be activated."
    }
}

$pythonCommand = Get-Command python.exe -ErrorAction Stop
$pythonExe = $pythonCommand.Source
$pythonVersion = Get-PythonVersion -PythonPath $pythonExe
if (($pythonVersion.Major -ne 3) -or
    ($pythonVersion.Minor -lt 10) -or
    ($pythonVersion.Minor -gt 13)) {
    throw "The selected environment uses Python $pythonVersion; this package set requires Python 3.10 through 3.13."
}

Write-Host "Installing into Conda environment '$targetEnvironment' with Python $pythonVersion."
Invoke-ExternalCommand -FilePath $pythonExe `
    -ArgumentList @('-m', 'pip', 'install', '--upgrade', 'pip', 'setuptools', 'wheel') `
    -Description 'Upgrading pip tools'

$nvidiaInfo = Get-NvidiaDriverInfo
$torchIndexUrl = 'https://download.pytorch.org/whl/cpu'
$expectCuda = $false

if ($nvidiaInfo.Available -and ($nvidiaInfo.CudaVersion -ge [version]'13.0')) {
    $torchIndexUrl = 'https://download.pytorch.org/whl/cu130'
    $expectCuda = $true
}
elseif ($nvidiaInfo.Available -and ($nvidiaInfo.CudaVersion -ge [version]'12.8')) {
    $torchIndexUrl = 'https://download.pytorch.org/whl/cu128'
    $expectCuda = $true
}
elseif ($nvidiaInfo.Available -and ($nvidiaInfo.CudaVersion -ge [version]'12.6')) {
    $torchIndexUrl = 'https://download.pytorch.org/whl/cu126'
    $expectCuda = $true
}

if ($expectCuda) {
    Write-Host "NVIDIA GPU detected: $($nvidiaInfo.GpuName) (driver supports CUDA $($nvidiaInfo.CudaVersion))."
    Write-Host "Installing the PyTorch CUDA wheel from $torchIndexUrl."
}
elseif ($nvidiaInfo.Available) {
    Write-Warning "The NVIDIA driver reports CUDA $($nvidiaInfo.CudaVersion), below the supported PyTorch CUDA wheel versions."
    Write-Host 'Installing the PyTorch CPU wheel.'
}
else {
    Write-Host 'No usable NVIDIA driver was detected; installing the PyTorch CPU wheel.'
}

Invoke-ExternalCommand -FilePath $pythonExe `
    -ArgumentList @(
        '-m', 'pip', 'install', '--upgrade',
        # PyTorch 2.11 is the newest official release with a matching torchaudio wheel.
        'torch==2.11.0', 'torchvision==0.26.0', 'torchaudio==2.11.0',
        '--index-url', $torchIndexUrl
    ) `
    -Description 'Installing PyTorch'

Write-Host 'Installing TensorFlow, Keras, and TensorBoard (CPU on native Windows)...'
Invoke-ExternalCommand -FilePath $pythonExe `
    -ArgumentList @(
        '-m', 'pip', 'install', '--upgrade',
        'tensorflow', 'keras', 'tensorboard'
    ) `
    -Description 'Installing the TensorFlow packages'

$otherPackages = @(
    'nvitop',
    'rich',
    'pytest',
    'pandas',
    'scikit-learn',
    'matplotlib',
    'jupyter',
    'transformers',
    'datasets',
    'wandb',
    'accelerate',
    'einops',
    'tokenizers',
    'sentencepiece',
    'lightning'
)

Write-Host 'Installing the remaining Python packages...'
Invoke-ExternalCommand -FilePath $pythonExe `
    -ArgumentList (@('-m', 'pip', 'install', '--upgrade') + $otherPackages) `
    -Description 'Installing the remaining Python packages'

Write-Host 'Checking installed package dependencies...'
Invoke-ExternalCommand -FilePath $pythonExe `
    -ArgumentList @('-m', 'pip', 'check') `
    -Description 'pip dependency check'

$expectedCudaLiteral = if ($expectCuda) { 'True' } else { 'False' }
$pytorchTest = @"
import torch
import torchaudio
import torchvision

expected_cuda = $expectedCudaLiteral
cpu_tensor = torch.rand(3, 3)
print(f"PyTorch {torch.__version__} CPU test passed: shape={tuple(cpu_tensor.shape)}")
print(f"TorchVision {torchvision.__version__}; TorchAudio {torchaudio.__version__}")
print(f"CUDA available to PyTorch: {torch.cuda.is_available()}")

if expected_cuda:
    if not torch.cuda.is_available():
        raise SystemExit("An NVIDIA GPU was detected, but PyTorch cannot use CUDA.")
    gpu_tensor = torch.rand(3, 3, device="cuda")
    torch.cuda.synchronize()
    print(f"PyTorch CUDA test passed on: {torch.cuda.get_device_name(0)}")
"@

Write-Host 'Testing PyTorch...'
Invoke-ExternalCommand -FilePath $pythonExe `
    -ArgumentList @('-c', $pytorchTest) `
    -Description 'PyTorch verification'

Write-Host ''
Write-Host "Installation and tests completed successfully in Conda environment '$targetEnvironment'."
Write-Host "For later use, run: conda activate $targetEnvironment"
