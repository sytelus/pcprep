# Windows PC preparation

This directory contains a personal, repeatable Windows 11 workstation setup.
The scripts favor native installers managed by WinGet, keep user-scoped tools
in the current user's profile, and stop on the first failed required step.

## Requirements

- 64-bit Windows 11 with Windows PowerShell 5.1.
- WinGet from Microsoft App Installer, network access, and enough disk space for
  the selected applications, Visual Studio Build Tools, and Python packages.
- An account that can approve one User Account Control prompt. Run the main
  entry point as the user who should own the Git, Rust, Conda, and alias setup.

Review the package list and applicable vendor licenses before running the full
setup. The scripts are unattended where installers support it, but they do not
bypass vendor license requirements.

## Security model

- WinGet calls use exact package IDs and explicit `winget` or `msstore` sources;
  Chocolatey font installs use the explicit public community source.
- The documented Command Prompt commands use `ExecutionPolicy Bypass` only for
  the newly started Windows PowerShell process and its local script. They do not
  change the user's persistent execution policy.
- Within the complete setup, the only direct executable download outside a
  package manager is Miniconda's official installer. Its Authenticode signature
  and Anaconda signer name are checked before execution, and its temporary
  installer is removed in a `finally` block.
- Package managers still rely on their repositories and vendor installers. Keep
  WinGet, Windows, Defender, and the installed applications current.

## Run the complete setup

From a normal (not elevated) PowerShell window:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
cd D:\GitHubSrc\pcprep\windows
.\prepare_new_box.ps1
```

Or, from a normal Command Prompt:

```bat
cd /d D:\GitHubSrc\pcprep\windows
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\prepare_new_box.ps1"
```

Add `-Yes` to either invocation to skip the confirmation prompt. Use `-Help` to
show usage without starting any setup step.

The script requests elevation once for machine-scoped work. Do not start the
whole setup as administrator unless necessary: Rustup, Miniconda, Git settings,
and aliases are intended for the current user.

To supply Git identity without an interactive prompt:

```powershell
$env:user_name = 'Your Name'
$env:user_email = 'you@example.com'
.\prepare_new_box.ps1 -Yes
```

In Command Prompt, use `set "user_name=Your Name"` and
`set "user_email=you@example.com"` before the `powershell.exe` command.

## What the setup does

The normal-user phase:

1. Installs or updates Git, Visual Studio Code, and GitHub CLI with WinGet.
2. Installs Codex CLI and Claude Code with WinGet unless a working command
   installed by another mechanism already exists.
3. Requests one elevated child process for machine-scoped setup.
4. Installs Rustup and selects the latest stable
   `x86_64-pc-windows-msvc` toolchain.
5. Compiles and runs a temporary Rust program to verify the MSVC linker and
   Windows SDK integration.
6. Installs Command Prompt aliases in `%LOCALAPPDATA%\pcprep` and configures
   Git, File Explorer Gallery visibility, Miniconda, and Python packages.

The elevated phase:

1. Reuses Chocolatey at `%ProgramData%\chocolatey` or installs it with WinGet
   when it is genuinely absent.
2. Verifies a Visual Studio installation containing the x64/x86 MSVC compiler
   and linker plus a usable Windows SDK. If incomplete, it installs or modifies
   Visual Studio Build Tools 2022 with the Desktop development with C++ workload.
3. Runs `utilities.ps1`.
4. Exposes a conservative allowlist of advanced power settings. It changes only
   visibility attributes, not the active plan or any AC/DC values.

WinGet's `install` command is used intentionally: missing packages are installed,
older packages are upgraded, and current packages are left alone.

## Utility applications

`utilities.ps1` installs these package IDs:

- Hardware and diagnostics: HWiNFO, CrystalDiskInfo, GPU-Z, HeavyLoad,
  UltraSearch, and Sysinternals Suite.
- Graphics and media: Paint.NET, Adobe Acrobat Reader, VLC, Foxit PDF Reader,
  GIMP, IrfanView, Inkscape, and Blender.
- Developer and system tools: 7-Zip, Wget, Go, Rufus, Node.js LTS, CMake, and
  PuTTY.

To run only this utility installation, use an elevated PowerShell window:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
cd D:\GitHubSrc\pcprep\windows
.\utilities.ps1
```

Or use an elevated Command Prompt:

```bat
cd /d D:\GitHubSrc\pcprep\windows
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\utilities.ps1"
```

Blender uses the official Microsoft Store product `9PP3C07GTVRH`. The regular
WinGet community manifest currently downloads from `download.blender.org`,
whose Cloudflare challenge rejects non-browser WinGet downloads on this network.

Fira Code and Cascadia Code are installed from Chocolatey's public community
source because they are not present in the configured WinGet catalogs. If
Chocolatey cannot be found, only those fonts are skipped.

Adobe and Foxit updater services are deliberately disabled immediately after
their applications are installed. Rerun `utilities.ps1` regularly so the PDF
readers continue receiving security updates.

Some utilities have special behavior:

- HWiNFO and GPU-Z can load signed hardware-access drivers while running. Avoid
  running multiple low-level sensor tools simultaneously.
- HeavyLoad intentionally stresses CPU, GPU, memory, or storage. Monitor
  temperatures and stop it if the system becomes unstable.
- Sysinternals Suite and GPU-Z may be installed portably and therefore might not
  appear as conventional entries in Installed apps.
- Rufus is portable and does not install a background service.

No package in the active install list is known to be malicious. The exclusions
are intentional:

- HWMonitor duplicates HWiNFO. It also remains excluded after the April 2026
  compromise of CPUID's download site; the authentic signed HWMonitor program
  itself was not the malware. See the
  [Broadcom incident report](https://www.broadcom.com/support/security-center/protection-bulletin/stx-rat-malware-distributed-via-cpuid-software-compromise).
- TortoiseSVN and Evernote add persistent Explorer, startup, updater, or other
  background components that are not wanted on this setup.
- VirtualBox installs kernel, USB, and network drivers; install it only when its
  virtual machines are actually needed.
- ConEmu and Rapid Environment Editor duplicate current Windows functionality,
  Java 8 is a legacy runtime, and Windows already provides `curl.exe`.
- Audacity, Notepad++, FreeCAD, and WinSCP remain optional rather than being
  silently installed on every PC.

Most WinGet MSI/EXE packages and Microsoft Store applications remain visible in
Windows Settings under **Apps > Installed apps** and use their normal uninstallers.
Chocolatey itself is directory-based, and portable applications are the main
exceptions.

## Rust and native build tools

`install_rust_prerequisites.ps1` accepts any Visual Studio 2017-or-later edition
that contains:

- MSVC x64/x86 compiler tools (`cl.exe`)
- the x64 MSVC linker (`link.exe`)
- Windows SDK headers
- x64 Windows API and Universal C Runtime import libraries

If those files are missing, the script installs Visual Studio Build Tools 2022
with `Microsoft.VisualStudio.Workload.VCTools;includeRecommended`, the current
x64/x86 MSVC component, and Windows 11 SDK 26100. This follows the official
[Rust MSVC prerequisites](https://rust-lang.github.io/rustup/installation/windows-msvc.html)
and [Microsoft Build Tools workload](https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=visualstudio)
documentation.

`configure_rust.ps1` then installs or synchronizes the stable x64 MSVC Rust
toolchain, makes it the default, reports `rustc` and `cargo` versions, and
performs a real compile/link/run smoke test. Temporary test files are removed in
a `finally` block even when compilation fails.

## Miniconda and Python packages

`install_miniconda.ps1` installs the current official x64 Miniconda release in
`%USERPROFILE%\miniconda3`. It verifies the installer's Authenticode signature,
adds only `condabin` to the user PATH, initializes PowerShell integration, and
accepts the Anaconda Terms of Service for the `main`, `r`, and `msys2` default
channels. Review [Anaconda's legal terms](https://www.anaconda.com/legal) before
running it.

`install_pip_packages.ps1` targets that installation's base environment
directly; it does not depend on shell activation. It installs:

- PyTorch and TorchVision (TorchAudio is explicitly removed)
- Keras configured with the PyTorch backend and TensorBoard
- nvitop, Rich, pytest, pandas, scikit-learn, matplotlib, and Jupyter
- Transformers, Datasets, Weights & Biases, Accelerate, Einops, Tokenizers,
  SentencePiece, and Lightning

The script selects the newest configured PyTorch CUDA wheel compatible with the
driver-reported CUDA level, otherwise it uses the CPU wheel. It finishes with
`pip check`, imports Keras/PyTorch/TorchVision, performs CPU tensor work, and—when
expected—allocates and synchronizes a CUDA tensor.

TensorFlow is intentionally excluded to avoid conflicting dependency constraints
in the shared base environment.

## Power settings

`enable_hidden_power.ps1` exposes only explicitly reviewed settings that exist
on the current machine. Modern Standby-specific settings are skipped when S0
Low Power Idle is unavailable. It does not create or activate power plans.

Preview or reverse these visibility changes manually from an elevated PowerShell:

```powershell
.\enable_hidden_power.ps1 -WhatIf
.\enable_hidden_power.ps1 -Undo
```

The processor performance boost-mode setting is part of this allowlist; the old
standalone registry import was removed so all visibility changes share the same
verification and undo behavior.

## Command Prompt aliases

`aliases.reg.bat` copies `aliases.doskey` to
`%LOCALAPPDATA%\pcprep\aliases.doskey` and configures the current user's Command
Processor `AutoRun` value. Using a stable installed copy prevents repository
moves from leaving a broken AutoRun path. Rerun the script after editing the
source alias file.

The AutoRun value is replaced, not merged with an unrelated existing AutoRun
command. Before the first replacement, the script exports the existing Command
Processor key to
`%LOCALAPPDATA%\pcprep\command-processor-before-pcprep.reg`. Review the existing
value before running if another program manages it; the backup is preserved on
later runs rather than being overwritten. Setup stops without changing the
registry if an existing key cannot be backed up.

Several aliases are intentionally powerful and should be used carefully:

- `grevertall` discards local changes and untracked files, then resets to
  `origin/master`.
- `gclean` runs `git clean -fdx` and deletes ignored as well as untracked files.
- `gcommit` stages all repository changes and commits them; `checkin` also
  pushes the resulting commit.
- `gtag` creates an annotated tag and pushes all local tags. `gdeletebranch`
  and `gdelbra` delete a branch from `origin` before deleting it locally.
- `mirfiles` uses `robocopy /MIR`; files absent from the source can be deleted
  from the destination.
- `mvx` and `smv` remove source files after successful Robocopy transfers.
- `removepass` interactively rewrites selected SSH private-key passphrases.
- `nvreset` attempts to reset NVIDIA GPU 0 and can interrupt GPU work.
- `claudeyolo` and `codexyolo` disable normal permission safeguards.
- `skillall` cancels all of the current user's Slurm jobs after confirmation.

Alternative names such as `gcln`/`gclean`, `cpx`/`cpz`/`copynewfiles`, and
`tmuxx`/`start-tmux` are retained intentionally for command-line muscle memory.
Their command definitions are duplicated because DOSKEY does not reliably
perform recursive macro expansion when one macro merely names another.

## Git configuration

`gitconfig.bat` changes the current user's global Git configuration. It
preserves an existing name and email, or reads `user_name` and `user_email`
environment variables before prompting. It configures LF commits with
checkout-as-is behavior (`core.autocrlf=input` and `core.eol=lf`), VS Code as
the editor and diff/merge tool, and rebasing for `git pull`.

The script also rewrites GitHub HTTPS repository URLs to SSH through a global
`url.*.insteadOf` rule. Make sure GitHub SSH authentication is configured, or
remove that rule if HTTPS credentials are preferred.

## Failure behavior and troubleshooting

- Required failures stop the complete setup and identify the failed phase.
- The scripts do not provide transactional rollback. Successfully completed
  earlier steps remain installed and can be safely rechecked by rerunning setup.
- Close every Windows Terminal window and open a new one after completion. A
  running terminal process retains the PATH that existed when it started.
- WinGet logs are under
  `%LOCALAPPDATA%\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir`.
- A reboot may be required after Visual Studio Build Tools or Chocolatey reports
  a reboot-required result.

## File layout

- `prepare_new_box.ps1`: orchestration, elevation, package setup, and errors.
- `utilities.ps1`: data-driven application and service configuration.
- `install_choco.bat`: standalone Chocolatey bootstrap using Chocolatey's
  published install command. The complete setup does not call it; it installs
  Chocolatey through WinGet instead. Run the standalone file only from an
  elevated Command Prompt, and review Chocolatey's downloaded script first.
- `install_rust_prerequisites.ps1` and `configure_rust.ps1`: Rust/MSVC setup.
- `install_miniconda.ps1` and `install_pip_packages.ps1`: Python environment.
- `enable_hidden_power.ps1`: reviewed power-setting visibility allowlist.
- `aliases.reg.bat`, `aliases.doskey`, `gitconfig.bat`, and `hide_gallery.bat`:
  per-user shell, Git, and File Explorer configuration.
