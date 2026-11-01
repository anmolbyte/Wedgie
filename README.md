<p align="center">
  <img src="docs/icon.png" width="180" alt="Wedgie icon">
</p>

<h1 align="center">Wedgie</h1>

<p align="center">
  <em>Keep your Mac awake with the lid closed — for long AI-agent sessions, builds, and downloads. Without burning your battery.</em>
</p>

<p align="center">
  <a href="https://github.com/anmolbyte/Wedgie/actions/workflows/build.yml"><img src="https://github.com/anmolbyte/Wedgie/actions/workflows/build.yml/badge.svg" alt="Build status"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
</p>

---

## Why

If you code with AI agents (Claude Code, Cursor, Aider) or run long builds, closing the lid kills your session. The usual `pmset disablesleep` workaround keeps the Mac awake — but it also keeps the **internal display awake under the closed lid**, silently burning battery for hours.

Wedgie does two things:

1. **Holds your Mac open** — toggles `pmset -a disablesleep 1` so the system stays awake when the lid is closed.
2. **Turns off the internal display when the lid closes** — saves battery, remembers your display brightness before the lid closed, and automatically restores it when you open the lid again.

## Install

Download the latest `Wedgie.zip` from the [Releases page](https://github.com/anmolbyte/Wedgie/releases), unzip, and drag `Wedgie.app` to `/Applications/`.

**First launch:** right-click the app → **Open** — Wedgie is open-source and not signed with a paid Developer ID, so Gatekeeper will warn you on first run. After that it's silent.

If you'd rather skip the click-through, strip the quarantine attribute manually:

```bash
xattr -dr com.apple.quarantine /Applications/Wedgie.app
```

## How it works

- **Left click** the menubar icon to toggle Wedgie on or off instantly.
- **Right click** the menubar icon to open the context menu showing the current status (**Enabled** or **Disabled**), toggle action, Settings, and Quit.

While Wedgie is enabled and you close the lid, Wedgie sets the internal display brightness to 0. When you open the lid back up, it remembers and restores your exact pre-close brightness.

## Features

- 🪶 **Lightweight** — single Swift binary, no background daemons, no helper tools
- 🔒 **Admin password lives in your Keychain**, never touched after Wedgie quits
- 🌒 **Launch at login** via `SMAppService`
- ⚡ **Start session on startup** — automatically activate awake mode whenever Wedgie launches
- 💡 **Brightness memory** — remembers your working brightness before the lid closes and reliably restores it on wake
- 🧯 **Crash-safe** — if the app dies mid-cycle, brightness is restored on next launch
- 🎯 **No private daemons, no kexts.** Just `pmset` (driven by your Keychain-stored admin password) and a thin call into `DisplayServices` for brightness control

## Settings

| Setting | Default | Notes |
| --- | --- | --- |
| Launch Wedgie at login | off | Uses `SMAppService.mainApp` (approve once in System Settings → Login Items) |
| Start session on startup | off | Automatically activates Wedgie when the app opens |
| Turn off internal display when lid closes | **on** | Saves battery while keeping the Mac awake; restores brightness on open |
| Saved password | stored in Keychain | "Forget" wipes it; Wedgie will re-prompt next time you toggle |

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon recommended (Intel may work but is untested)

## Build from source

```bash
git clone https://github.com/anmolbyte/Wedgie.git
cd Wedgie
./build.sh release
open build/Wedgie.app
```

To regenerate the app icon:

```bash
swift run WedgieIcon
```

## Privacy

- Wedgie **never makes a network connection**.
- Your admin password lives in your Keychain, accessible only to Wedgie.
- Wedgie does not collect, transmit, log, or phone home with anything.

## Limitations

- Wedgie depends on a private `DisplayServices` symbol to control brightness. This means **App Store distribution is not possible** — that's a hard trade-off for the lid-close brightness feature.
- On Macs with no internal display (Mac mini, Studio, Pro), the brightness step is a no-op — the rest still works.
- macOS will sleep the Mac at very low battery regardless of `pmset` (hardware-enforced). There is no workaround.

## License

MIT. See [LICENSE](LICENSE).
