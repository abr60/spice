# Spice

Personal dotfiles and system setup for [Omarchy](https://github.com/basecamp/omarchy) on Arch Linux (Hyprland).

## What's Inside

**Themes** -- Community Omarchy themes installed via `setup.sh` (the `THEMES` array in
`install/themes/themes.sh`).  The repo does not ship themes — they are installed
into `~/.config/omarchy/themes/` on setup.  Sample themes include canvas,
emerald, harbor, and whitegold.  Matching application configs exist for many
terminals, editors, bars, launchers, and lock screens.

**Plugins** -- 15 Omarchy shell plugins (short ids, renamed from
author-prefixed names).  Reference in `config/omarchy/plugins/`, managed via
`shell.json`:

- `activity-monitor` — system activity in the bar
- `auto-wallpaper` — automatic wallpaper rotation
- `bar-autohide` — auto-hide the bar
- `bluetooth-audio` — bluetooth audio control
- `cursor-style` — cursor style management
- `herald-notification` — notification announcements
- `navbar-cat` — navbar cat (decorative)
- `omnimedia` — media controls (compact horizontal card)
- `otoru` — otoru widget
- `overview` — workspace overview (configured in shell.json)
- `protonvpn` — Proton VPN control
- `quran` — Quran widget
- `shell-settings` — shell settings panel
- `theme-scheduler` — schedule theme changes
- `yt-music` — YouTube music widget (floating window 450×850)

Scripts — Utility scripts in `bin/` (interactive or daemon):

| Script | Interactive | Daemon | Notable deps |
|---|---|---|---|
| `comic-translate` | ✗ | ✗ | grim, slurp, tesseract, translate-shell |
| `dots-push` | ✅ | ✗ | gum, git | Force-pushes to main; spice/Walls/Assets/Lazygit |
| `earbuds-status` | ✗ | ✅ | bluetoothctl | Polls every 5s |
| `hdd-status` | ✗ | ✗ | blkid, lsblk | Bar widget JSON |
| `hdd-unmount` | ✗ | ✗ | udisksctl, lsof | Refuses when busy |
| `media-download` | ✅ | ✗ | yt-dlp, mpc | Cookies via chromium; 5s rate-limit retry |
| `mp4-to-gif` | ✅ | ✗ | ffmpeg, gifsicle | Two-pass palette render |
| `spotify-music-download` | ✅ | ✗ | spotifydl, mpc | Before/after snapshot move |
| `write-iso` | ✅ | ✗ | dd, fzf, pv | Destructive to USB |

> **Low battery** — Omarchy already warns once at 10%. `config/omarchy/hooks/battery-low.d/persistent-nag` (a `battery-low.d` hook) keeps nagging: sound on every drop, screen dim + critical notification below 5%, auto-stops when you plug in.

**Install system** — TUI-driven setup (`setup.sh`) with gum multi-select, logging,
and tagged package installation.

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

Fetches remote changes, resets local state, re-runs install scripts, re-stows
configs, and reloads the UI. Generates a report at `~/.local/state/spice/update-report.txt`.

## Structure

```
spice/
├── setup.sh              # Interactive gum-based setup wizard
├── update.sh             # Remote-first update: reset --hard + re-apply scripts
├── install.sh            # Bootstrap installer (curl | bash entry point)
├── CONTEXT.md            # Session log: fixes, architecture notes, known issues
├── agents/               # Agent skills (this skill, installed at ~/.agents/skills)
│   └── skills/spice/     #   SKILL.md, config.md, scripts.md, setup.md
├── applications/         # Desktop entries + icons
├── bin/                  # Custom user scripts (see scripts.md)
│   ├── lib/helpers.sh    # gum-based helpers (log_header, spinner, show_done, ...)
│   ├── comic-translate
│   ├── dots-push
│   ├── earbuds-status
│   ├── hdd-status
│   ├── hdd-unmount
│   ├── media-download
│   ├── mp4-to-gif
│   ├── spotify-music-download
│   └── write-iso
├── config/               # Deployed to ~/.config/ (stow, omarchy = copy)
│   ├── hypr/             # Hyprland config (hyprland.lua + requires)
│   ├── omarchy/          # shell.json, plugins, hooks, themed, branding
│   ├── opencode/         # opencode.json, tui.json, dcp.jsonc, smart-title.jsonc, plugin/
│   ├── calibre/ mpd/ mpv/ rmpc/ sioyek/ uwsm/ yazi/ miscellaneous/
├── install/              # Installation pipeline (see setup.md)
│   ├── config/           #   stow.sh, omarchy.sh, applications.sh, fonts.sh, pam.sh, zsh.sh
│   ├── extras/           #   gpu-driver.sh, howdy.sh, thinkfan.sh, easyeffects.sh
│   ├── lib/              #   helpers.sh, spice.txt
│   ├── packaging/        #   install-packages.sh, packages.txt, webapps.sh
│   ├── services/         #   mpd-rmpc.sh
│   └── themes/           #   themes.sh, wallpapers.sh
└── system/               # System-level configs (not stowed)
    ├── easyeffects/      #   presets (t14-dolby-*.json)
    └── thinkfan/         #   thinkfan.conf, hwmon fix service + script
```

## Requirements

- Arch Linux with Omarchy
- `gum` (used by setup TUI and scripts)
- `stow` (for config symlinking)
- `fzf` (for ISO selection and some scripts)
- `yay` (for AUR package bootstrapping, included in base-devel)

## License

Personal dotfiles -- use at your own risk.