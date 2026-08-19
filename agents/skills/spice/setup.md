# Spice Setup, Install & Update

This guide documents the `setup.sh` wizard, the `install/` pipeline, package
management, config deployment (stow + omarchy.sh), services, themes, extras,
and the `update.sh` flow.

## Entry Points

| Script | Purpose |
|--------|---------|
| `install.sh` | Bootstrap installer — clones/updates the repo at `~/spice`, then `exec ./setup.sh`. Used via `curl ... | bash`. |
| `setup.sh` | Interactive wizard (gum-based) for fresh or partial install |
| `install/packaging/install-packages.sh` | Headless package installer with tag support |
| `update.sh` | Remote-first update: `git reset --hard` to remote, then re-applies install scripts and reloads |

## setup.sh Wizard

`bash ~/spice/setup.sh`

Flow:

1. Sources `install/lib/helpers.sh` for shared functions, colors, and gum theme.
2. Prints the logo (`install/lib/spice.txt`) and a splash banner.
3. Shows a **multi-select** of steps (gum choose, space to toggle):
   - `Packages` → `install/packaging/install-packages.sh`
   - `Configs` → `install/config/stow.sh` (stow symlinks + omarchy copy)
   - `Applications` → `install/config/applications.sh`
   - `MPD + RMPC` → `install/services/mpd-rmpc.sh`
   - `Themes` → `install/themes/themes.sh` (community themes)
   - `Fonts` → `install/config/fonts.sh`
   - `Zsh` → `install/config/zsh.sh`
   - `GPU Drivers` → `install/extras/gpu-driver.sh` (sets `NEEDS_REBOOT=true`)
   - `Howdy` → `install/extras/howdy.sh` (face recognition)
   - `Thinkfan` → `install/extras/thinkfan.sh` (ThinkPad fan control)
   - `EasyEffects` → `install/extras/easyeffects.sh` (audio presets)
   - `Waydroid` → `install/extras/waydroid.sh` (Android container, sets `NEEDS_REBOOT=true`)
   - `Wallpapers` → `install/themes/wallpapers.sh`
4. Shows a summary and asks for confirmation (`gum confirm "Run it?"`).
5. Executes each selected step with `run_logged`, streaming output to the log.
6. At the end, prompts for a reboot if `NEEDS_REBOOT` was set.

Each step is **skippable**: missing scripts are logged as `SKIPPED`; failures
are logged and setup continues.

**Logs:** `~/.local/state/spice/logs/setup-<timestamp>.log`

## Package Management

Installer: `install/packaging/install-packages.sh` with list
`install/packaging/packages.txt`.

### Usage

```bash
bash install/packaging/install-packages.sh              # untagged lines only
bash install/packaging/install-packages.sh --tag thinkfan  # only [tag:thinkfan] lines
```

The `--tag` flag may be `$1` or later for backwards compatibility. There is no
separate "core"/"extra" mode anymore — untagged is the default.

### packages.txt Format

- `#` comments are ignored.
- Untagged lines install by default.
- Lines with `[tag:<tag>]` are opt-in; install only with `--tag <tag>`.
- Existing tags: `thinkfan`, `easyeffects`, `howdy`, `Hyprpm`.

### Installer behavior

- **pkg_is_installed** — `pacman -Q`, skips already-installed packages.
- **pkg_in_pacman** — `pacman -Si`; repo packages go through `sudo pacman -S`.
- **AUR fallback** — anything not in the repos goes through `yay -S`
  (bootstraps `yay-bin` from the AUR if missing, via `base-devel` + `git`).
- Install/skip/fail are tallied; exit code is 1 if anything failed.
- **Log:** `~/.local/state/spice/logs/install-packages[<tag>].log`

## Config Deployment

Two scripts handle `config/` → `~/.config/`:

### `install/config/stow.sh`

1. **Wipes existing targets** for the stow dirs (calibre, hypr, mpd, mpv,
   rmpc, sioyek, uwsm, yazi) with `rm -rf` — destructive to local edits in
   those dirs.
2. Runs `stow --target="$HOME/.config" --ignore='^omarchy$' --verbose=1 config`
   — **omarchy is intentionally excluded** from stow.
3. Runs `install/config/omarchy.sh` (below).
4. **Regenerates theme-derived links** by running the theme-set hooks:
   - `~/.config/omarchy/hooks/theme-set.d/update-yazi-theme` → regenerates
     `~/.config/yazi/theme.toml` symlink
   - `~/.config/omarchy/hooks/theme-set.d/update-rmpc-theme` → regenerates
     `~/.config/rmpc/themes/omarchy.ron` symlink
5. Reloads: `hyprctl reload` + `qs -c reload`.

### `install/config/omarchy.sh`

Copies `branding`, `hooks`, `plugins`, `themed`, and `shell.json` from
`config/omarchy/` into `~/.config/omarchy/`. It **never symlinks the whole
omarchy dir** because Omarchy owns it at runtime (it installs/manages themes
and plugins there). Anything else in `~/.config/omarchy/` (like `themes/`) is
left untouched.

> **Reminder:** after editing `config/omarchy/**` in the repo, re-run
> `omarchy.sh` (or setup) so changes reach `~/.config/omarchy` — stow alone
> does not cover omarchy.

## Services

`install/services/mpd-rmpc.sh` — the only service script:

- Creates MPD state dirs and `~/Music` if missing.
- Enables user services: `mpd.service`, `mpd-mpris.service`.
- Writes a **drop-in override** at
  `~/.config/systemd/user/mpd-mpris.service.d/override.conf` with
  `Requires=mpd.service` (fixes cold-boot ordering; the packaged unit only has
  `After=`). Written only if absent.
- Starts MPD if not running; waits up to ~5s for the cava FIFO
  (`/tmp/mpd.fifo`); runs `mpc update`; checks rmpc connectivity.

## Themes

`install/themes/themes.sh` — installs community Omarchy themes via
`omarchy theme install <url>` from the `THEMES` array:

- whitegold, roseofdune, batou, thegreek, turbonite, harbor, inkypinky
  (all `HANCORE-linux/omarchy-<name>-theme` on GitHub).
- Already-installed themes are skipped; the previously active theme is
  **restored afterwards** so it never hijacks the current look.
- Force reinstall: `FORCE=1 bash install/themes/themes.sh`.

`install/themes/wallpapers.sh` — clones/updates wallpapers to `~/Wallpapers`.

## Extras

| Extras script | What it does | Side effects |
|---------------|--------------|--------------|
| `gpu-driver.sh` | Installs drivers for detected hardware | Reboot recommended |
| `howdy.sh` | Face recognition for sudo/login | `[tag:howdy]` packages |
| `thinkfan.sh` | ThinkPad fan curve control | `[tag:thinkfan]` packages |
| `easyeffects.sh` | Audio presets + plugins | `[tag:easyeffects]` packages |
| `waydroid.sh` | Android container setup | Reboot recommended |

## update.sh Flow

Remote-first; **overwrites local state**:

1. `ensure_installed gum`.
2. `git fetch origin`; resolves `origin/HEAD` (falling back to `main`/`master`).
3. If local == remote, exits ("Already up to date").
4. Shows incoming commits + changed files; writes report to
   `~/.local/state/spice/update-report.txt`.
5. `git reset --hard "$REMOTE"` — **wipes local uncommitted changes**.
6. Re-applies install scripts (missing scripts are skipped, failures warn):
   - `packaging/install-packages.sh` (packages)
   - `config/fonts.sh` (fonts)
   - `config/applications.sh` (applications)
   - `services/mpd-rmpc.sh` (MPD/RMPC)
   - `extras/wallpapers.sh` (wallpapers — note: the file lives under
     `install/themes/`, so this step currently warns "not found — skipping";
     a known leftover)
7. Re-stows: `stow --restow --target="$HOME/.config" --ignore='^omarchy$' config`,
   reports conflicts if any; then runs `install/config/omarchy.sh`.
8. Reloads UI: `hyprctl reload` + `qs -c reload` (inline; the old
   `install/services/reload.sh` is gone).
9. Writes a summary (duration, commit roll-forward) to the report.

**State:** `~/.local/state/spice/update-report.txt`

## Shared Helper Libraries

### `install/lib/helpers.sh`

Sourced by install scripts. Provides:

- **Color palette** — forest green + cream theme (`C_PRIMARY`, `C_ACCENT`, ...)
- **Gum theme** — exported `GUM_*` env vars for consistent styling
- **Terminal dimensions** — reads `stty` via `/dev/tty`; falls back to 80×24
- **Logo renderer** — `print_logo` centers and prints `lib/spice.txt`
- **Logging functions** — `msg`, `ok`, `warn`, `err`, `die`, `section`
- **Gum helpers** — `spinner`, `ask_yes_no`, `gum_input` (with plain-text
  fallbacks when gum is absent)
- **Package helpers** — `is_installed`, `ensure_installed`
- **Filesystem helpers** — `remove_path`, `ensure_dir`
- **Hardware detection** — `is_laptop`, `detect_hardware_type`, `has_battery`
- **Systemd helpers** — `enable_system_service`, `enable_user_service` (skip
  missing units gracefully)
- **`run_step`** — shared step runner with optional `critical:true` and log file

### `bin/lib/helpers.sh`

A **different** helper file used by the interactive `bin/` scripts:
`log_header`, `log_step`, `log_info`, `log_success`, `log_error`,
`log_detail`, `spinner`, `ask_yes_no`, `log_progress`, `show_done`, and
`_ensure_gum`. All gum-based; `_ensure_gum` exits if gum is missing (the
auto-call on source was removed — scripts call it explicitly if needed).

## Troubleshooting

- **Setup failed partway?** Check the timestamped log in
  `~/.local/state/spice/logs/`. Failed steps are logged with `Failed: <label>`.
- **Package install failed?** See `install-packages*.log`; `FAILED: <pkg>`
  lines name the culprits.
- **Stow conflicts?** `stow --restow` reports them; resolve manually in
  `~/.config/` then re-run.
- **Omarchy config not live after editing repo?** Re-run
  `install/config/omarchy.sh` — omarchy content is copied, not symlinked.
- **Missing gum?** `install/lib/helpers.sh` falls back to plain text prompts,
  but `setup.sh` itself requires gum for the multi-select UI.
- **Local changes vanished?** `update.sh` does `git reset --hard`. Check
  `git reflog` in `~/spice` if you need to recover.