# Unimplemented Tutorial Recommendations

This document audits `macos-expert-tutorial.md` against the `mac/` setup scripts and catalogs every concrete recommendation the tutorial makes that the scripts intentionally do not automate. The scripts' philosophy is conservative: install only what most Mac developers want, stay reversible, avoid personal aesthetics or niche tooling, and keep the Python/PyTorch/Codex/Claude Code target narrow.

## 1. System preferences / `defaults write` settings not applied

- **Show hidden dotfiles in Finder** (`AppleShowAllFiles -bool true`).
  Section: Part 4 – Configure Finder.
  Why: Highly personal preference; most developers prefer `Cmd+Shift+.` toggle to avoid Finder clutter.

- **Full POSIX path in Finder title bar** (`_FNSPathControlTitlePath`).
  Section: Part 4 / Part 16.
  Why: Niche: only a minority of developers want it; the enabled `ShowPathbar` already exposes the path.

- **Dock auto-hide + animation tuning** (`autohide`, `autohide-delay 0`, `autohide-time-modifier 0.3`, `minimize-to-application`, `mru-spaces false`).
  Section: Part 4 – Configure Dock.
  Why: Highly personal preference (Dock layout/animation behavior).

- **Screensaver immediate password prompt** (`askForPassword 1`, `askForPasswordDelay 0`).
  Section: Part 17 – Secure Your Mac.
  Why: Already covered by macOS defaults on modern releases; users configure the grace period via System Settings.

- **Disable Resume system-wide** (`NSQuitAlwaysKeepsWindows false`).
  Section: Part 16.
  Why: Highly personal preference (changes app relaunch behavior).

- **Expand print panel by default** (`PMPrintingExpandedStateForPrint*`).
  Section: Part 16.
  Why: Niche: only a minority of developers want it.

- **Disable AirDrop for strangers** (`DisableAirDrop -bool true`).
  Section: Part 17.
  Why: Manual-only: can't be automated safely – discovery settings belong in Control Center / AirDrop UI.

- **Default screenshot format override** (`com.apple.screencapture type`).
  Section: Part 16.
  Why: Already covered by macOS defaults (PNG is the default, which is what we already keep).

- **Disable window animations in Finder** (`DisableAllAnimations`).
  Section: Part 16.
  Why: Highly personal preference (aesthetic/animation choice).

- **Raise `maxfiles` via `ulimit -n 65536` in `.zshrc` and `launchctl limit`**.
  Section: Part 19 – Pitfall 12.
  Why: Risky or hard to reverse at the system level; shell rc edits are avoided to keep the machine reversible and not own the user's shell config.

- **Caps Lock → Control/Escape remap**.
  Section: Part 4 – Keyboard.
  Why: Highly personal preference; Apple exposes it only through System Settings UI.

- **Function keys as standard F-keys** (`com.apple.keyboard.fnState`).
  Section: Part 4 – Keyboard.
  Why: Manual-only: can't be automated safely – this is a per-keyboard UI toggle with inconsistent domains.

- **`Fn` key behavior → "Do Nothing" / "Show Emoji"**.
  Section: Part 4 – Keyboard.
  Why: Highly personal preference.

- **Trackpad: tap-to-click, tracking speed, three-finger gestures**.
  Section: Part 4 – Trackpad.
  Why: Highly personal preference (aesthetics/ergonomics).

- **Display: "More Space" resolution, Night Shift schedule, True Tone**.
  Section: Part 4 – Display.
  Why: Manual-only: can't be automated safely – resolution scaling is per-panel and lives in the UI.

- **Hot Corners (Mission Control / Desktop / Quick Note)**.
  Section: Part 4 – Desktop & Dock.
  Why: Highly personal preference.

- **Dark/Light Appearance auto-switch, accent color, scroll bars "Always"**.
  Section: Part 4 – Appearance.
  Why: Highly personal preference (aesthetics).

- **Battery → "Prevent automatic sleeping on power adapter" / "Wake for network access"**.
  Section: Part 4 – Energy.
  Why: Manual-only: can't be automated safely for laptops without side effects; `pmset` edits also require sudo and can surprise users.

- **Safari: show full URL, enable Develop menu**.
  Section: Part 16.
  Why: Out of scope for Python/PyTorch/Codex/Claude stated target (user may not use Safari).

- **TextEdit → plain text default, Mail plain-address paste**.
  Section: Part 16.
  Why: Niche: only a minority of developers want it.

## 2. CLI tools from `Brewfile.core` we didn't include

- **`eza`** (modern `ls`).
  Section: Part 4 / Part 6.
  Why: Highly personal preference – shipping it implies aliasing `ls`, which the scripts deliberately avoid.

- **`neovim`**.
  Section: Part 7 Brewfile example.
  Why: Niche: only a minority of developers want it; `vim` ships with macOS.

- **`trash-cli` / `rename` / `tldr`**.
  Section: Part 4.
  Why: Highly personal preference – `trash` requires aliasing `rm`, which changes core shell semantics.

- **`neofetch`**.
  Section: Part 4 / Part 12.
  Why: Niche: only a minority of developers want it (cosmetic system banner).

- **`gnu-which`**.
  Section: Part 4.
  Why: Redundant with installed tooling – BSD `which` is adequate for almost every script.

- **`ncdu`**.
  Section: Part 14.
  Why: Niche: only a minority of developers want it; `du` + `btop` cover the common cases.

- **`sysbench` / `stress` / `speedtest-cli` / `iperf3`**.
  Section: Part 12.
  Why: Out of scope for Python/PyTorch/Codex/Claude stated target (benchmarking).

- **`bun`**.
  Section: Part 10.
  Why: Out of scope for Python/PyTorch/Codex/Claude stated target; Node already covers the npm surface the repo needs.

- **`fnm`** (Fast Node Manager).
  Section: Part 7 – Node.js.
  Why: Redundant with installed tooling – Homebrew's `node` formula is installed and adequate for the two CLIs (Codex, Claude Code) the repo actually cares about.

- **`fzf` shell integration** (`$(brew --prefix)/opt/fzf/install`).
  Section: Part 4.
  Why: Highly personal preference (shell customization); installing the binary without modifying user rc files preserves reversibility.

- **Homebrew auto-update (`brew autoupdate start`)**.
  Section: Part 4.
  Why: Risky or hard to reverse – installs a launchd agent that upgrades packages unattended.

## 3. GUI apps / casks we didn't include

- **`alt-tab`**.
  Section: Part 4.
  Why: Highly personal preference (Windows-style Alt-Tab vs. macOS Cmd-Tab).

- **`stats`** (menu bar monitor).
  Section: Part 4.
  Why: Highly personal preference (menu-bar aesthetics).

- **`appcleaner`**.
  Section: Part 4.
  Why: Niche: only a minority of developers want it; most users rarely uninstall apps.

- **`the-unarchiver`**.
  Section: Part 4.
  Why: Redundant with installed tooling – macOS Archive Utility and CLI tools already handle zip/tar/gz.

- **`firefox` / `google-chrome`**.
  Section: Part 4.
  Why: Highly personal preference (browser choice); Safari ships.

- **`qlmarkdown` / `qlstephen`** (Quick Look plugins).
  Section: Part 4.
  Why: Niche: only a minority of developers want it.

- **Developer fonts (`font-jetbrains-mono`, `font-meslo-lg-nerd-font`, `font-fira-code`)**.
  Section: Part 6 – Install a Good Font.
  Why: Highly personal preference (typography); Apple's SF Mono is already installed.

- **`betterdisplay`**.
  Section: Part 15.
  Why: Niche: only a minority of developers want it; only matters with non-Apple external panels.

- **`geekbench` / `amorphousdiskmark`**.
  Section: Part 12.
  Why: Paid or license-restricted software (Geekbench) / niche benchmarking.

## 4. Productivity apps (launchers, window managers, clipboard, etc.)

- **`raycast`** (Spotlight replacement).
  Section: Part 18.
  Why: Highly personal preference; Spotlight is adequate for the stated workflow.

- **Rectangle custom keybindings** (ctrl+option+arrows, quarters, thirds).
  Section: Part 5.
  Why: Manual-only: can't be automated safely – Rectangle stores its shortcut prefs in a domain that requires a launched app to populate; we install the app and leave the defaults.

## 5. Shell customization

- **Oh My Zsh**.
  Section: Part 6.
  Why: Highly personal preference (called out explicitly in README).

- **Powerlevel10k theme**.
  Section: Part 6.
  Why: Highly personal preference (prompt style).

- **`zsh-autosuggestions`, `zsh-syntax-highlighting`, `zsh-completions`**.
  Section: Part 6.
  Why: Highly personal preference (shell behavior changes).

- **Force GNU coreutils ahead of BSD on PATH**.
  Section: Part 6.
  Why: Risky or hard to reverse – explicitly called out in README; breaks stock macOS scripts that expect BSD behavior.

- **Aliases (`ls=eza`, `cat=bat`, `grep=rg`, `find=fd`, `rm=trash`, `vim=nvim`, git/py shortcuts)**.
  Section: Part 6.
  Why: Highly personal preference (core shell UX).

- **Custom `HISTSIZE`, `SHARE_HISTORY`, FZF env vars**.
  Section: Part 6.
  Why: Highly personal preference; avoids owning the user's `.zshrc`.

- **`mkproject`, `note`, `timer` shell functions**.
  Section: Part 18.
  Why: Highly personal preference (personal workflow macros).

## 6. Keyboard / trackpad / input tooling

- **Karabiner-Elements**.
  Section: Part 4 – Cask list.
  Why: Highly personal preference (called out explicitly in README); also installs a system extension that requires manual approval.

- **Hammerspoon / BetterTouchTool**.
  Section: Not explicitly recommended but implied by trackpad/keyboard sections.
  Why: Niche: only a minority of developers want it; BetterTouchTool is paid.

## 7. Python / AI stack items not in `requirements-ai.txt`

- **`pyenv` + `pyenv-virtualenv`**.
  Section: Part 7 – Option A.
  Why: Redundant with installed tooling – `uv` + Homebrew `python@3.12` serve the same role with less surface area.

- **Ollama**.
  Section: Part 9.
  Why: Out of scope for Python/PyTorch/Codex/Claude stated target (called out explicitly in README).

- **llama.cpp (source build or brew)**.
  Section: Part 9.
  Why: Out of scope for Python/PyTorch/Codex/Claude stated target (called out explicitly in README).

- **MLX / `mlx-lm`**.
  Section: Part 9.
  Why: Out of scope for Python/PyTorch/Codex/Claude stated target (local LLM framework, not PyTorch).

- **`lm-studio` cask**.
  Section: Part 9.
  Why: Out of scope for Python/PyTorch/Codex/Claude stated target; also closed-source GUI.

- **Open WebUI (Docker)**.
  Section: Part 9.
  Why: Out of scope for Python/PyTorch/Codex/Claude stated target.

- **`seaborn`, `einops`, `tqdm`, `wandb`, `ipywidgets`, `gymnasium`, `stable-baselines3`, `jax`, `jax-metal`, `aider-chat`**.
  Section: Part 8 / Part 11.
  Why: Niche: only a minority of developers want it – kept `requirements-ai.txt` short and mainstream; `tqdm` arrives transitively via `transformers`/`datasets`.

- **JupyterLab extensions / `ipywidgets` interactive widgets**.
  Section: Part 8.
  Why: Niche: only a minority of developers want it; the base `jupyterlab` + registered kernel is sufficient for most notebooks.

- **`pip cache purge`, `conda clean`, `pip install` into system Python warnings**.
  Section: Part 14.
  Why: Out of scope for Python/PyTorch/Codex/Claude stated target – covered by using `uv` and an isolated venv in the first place.

## 8. Developer toolchain additions

- **Full Xcode IDE + `xcodebuild -license accept` + `xcodebuild -downloadAllPlatforms`**.
  Section: Part 10.
  Why: Manual-only: can't be automated safely – Xcode requires App Store + Apple ID sign-in; the script emits a `next_steps` note instead.

- **iOS / watchOS / visionOS simulators**.
  Section: Part 10.
  Why: Out of scope for Python/PyTorch/Codex/Claude stated target; adds 10+ GB.

- **Rustup, Go, Java, Android SDK**.
  Section: Not explicit in tutorial but implied by "developer environment".
  Why: Out of scope for Python/PyTorch/Codex/Claude stated target.

- **npm globals: `typescript`, `ts-node`, `create-react-app`, `create-next-app`, `vercel`, `netlify-cli`**.
  Section: Part 10 – Web Development.
  Why: Out of scope for Python/PyTorch/Codex/Claude stated target; only Codex + Claude Code are installed as npm globals.

## 9. Security / privacy beyond firewall + Touch ID

- **FileVault enablement / status check (`fdesetup status`)**.
  Section: Part 4 / Part 17.
  Why: Manual-only: can't be automated safely – enabling FileVault requires an interactive recovery-key flow; the tutorial correctly places it in first-boot Setup Assistant.

- **Gatekeeper policy ("App Store and identified developers")**.
  Section: Part 4 – Privacy & Security.
  Why: Already covered by macOS defaults.

- **Full Disk Access for Terminal/iTerm2**.
  Section: Part 16 / Part 17.
  Why: Manual-only: can't be automated safely – TCC grants require user interaction in System Settings; a `next_steps` note is emitted.

- **Firewall per-app allow/block rules**.
  Section: Part 17.
  Why: Manual-only: can't be automated safely – depends on specific app paths that only exist after user installs.

- **SIP disable / `csrutil`**.
  Section: Part 16.
  Why: Risky or hard to reverse – requires Recovery Mode boot; explicitly discouraged by the tutorial itself.

- **Little Snitch / Lulu, YubiKey support**.
  Section: Not in tutorial.
  Why: Niche: only a minority of developers want it.

## 10. Networking / SSH / VPN

- **Generate a new SSH keypair (`ssh-keygen -t ed25519` and `ssh-add --apple-use-keychain`)**.
  Section: Part 6 – SSH Configuration.
  Why: Manual-only: can't be automated safely – requires interactive passphrase + per-user identity decisions; script only writes `~/.ssh/config` when none exists.

- **Enable SSH server (`systemsetup -setremotelogin on`)**.
  Section: Part 17.
  Why: Risky or hard to reverse – opens the machine to inbound connections; should be an explicit user decision.

- **Tailscale / WireGuard / mosh**.
  Section: Not in tutorial.
  Why: Niche: only a minority of developers want it.

## 11. Backup / sync / filesystem

- **Time Machine configuration / local snapshot management (`tmutil`)**.
  Section: Part 14.
  Why: Manual-only: can't be automated safely – destination selection is a GUI flow.

- **iCloud Desktop & Documents / "Optimize Storage" recommendations**.
  Section: Part 14.
  Why: Manual-only: can't be automated safely; requires Apple ID sign-in.

- **rclone configs, Dropbox, etc.**.
  Section: Not in tutorial.
  Why: Niche: only a minority of developers want it.

## 12. Power / battery / thermal

- **`caffeinate` usage tips**.
  Section: Part 3.
  Why: Already covered by macOS defaults – `caffeinate` ships with macOS; no install needed.

- **`pmset` tweaks (display sleep, wake-for-network, etc.)**.
  Section: Part 4 – Energy.
  Why: Risky or hard to reverse for laptops; defaults are sensible and the Docker-related battery notes are already surfaced via `next_steps`.

- **Low Power Mode setting**.
  Section: Part 4.
  Why: Highly personal preference.

## 13. Editor / IDE configuration beyond VS Code install

- **`code` CLI install via Command Palette** – partially implemented via `maybe_link_vscode_cli` (symlink into `~/.local/bin`), so the Cmd+Shift+P step is redundant.
  Section: Part 11.
  Why: Already implemented (symlink approach).

- **VS Code extension install list** (Python, Pylance, Jupyter, Remote-SSH, ESLint, Prettier, GitLens, Copilot, CMake Tools, YAML, TOML, ErrorLens, spell checker, Vim).
  Section: Part 11.
  Why: Highly personal preference (extensions are per-developer workflow); also, some require signed-in accounts (Copilot).

- **VS Code user settings JSON** (font family, theme "One Dark Pro", Material icons, autosave, formatOnSave, Black formatter).
  Section: Part 11.
  Why: Highly personal preference (editor aesthetics/behavior).

- **Cursor IDE**.
  Section: Part 11.
  Why: Out of scope for Python/PyTorch/Codex/Claude stated target; competes with Claude Code already installed.

- **Zed / JetBrains IDEs**.
  Section: Not in tutorial but common.
  Why: Paid or license-restricted software (JetBrains) / niche (Zed).

- **iTerm2 "Natural Text Editing" preset + color schemes + ligatures**.
  Section: Part 6.
  Why: Manual-only: can't be automated safely – iTerm2 preferences live in a binary plist that the app rewrites; risk of corruption outweighs benefit.

## 14. Git configuration beyond `configure_git`

- **Signed commits / GPG or SSH signing key setup**.
  Section: Not in tutorial.
  Why: Manual-only: can't be automated safely – requires generating/choosing a key and registering it with GitHub.

- **`delta` / `diff-so-fancy` pager**.
  Section: Not in tutorial.
  Why: Highly personal preference (diff aesthetics).

- **Extensive alias set beyond `core.*`**.
  Section: Part 6 (`gs`, `gd`, `gl`, `gco`).
  Why: Highly personal preference (shell aliases rather than git config).

- **`gh auth login`**.
  Section: Not explicit, but implied.
  Why: Manual-only: can't be automated safely (interactive OAuth); already surfaced as a `next_steps` note.

## 15. Misc / uncategorized

- **Automator / Shortcuts: "Open Terminal Here" quick action**.
  Section: Part 18.
  Why: Manual-only: can't be automated safely – Automator workflows must be installed into `~/Library/Services` and registered with the Services menu.

- **`mdutil` Spotlight exclusions / index rebuild**.
  Section: Part 14.
  Why: Risky or hard to reverse – Spotlight exclusions affect system search for other apps (Mail, etc.).

- **App Store / Apple ID sign-in**.
  Section: Part 4 – Initial Boot.
  Why: Manual-only: can't be automated safely – gated by Apple ID flow.

- **Setup Assistant choices (Migration Assistant, Siri, Screen Time, Touch ID enrollment)**.
  Section: Part 4.
  Why: Manual-only: can't be automated safely – first-boot wizard is pre-login.

- **Universal Clipboard / Handoff / Continuity toggles**.
  Section: Part 17.
  Why: Highly personal preference.

- **Disable Spotlight indexing for specific folders**.
  Section: Part 13.
  Why: Risky or hard to reverse (per above) and niche.

---

*Audit date: 2026-04-19 · Source branch: `master` · Commit: `71e14c6`*
