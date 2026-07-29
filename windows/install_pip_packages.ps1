#Requires -Version 5.1

<#
.SYNOPSIS
Installs the shared Python and machine-learning tools used on this PC.

.DESCRIPTION
The script targets Conda's base environment directly, upgrades pip, installs
the requested packages, and finishes with dependency and PyTorch tests.

All packages are installed directly into Conda's base environment. The script
requires a Python version supported by the current stable PyTorch release.

PyTorch is installed with CUDA support when a compatible NVIDIA driver is
detected; otherwise its CPU build is installed. The CUDA-enabled PyTorch wheel
includes its own runtime, so the full CUDA Toolkit does not have to be installed
separately.

TensorFlow is intentionally not installed. Keras is configured to use the
installed PyTorch package as its backend.

.EXAMPLE
cd D:\GitHubSrc\pcprep\windows
.\install_pip_packages.ps1

If PowerShell blocks local scripts, allow them only for the current window:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned

.EXAMPLE
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\install_pip_packages.ps1"

Runs from a normal Command Prompt after changing to this script's directory.

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

    $condaOnPath = Get-Command conda.exe -CommandType Application `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1
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

    # Avoid embedded quotes so this also survives Windows PowerShell 5.1 native parsing.
    $versionExpression =
        'import sys; print(sys.version_info.major, sys.version_info.minor, sys.version_info.micro, sep=chr(46))'
    $versionText = & $PythonPath -c $versionExpression
    if ($LASTEXITCODE -ne 0) {
        throw "Could not determine the Python version from $PythonPath."
    }

    return [version](($versionText | Select-Object -Last 1).Trim())
}

function Get-NvidiaDriverInfo {
    $nvidiaSmi = Get-Command nvidia-smi.exe -CommandType Application `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1
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
$targetEnvironment = 'base'
$pythonExe = Join-Path $condaBase 'python.exe'
if (-not (Test-Path -LiteralPath $pythonExe -PathType Leaf)) {
    throw "Conda's base Python executable was not found: $pythonExe"
}
$pythonVersion = Get-PythonVersion -PythonPath $pythonExe
if (($pythonVersion.Major -ne 3) -or
    ($pythonVersion.Minor -lt 10) -or
    ($pythonVersion.Minor -gt 14)) {
    throw "Conda base uses Python $pythonVersion; current stable PyTorch on Windows requires Python 3.10 through 3.14."
}

Write-Host "Installing into Conda environment '$targetEnvironment' with Python $pythonVersion."
Invoke-ExternalCommand -FilePath $pythonExe `
    -ArgumentList @('-m', 'pip', 'install', '--upgrade', 'pip', 'setuptools', 'wheel') `
    -Description 'Upgrading pip tools'

$nvidiaInfo = Get-NvidiaDriverInfo
$torchIndexUrl = 'https://download.pytorch.org/whl/cpu'
$expectCuda = $false
$cudaWheelOptions = @(
    [pscustomobject]@{
        MinimumDriverCuda = [version]'13.2'
        IndexUrl          = 'https://download.pytorch.org/whl/cu132'
    }
    [pscustomobject]@{
        MinimumDriverCuda = [version]'13.0'
        IndexUrl          = 'https://download.pytorch.org/whl/cu130'
    }
    [pscustomobject]@{
        MinimumDriverCuda = [version]'12.6'
        IndexUrl          = 'https://download.pytorch.org/whl/cu126'
    }
)

if ($nvidiaInfo.Available) {
    foreach ($option in $cudaWheelOptions) {
        if ($nvidiaInfo.CudaVersion -ge $option.MinimumDriverCuda) {
            $torchIndexUrl = $option.IndexUrl
            $expectCuda = $true
            break
        }
    }
}

if ($expectCuda) {
    Write-Host "NVIDIA GPU detected: $($nvidiaInfo.GpuName) (driver supports CUDA $($nvidiaInfo.CudaVersion))."
    Write-Host "Installing the PyTorch CUDA wheel from $torchIndexUrl."
}
elseif ($nvidiaInfo.Available) {
    Write-Warning (
        'The NVIDIA driver reports CUDA {0}, below the supported PyTorch CUDA wheel versions.' -f
            $nvidiaInfo.CudaVersion
    )
    Write-Host 'Installing the PyTorch CPU wheel.'
}
else {
    Write-Host 'No usable NVIDIA driver was detected; installing the PyTorch CPU wheel.'
}

Write-Host 'Removing TorchAudio as requested...'
Invoke-ExternalCommand -FilePath $pythonExe `
    -ArgumentList @('-m', 'pip', 'uninstall', '--yes', 'torchaudio') `
    -Description 'Removing TorchAudio'

Invoke-ExternalCommand -FilePath $pythonExe `
    -ArgumentList @(
        '-m', 'pip', 'install', '--upgrade',
        # No version pins: the production PyTorch index supplies its latest stable builds.
        'torch', 'torchvision',
        '--index-url', $torchIndexUrl
    ) `
    -Description 'Installing PyTorch'

Write-Host 'Installing Keras and TensorBoard...'
Invoke-ExternalCommand -FilePath $pythonExe `
    -ArgumentList @(
        '-m', 'pip', 'install', '--upgrade',
        'keras', 'tensorboard'
    ) `
    -Description 'Installing Keras and TensorBoard'

Write-Host 'Configuring Keras to use its PyTorch backend...'
$kerasConfiguration = @'
import json
import os
from pathlib import Path

keras_home = Path(os.environ.get("KERAS_HOME", Path.home() / ".keras"))
config_path = keras_home / "keras.json"
config = {}

if config_path.exists():
    with config_path.open(encoding="utf-8-sig") as config_file:
        config = json.load(config_file)
    if not isinstance(config, dict):
        raise TypeError(f"Expected a JSON object in {config_path}.")

if config.get("backend") != "torch":
    config["backend"] = "torch"
    keras_home.mkdir(parents=True, exist_ok=True)
    temporary_path = config_path.with_suffix(".json.tmp")
    temporary_path.write_text(json.dumps(config, indent=4) + "\n", encoding="utf-8")
    temporary_path.replace(config_path)

print(f"Keras backend configured as torch in {config_path}")
'@
$kerasConfiguration | & $pythonExe -
if ($LASTEXITCODE -ne 0) {
    throw "Configuring Keras failed with exit code $LASTEXITCODE."
}

# Make the backend choice unambiguous for the verification process too.
$env:KERAS_BACKEND = 'torch'

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
import keras
import torch
import torchvision

expected_cuda = $expectedCudaLiteral
if keras.backend.backend() != "torch":
    raise SystemExit(f"Keras selected the unexpected backend: {keras.backend.backend()}")
print(f"Keras {keras.__version__} PyTorch backend test passed")
cpu_tensor = torch.rand(3, 3)
print(f"PyTorch {torch.__version__} CPU test passed: shape={tuple(cpu_tensor.shape)}")
print(f"TorchVision {torchvision.__version__}")
print(f"CUDA available to PyTorch: {torch.cuda.is_available()}")

if expected_cuda:
    if not torch.cuda.is_available():
        raise SystemExit("An NVIDIA GPU was detected, but PyTorch cannot use CUDA.")
    gpu_tensor = torch.rand(3, 3, device="cuda")
    torch.cuda.synchronize()
    print(f"PyTorch CUDA test passed on: {torch.cuda.get_device_name(0)}")
"@

Write-Host 'Testing PyTorch...'
# Feed the test through standard input. Windows PowerShell 5.1 can remove quote
# characters from multiline Python passed as a native executable argument.
$pytorchTest | & $pythonExe -
if ($LASTEXITCODE -ne 0) {
    throw "PyTorch verification failed with exit code $LASTEXITCODE."
}

Write-Host ''
Write-Host "Installation and tests completed successfully in Conda environment '$targetEnvironment'."
Write-Host "For later use, run: conda activate $targetEnvironment"
