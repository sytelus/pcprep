# Tools and containers

## Utility scripts

| Path | Purpose | Important boundary |
| --- | --- | --- |
| `utils/small2zip.py` | Select small subtrees, create verified ZIP archives, then delete archived sources | Destructive in normal mode; no concurrent writers; ZIP does not preserve all Windows metadata |
| `utils/test_small2zip.py` | Unit and failure-injection coverage for `small2zip` | Requires dependencies from `utils/requirements.txt` |
| `utils/copyallfiles.bat` | Robocopy-based bulk copy/move with exclusions and logging | Options can move/delete source material; inspect arguments and log path |
| `utils/Collect-SleepDiagnostics_v2.ps1` | Collect Windows sleep/power diagnostics into a report under `C:\temp` | Reads system state but creates an output directory/report |
| `utils/logs_around.ps1` | Query Windows Event Logs around a selected time | Read-only Event Log query |
| `utils/chmodx.bat` | Invoke WSL `chmod +x` for a path | Changes Linux-side permissions |
| `utils/copyallfiles_errors_prompt.txt` | Analysis prompt for copy logs | Documentation only |

The root `tests/atari.py` and `tests/cuda.py` are manual framework/GPU smoke
scripts. They depend on external ML stacks and hardware and are not automated
regression tests.

## `small2zip`

The utility scans a directory, selects eligible folders, writes a temporary ZIP,
verifies its manifest, atomically publishes the archive, and only then removes
the source selection. Its default action is therefore intentionally destructive.

List-only inspection:

```powershell
python utils\small2zip.py --list D:\path\to\tree
```

Before destructive use:

- ensure the archive destination is on reliable storage with enough free space;
- back up the source;
- close or exclude files being modified by other processes;
- run only one process for a given source/target pair;
- understand that ZIP does not preserve ACLs, alternate data streams, reparse
  point semantics, or every platform timestamp/attribute;
- retain and inspect the log/manifest until source and archive counts are
  independently verified.

The existing implementation has a confirmed cross-process race in which one
process can remove another's partial archive and both can delete source data.
Do not run concurrent instances until the P0 issue in [TODO.md](../TODO.md) is
fixed and regression-tested.

## CPU devbox

`ubuntu/docker/cpu-devbox/` builds an Ubuntu 24.04, multi-architecture,
Miniforge-based development image with a CPU ML stack and shared shell
configuration. Its local and multi-architecture build scripts, run script,
verification script, builder setup, image inspection, prune, and push helpers
are documented in its [README](../ubuntu/docker/cpu-devbox/README.md) and
[requirements](../ubuntu/docker/cpu-devbox/REQUIREMENTS.md).

`docker-move-data.sh` is not safe to use in its current form: its documented
dry-run mode still makes persistent changes, it can proceed after failed service
stops or inconclusive verification, and it can discard Docker configuration.
Treat the root P0 as a hard blocker. `dockerprune.sh` is also destructive by
design and must not be scheduled or run casually.

## GPU devbox

`ubuntu/docker/gpu-devbox/` builds from an NVIDIA NGC PyTorch image and adds
developer tooling plus optional nightly/vLLM-related packages. It requires a
compatible NVIDIA driver and container runtime. Its README, requirements,
learnings, TODO, native arm64 build, local/multiarch build, run, verify, builder,
inspection, prune, and push scripts are self-contained in that directory.

Container base tags and most downloaded dependencies are currently mutable or
unpinned. Reproducibility and supply-chain verification are root P1 work even
where build scripts request provenance/SBOM output.

## VS Code dev container

`.devcontainer/devcontainer.json` currently points to
`sytelus/gpu-devbox:latest`, requests `--gpus all`, and configures a Python path
under `/opt/nanugpt-venv`. The image tag is mutable, GPU access is effectively
mandatory despite being described as optional, and neither Dockerfile creates
that interpreter path. Use the CPU/GPU run scripts directly until the dev
container configuration is corrected.

