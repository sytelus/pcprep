# The Power User's Fast Track to macOS Mastery
## A Complete Guide for Windows/Linux Experts Switching to Mac (M5 Pro)

---

# Table of Contents

1. [Part 1: Understanding macOS — Lineage, Architecture & Philosophy](#part-1-understanding-macos)
2. [Part 2: Terminology & Vocabulary Every Advanced Mac User Knows](#part-2-terminology--vocabulary)
3. [Part 3: macOS vs Ubuntu Linux — The Key Differences](#part-3-macos-vs-ubuntu-linux)
4. [Part 4: Day-One Setup — First Boot to Productive Machine](#part-4-day-one-setup)
5. [Part 5: Keyboard, Navigation & Window Management](#part-5-keyboard-navigation--window-management)
6. [Part 6: The Terminal — Your Home Base](#part-6-the-terminal)
7. [Part 7: Package Management & Developer Environment](#part-7-package-management--developer-environment)
8. [Part 8: Python, PyTorch & Deep Learning on Apple Silicon](#part-8-python-pytorch--deep-learning)
9. [Part 9: Running Local LLMs on M5 Pro](#part-9-running-local-llms-on-m5-pro)
10. [Part 10: iOS/Web Development Setup](#part-10-iosweb-development-setup)
11. [Part 11: VS Code, Coding Agents & Editor Setup](#part-11-vs-code-coding-agents--editor-setup)
12. [Part 12: System Benchmarking & Performance Profiling](#part-12-system-benchmarking--performance-profiling)
13. [Part 13: Debugging, Monitoring & "Why Is My System Busy?"](#part-13-debugging-monitoring--system-busy)
14. [Part 14: Storage Management — Understanding & Reclaiming Space](#part-14-storage-management)
15. [Part 15: Display, Accessibility & Advanced Settings](#part-15-display-accessibility--advanced-settings)
16. [Part 16: Power User Features & Hidden Settings](#part-16-power-user-features--hidden-settings)
17. [Part 17: Security, Networking & Firewall](#part-17-security-networking--firewall)
18. [Part 18: Productivity Workflows & Automation](#part-18-productivity-workflows--automation)
19. [Part 19: Common Pitfalls & How to Avoid Them](#part-19-common-pitfalls)
20. [Part 20: Quick Reference Cheat Sheet](#part-20-quick-reference-cheat-sheet)

---

# Part 1: Understanding macOS

## The Lineage: Why macOS Is Unix But Not Linux

This is the single most important conceptual foundation. You know Ubuntu well — macOS will feel familiar yet subtly different. Here's why:

```
UNIX (1969, AT&T Bell Labs)
├── BSD (Berkeley Software Distribution, 1977)
│   ├── FreeBSD
│   ├── OpenBSD
│   ├── NetBSD
│   └── NeXTSTEP (1989, Steve Jobs' company after leaving Apple)
│       └── Darwin (open-source kernel, Apple, 2000)
│           └── macOS (proprietary userland + Darwin kernel)
│               ├── XNU Kernel (Mach microkernel + BSD layer)
│               ├── BSD userland tools (often older versions)
│               ├── Aqua GUI (the graphical interface)
│               └── Frameworks: Cocoa, Metal, Core ML, etc.
│
├── System V
│   └── (influenced many commercial Unixes)
│
└── Linux (1991, Linus Torvalds — NOT Unix, Unix-like)
    ├── Debian → Ubuntu
    ├── Red Hat → Fedora, CentOS
    └── Arch, etc.
```

**Key insight**: macOS is a *certified UNIX* operating system (UNIX 03 compliant via the Open Group). Linux is "Unix-like" but never certified. Ironically, macOS is more "Unix" than Linux in a legal/certification sense.

### The XNU Kernel

macOS runs the **XNU kernel** ("X is Not Unix" — a recursive joke). It's a hybrid:
- **Mach microkernel**: Handles memory management, IPC (inter-process communication), threading
- **BSD layer**: Provides the POSIX API, networking stack, file systems, process model
- **I/O Kit**: Object-oriented driver framework (written in a restricted subset of C++)

This is fundamentally different from the Linux monolithic kernel. In practice, you rarely notice — but it explains some behavioral differences.

### Apple Silicon Architecture

Your M5 Pro uses Apple's ARM-based architecture:
- **Unified Memory Architecture (UMA)**: CPU and GPU share the same physical memory pool. No copying data between CPU RAM and GPU VRAM — this is why local LLMs run so efficiently on Apple Silicon.
- **Neural Engine**: Dedicated hardware for ML inference (used by Core ML)
- **Performance/Efficiency Cores**: Like ARM big.LITTLE. macOS schedules tasks automatically.
- **Metal**: Apple's GPU API (replaces OpenGL, which is deprecated on macOS). PyTorch uses Metal via the MPS (Metal Performance Shaders) backend.
- **Memory bandwidth**: Apple Silicon has exceptionally high memory bandwidth compared to typical DDR configurations, which is critical for LLM inference where the bottleneck is memory bandwidth.

### The File System: APFS

macOS uses **APFS** (Apple File System), not ext4:
- **Case-insensitive but case-preserving** (by default): `README.md` and `readme.md` are the SAME file. This catches Linux users constantly. You can format as case-sensitive, but many macOS apps break.
- **Copy-on-write**: Duplicating files is nearly instant (space-efficient clones)
- **Snapshots**: Time Machine uses these for backups
- **No traditional partition table dance**: APFS uses "containers" with flexible "volumes" that share space
- **Space sharing**: Multiple volumes in a container dynamically share free space

### The Security Model

macOS has multiple layers that will surprise you:
- **Gatekeeper**: Blocks apps not signed or notarized by Apple
- **System Integrity Protection (SIP)**: Prevents modification of system files, even by root
- **TCC (Transparency, Consent, and Control)**: Per-app permissions for camera, mic, files, screen recording, accessibility, etc.
- **Signed System Volume (SSV)**: The system volume is cryptographically sealed
- **App Sandbox**: App Store apps run in sandboxes with limited file system access

---

# Part 2: Terminology & Vocabulary

Here's the vocabulary that Mac power users use daily. Your Windows/Linux equivalent is provided:

## Hardware & System Terms

| Mac Term | What It Means | Windows/Linux Equivalent |
|----------|--------------|------------------------|
| **Apple Silicon** | Apple's ARM-based SoC (M1/M2/M3/M4/M5 family) | Intel/AMD CPU + discrete GPU |
| **Unified Memory** | Shared CPU/GPU memory pool | RAM + VRAM (separate) |
| **Neural Engine** | On-chip ML accelerator | No direct equivalent (like a built-in NPU) |
| **MagSafe** | Magnetic charging connector | Barrel jack / USB-C PD |
| **Touch ID** | Fingerprint sensor in power button | Windows Hello fingerprint |
| **Touch Bar** | (Older models) OLED strip replacing function keys | N/A (discontinued on new models) |
| **Retina Display** | High-DPI display (>200 PPI) | HiDPI display |
| **ProMotion** | Adaptive refresh rate (up to 120Hz) | Variable refresh rate / G-Sync |
| **Force Touch / Haptic Trackpad** | Pressure-sensitive trackpad with haptic feedback | Standard trackpad + click |
| **Thunderbolt** | High-bandwidth port (USB-C connector, TB protocol) | Thunderbolt (same, but Mac has it on all ports) |
| **SMC** | System Management Controller (power, fans, lights) | Embedded controller |
| **NVRAM/PRAM** | Non-volatile RAM storing boot settings | BIOS/UEFI settings |
| **T2/Secure Enclave** | Security chip (handles Touch ID, encryption, boot) | TPM (Trusted Platform Module) |

## Software & UI Terms

| Mac Term | What It Means | Windows/Linux Equivalent |
|----------|--------------|------------------------|
| **Finder** | File manager application | File Explorer / Nautilus |
| **Dock** | App launcher bar (bottom/side of screen) | Taskbar |
| **Menu Bar** | Top of screen, always-visible app menu | Title bar menu (per window) |
| **Mission Control** | Overview of all windows and desktops | Task View (Win+Tab) |
| **Spaces** | Virtual desktops | Virtual Desktops |
| **Spotlight** | System-wide search (Cmd+Space) | Windows Search / Start menu |
| **Launchpad** | Grid of all installed apps | Start menu |
| **Stage Manager** | Window tiling/management feature | Snap Layouts |
| **AirDrop** | Peer-to-peer file sharing | Nearby Share |
| **Handoff / Continuity** | Cross-device workflow (Mac ↔ iPhone) | No direct equivalent |
| **Universal Clipboard** | Copy on one Apple device, paste on another | Cloud clipboard (limited) |
| **Quick Look** | Press Space to preview any file in Finder | Preview pane |
| **Time Machine** | Built-in incremental backup system | File History / rsync |
| **FileVault** | Full-disk encryption | BitLocker / LUKS |
| **Gatekeeper** | App signature/notarization enforcement | SmartScreen |
| **SIP** | System Integrity Protection | No equivalent (prevents root from modifying OS) |
| **Activity Monitor** | Process and resource monitor | Task Manager / htop |
| **Console.app** | System log viewer | Event Viewer / journalctl |
| **Disk Utility** | Disk management and formatting | Disk Management / GParted |
| **Terminal.app** | Built-in terminal emulator | cmd/PowerShell / GNOME Terminal |
| **DMG** | Disk image (app distribution format) | ISO / installer .exe |
| **PKG** | Installer package | MSI / .deb |
| **App Bundle (.app)** | A directory that looks like a single file | .exe + supporting DLLs |
| **Preferences / Settings** | System configuration | Control Panel / Settings |
| **plist** | Property List — XML/binary config files | Registry / .conf files |
| **defaults** | CLI tool to read/write plist preferences | reg.exe / gsettings |
| **Keychain** | System password/secret manager | Credential Manager / GNOME Keyring |
| **Login Items** | Apps that start on login | Startup folder / systemd user services |
| **launchd** | Init system and service manager | systemd / Task Scheduler |
| **Homebrew** | Third-party package manager | apt / winget |
| **Rosetta 2** | x86 → ARM translation layer | WSL (different purpose, but similar idea of compatibility layer) |
| **XProtect** | Built-in antimalware | Windows Defender |

## Common Mac Jargon in Conversation

- **"Nuke and pave"**: Erase and reinstall macOS from scratch
- **"Blessed volume"**: The bootable system volume
- **"Recovery Mode"**: Boot environment for reinstalling/repairing (hold power button on Apple Silicon)
- **"Safe Boot"**: Minimal boot with extensions disabled (hold Shift)
- **"PRAM reset"**: Clearing stored hardware settings (less relevant on Apple Silicon)
- **"Kernel panic"**: macOS equivalent of BSOD / Linux kernel panic (same term)
- **"Beach ball"**: The spinning rainbow wait cursor (system is busy/hung)
- **"Quarantine flag"**: Extended attribute macOS adds to downloaded files for Gatekeeper
- **"Notarized"**: App has been scanned and approved by Apple's automated system
- **"Fat binary" / "Universal binary"**: App compiled for both Intel and ARM
- **"Kext"**: Kernel extension (like a Linux kernel module) — mostly deprecated in favor of System Extensions
- **"Cask"**: Homebrew term for GUI applications (vs. CLI "formulae")

---

# Part 3: macOS vs Ubuntu Linux

## File System Layout

```
Ubuntu Linux:                    macOS:
/                               /
├── /bin                        ├── /bin          (symlink → /usr/bin on modern macOS)
├── /sbin                       ├── /sbin         (symlink → /usr/sbin)
├── /usr                        ├── /usr
│   ├── /usr/bin                │   ├── /usr/bin
│   ├── /usr/lib                │   ├── /usr/lib
│   └── /usr/local              │   └── /usr/local  ← Homebrew installs here (Intel)
├── /etc                        ├── /etc           (symlink → /private/etc)
├── /tmp                        ├── /tmp           (symlink → /private/tmp)
├── /var                        ├── /var           (symlink → /private/var)
├── /home/username              ├── /Users/username ← NOTE: /Users, not /home
├── /root                       ├── /var/root
├── /opt                        ├── /opt
│                               ├── /opt/homebrew  ← Homebrew installs here (ARM)
├── /proc                       │                  ← NO /proc on macOS!
├── /sys                        │                  ← NO /sys on macOS!
│                               ├── /System        ← macOS system files (read-only, sealed)
│                               ├── /Library       ← System-wide app support, preferences
│                               ├── /Applications  ← Where .app bundles live
│                               ├── /Volumes       ← Mount point for all volumes
│                               └── /private       ← Contains real etc, tmp, var
```

**Critical differences:**
- No `/proc` filesystem. Use `sysctl` to query kernel parameters instead.
- No `/sys`. Device info comes through `ioreg`, `system_profiler`, and I/O Kit.
- `/Users` not `/home`. The `$HOME` variable works the same, but the path is different.
- `/System` is **read-only and sealed** by the Signed System Volume. You cannot modify it even with `sudo`. SIP enforces this.
- Homebrew on Apple Silicon installs to `/opt/homebrew`, not `/usr/local`.

## Command Differences

Many commands you know from Ubuntu have different versions or are missing on macOS because macOS ships **BSD userland tools**, not GNU coreutils.

### Commands That Behave Differently

| Command | Ubuntu (GNU) | macOS (BSD) | Fix |
|---------|-------------|-------------|-----|
| `ls` | GNU ls (colorized with `--color=auto`) | BSD ls (use `-G` for color) | Install `coreutils` via Homebrew |
| `sed` | GNU sed (supports `-i` without extension) | BSD sed (`-i` requires `''` as arg: `sed -i '' 's/a/b/'`) | Install `gnu-sed` |
| `grep` | GNU grep (supports `-P` for PCRE) | BSD grep (no `-P` flag) | Install `grep` (GNU version) |
| `find` | GNU find | BSD find (minor option differences) | Install `findutils` |
| `xargs` | GNU xargs | BSD xargs (no `--no-run-if-empty` by default) | Install `findutils` |
| `date` | GNU date (supports `-d` for date parsing) | BSD date (uses `-j -f` instead) | Install `coreutils` |
| `tar` | GNU tar | BSD tar (bsdtar — different flags for some operations) | Install `gnu-tar` |
| `readlink` | GNU readlink (supports `-f`) | BSD readlink (no `-f`) | Install `coreutils` |
| `stat` | GNU stat | BSD stat (completely different syntax!) | Install `coreutils` |
| `du` | GNU du | BSD du (no `--max-depth`, use `-d`) | Install `coreutils` |
| `cp` | GNU cp | BSD cp (no `--reflink`) | APFS clones via `cp -c` |
| `mktemp` | GNU mktemp | BSD mktemp (different template requirements) | Install `coreutils` |

### Commands That Don't Exist on macOS

| Ubuntu Command | macOS Alternative |
|---------------|-------------------|
| `apt` / `apt-get` | `brew` (Homebrew) |
| `systemctl` | `launchctl` (launchd) |
| `journalctl` | `log show` / Console.app |
| `ip addr` | `ifconfig` (still works) or `networksetup` |
| `ss` | `lsof -i` or `netstat` |
| `lspci` | `system_profiler SPPCIDataType` |
| `lsusb` | `system_profiler SPUSBDataType` |
| `lsblk` | `diskutil list` |
| `free` | `vm_stat` or `memory_pressure` |
| `dmesg` | `log show --predicate 'eventMessage contains "..."'` |
| `uname -r` | `uname -r` (works but shows XNU version) / `sw_vers` for macOS version |
| `useradd` | `sysadminctl` or `dscl` (Directory Services CLI) |
| `service` | `launchctl` |
| `update-alternatives` | No equivalent; manage via Homebrew or PATH |
| `xdg-open` | `open` |
| `xclip` / `xsel` | `pbcopy` / `pbpaste` |
| `notify-send` | `osascript -e 'display notification ...'` or `terminal-notifier` |
| `watch` | Install via `brew install watch` |
| `htop` | Install via `brew install htop` (or use `top`, Activity Monitor) |
| `tree` | Install via `brew install tree` |

### macOS-Specific Commands You Should Learn

```bash
# System information
sw_vers                      # macOS version info
system_profiler              # Detailed hardware/software info
sysctl -a                    # Kernel parameters (replaces /proc)
ioreg                        # I/O Registry (device tree)

# Disk management
diskutil list                # List disks and partitions
diskutil info /              # Info about root volume
diskutil apfs list           # List APFS containers/volumes

# File operations
open .                       # Open current directory in Finder
open -a "Application Name"   # Launch an application
open file.pdf                # Open file with default app
mdfind "search term"         # Spotlight search from CLI
mdls file.txt                # Show Spotlight metadata for a file
xattr -l file                # Show extended attributes
xattr -d com.apple.quarantine file  # Remove quarantine flag

# Clipboard
pbcopy < file.txt            # Copy file contents to clipboard
echo "hello" | pbcopy        # Copy string to clipboard
pbpaste                      # Paste clipboard contents
pbpaste > file.txt           # Paste clipboard to file

# Network
networksetup -listallhardwareports  # List network interfaces
scutil --dns                 # DNS configuration
dscacheutil -flushcache      # Flush DNS cache

# Services (launchd — replaces systemd)
launchctl list               # List loaded services
launchctl load ~/Library/LaunchAgents/com.example.plist
launchctl unload ~/Library/LaunchAgents/com.example.plist

# Preferences (replaces registry editing)
defaults read                # Read all preferences
defaults read com.apple.finder  # Read Finder preferences
defaults write com.apple.finder AppleShowAllFiles -bool true  # Show hidden files
defaults delete com.apple.dock  # Reset Dock to defaults

# Power and hardware
pmset -g                     # Power management settings
caffeinate -t 3600           # Prevent sleep for 1 hour
system_profiler SPHardwareDataType  # Hardware overview

# macOS-specific utilities
say "Hello World"            # Text-to-speech
screencapture -i output.png  # Interactive screenshot
textutil -convert html doc.rtf  # Document format conversion
plutil -lint file.plist      # Validate plist files
log show --last 1h           # Show system logs from last hour
```

## Process & Service Management: launchd vs systemd

macOS uses `launchd` instead of `systemd`. It's similar in concept but different in practice:

```bash
# systemd (Ubuntu)              → launchd (macOS)
systemctl start nginx           → launchctl load /path/to/plist
systemctl stop nginx            → launchctl unload /path/to/plist
systemctl enable nginx          → Place plist in LaunchDaemons/LaunchAgents
systemctl disable nginx         → Remove plist (or use launchctl unload -w)
systemctl status nginx          → launchctl list | grep nginx
journalctl -u nginx             → log show --predicate 'process == "nginx"'
systemctl daemon-reload         → (not needed — launchd watches automatically)
```

Service plist locations:
- `/System/Library/LaunchDaemons/` — Apple system daemons (read-only)
- `/Library/LaunchDaemons/` — Third-party system daemons (runs as root)
- `/Library/LaunchAgents/` — Third-party per-user agents (runs on any user login)
- `~/Library/LaunchAgents/` — Per-user agents (runs on your login only)

A launch agent plist looks like this:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.example.myservice</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/myservice</string>
        <string>--flag</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/myservice.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/myservice.stderr.log</string>
</dict>
</plist>
```

---

# Part 4: Day-One Setup

## Initial Boot Checklist

When you first power on your M5 Pro MacBook, macOS Setup Assistant will walk you through basics. Here are the important choices:

1. **Language & Region**: Choose your preference. You can change later.
2. **Accessibility**: Skip for now (we'll configure later).
3. **Wi-Fi**: Connect to your network.
4. **Migration Assistant**: **Skip this** since you're coming from Windows. You can always run it later from `/Applications/Utilities/Migration Assistant.app` if needed.
5. **Apple ID**: Sign in or create one. This is important for:
   - App Store access (needed for Xcode)
   - iCloud sync (optional but useful)
   - Find My Mac (theft protection)
6. **FileVault**: **Enable it.** Full-disk encryption with negligible performance impact on Apple Silicon. Your disk is hardware-encrypted by default, but FileVault adds user-password-gated access.
7. **Siri**: Your choice. You can disable later.
8. **Screen Time**: Skip.
9. **Touch ID**: Set up at least one fingerprint. You'll use it constantly for `sudo`, app installs, and password autofill.

## Essential System Preferences (Now Called "System Settings")

Open **System Settings** (⌘ + Space, type "System Settings"):

### General
```
System Settings → General → Software Update
  → Enable "Check for updates" and "Install macOS updates"
  → Enable "Install application updates from the App Store"

System Settings → General → About
  → Note your macOS version, memory, serial number
```

### Trackpad (This Is Crucial — Mac Trackpads Are a Superpower)
```
System Settings → Trackpad
  → Point & Click:
    → "Tap to click" → ON (otherwise you have to physically press)
    → "Tracking speed" → Move to 70-80% (faster than default)
    → "Click" → Set to "Light"
    → "Force Click and haptic feedback" → ON
    → "Look up & data detectors" → "Tap with Three Fingers"
  → Scroll & Zoom:
    → "Natural scrolling" → Your preference
      (If coming from Windows, you might want this OFF — it reverses scroll direction.
       "Natural" means content follows finger direction, like a touchscreen.)
    → "Zoom in or out" → ON (pinch to zoom)
    → "Smart zoom" → ON (double-tap two fingers)
    → "Rotate" → ON
  → More Gestures:
    → "Swipe between pages" → "Scroll Left or Right with Two Fingers"
    → "Swipe between full-screen apps" → "Swipe Left or Right with Three Fingers"  
    → "Mission Control" → "Swipe Up with Three Fingers"
    → "App Exposé" → "Swipe Down with Three Fingers"
```

### Keyboard
```
System Settings → Keyboard
  → "Key repeat rate" → Fast (rightmost)
  → "Delay until repeat" → Short (rightmost)
  → "Press 🌐 key to" → Change this to "Do Nothing" or "Show Emoji"
  → Keyboard Shortcuts → Modifier Keys:
    → CRITICAL FOR WINDOWS USERS:
      Consider swapping Caps Lock → Control (or Escape for Vim users)
      Many developers do this because Ctrl is used heavily in terminal
  → Keyboard Shortcuts → Function Keys:
    → "Use F1, F2, etc. keys as standard function keys" → ON
      (You can still access brightness/volume by holding Fn)
  → Text Input → Input Sources → Edit:
    → Turn OFF "Correct spelling automatically"
    → Turn OFF "Capitalize words automatically"
    → Turn OFF "Add period with double-space" 
    → Turn OFF all smart quotes and dashes (these WILL break your code)
```

**⚠️ CRITICAL**: Those auto-correct and smart quote settings will absolutely ruin your day when coding. `"straight quotes"` become `"curly quotes"` silently, breaking JSON, Python strings, and everything else. Disable these immediately.

### Display
```
System Settings → Displays
  → Resolution: Choose "More Space" for maximum screen real estate
    (The MacBook Pro Retina display can push more logical pixels)
  → ProMotion: Should be "Adaptive" by default (120Hz)
  → True Tone: ON (adapts color temperature to ambient light)
  → Night Shift: Schedule → Sunset to Sunrise (reduces blue light)
```

### Desktop & Dock
```
System Settings → Desktop & Dock
  → Size: → Make it smaller (30-40%)
  → Magnification: → OFF (or slight, your preference)
  → "Position on screen" → Bottom or Left (Left saves vertical space)
  → "Minimize windows using" → "Scale effect" (faster than Genie)
  → "Automatically hide and show the Dock" → ON (reclaim screen space)
  → "Show suggested and recent apps in Dock" → OFF
  → "Default web browser" → Set your preference
  → "Hot Corners" (at the bottom):
    → Top-left: Mission Control
    → Top-right: Desktop
    → Bottom-left: (disabled or Lock Screen)
    → Bottom-right: Quick Note
    Hot Corners are a power-user feature — you fling your cursor to a corner
    to trigger an action instantly.
```

### Appearance & Wallpaper
```
System Settings → Appearance
  → "Appearance" → Auto (switches dark/light with time)
  → "Accent color" → Your preference
  → "Sidebar icon size" → Small (more items visible)
  → "Show scroll bars" → "Always"
```

### Privacy & Security
```
System Settings → Privacy & Security
  → FileVault: Verify it's ON
  → Firewall: Turn ON
  → Allow applications downloaded from: "App Store and identified developers"
  → Full Disk Access: You'll add Terminal/iTerm here later
  → Developer Tools: You'll add Terminal here to bypass some restrictions
```

### Energy
```
System Settings → Battery
  → "Low power mode" → "Only on Battery" or "Never" for development
  → Options:
    → "Prevent automatic sleeping on power adapter" → ON
    → "Wake for network access" → ON
```

### Lock Screen
```
System Settings → Lock Screen
  → "Require password after screen saver begins or display is turned off"
    → "After 5 seconds" (good security/convenience balance)
```

## Install Xcode Command Line Tools (Do This First)

Before anything else, you need the Xcode Command Line Tools. This gives you `git`, `clang`, `make`, and other essential build tools:

```bash
xcode-select --install
```

A dialog will pop up. Click "Install" and wait (~5-10 minutes on fast internet). This is separate from the full Xcode IDE (which is ~35 GB). You only need the full Xcode if you're building iOS apps (we'll cover that later).

Verify:
```bash
xcode-select -p
# Should output: /Library/Developer/CommandLineTools
git --version
clang --version
```

## Install Homebrew (Your Package Manager)

Homebrew is the de facto macOS package manager. Think of it as `apt` for macOS:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After installation, **follow the instructions it prints** to add Homebrew to your PATH. On Apple Silicon, it installs to `/opt/homebrew`, so you'll need:

```bash
# Add to ~/.zprofile (or ~/.zshrc)
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Then reload:
```bash
source ~/.zprofile
```

Verify:
```bash
brew --version
brew doctor    # Checks for issues
```

### Essential Homebrew Packages to Install Immediately

```bash
# GNU coreutils (so commands behave like Linux)
brew install coreutils findutils gnu-sed gnu-tar grep gawk

# Essential CLI tools
brew install wget curl htop tree jq ripgrep fd bat eza
brew install fzf tmux watch gnu-which

# After installing fzf, run its install script:
$(brew --prefix)/opt/fzf/install

# Development essentials
brew install git git-lfs cmake ninja pkg-config

# System monitoring
brew install btop neofetch

# Useful utilities  
brew install tldr trash-cli rename

# Modern CLI replacements
# bat = cat with syntax highlighting
# eza = ls with colors and git integration
# ripgrep (rg) = grep but 10x faster
# fd = find but faster and more intuitive
# fzf = fuzzy finder for everything
```

### Install GUI Applications via Homebrew Casks

```bash
# Terminal
brew install --cask iterm2          # Superior terminal emulator

# Browser
brew install --cask firefox         # or google-chrome

# Editors
brew install --cask visual-studio-code

# Utilities
brew install --cask rectangle       # Window management (ESSENTIAL)
brew install --cask alt-tab         # Windows-style Alt-Tab behavior
brew install --cask stats           # Menu bar system monitor
brew install --cask appcleaner      # Properly uninstall apps (removes plists etc.)
brew install --cask the-unarchiver  # Handle all archive formats
brew install --cask karabiner-elements  # Advanced keyboard customization

# Development
brew install --cask docker          # Docker Desktop

# Quick Look plugins (preview files by pressing Space in Finder)
brew install --cask qlmarkdown qlstephen
```

### Set Up Homebrew Auto-Update

```bash
# Check for updates periodically
brew autoupdate start --upgrade --cleanup
```

## Configure Finder for Power Users

Finder is weak by default. Fix it:

```bash
# Show hidden files (dotfiles)
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show path bar at bottom of Finder
defaults write com.apple.finder ShowPathbar -bool true

# Show status bar at bottom of Finder
defaults write com.apple.finder ShowStatusBar -bool true

# Show full POSIX path in title bar
defaults write com.apple.finder _FNSPathControlTitlePath -bool true

# Search the current folder by default (not the whole Mac)
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Use column view by default (most useful for developers)
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"
# Options: icnv (icon), Nlsv (list), clmv (column), Flwv (gallery)

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Restart Finder to apply
killall Finder
```

## Configure Dock

```bash
# Remove animation delay for hiding/showing
defaults write com.apple.dock autohide-delay -float 0

# Speed up hide/show animation
defaults write com.apple.dock autohide-time-modifier -float 0.3

# Don't show recent applications
defaults write com.apple.dock show-recents -bool false

# Minimize to application icon
defaults write com.apple.dock minimize-to-application -bool true

# Restart Dock
killall Dock
```

## Configure Screenshots

By default, screenshots go to Desktop and are PNG. Let's fix that:

```bash
# Create a dedicated screenshots folder
mkdir -p ~/Screenshots

# Set screenshots to save there
defaults write com.apple.screencapture location -string "~/Screenshots"

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

# Apply
killall SystemUIServer
```

Screenshot shortcuts:
- `Cmd+Shift+3`: Full screen
- `Cmd+Shift+4`: Selection
- `Cmd+Shift+4, then Space`: Specific window
- `Cmd+Shift+5`: Screenshot toolbar (screen recording too)

---

# Part 5: Keyboard, Navigation & Window Management

## The Modifier Key Map (Most Important Concept)

macOS has FOUR modifier keys. This is the mapping from Windows:

```
Windows:          macOS:           Symbol:
Ctrl          →   ⌘ Command       ⌘
Alt           →   ⌥ Option        ⌥
Windows key   →   (no equivalent — Spotlight uses ⌘+Space)
              →   ⌃ Control       ⌃  (exists but used less in GUI, more in terminal)
Shift         →   ⇧ Shift         ⇧
              →   🌐 Fn/Globe     fn (bottom-left key on Mac keyboards)
```

**The core mental shift**: Almost everywhere you used `Ctrl` on Windows, use `⌘ Command` on Mac:
- `Ctrl+C` (copy) → `⌘+C`
- `Ctrl+V` (paste) → `⌘+V`
- `Ctrl+Z` (undo) → `⌘+Z`
- `Ctrl+S` (save) → `⌘+S`
- `Ctrl+Tab` (switch tabs) → `⌘+Tab` is app switching; `⌃+Tab` is tab switching
- `Alt+Tab` (switch apps) → `⌘+Tab`
- `Alt+F4` (close window) → `⌘+Q` (quit app) or `⌘+W` (close window)

**But in the Terminal**, `Ctrl` is still `Ctrl` for terminal control sequences:
- `Ctrl+C` to interrupt a process (NOT `⌘+C` — that copies text)
- `Ctrl+D` for EOF
- `Ctrl+Z` to suspend
- `Ctrl+R` for reverse search

This dual-mode behavior is actually elegant once you internalize it: `⌘` for GUI operations, `⌃` for terminal/Unix operations.

## Essential Keyboard Shortcuts

### System-Wide
```
⌘ + Space          Spotlight search (launch apps, files, calculations)
⌘ + Tab            Switch between apps (like Alt+Tab)
⌘ + ` (backtick)   Switch between windows of SAME app
⌘ + Q              Quit application (not just close window!)
⌘ + W              Close current window/tab
⌘ + H              Hide application
⌘ + M              Minimize to dock
⌘ + N              New window/document
⌘ + T              New tab (in most apps)
⌘ + ,              Open preferences for current app (universal convention!)
⌘ + Shift + .      Show/hide hidden files in Open/Save dialogs
⌘ + Option + Esc   Force Quit Applications (like Ctrl+Alt+Delete)
⌘ + Shift + 3/4/5  Screenshots (full/selection/toolbar)
⌃ + ⌘ + Q          Lock screen
⌃ + ⌘ + F          Toggle fullscreen for current app
Fn + F              Toggle full-screen (newer macOS)
```

### Text Editing (Works Everywhere, Not Just Terminal)
```
⌘ + Left/Right     Jump to beginning/end of line
⌘ + Up/Down        Jump to beginning/end of document
⌥ + Left/Right     Jump between words (like Ctrl+Left/Right on Windows)
⌥ + Delete         Delete previous word
Fn + Delete         Forward delete (Mac keyboards lack a forward delete key!)
⌘ + Delete          Delete to beginning of line
⌘ + Shift + Left    Select to beginning of line
⌥ + Shift + Left    Select previous word
⌃ + K               Kill (cut) to end of line (Emacs-style — works everywhere)
⌃ + A / ⌃ + E       Beginning / End of line (Emacs-style)
```

### Finder
```
⌘ + Shift + G       Go to Folder (type a path)
⌘ + Shift + .       Toggle hidden files
Space                Quick Look (preview file without opening)
⌘ + I                Get Info (file properties)
⌘ + D                Duplicate
⌘ + Delete           Move to Trash
⌘ + Shift + Delete   Empty Trash
Enter                Rename selected file (NOT open! Double-click to open.)
⌘ + ↓                Open selected file/folder
⌘ + ↑                Go to parent folder
```

### IMPORTANT: Close vs Quit

This confuses every Windows user:
- **⌘+W** (Close): Closes the current window. The app **keeps running** in the background. The Dock dot/indicator stays visible under the app icon.
- **⌘+Q** (Quit): Actually terminates the application.

On Windows, closing the last window usually quits the app. On macOS, apps persist without windows. This is by design — Mac apps are meant to be "always ready." But it does use memory, so quit apps you're not using.

## Window Management with Rectangle

macOS has no built-in keyboard-driven window snapping like Windows' `Win+Arrow`. Install Rectangle (you did in the Homebrew section above):

```
# Rectangle shortcuts (after install, works like Windows):
⌃ + ⌥ + Left        Snap window to left half
⌃ + ⌥ + Right       Snap window to right half
⌃ + ⌥ + Up          Snap window to top half
⌃ + ⌥ + Down        Snap window to bottom half
⌃ + ⌥ + Enter       Maximize window
⌃ + ⌥ + C           Center window
⌃ + ⌥ + U           Top-left quarter
⌃ + ⌥ + I           Top-right quarter
⌃ + ⌥ + J           Bottom-left quarter
⌃ + ⌥ + K           Bottom-right quarter
⌃ + ⌥ + D           First third
⌃ + ⌥ + F           Center third
⌃ + ⌥ + G           Last third
```

## Spaces (Virtual Desktops)

Create and manage virtual desktops:
- **Open Mission Control**: Swipe up with 3 fingers, or press `⌃+Up`
- **Add a Space**: Click `+` in the top-right of Mission Control
- **Switch Spaces**: Swipe left/right with 3 fingers, or `⌃+Left/Right`
- **Move window to another Space**: Drag window to edge of screen and hold, or in Mission Control drag window to a Space

Recommended setup: 3-4 Spaces for different contexts (e.g., Code, Browser, Terminal, Communication).

---

# Part 6: The Terminal

## Choosing a Terminal: iTerm2

While macOS includes Terminal.app, install **iTerm2** for a dramatically better experience:

```bash
brew install --cask iterm2
```

Key iTerm2 features:
- Split panes (`⌘+D` horizontal, `⌘+Shift+D` vertical)
- Search across scrollback (`⌘+F`)
- Profiles with different themes/fonts
- Native tmux integration
- Clickable URLs
- Autocomplete from scrollback
- Instant replay (step through terminal history)

### iTerm2 Configuration

Open iTerm2 → Preferences (`⌘+,`):
- **Appearance → Theme**: "Minimal" (modern look)
- **Profiles → Default → Colors**: Import a color scheme (e.g., Solarized Dark, Catppuccin, or Dracula from https://iterm2colorschemes.com)
- **Profiles → Default → Text**:
  - Font: "JetBrains Mono" or "MesloLGS NF" (Nerd Font) at 13-14pt
  - Enable "Use ligatures" if your font supports them
- **Profiles → Default → Terminal**:
  - "Scrollback lines": 10000 (or unlimited)
- **Profiles → Default → Keys → Key Mappings → Presets**:
  - Select "Natural Text Editing" — this makes ⌥+Arrow move between words and ⌘+Arrow jump to line start/end inside the terminal. Without this, your shell won't respond to Mac text editing shortcuts.

### Install a Good Font

Developer fonts with ligatures and powerline symbols:
```bash
brew install --cask font-jetbrains-mono
brew install --cask font-meslo-lg-nerd-font
brew install --cask font-fira-code
```

## Zsh — Your Default Shell

macOS defaults to **zsh** (not bash). Zsh is excellent. Here's how to power it up:

### Install Oh My Zsh

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Install Powerlevel10k Theme (Fast, Beautiful, Informative)

```bash
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
  ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```

Edit `~/.zshrc`:
```bash
ZSH_THEME="powerlevel10k/powerlevel10k"
```

Restart terminal — Powerlevel10k's configuration wizard will launch.

### Install Essential Zsh Plugins

```bash
# Autosuggestions (suggests commands from history as you type)
git clone https://github.com/zsh-users/zsh-autosuggestions \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Syntax highlighting (colors commands green/red as you type)
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Completions
git clone https://github.com/zsh-users/zsh-completions \
  ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions
```

Edit `~/.zshrc` plugins line:
```bash
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  docker
  kubectl
  python
  pip
  fzf
  brew
)
```

### Useful .zshrc Additions

```bash
# GNU coreutils with normal names (optional — prefix with 'g' is default)
# This makes 'ls' behave like GNU ls instead of BSD ls
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/findutils/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/gnu-tar/libexec/gnubin:$PATH"

# Aliases
alias ls='eza --icons --group-directories-first'
alias ll='eza -alh --icons --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never'
alias grep='rg'
alias find='fd'
alias top='btop'
alias vim='nvim'     # if you install neovim

# Quick directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# macOS specific
alias showfiles='defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder'
alias hidefiles='defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder'
alias flushdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'
alias localip='ipconfig getifaddr en0'
alias publicip='curl -s ifconfig.me'
alias cleanup='find . -name ".DS_Store" -type f -delete'

# Quick edit configs
alias zshrc='code ~/.zshrc'
alias reload='source ~/.zshrc'

# Python/ML aliases
alias py='python3'
alias pip='pip3'
alias jup='jupyter notebook'
alias tb='tensorboard --logdir'

# Git aliases (in addition to oh-my-zsh git plugin)
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -20'
alias gco='git checkout'

# Safety nets
alias rm='trash'   # Move to trash instead of permanent delete
alias cp='cp -i'   # Prompt before overwrite
alias mv='mv -i'

# History settings
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY       # Share history between terminals
setopt HIST_IGNORE_DUPS    # Ignore duplicate commands
setopt HIST_IGNORE_SPACE   # Ignore commands starting with space

# FZF configuration
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
```

### SSH Configuration

If you SSH into remote servers:
```bash
# macOS-specific: Use Keychain to store SSH key passphrases
# Create or edit ~/.ssh/config:
Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519
```

Generate a new SSH key:
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
# Add to macOS Keychain:
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

---

# Part 7: Package Management & Developer Environment

## Homebrew Deep Dive

```bash
# Search for packages
brew search <term>

# Install formula (CLI tool)
brew install <formula>

# Install cask (GUI app)
brew install --cask <app>

# List installed packages
brew list
brew list --cask

# Update Homebrew itself + all package definitions
brew update

# Upgrade all installed packages
brew upgrade

# Upgrade a specific package
brew upgrade <formula>

# See outdated packages
brew outdated

# Remove a package
brew uninstall <formula>

# Cleanup old versions and cache
brew cleanup

# See info about a package
brew info <formula>

# List package dependencies
brew deps <formula>
brew deps --tree <formula>

# Tap additional repositories
brew tap <user/repo>

# Pin a package to prevent upgrades
brew pin <formula>
```

### Brewfile — Version Control Your Setup

Create a `Brewfile` to reproducibly set up any Mac:

```bash
# Generate from current installation
brew bundle dump --file=~/Brewfile

# Install from Brewfile
brew bundle --file=~/Brewfile
```

Example `Brewfile`:
```ruby
# Taps
tap "homebrew/bundle"

# CLI tools
brew "git"
brew "git-lfs"
brew "coreutils"
brew "gnu-sed"
brew "ripgrep"
brew "fd"
brew "bat"
brew "eza"
brew "fzf"
brew "htop"
brew "btop"
brew "jq"
brew "tree"
brew "tmux"
brew "watch"
brew "wget"
brew "cmake"
brew "ninja"
brew "neovim"
brew "trash-cli"

# GUI applications
cask "iterm2"
cask "visual-studio-code"
cask "rectangle"
cask "alt-tab"
cask "stats"
cask "docker"
cask "appcleaner"
cask "firefox"
cask "the-unarchiver"
cask "font-jetbrains-mono"
cask "font-meslo-lg-nerd-font"
```

## Git Configuration

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
git config --global init.defaultBranch main
git config --global core.editor "code --wait"    # VS Code as git editor
git config --global pull.rebase true
git config --global fetch.prune true
git config --global diff.colorMoved zebra

# macOS-specific: ignore .DS_Store globally
echo '.DS_Store' >> ~/.gitignore_global
echo '.Trash-*' >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global

# Credential helper — use macOS Keychain
git config --global credential.helper osxkeychain
```

## Python Version Management

**Never use the system Python** (`/usr/bin/python3`). It's managed by macOS and you shouldn't install packages into it. Use one of these:

### Option A: pyenv (Recommended for Managing Multiple Python Versions)

```bash
brew install pyenv pyenv-virtualenv

# Add to ~/.zshrc:
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# Reload shell
source ~/.zshrc

# Install Python
pyenv install 3.12.8     # or latest stable
pyenv install 3.11.11    # if you need 3.11 for compatibility
pyenv global 3.12.8      # Set default

# Verify
python --version    # Should show 3.12.x
which python        # Should show ~/.pyenv/shims/python
```

### Option B: Miniconda/Miniforge (Better for ML/Scientific Computing)

Miniforge is preferred on Apple Silicon because it provides `conda-forge` packages compiled for ARM:

```bash
brew install miniforge

# Initialize conda for zsh
conda init zsh

# Reload shell
source ~/.zshrc

# Create environments
conda create -n ml python=3.12
conda activate ml
```

### Option C: uv (Fastest, Modern)

`uv` is an extremely fast Python package installer and resolver written in Rust:

```bash
brew install uv

# Create a virtual environment
uv venv .venv
source .venv/bin/activate

# Install packages (10-100x faster than pip)
uv pip install torch numpy pandas

# uv can also manage Python versions
uv python install 3.12
```

## Node.js

```bash
# Install via fnm (Fast Node Manager) — recommended
brew install fnm
echo 'eval "$(fnm env --use-on-cd)"' >> ~/.zshrc
source ~/.zshrc

fnm install --lts
fnm use lts-latest
node --version
npm --version
```

## Docker

Docker Desktop for Mac runs a lightweight Linux VM (since macOS isn't Linux, containers need a Linux kernel):

```bash
brew install --cask docker
```

After installing, launch Docker Desktop from Applications. It runs in the menu bar.

**Important Apple Silicon notes for Docker:**
- Most images now have ARM64 variants
- If you need x86 images: `docker run --platform linux/amd64 ...` (uses Rosetta 2 — slower)
- Docker's VM uses limited memory by default. Go to Docker Desktop → Settings → Resources → increase memory for ML workloads.

---

# Part 8: Python, PyTorch & Deep Learning

## PyTorch with Metal (MPS) Backend

Apple Silicon GPUs are accessed via the **MPS (Metal Performance Shaders)** backend in PyTorch. This gives you GPU acceleration for training and inference without CUDA:

```bash
# Create a dedicated ML environment
conda create -n ml python=3.12 -y
conda activate ml

# Install PyTorch (check https://pytorch.org for latest)
pip install torch torchvision torchaudio

# Or via conda
conda install pytorch torchvision torchaudio -c pytorch
```

### Verify MPS Backend

```python
import torch

# Check MPS availability
print(f"MPS available: {torch.backends.mps.is_available()}")
print(f"MPS built: {torch.backends.mps.is_built()}")

# Create tensor on MPS
device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
x = torch.randn(5, 3, device=device)
print(f"Tensor device: {x.device}")

# Quick benchmark
import time
size = 4096
a = torch.randn(size, size, device=device)
b = torch.randn(size, size, device=device)

start = time.time()
for _ in range(10):
    c = torch.mm(a, b)
    torch.mps.synchronize()  # Wait for MPS operations to complete
elapsed = time.time() - start
print(f"Matrix multiply ({size}x{size}), 10 iterations: {elapsed:.3f}s")
```

### MPS Caveats and Tips

```python
# 1. Not all operations are supported on MPS yet.
# If you hit an error, fall back to CPU for that operation:
try:
    result = model(input.to("mps"))
except RuntimeError:
    result = model(input.to("cpu"))

# 2. Memory management
torch.mps.empty_cache()          # Free unused cached memory
torch.mps.set_per_process_memory_fraction(0.7)  # Limit MPS memory usage

# 3. Synchronization — MPS operations are asynchronous
torch.mps.synchronize()          # Wait for all queued operations

# 4. For debugging, you can force synchronous execution:
import os
os.environ["PYTORCH_MPS_FORCE_SYNC"] = "1"

# 5. Some operations may give different numerical results than CUDA
# due to different floating-point implementations. This is normal.
```

### Common ML Stack Installation

```bash
# Core ML libraries
pip install numpy scipy pandas scikit-learn matplotlib seaborn

# Deep learning
pip install torch torchvision torchaudio
pip install transformers datasets tokenizers  # Hugging Face
pip install accelerate                         # Hugging Face multi-GPU/MPS
pip install wandb                              # Experiment tracking
pip install tensorboard                        # Visualization

# Jupyter
pip install jupyterlab ipywidgets

# Reinforcement learning
pip install gymnasium stable-baselines3

# Additional useful packages
pip install einops tqdm rich
```

### Hugging Face + MPS Example

```python
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

model_name = "microsoft/phi-2"  # Small enough for local development
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    torch_dtype=torch.float16,
    device_map="mps"  # Automatically use MPS
)

inputs = tokenizer("The key to training good LLMs is", return_tensors="pt").to("mps")
outputs = model.generate(**inputs, max_new_tokens=100)
print(tokenizer.decode(outputs[0]))
```

### JAX on Apple Silicon (Alternative to PyTorch)

```bash
pip install jax jaxlib           # CPU only (MPS support is experimental)
# jax-metal for GPU acceleration:
pip install jax-metal
```

---

# Part 9: Running Local LLMs on M5 Pro

Your M5 Pro is exceptional for local LLM inference because of its high unified memory bandwidth. Here are the best tools:

## llama.cpp (The Gold Standard for Local LLMs)

llama.cpp has first-class Apple Silicon support with Metal GPU acceleration:

```bash
# Clone and build
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp
make -j$(sysctl -n hw.ncpu) GGML_METAL=1

# Or install via Homebrew (easier)
brew install llama.cpp
```

### Download and Run Models

Models come in **GGUF format** with various quantization levels:
- **Q4_K_M**: Good balance of quality and speed (recommended starting point)
- **Q5_K_M**: Better quality, slightly slower
- **Q8_0**: Near-original quality
- **F16**: Full half-precision (needs more RAM)

```bash
# Download a model (e.g., from Hugging Face)
# Example: Llama 3.1 8B
# Visit huggingface.co, find GGUF versions

# Run inference
llama-cli -m ~/models/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf \
  -p "Explain reinforcement learning in simple terms:" \
  -n 512 \
  --gpu-layers 99 \
  --threads $(sysctl -n hw.performancecores)

# Start a server (OpenAI-compatible API)
llama-server -m ~/models/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf \
  --gpu-layers 99 \
  --host 0.0.0.0 \
  --port 8080 \
  --threads $(sysctl -n hw.performancecores)
```

**Key flags:**
- `--gpu-layers 99` (or `-ngl 99`): Offload all layers to Metal GPU. Use a lower number if the model doesn't fit in memory.
- `--threads`: Set to your performance core count. For M5 Pro, check with `sysctl -n hw.performancecores`.

### Memory Requirements

With your M5 Pro's unified memory, you can estimate what fits:

| Model Size | Q4_K_M | Q5_K_M | Q8_0 | F16 |
|-----------|--------|--------|------|-----|
| 7B params | ~4.4 GB | ~5.1 GB | ~7.2 GB | ~14 GB |
| 13B params | ~7.9 GB | ~9.2 GB | ~13.5 GB | ~26 GB |
| 34B params | ~20 GB | ~23 GB | ~34 GB | ~68 GB |
| 70B params | ~40 GB | ~47 GB | ~70 GB | ~140 GB |

With a 36 GB M5 Pro, you can comfortably run 7B models at any quantization, 13B at Q8 or below, and even 34B at Q4. With a 48 GB model, 70B Q4 becomes feasible.

## Ollama (Easiest Way to Run Local LLMs)

```bash
brew install ollama

# Start the Ollama server
ollama serve   # Runs in background

# Pull and run models
ollama pull llama3.1:8b
ollama run llama3.1:8b

# List available models
ollama list

# Use via API (OpenAI-compatible)
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.1:8b",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

Ollama uses llama.cpp under the hood but provides a simpler experience with automatic model management.

## MLX (Apple's Native ML Framework)

MLX is Apple's own ML framework designed specifically for Apple Silicon. It's like NumPy/PyTorch but optimized for unified memory:

```bash
pip install mlx mlx-lm
```

```python
import mlx.core as mx
import mlx_lm

# Load and run a model
model, tokenizer = mlx_lm.load("mlx-community/Llama-3.1-8B-Instruct-4bit")
response = mlx_lm.generate(
    model, tokenizer,
    prompt="Explain RLHF in simple terms:",
    max_tokens=500
)
print(response)
```

MLX advantages:
- Zero-copy operations (data stays in unified memory)
- Lazy evaluation (like JAX)
- Often faster than PyTorch MPS for inference
- Growing model library at `mlx-community` on Hugging Face

## LM Studio (GUI for Local LLMs)

For a nice graphical interface:
```bash
brew install --cask lm-studio
```

LM Studio provides:
- Model browser and downloader
- Chat interface
- OpenAI-compatible local API server
- Benchmarking tools

## Open WebUI (ChatGPT-like Interface for Local Models)

```bash
# Requires Docker and Ollama
docker run -d -p 3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main
```

Then visit `http://localhost:3000` for a full ChatGPT-like interface backed by your local Ollama models.

---

# Part 10: iOS/Web Development Setup

## Xcode (Required for iOS Development)

```bash
# Install full Xcode from App Store (it's ~35 GB — start the download early)
# Open App Store → Search "Xcode" → Install

# After install, accept the license:
sudo xcodebuild -license accept

# Install additional components
xcodebuild -downloadAllPlatforms    # iOS, watchOS, visionOS simulators

# Verify
xcodebuild -version
swift --version
```

### Xcode Essentials for a Beginner

- **Simulator**: Run iOS apps without a physical device. Launch from Xcode → Open Developer Tool → Simulator, or `open -a Simulator`.
- **Instruments**: Profiling tool (like perf/valgrind). Xcode → Open Developer Tool → Instruments.
- **Swift Playgrounds**: Interactive Swift REPL-like environment.
- **Interface Builder / SwiftUI Preview**: Visual UI design tools.

### Swift and SwiftUI

Swift is Apple's modern programming language. SwiftUI is the declarative UI framework:

```swift
// Quick Swift test
// Save as hello.swift and run with: swift hello.swift
import Foundation

print("Hello from Swift on Apple Silicon!")
print("CPU: \(ProcessInfo.processInfo.processorCount) cores")
print("Memory: \(ProcessInfo.processInfo.physicalMemory / 1_073_741_824) GB")
```

For iOS app development, you'll primarily work with:
- **SwiftUI**: Modern declarative UI framework (recommended for new projects)
- **UIKit**: Older imperative UI framework (still widely used)
- **Core ML**: On-device ML inference
- **Metal**: GPU programming
- **Combine**: Reactive programming framework

## Web Development

```bash
# Node.js (already installed via fnm above)
fnm install --lts

# Common global tools
npm install -g typescript ts-node
npm install -g create-react-app create-next-app
npm install -g vercel netlify-cli

# Bun (fast JavaScript runtime — excellent on Apple Silicon)
brew install bun
```

---

# Part 11: VS Code, Coding Agents & Editor Setup

## VS Code Setup

```bash
brew install --cask visual-studio-code
```

### Add `code` to PATH

Open VS Code → `⌘+Shift+P` → Type "shell command" → Select "Shell Command: Install 'code' command in PATH"

Now you can:
```bash
code .                  # Open current directory
code file.py            # Open file
code --diff file1 file2 # Diff two files
```

### Essential Extensions

```bash
# Install extensions from terminal
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension ms-toolsai.jupyter
code --install-extension ms-vscode-remote.remote-ssh
code --install-extension ms-vscode.cpptools-extension-pack
code --install-extension dbaeumer.vscode-eslint
code --install-extension esbenp.prettier-vscode
code --install-extension eamodio.gitlens
code --install-extension vscodevim.vim              # If you use Vim keybindings
code --install-extension github.copilot
code --install-extension github.copilot-chat
code --install-extension ms-vscode.cmake-tools
code --install-extension redhat.vscode-yaml
code --install-extension tamasfe.even-better-toml
code --install-extension streetsidesoftware.code-spell-checker
code --install-extension usernamehw.errorlens
```

### VS Code Settings for macOS

Open settings JSON (`⌘+Shift+P` → "Preferences: Open User Settings (JSON)"):

```json
{
    "editor.fontFamily": "JetBrains Mono, Menlo, Monaco, monospace",
    "editor.fontSize": 14,
    "editor.fontLigatures": true,
    "editor.lineHeight": 1.6,
    "editor.minimap.enabled": false,
    "editor.renderWhitespace": "boundary",
    "editor.bracketPairColorization.enabled": true,
    "editor.guides.bracketPairs": true,
    "editor.smoothScrolling": true,
    "editor.cursorSmoothCaretAnimation": "on",
    "editor.formatOnSave": true,
    "editor.inlineSuggest.enabled": true,
    
    "terminal.integrated.fontFamily": "MesloLGS NF",
    "terminal.integrated.fontSize": 13,
    "terminal.integrated.defaultProfile.osx": "zsh",
    "terminal.integrated.env.osx": {
        "FZF_DEFAULT_COMMAND": "fd --type f --hidden --exclude .git"
    },
    
    "workbench.colorTheme": "One Dark Pro",
    "workbench.iconTheme": "material-icon-theme",
    
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "files.exclude": {
        "**/.DS_Store": true,
        "**/__pycache__": true,
        "**/*.pyc": true
    },
    
    "python.defaultInterpreterPath": "python3",
    "python.terminal.activateEnvironment": true,
    
    "[python]": {
        "editor.defaultFormatter": "ms-python.black-formatter",
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
            "source.organizeImports": "explicit"
        }
    }
}
```

### VS Code Keyboard Shortcuts for macOS

Key differences from Windows VS Code:
```
⌘ + P               Quick Open (file search)
⌘ + Shift + P       Command Palette
⌘ + B               Toggle sidebar
⌘ + J               Toggle terminal panel
⌘ + `               Toggle integrated terminal
⌘ + Shift + E       Explorer panel
⌘ + Shift + F       Search panel
⌘ + Shift + G       Source control panel
⌃ + `               New terminal
⌘ + \               Split editor
⌘ + 1/2/3           Focus editor group
⌃ + Tab             Switch between tabs
⌘ + Shift + [/]     Switch between tabs (left/right)
⌘ + K, ⌘ + S        Keyboard shortcuts editor
F5                   Start debugging
⌘ + Shift + B       Run build task
⌃ + Shift + `       Create new terminal
```

## Coding Agents Setup

### Claude Code (Anthropic's CLI Agent)

```bash
# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Launch
claude

# Or in a project directory
cd ~/projects/my-ml-project
claude
```

### GitHub Copilot

Install the VS Code extension:
```bash
code --install-extension github.copilot
code --install-extension github.copilot-chat
```

### Cursor IDE (AI-Native Editor)

```bash
brew install --cask cursor
```

### Aider (Terminal-Based AI Coding Agent)

```bash
pip install aider-chat

# Use with local models via Ollama
aider --model ollama/llama3.1:8b

# Or with Claude/GPT API
export ANTHROPIC_API_KEY=your_key
aider --model claude-sonnet-4-20250514
```

---

# Part 12: System Benchmarking & Performance Profiling

## Quick System Info

```bash
# Hardware overview
system_profiler SPHardwareDataType

# Example output and what to note:
#   Chip: Apple M5 Pro
#   Total Number of Cores: X (Y performance + Z efficiency)
#   Memory: XX GB
#   Model Identifier: Mac16,X

# Detailed CPU info
sysctl -n machdep.cpu.brand_string
sysctl -n hw.ncpu                    # Total cores
sysctl -n hw.performancecores        # Performance cores
sysctl -n hw.efficiencycores         # Efficiency cores
sysctl -n hw.memsize                 # Memory in bytes

# GPU info
system_profiler SPDisplaysDataType

# Quick overview (install neofetch for a pretty display)
neofetch
```

## Geekbench (Industry Standard Benchmark)

```bash
brew install --cask geekbench
# Run from Applications → Geekbench 6
# Gives you CPU single-core, multi-core, and GPU (Metal) scores
# Compare results at browser.geekbench.com
```

## Disk Benchmarks

```bash
# Using built-in tools
# Write speed test (creates a 5GB file)
dd if=/dev/zero of=~/testfile bs=1m count=5000
# Read speed test
dd if=~/testfile of=/dev/null bs=1m
# Clean up
rm ~/testfile

# Better: Use Blackmagic Disk Speed Test from App Store (free)
# Or AmorphousDiskMark
brew install --cask amorphousdiskmark
```

## Memory Bandwidth Benchmark

```bash
# Install and run
brew install sysbench
sysbench memory run

# Or use the stream benchmark
git clone https://github.com/jeffhammond/STREAM.git
cd STREAM
cc -O3 -o stream stream.c -DSTREAM_ARRAY_SIZE=100000000
./stream
```

## GPU / Metal Benchmarks

```bash
# GFXBench Metal
# Download from App Store

# Or use a PyTorch benchmark
python3 -c "
import torch
import time

device = torch.device('mps')
sizes = [1024, 2048, 4096, 8192]

for size in sizes:
    a = torch.randn(size, size, device=device)
    b = torch.randn(size, size, device=device)
    
    # Warmup
    for _ in range(3):
        torch.mm(a, b)
    torch.mps.synchronize()
    
    # Benchmark
    start = time.time()
    iterations = 20
    for _ in range(iterations):
        torch.mm(a, b)
    torch.mps.synchronize()
    elapsed = time.time() - start
    
    gflops = (2 * size**3 * iterations) / elapsed / 1e9
    print(f'{size}x{size}: {elapsed/iterations*1000:.1f}ms per matmul, {gflops:.1f} GFLOPS')
"
```

## Network Benchmarks

```bash
brew install iperf3 speedtest-cli

# Internet speed
speedtest-cli

# Local network throughput (need iperf3 server on another machine)
iperf3 -c <server-ip>
```

## LLM Inference Benchmark

```bash
# Using llama.cpp's built-in benchmark
llama-bench -m ~/models/your-model.gguf -ngl 99

# This outputs tokens/second for prompt processing and generation
# Key metrics:
#   - Prompt eval: tokens/sec (how fast it processes input)
#   - Token generation: tokens/sec (how fast it generates output)
```

## Stress Testing

```bash
# CPU stress test
# Option 1: yes command (quick and dirty)
# Run one per core. M5 Pro with 12 cores:
for i in $(seq 1 12); do yes > /dev/null & done
# Stop with: killall yes

# Option 2: Use stress
brew install stress
stress --cpu 12 --timeout 300   # 5-minute CPU stress test

# Monitor thermals during stress test
sudo powermetrics --samplers smc -i 1000 | grep -i "die temperature"

# Memory stress test
stress --vm 4 --vm-bytes 8G --timeout 120
```

## Thermal & Power Monitoring

```bash
# powermetrics (the Swiss Army knife of Mac system monitoring)
# Requires sudo
sudo powermetrics --samplers all -i 5000

# Specific samplers:
sudo powermetrics --samplers cpu_power -i 2000     # CPU power/frequency
sudo powermetrics --samplers gpu_power -i 2000     # GPU power/frequency  
sudo powermetrics --samplers thermal -i 2000       # Thermal info
sudo powermetrics --samplers smc -i 2000           # System Management Controller

# Quick thermal check
sudo powermetrics --samplers smc -i 1000 -n 1

# Battery health
system_profiler SPPowerDataType
# Or
ioreg -l -w0 | grep -i "designcapacity\|maxcapacity\|currentcapacity\|cyclecount"
```

---

# Part 13: Debugging, Monitoring & "Why Is My System Busy?"

## Activity Monitor (GUI — Quick & Visual)

Open: `⌘+Space` → "Activity Monitor"

Tabs:
- **CPU**: Sort by "% CPU" to find resource hogs
- **Memory**: Look at "Memory Pressure" graph (green = good, yellow = warning, red = swapping)
- **Energy**: Find apps draining battery
- **Disk**: Identify heavy I/O
- **Network**: Spot bandwidth consumers

**Key column to watch**: "Memory Pressure" is more important than raw memory usage. macOS aggressively caches in RAM, so "Memory Used" being high is normal. Memory Pressure tells you if the system is actually struggling.

## CLI Monitoring Tools

### htop / btop (Interactive Process Monitor)

```bash
btop   # Beautiful, modern (install: brew install btop)
htop   # Classic (install: brew install htop)
```

### top (Built-in, No Install Needed)

```bash
top -o cpu     # Sort by CPU usage
top -o rsize   # Sort by resident memory
top -l 1 -s 0  # One snapshot (good for scripts)
```

### Investigating "Why Is My Mac Slow?"

```bash
# Step 1: Check CPU usage
top -l 1 -s 0 -o cpu | head -20

# Step 2: Check memory pressure
memory_pressure
# If it says "The system has X% memory available" and level is "normal", RAM is fine

# Step 3: Check for swap usage
sysctl vm.swapusage
# If swap used > 0 and growing, you're running low on memory

# Step 4: Check disk I/O
iostat -d 2    # Disk I/O stats every 2 seconds

# Step 5: Check for runaway processes
ps aux | sort -nrk 3,3 | head   # Top CPU consumers
ps aux | sort -nrk 4,4 | head   # Top memory consumers

# Step 6: Check thermal throttling
sudo powermetrics --samplers cpu_power -i 2000 -n 3
# Look at "CPU Speed" — if it's below base frequency, you're throttling

# Step 7: Check kernel_task CPU usage
# kernel_task artificially consumes CPU to reduce heat generation.
# If kernel_task is using 200%+ CPU, your Mac is thermally throttling.
# Solution: ensure airflow, reduce workload, check for blocked vents.
```

### Common Culprits for Slow Performance

| Process | What It Is | Fix |
|---------|-----------|-----|
| `kernel_task` | Thermal management (intentional CPU throttling) | Improve cooling, reduce load |
| `mds` / `mds_stores` / `mdworker` | Spotlight indexing | Wait (it finishes), or exclude folders in Spotlight prefs |
| `WindowServer` | Display compositor | Reduce transparency, reduce displays |
| `backupd` | Time Machine backup | Wait, or temporarily disable |
| `cloudd` | iCloud sync | Wait, or check iCloud settings |
| `nsurlsessiond` | Network downloads (often App Store updates) | Check App Store, wait |
| `softwareupdated` | System updates downloading | Check Software Update |
| `trustd` | Certificate verification | Usually brief; wait |
| `photoanalysisd` | ML-based photo analysis | Wait (runs once, then quiets) |
| `siriknowledged` | Siri suggestions indexing | Wait |
| `coreaudiod` | Audio daemon | Restart with `sudo killall coreaudiod` |

### Killing Unresponsive Apps

```bash
# GUI way: ⌘ + Option + Escape → Force Quit menu

# CLI way
kill <PID>           # Graceful termination (SIGTERM)
kill -9 <PID>        # Force kill (SIGKILL)
killall "App Name"   # Kill by name
pkill -f "pattern"   # Kill by pattern match
```

## System Logs

```bash
# Recent system logs
log show --last 1h --level error

# Filter by process
log show --last 30m --predicate 'process == "kernel"'

# Stream live logs
log stream --level info

# Search for specific messages
log show --last 1h --predicate 'eventMessage contains "panic"'

# Crash reports are in:
# ~/Library/Logs/DiagnosticReports/
ls ~/Library/Logs/DiagnosticReports/
```

## Network Debugging

```bash
# DNS lookup
nslookup example.com
dig example.com

# Check active connections
lsof -i -P -n | head -30
lsof -i :8080          # Check what's using port 8080
lsof -i tcp            # All TCP connections

# Trace route
traceroute example.com

# Packet capture
sudo tcpdump -i en0 -n -c 100

# Check network interfaces
ifconfig
networksetup -listallhardwareports
networksetup -getinfo Wi-Fi

# Flush DNS cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Wi-Fi diagnostics
# Hold Option and click the Wi-Fi icon in menu bar for detailed info
# Or:
/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -s
# (scans for nearby networks with signal strength)
```

---

# Part 14: Storage Management

## Understanding macOS Storage

```bash
# Disk usage overview
df -h /
diskutil list
diskutil info /

# APFS container details
diskutil apfs list
```

### Where Does Space Go?

```bash
# Interactive disk usage explorer (CLI)
brew install ncdu
sudo ncdu /    # Needs sudo to scan system directories

# Or use du for specific directories
du -sh ~/Library/Caches/*   | sort -hr | head -20
du -sh ~/Library/*          | sort -hr | head -20
du -sh /Library/Caches/*    | sort -hr | head -20
```

### Common Space Consumers

| Location | What | Typical Size | Safe to Clean? |
|----------|------|-------------|---------------|
| `~/Library/Caches/` | App caches | 5-50 GB | Yes, apps rebuild them |
| `~/Library/Developer/Xcode/` | Xcode data | 10-100+ GB | Partially (see below) |
| `~/Library/Developer/CoreSimulator/` | iOS Simulators | 5-30 GB | Delete unused simulators |
| `/Library/Developer/CommandLineTools/` | CLI tools | 2-5 GB | Don't delete |
| `~/Library/Containers/` | Sandboxed app data | Varies | Careful — this is app data |
| `~/Library/Application Support/` | App data | Varies | App-specific |
| `~/.Trash/` | Trash | Varies | `⌘+Shift+Delete` to empty |
| `/System/Volumes/Data/.Spotlight-V100/` | Spotlight index | 1-5 GB | Can rebuild |
| `~/.docker/` | Docker images/containers | 5-100 GB | `docker system prune -a` |
| `~/Library/Group Containers/` | Shared app data | Varies | Careful |
| `/private/var/folders/` | Temp files | Varies | Cleans on reboot |

### Cleaning Commands

```bash
# 1. Homebrew cleanup
brew cleanup --prune=all
brew autoremove

# 2. Remove old Xcode data
# Derived data (safe to delete — gets rebuilt on next build)
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Archives (old app builds)
rm -rf ~/Library/Developer/Xcode/Archives/*

# Device support (old iOS version support files)
ls ~/Library/Developer/Xcode/iOS\ DeviceSupport/
# Delete old versions you don't need

# 3. Docker cleanup
docker system prune -a --volumes

# 4. Conda/pip cleanup
conda clean --all
pip cache purge

# 5. npm cleanup
npm cache clean --force

# 6. System caches (safe, they rebuild)
sudo rm -rf /Library/Caches/*
rm -rf ~/Library/Caches/*

# 7. Log files
sudo rm -rf /private/var/log/asl/*.asl
rm -rf ~/Library/Logs/*

# 8. Find large files
find ~ -type f -size +500M 2>/dev/null | head -20

# 9. Local Time Machine snapshots (usually auto-managed)
tmutil listlocalsnapshots /
# To delete one:
# sudo tmutil deletelocalsnapshots <date>

# 10. Purge purgeable space (macOS manages this, but you can force it)
# Just filling the disk will trigger macOS to free purgeable space
```

### macOS Storage Management (GUI)

```
Apple menu → About This Mac → Storage → Manage...
```

This shows:
- **Recommendations**: Enable "Store in iCloud", "Optimize Storage", "Empty Trash Automatically"
- **Applications**: Size of each app
- **Documents**: Large files and downloads
- **Mail**: Email attachment storage

### Monitoring Storage Over Time

```bash
# Quick check
df -h /

# Watch for changes
watch -n 60 'df -h / | tail -1'

# Set up an alias
alias diskspace='df -h / | awk "NR==2 {print \"Used: \" \$3 \" / \" \$2 \" (\" \$5 \" full)\"}"'
```

---

# Part 15: Display, Accessibility & Advanced Settings

## Display Configuration

### Resolution Scaling

macOS Retina displays use a concept called **HiDPI scaling**. The native panel resolution is very high, but macOS renders at a "scaled" resolution and then maps to physical pixels:

```
System Settings → Displays → Resolution
```

The options from left to right:
1. **Larger Text**: 1x scaling — big UI, less content visible
2. **Default**: Apple's recommended balance
3. **More Space**: Higher logical resolution — more content, smaller elements

For development, **"More Space"** is usually ideal. You get more screen real estate for code.

### External Monitor Setup

```bash
# List connected displays
system_profiler SPDisplaysDataType

# For HiDPI on external monitors, you may need:
# BetterDisplay app (handles scaling for non-Apple monitors)
brew install --cask betterdisplay
```

**Common issue**: Non-Apple external monitors often don't enable HiDPI by default, making text look blurry. BetterDisplay fixes this by creating custom scaled resolutions.

### Night Shift & True Tone

```
System Settings → Displays
  → Night Shift: Schedule "Sunset to Sunrise" (reduces blue light)
  → True Tone: ON (adapts to ambient lighting — disable for color-critical work)
```

### Font Rendering

macOS renders fonts differently than Windows. macOS favors font design fidelity (heavier/smoother), while Windows favors pixel-grid alignment (sharper but less true to design). You can adjust:

```bash
# Reduce font smoothing (if fonts look too heavy/blurry to you)
defaults write -g AppleFontSmoothing -int 0   # 0=off, 1=light, 2=medium, 3=heavy
# Log out and back in to apply

# Reset to default
defaults delete -g AppleFontSmoothing
```

## Accessibility Features for Developers

```
System Settings → Accessibility
```

Useful developer features:
- **Zoom**: Hold `⌃` and scroll to zoom into any part of the screen. Great for presentations and reading small print.
  - Enable: Accessibility → Zoom → "Use scroll gesture with modifier keys to zoom"
- **Reduce Motion**: Faster animations, less visual distraction
  - Accessibility → Display → "Reduce motion"
- **Increase Contrast**: Sharper UI element borders
- **Reduce Transparency**: Solid backgrounds instead of translucent ones (slightly faster rendering)

## Dark Mode

```bash
# Toggle via CLI
osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to true'

# Or toggle:
osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode of appearance preferences'
```

---

# Part 16: Power User Features & Hidden Settings

## The `defaults` Command (Your Registry Editor)

On macOS, `defaults` is how you access hidden settings. It reads and writes **property lists (plists)**, which are macOS's equivalent of the Windows Registry (but per-app, not centralized).

```bash
# Read all settings for an app
defaults read com.apple.finder

# Read a specific key
defaults read com.apple.finder AppleShowAllFiles

# Write a setting
defaults write com.apple.finder AppleShowAllFiles -bool true

# Delete a setting (revert to default)
defaults delete com.apple.finder AppleShowAllFiles

# List all domains (all apps with preferences)
defaults domains | tr ',' '\n' | sort

# Read global settings
defaults read NSGlobalDomain
```

### Treasure Trove of Hidden Settings

```bash
# --- Finder ---
# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Show full path in title
defaults write com.apple.finder _FNSPathControlTitlePath -bool true

# Disable window animations
defaults write com.apple.finder DisableAllAnimations -bool true

# --- Dock ---
# Add spacer tiles to Dock
defaults write com.apple.dock persistent-apps -array-add '{"tile-type"="spacer-tile";}'
killall Dock

# Highlight hidden apps in Dock (translucent icons)
defaults write com.apple.dock showhidden -bool true

# --- Screenshots ---
# Change default format (png, jpg, pdf, tiff)
defaults write com.apple.screencapture type -string "png"

# --- Mission Control ---
# Speed up animations
defaults write com.apple.dock expose-animation-duration -float 0.1
killall Dock

# Don't automatically rearrange Spaces
defaults write com.apple.dock mru-spaces -bool false

# --- Safari (if you use it) ---
# Show the full URL
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# Enable Developer menu
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true

# --- General ---
# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Disable Resume system-wide (apps don't reopen previous windows)
defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

# Disable smart quotes and dashes (CRITICAL for developers)
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable autocorrect
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Enable key repeat (instead of press-and-hold for accented characters)
# This is essential for Vim users!
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Faster key repeat
defaults write NSGlobalDomain KeyRepeat -int 2           # Lower = faster
defaults write NSGlobalDomain InitialKeyRepeat -int 15    # Lower = shorter delay

# --- TextEdit ---
# Default to plain text
defaults write com.apple.TextEdit RichText -int 0

# --- Mail ---
# Copy addresses as "name@example.com" instead of "Name <name@example.com>"
defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false

# --- Time Machine ---
# Prevent Time Machine from prompting to use new hard drives
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
```

**After changing defaults, you usually need to restart the affected app:**
```bash
killall Finder
killall Dock
killall SystemUIServer
# Or log out and back in for global changes
```

## Recovery Mode & Boot Options

On Apple Silicon, there's no BIOS/UEFI menu. Instead:

**Shut down** → **Press and hold the power button** until you see "Loading startup options..."

Options:
- **Macintosh HD**: Normal boot
- **Options** (gear icon): Recovery Mode
  - Reinstall macOS
  - Disk Utility (repair/erase drives)
  - Safari (for internet recovery)
  - Terminal (for advanced repairs)
  - Startup Security Utility

**Safe Mode**: Shut down → Press power button → Immediately press and hold **Shift** until login screen appears. Safe Mode disables non-essential extensions and clears caches.

**Single User Mode**: Doesn't exist on Apple Silicon (use Recovery Mode terminal instead).

## SIP (System Integrity Protection)

SIP prevents modification of system files, even by root. It protects:
- `/System/`
- `/usr/` (except `/usr/local/`)
- `/bin/`, `/sbin/`
- Preinstalled Apple apps

```bash
# Check SIP status
csrutil status

# To disable SIP (NOT recommended unless absolutely necessary):
# 1. Boot to Recovery Mode
# 2. Open Terminal from Utilities menu
# 3. csrutil disable
# 4. Reboot

# To re-enable:
# Same steps but: csrutil enable
```

**When would you disable SIP?** Almost never. Possible reasons: kernel extension development, certain security research, or tools that need to inject into system processes. Homebrew, Docker, and all normal development work fine with SIP enabled.

## TCC (Privacy Permissions) Management

The TCC database controls which apps can access camera, microphone, files, etc.

```bash
# List TCC database contents (requires Full Disk Access in terminal)
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT client, service FROM access WHERE allowed = 1"

# Reset all permissions for an app
tccutil reset All com.apple.Terminal

# Reset specific permission
tccutil reset ScreenCapture com.example.app
```

To grant Terminal/iTerm2 Full Disk Access:
```
System Settings → Privacy & Security → Full Disk Access → Add Terminal/iTerm2
```

This is needed for some `find`, `ls`, and other commands to access protected directories.

---

# Part 17: Security, Networking & Firewall

## Firewall Configuration

```bash
# Enable firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Check firewall status
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Enable stealth mode (don't respond to pings)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

# Allow/block specific apps
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /path/to/app
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --blockapp /path/to/app
```

## SSH Configuration

```bash
# Enable SSH server (Remote Login)
sudo systemsetup -setremotelogin on

# Check if SSH is enabled
sudo systemsetup -getremotelogin

# Disable
sudo systemsetup -setremotelogin off
```

## Networking Commands

```bash
# Get IP address
ipconfig getifaddr en0    # Wi-Fi
ipconfig getifaddr en1    # Ethernet (Thunderbolt adapter)

# Get all network info
ifconfig -a

# Get public IP
curl -s ifconfig.me

# DNS configuration
scutil --dns

# Network quality test (built into macOS)
networkQuality     # Tests download, upload, and responsiveness

# Wi-Fi diagnostics
# Option-click Wi-Fi icon for detailed info
# Or create a diagnostic report:
sudo /usr/libexec/WiFiAgent

# Manage network locations
networksetup -listlocations
networksetup -switchtolocation "Work"
```

## Secure Your Mac

```bash
# 1. FileVault (already enabled in setup)
fdesetup status

# 2. Require password immediately after sleep
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# 3. Disable AirDrop for strangers
defaults write com.apple.NetworkBrowser DisableAirDrop -bool true

# 4. Show Wi-Fi and Bluetooth status in menu bar
# (Done via System Settings → Control Center)

# 5. Disable Handoff if you don't use it
# System Settings → General → AirDrop & Handoff → Handoff → OFF

# 6. Review app permissions regularly
# System Settings → Privacy & Security → review each category
```

---

# Part 18: Productivity Workflows & Automation

## Spotlight (Your Command Center)

`⌘+Space` opens Spotlight. It can:
- Launch apps ("Terminal", "VS Code")
- Calculate math ("sqrt(144)", "50 USD in EUR")
- Search files ("kind:pdf date:this week")
- Look up definitions ("define: ephemeral")
- Convert units ("50 kg in lbs")
- Open System Settings ("Keyboard settings")

### Spotlight Search Syntax

```
# Filter by file type
kind:pdf budget
kind:image vacation
kind:folder projects

# Filter by date
date:today
date:yesterday
date:this week
created:2024-01-01

# Boolean
budget AND 2024
report NOT draft

# Metadata
author:john
tag:important
```

## Automator / Shortcuts

macOS has two automation tools:
- **Shortcuts** (modern, simpler): Build workflows visually. Access via the Shortcuts app.
- **Automator** (legacy, more powerful): Create complex workflows, services, and folder actions.

### Example: Create a Quick Action to Open Terminal Here

1. Open **Automator**
2. Choose "Quick Action"
3. Set "Workflow receives current" to "folders" in "Finder"
4. Add "Run Shell Script" action
5. Shell: `/bin/zsh`
6. Script: `cd "$1" && open -a iTerm .`
7. Save as "Open Terminal Here"

Now right-click any folder → Quick Actions → Open Terminal Here.

### Example: Useful Shell Aliases as Automation

```bash
# Create a "new project" command
mkproject() {
    mkdir -p "$1"/{src,tests,docs,data}
    cd "$1"
    git init
    python3 -m venv .venv
    echo ".venv/\n__pycache__/\n.DS_Store\n*.pyc" > .gitignore
    echo "# $1" > README.md
    echo "Created project: $1"
    code .
}

# Quick note-taking
note() {
    local file=~/Notes/$(date +%Y-%m-%d).md
    if [ $# -eq 0 ]; then
        code "$file"
    else
        echo "## $(date +%H:%M) - $*" >> "$file"
        echo "Note added."
    fi
}

# Quick timer
timer() {
    local seconds=$((${1:-25} * 60))
    echo "Timer set for ${1:-25} minutes"
    sleep $seconds
    osascript -e 'display notification "Time is up!" with title "Timer" sound name "Glass"'
    say "Time is up"
}
```

## AppleScript / osascript

AppleScript is macOS's built-in scripting language for controlling apps:

```bash
# Show a notification
osascript -e 'display notification "Build complete!" with title "Dev" sound name "Hero"'

# Get current Finder path
osascript -e 'tell app "Finder" to POSIX path of (insertion location as alias)'

# Toggle Dark Mode
osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode'

# Control system volume
osascript -e 'set volume output volume 50'

# Lock the screen
osascript -e 'tell app "System Events" to keystroke "q" using {command down, control down}'

# Open a URL in default browser
open "https://github.com"
```

## Raycast (Spotlight Replacement — Highly Recommended)

```bash
brew install --cask raycast
```

Raycast is a supercharged Spotlight replacement with:
- Everything Spotlight does, but faster
- Clipboard history
- Snippet expansion
- Window management
- Calculator with history
- GitHub, Jira, and other integrations
- Custom scripts and extensions
- AI integration

After installing, set it to launch with `⌘+Space` (it'll ask to replace Spotlight).

---

# Part 19: Common Pitfalls

## Pitfall 1: Case-Insensitive File System

```bash
# THIS WILL FAIL ON MAC (but works on Linux):
touch readme.md
touch README.md
# There's still only ONE file!

ls readme.md   # Works
ls README.md   # Same file!
```

**Impact**: Git repos from Linux may have files that differ only by case. macOS can't represent both. This causes subtle bugs.

**Fix**: Be disciplined about naming. Use `git config core.ignorecase false` to make Git case-aware (but this has its own quirks).

## Pitfall 2: .DS_Store Files Everywhere

macOS creates `.DS_Store` files in every directory Finder visits. They contain folder view settings.

```bash
# Add to global .gitignore
echo '.DS_Store' >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global

# Clean existing ones
find ~/projects -name '.DS_Store' -delete

# Prevent creation on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
```

## Pitfall 3: Smart Quotes and Auto-Correct in Code

macOS system-wide replaces `"straight quotes"` with `"curly quotes"` and `--` with `—`. This silently breaks code.

```bash
# Disable everywhere
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
```

## Pitfall 4: Path Differences

```bash
# Linux                → Mac
/home/user             → /Users/user
/tmp                   → /private/tmp (symlinked to /tmp)
/etc                   → /private/etc (symlinked to /etc)
/var                   → /private/var (symlinked to /var)
/usr/local/bin         → /opt/homebrew/bin (Homebrew on ARM)
```

## Pitfall 5: File Permissions and Extended Attributes

macOS adds extended attributes to downloaded files (quarantine flags):

```bash
# See extended attributes
xattr -l downloaded_file.zip

# Remove quarantine flag
xattr -d com.apple.quarantine downloaded_file.zip

# Remove ALL extended attributes
xattr -c file
```

This is why you sometimes see "this app is from an unidentified developer" — it's the quarantine flag.

## Pitfall 6: Sleep vs Shut Down

macOS is designed to sleep, not shut down. Apple Silicon Macs:
- Use almost no power in sleep
- Wake instantly
- Maintain network connections for updates and Find My

**Don't shut down** unless you're troubleshooting or doing a major OS update. Just close the lid.

## Pitfall 7: Closing Windows Doesn't Quit Apps

As mentioned earlier, `⌘+W` closes the window but the app keeps running. Use `⌘+Q` to actually quit, or get comfortable with apps running in the background (macOS handles this well with memory compression and app nap).

## Pitfall 8: `sudo` on macOS

`sudo` works, but:
- Some directories are protected even from root (SIP).
- First-time `sudo` in a terminal session asks for your user password (same as login password).
- Touch ID can authorize `sudo` — see below:

```bash
# Enable Touch ID for sudo
# On Apple Silicon with recent macOS:
sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
sudo nano /etc/pam.d/sudo_local
# Uncomment the line:
# auth       sufficient     pam_tid.so
# Save and exit. Now sudo prompts Touch ID!
```

## Pitfall 9: Python Path Confusion

macOS ships with a system Python at `/usr/bin/python3`. After installing via Homebrew, pyenv, or conda, you may have multiple Pythons:

```bash
# Check which Python you're using
which python3
python3 --version

# Common Python locations on macOS:
/usr/bin/python3                    # System Python (DON'T USE FOR DEV)
/opt/homebrew/bin/python3           # Homebrew Python
~/.pyenv/shims/python3              # pyenv-managed
~/miniforge3/bin/python3            # Conda base
~/miniforge3/envs/ml/bin/python3    # Conda environment
```

**Rule**: Always use virtual environments. Never `pip install` into the system or base Python.

## Pitfall 10: Docker Memory Limits

Docker Desktop for Mac runs containers in a Linux VM. The VM has limited resources by default:

```
Docker Desktop → Settings → Resources:
  → CPUs: Set to at least half your cores
  → Memory: 8-16 GB for ML workloads
  → Swap: 2-4 GB
  → Disk image size: Increase if you use many images
```

## Pitfall 11: Rosetta 2 and Architecture Confusion

Some older tools may install x86 versions. Check architecture:

```bash
# Check if a binary is ARM or x86
file $(which python3)
# arm64 = native, x86_64 = running through Rosetta

# Force running a command under Rosetta
arch -x86_64 /bin/bash
# Now everything in this shell is x86

# Check current architecture
arch
# Should say "arm64" normally
```

## Pitfall 12: Max Open Files Limit

macOS has a low default for maximum open files, which can cause issues with `npm install`, webpack, or other tools that open many files:

```bash
# Check current limit
ulimit -n    # Default is usually 256!

# Increase for current session
ulimit -n 65536

# Make permanent — add to ~/.zshrc:
ulimit -n 65536

# For system-wide changes (survives reboot):
sudo launchctl limit maxfiles 65536 200000
```

---

# Part 20: Quick Reference Cheat Sheet

## Keyboard Shortcut Quick Reference

```
SYSTEM
⌘ + Space           Spotlight / Raycast
⌘ + Tab             Switch apps
⌘ + ` (backtick)    Switch windows of same app
⌘ + Q               Quit app
⌘ + W               Close window
⌘ + H               Hide app
⌘ + M               Minimize
⌘ + ,               App preferences
⌘ + Option + Esc    Force Quit dialog
⌃ + ⌘ + Q           Lock screen
⌃ + ⌘ + F           Toggle fullscreen

TEXT EDITING
⌘ + ←/→             Start/end of line
⌥ + ←/→             Jump by word
⌘ + ↑/↓             Start/end of document
⌥ + Delete           Delete word backward
Fn + Delete          Forward delete
⌘ + Delete           Delete to line start

FINDER
⌘ + Shift + G       Go to Folder
⌘ + Shift + .       Toggle hidden files
⌘ + I               Get Info
Space                Quick Look
Enter                Rename (NOT open!)
⌘ + ↓               Open item
⌘ + ↑               Parent folder
⌘ + Delete           Move to Trash

SCREENSHOTS  
⌘ + Shift + 3       Full screen
⌘ + Shift + 4       Selection
⌘ + Shift + 4 + Space  Window capture
⌘ + Shift + 5       Screenshot toolbar

TERMINAL
⌃ + C               Interrupt
⌃ + D               EOF
⌃ + Z               Suspend
⌃ + L               Clear
⌃ + R               Reverse search
⌃ + A               Beginning of line
⌃ + E               End of line
⌃ + K               Kill to end of line
⌃ + W               Delete word backward
```

## Command Translation: Ubuntu → macOS

```bash
# Package management
apt install X          → brew install X
apt remove X           → brew uninstall X
apt update             → brew update
apt upgrade            → brew upgrade
apt search X           → brew search X
dpkg -l                → brew list

# System info
cat /proc/cpuinfo      → sysctl -a | grep machdep.cpu
cat /proc/meminfo      → vm_stat; sysctl hw.memsize
free -h                → memory_pressure; vm_stat
uname -a               → sw_vers; uname -a
lsb_release -a         → sw_vers

# Services
systemctl start X      → launchctl load X.plist  
systemctl stop X       → launchctl unload X.plist
systemctl status X     → launchctl list | grep X
journalctl -u X        → log show --predicate 'process == "X"'

# Network
ip addr                → ifconfig
ss -tulpn              → lsof -i -P -n
ip route               → netstat -rn

# Disk
lsblk                  → diskutil list
mount                  → mount (same)
df -h                  → df -h (same)
fdisk -l               → diskutil list

# Files
xdg-open file          → open file
xclip                  → pbcopy / pbpaste
nautilus .             → open .
locate file            → mdfind file
updatedb               → mdutil -E /  (rebuild Spotlight index)

# Process
kill -9 PID            → kill -9 PID (same)
pkill name             → pkill name (same)
pgrep name             → pgrep name (same)
nice/renice            → nice/renice (same)
```

## File Locations Quick Reference

```
Your home:           ~/  or  /Users/yourusername/
Applications:        /Applications/
System preferences:  /Library/Preferences/
User preferences:    ~/Library/Preferences/
App support data:    ~/Library/Application Support/
Caches:              ~/Library/Caches/
Logs:                ~/Library/Logs/
LaunchAgents:        ~/Library/LaunchAgents/
Homebrew:            /opt/homebrew/  (Apple Silicon)
Homebrew bins:       /opt/homebrew/bin/
Xcode tools:        /Library/Developer/CommandLineTools/
System Python:       /usr/bin/python3 (DON'T USE)
Hosts file:          /etc/hosts (actually /private/etc/hosts)
SSH config:          ~/.ssh/config
Zsh config:          ~/.zshrc, ~/.zprofile
Git config:          ~/.gitconfig
```

## Day-One Setup Script (All-in-One)

Save this and run it on your fresh Mac (review each section first):

```bash
#!/bin/zsh
# mac-setup.sh — Run on a fresh macOS install
# Review and customize before running!

set -e

echo "=== Installing Xcode Command Line Tools ==="
xcode-select --install 2>/dev/null || true
echo "If prompted, click Install and wait, then re-run this script."
echo "Press Enter when ready to continue..."
read

echo "=== Installing Homebrew ==="
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

echo "=== Installing CLI tools ==="
brew install coreutils findutils gnu-sed gnu-tar grep gawk
brew install git git-lfs wget curl htop btop tree jq
brew install ripgrep fd bat eza fzf tmux watch neovim
brew install cmake ninja pkg-config
brew install pyenv pyenv-virtualenv
brew install fnm
brew install trash-cli rename tldr

echo "=== Installing GUI apps ==="
brew install --cask iterm2
brew install --cask visual-studio-code
brew install --cask rectangle
brew install --cask alt-tab
brew install --cask stats
brew install --cask appcleaner
brew install --cask the-unarchiver
brew install --cask docker
brew install --cask raycast
brew install --cask font-jetbrains-mono
brew install --cask font-meslo-lg-nerd-font

echo "=== Configuring Finder ==="
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
defaults write com.apple.finder _FXSortFoldersFirst -bool true

echo "=== Configuring Dock ==="
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.3
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock minimize-to-application -bool true
defaults write com.apple.dock mru-spaces -bool false

echo "=== Configuring input ==="
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

echo "=== Configuring screenshots ==="
mkdir -p ~/Screenshots
defaults write com.apple.screencapture location -string "~/Screenshots"
defaults write com.apple.screencapture disable-shadow -bool true

echo "=== Configuring misc ==="
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"

echo "=== Configuring Git ==="
echo '.DS_Store' >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
git config --global credential.helper osxkeychain
git config --global init.defaultBranch main
git config --global pull.rebase true

echo "=== Setting up SSH ==="
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat > ~/.ssh/config << 'SSH_CONFIG'
Host *
    AddKeysToAgent yes
    UseKeychain yes
SSH_CONFIG

echo "=== Increasing file limits ==="
echo 'ulimit -n 65536' >> ~/.zshrc

echo "=== Enabling Touch ID for sudo ==="
if [ -f /etc/pam.d/sudo_local.template ]; then
    sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
    sudo sed -i '' 's/^#auth/auth/' /etc/pam.d/sudo_local
fi

echo "=== Enabling Firewall ==="
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

echo "=== Restarting affected services ==="
killall Finder 2>/dev/null || true
killall Dock 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

echo ""
echo "=== DONE! ==="
echo "Next steps:"
echo "1. Open iTerm2 and configure it (Profiles → Keys → Presets → Natural Text Editing)"
echo "2. Install Oh My Zsh: sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
echo "3. Install Powerlevel10k theme"
echo "4. Set up Python with pyenv or miniforge"
echo "5. Install VS Code extensions"
echo "6. Log out and back in for all settings to take effect"
```

---

## Final Notes

### The Philosophy Shift

Windows thinks in terms of: **registry, Control Panel, MSI installers, drive letters, backslashes**.
Linux thinks in terms of: **packages, config files, systemd, everything-is-a-file**.
macOS thinks in terms of: **bundles, plists, launchd, frameworks, sandboxing, and a curated experience**.

macOS sits at a unique intersection: it has a genuine Unix core that you can use like any other Unix system, but it also has a polished GUI layer with deep hardware integration. The key to mastering it is understanding both layers and knowing when to use which.

### Your Daily Workflow Will Be

1. **Raycast/Spotlight** to launch everything
2. **iTerm2** with tmux/tabs for terminal work
3. **VS Code** for editing (with integrated terminal)
4. **Rectangle** for window management
5. **Git** for version control (same as Linux)
6. **Homebrew** for installing everything
7. **pyenv/conda** for Python environments
8. **Ollama/llama.cpp/MLX** for local LLMs
9. **Docker** when you need Linux containers
10. **Activity Monitor/btop** when things feel slow

Welcome to macOS. It's different, but once you internalize the patterns, it's extremely productive.

---

*Generated on: March 2026*
*Target: macOS on Apple M5 Pro, for Windows/Ubuntu power users*
