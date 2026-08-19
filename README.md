# Spice

Personal dotfiles and system setup for [Omarchy](https://github.com/basecamp/omarchy) on Arch Linux (Hyprland).

## What's Inside

**Themes** -- 4 color themes (canvas, emerald, harbor, whitegold) with matching configs for 20+ applications: terminals, editors, bars, launchers, lock screens, and more.

**Plugins** -- 16 Omarchy shell plugins: theme scheduler, auto wallpaper, bar auto-hide, YouTube Music widget, ProtonVPN status, Bluetooth audio selector, notification system, Quran reader, workspace overview, audio visualizer, activity monitor, and cursor manager.

**Scripts** -- Utility scripts in `bin/`:
| Script | Description |
|---|---|
| `media-download` | yt-dlp wrapper with gum TUI (video + music, playlist support, MPD sync) |
| `dots-push` | Interactive git push helper |
| `write-iso` | Write ISO images to USB |
| `comic-translate` | Translate comics (Latin/CJK) |
| `mp4-to-gif` | Video to GIF converter |
| `spotify-music-download` | Spotify track downloader |

> **Low battery** — Omarchy already warns once at 10%. `config/omarchy/hooks/battery-low.d/persistent-nag` (a `battery-low.d` hook) keeps nagging: sound on every drop, screen dim + critical notification below 5%, auto-stops when you plug in.

**Install system** -- TUI-driven setup (`setup.sh`) with gum multi-select, logging, and tagged package installation.

## Quick Start

You can install Spice with a single command. 

**Option 1: Using the shortened URL (recommended for convenience):**

```bash
curl -fsSL https://abr60.github.io/spice/install.sh | bash
```

**Option 2: Using the direct raw GitHub URL (recommended for immediate reliability):**

```bash
curl -fsSL https://raw.githubusercontent.com/abr60/spice/main/install.sh | bash
```

Alternatively, you can clone and run it manually:

```bash
git clone https://github.com/abr60/spice.git ~/spice
cd ~/spice && ./install.sh
```

Select what to install from the menu. Everything is logged to `~/.local/state/spice/logs/`.

## Updating

```bash
bash ~/spice/update.sh
```

Fetches remote changes, resets local state, re-runs install scripts, re-stows configs, and reloads the UI. Generates a report at `~/.local/state/spice/update-report.txt`.

## Structure

```
spice/
├── setup.sh              # Interactive installer (gum TUI)
├── update.sh             # Remote-first update script
├── applications/         # Desktop entries + webapp icons
├── bin/                  # Custom utility scripts
├── config/               # App configs (stowed to ~/.config)
│   ├── hypr/             # Hyprland (lua modules, assets, sounds)
│   ├── omarchy/          # Pasted into ~/.config/omarchy (branding, hooks, plugins, themed, shell.json) — never stowed whole
│   ├── mpv/              # MPV with Anime4K shaders
│   ├── rmpc/             # Rust MPD client
│   └── ...
└── install/
    ├── lib/              # helpers.sh + spice.txt (logo)
    ├── packaging/        # Package lists + installer
    ├── config/           # Stow + config scripts
    ├── services/         # Systemd service setup
    └── extras/           # GPU, Howdy, Thinkfan, Waydroid, wallpapers
```

## Requirements

- Arch Linux with Omarchy
- `gum` (used by setup TUI and scripts)
- `stow` (for config symlinking)

## License

Personal dotfiles -- use at your own risk.
