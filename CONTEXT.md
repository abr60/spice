# Crash diagnosis: spotifydl (PID 87663)

Date: Wed 2026-08-19, 07:39:11 +06 — Omarchy machine (hostname `omarchy`)

## What crashed

`spotifydl embedded https://open.spotify.com/playlist/3ymBnAz3AzGJrTh1pyDnRQ?si=38d825cc780549d3`

The tool was downloading a Spotify playlist in parallel (dozens of tokio worker
threads; ~30 MP3s landing in `~/Music/Spotify/`). One worker thread
(`tokio-rt-worker`, TID 87670) panicked and aborted the whole process.

- Signal: SIGABRT (6), si_code SI_TKILL
- Binary: /usr/bin/spotifydl (package `spotifydl 1.0.0-1`, github.com/bjn7/spotifydl)
- Built with Rust `panic = "abort"` (confirmed via `library/panic_abort` string in binary)

## Mechanism (proven from the core dump)

Panic message embedded in core:

```
thread 'tokio-rt-worker' (87670) panicked at src/download.rs:104:70:
called `Result::unwrap()` on an `Err` value: error sending request for url
  (https://i.scdn.co/image/ab67616d00001e02af9a38064dc3cc873ad7bf72)
Caused by:
    0: client error (Connect)
    1: received fatal alert: InternalError
```

- While fetching an **album-cover image** from Spotify's CDN, the request failed.
  `received fatal alert: InternalError` (TLS alert 80) means the TLS handshake
  failed — server- or network-side, not local misconfiguration.
- spotifydl unwraps that network Result (`src/download.rs:104`), and with
  `panic=abort` a recoverable network failure becomes a hard SIGABRT that kills
  the entire batch.

## Ruled out

- Not resource exhaustion: 6.8 GiB available, swap unused, no OOM kills in journal.
- One-off crash: no prior `spotifydl` coredumps in `coredumpctl list`.
- Not an Omarchy bug: the cause sits entirely inside the third-party `spotifydl`
  application. Correct upstream for a report: https://github.com/bjn7/spotifydl

## Data loss

None. All fully-downloaded MP3s are intact. A few in-flight downloads were
interrupted, leaving **0-byte placeholder files** in `~/Music/Spotify/` (e.g.
`passion - Speed Up - silent anthem.mp3`, `algo mudou dentro de mim - JHONS
REDGOLIO QUERIDA.mp3`). Delete them; a re-run re-downloads.

## Recurrence

Likely — every time a CDN request fails mid-download, the `unwrap()` panics and
`panic=abort` kills the process. Workaround: re-run spotifydl after a transient
network blip.

## Notes

- Core was extracted to a fresh mktemp path for gdb symbolization and deleted
  afterwards; debuginfod did not resolve symbols (no debug package). The panic
  message was recovered by searching the core with `strings`.
- Panic message not in the journal (process ran from a terminal, output went to
  the terminal, not the journal).

---

# Spice Project Context

> Read this file at the start of any session to understand the project state.

## What Is This

Personal dotfiles + system setup overlay for [Omarchy](https://github.com/basecamp/omarchy) on Arch Linux (Hyprland). Lives at `~/spice`, uses GNU Stow to symlink configs to `~/.config`.

## Session Log

### 2026-08-19 -- Initial audit + fixes

**Bugs fixed:**
- `install/packaging/install-packages.sh` -- core mode was broken (read `packages.txt` instead of `pkgs-core.txt`). Default changed to `extra`.
- `install/config/configs.sh` -- stow list was missing `omarchy` dir (themes, plugins, hooks not getting symlinked). Added it.
- `bin/lib/helpers.sh` -- `_ensure_gum` was called on source, exiting any script before its own logic ran. Removed the auto-call.
- `config/hypr/assets/lib/helpers.sh` -- same `_ensure_gum` fix.
- `bin/write-iso` -- was sourcing from `~/spice/bin/lib/helpers.sh` (duplicate). Changed to `$HOME/.config/hypr/assets/lib/helpers.sh` to match other scripts.

**Repo hygiene:**
- Added `.gitignore` (logs, state, editor files, secrets).
- Wrote proper `README.md` (was just `# spice`).

**Archer -> Spice rename:** Already complete across codebase. Only stale entries in `mpv/memo-history.log` (historical, not worth changing).

### 2026-08-19 -- media-download + spotify-music-download fixes

**media-download problems (round 1):**
- All yt-dlp commands had `2>/dev/null` -- hid actual errors. User saw "Download failed" with zero info.
- `${PIPESTATUS[0]}` checked after subshell pipe -- exit codes got swallowed.
- Generic error messages.

**media-download fixes (round 1):**
- Captured stderr to temp file, shown to user on failure.
- Moved `${PIPESTATUS[0]}` check outside pipe chain using `dl_exit` variable.
- Validation step now shows yt-dlp's actual error (e.g. "Sign in to confirm you're not a bot").

**media-download problems (round 2 -- rate limiting):**
- yt-dlp `--dump-json` validation without cookies worked from terminal but failed in script due to YouTube bot detection.
- "Try without cookies first, then try with cookies" pattern doubled request count, making rate limiting worse.
- Each failed attempt triggered another request within seconds, keeping the 429 rate limit active.

**media-download fixes (round 2):**
- Every yt-dlp call now always uses `--cookies-from-browser chromium::GNOMEKEYRING`.
- Removed dual-path retry ("try without cookies, then try with") -- was the main cause of rate limiting.
- Failed attempts now sleep 5s before retrying with the same command (gives YouTube cooldown time).
- Playlist detection gets 3s sleep on retry.
- Result: 1-2 yt-dlp requests per run instead of 4-6.

**spotify-music-download fixes (round 1):**
- Before/after snapshot pattern: compares file lists to find new files.
- Also checks CWD for new audio files.
- Captures spotifydl stderr and displays on failure.

**spotify-music-download fixes (round 2):**
- Added 5s sleep + retry on failure (same pattern as media-download).
- Cleaned up error message wording.

### 2026-08-19 -- omnimedia plugin refactor

**Layout changes:**
- Refactored from vertical layout to horizontal compact card (album art left, info + controls right).
- Removed CAVA visualizer standalone section (was taking vertical space).
- Removed Wallpaper preview block.
- Progress bar and playback controls (prev/play/pause/next/shuffle/repeat) now inline below title/artist.
- Player source selection list retained at bottom.
- Removed unused wallpaper-related properties.

### 2026-08-19 -- plugin id rename + preview shrink

- Renamed all 15 external plugin ids/dirs from author-prefixed (`ericvrp.bar-autohide`) to short names (`bar-autohide`). Updated `shell.json`, `manifest.json` ids, QML `moduleName`s, hypr lua refs, and all functional scripts/tests.
- Removed plugin preview/screenshot images (~1.8MB); kept runtime-referenced images (winamp-logo.svg, protonvpn icon, navbar-cat sprites/xbm).
- Fixed a regression in `cursor-style/bin/omarchy-cursor-menu-entry`: the ownership check `*cursor-style*` matched the row key `style.cursor-style` itself and deleted user-redefined rows on `--remove`. Now matches `omarchy-cursor-menu-entry` or `toggle cursor-style`.
- All plugin test suites pass (yt-music, bluetooth-audio, cursor-style).

### 2026-08-19 -- overview keybind fix

- Overview (SUPER+grave) wasn't working: `bindings.lua` called `omarchy-shell shell toggle overview`, but the installed plugin id is `omarchy-overview`. Shell's `toggle`/`summon` silently no-ops on unknown ids (warns to the shell log only).
- Fixed `config/hypr/bindings.lua:17` to use `toggle omarchy-overview`. Verified via IPC state flip open/closed, then `hyprctl reload`.
- Side note: installed plugin dirs are author-prefixed (`sanjar.omnimedia`, `omarchy-overview`) while the spice repo has short names (`omnimedia`, `overview`). The two copies diverge; edits to installed plugins under `~/.config/omarchy/plugins/` do NOT live in the spice repo.

### 2026-08-19 -- rmpc dynamic omarchy theme + yazi crash fix

**rmpc theme made dynamic (previously hardcoded `matugen.ron`):**
- `config/rmpc/themes/` cleared to a single theme. Old themes (`matugen.ron`, `dark-mocha.ron`, `mocha.ron`, `monochrome.ron`, `nord.ron`, `versatile.ron`) deleted.
- Theme moved to `config/omarchy/themed/omarchy.ron.tpl` — a template processed by `omarchy-theme-set-templates` on every theme set. Uses `{{ accent }}`, `{{ foreground }}`, `{{ muted }}`, `{{ dark_background }}`, `{{ lighter_background }}`.
- `config/rmpc/config.ron:7` theme changed `"matugen"` → `"omarchy"`.
- New hook `config/omarchy/hooks/theme-set.d/update-rmpc-theme` symlinks the generated theme (`~/.local/state/omarchy/current/theme/omarchy.ron`) into `~/.config/rmpc/themes/omarchy.ron`.
- `install/config/stow.sh` now regenerates the rmpc theme link after stow (mirrors the yazi step).
- The `~/.config/rmpc/themes/omarchy.ron` symlink is git-tracked like `config/yazi/theme.toml` (both point into the omarchy state dir).

**yazi crash fix (TOML parse error on `{{ red }}`):**
- `config/omarchy/hooks/theme-set.d/update-yazi-theme` was substituting only raw `colors.toml` keys, so derived aliases (`{{ dark_background }}`, `{{ lighter_background }}`, `{{ light_foreground }}`) stayed as literal `{{ }}` strings → yazi crashed.
- Hook now uses `omarchy-theme-color --file "$COLORS_FILE" --all` (full resolved set, tab-separated) to build the sed script, same as `omarchy-theme-set-templates`.
- `config/omarchy/themed/yazi.toml.tpl` light-theme readability fixes:
  - Hardcoded Catppuccin pastels in `[filetype]` (invisible on light backgrounds) → theme vars: images=`{{ cyan }}`, media=`{{ yellow }}`, archives=`{{ magenta }}`, documents=`{{ green }}`.
  - `[which] rest` was `{{ background }}` (invisible, text = bg color) → `{{ muted }}`.

**Syncing reminder:** `~/.config/omarchy` is NOT stowed — it's copied by `install/config/omarchy.sh`. Edits to `config/omarchy/**` in spice must be re-pasted there (and hooks re-run) to take effect live. `~/.config/rmpc` IS a stow symlink into the repo.

### 2026-08-19 -- MPD + mpd-mpris fixes

**Audit of `config/mpd/` + `install/services/` found two issues:**
- `mpd-mpris.service` (packaged unit `/usr/lib/systemd/user/`) ships with `After=mpd.service` but no `Requires=`. Cold boot could start the bridge before MPD binds → MPRIS dead. Since `/usr/lib` units get wiped on package updates, the fix is a user drop-in override at `~/.config/systemd/user/mpd-mpris.service.d/override.conf` with `Requires=mpd.service`, written by `install/services/mpd-rmpc.sh` (guarded by `[[ -f ]]`).
- `config/mpd/mpd.conf` had no `restore_paused` → MPD auto-resumed playback on every restart/reboot. Added `restore_paused "yes"`.

**Verified:** rmpc connects `127.0.0.1:6600` == MPD bind. mpd-mpris connects via `localhost` (resolves `::1`, MPD binds IPv4-only `127.0.0.1`) — works only because Go's dialer falls back to IPv4. Fragile but functional; not changed. Live `~/.config/mpd` IS a stow symlink (`../spice/config/mpd`), so config edits go live instantly. After `systemctl --user restart mpd`, playlist restores paused, mpd-mpris reconnects fine.

## Architecture Notes

**Two helpers.sh files (same API, different locations):**
- `config/hypr/assets/lib/helpers.sh` -- the "source of truth", stowed to `~/.config/hypr/assets/lib/helpers.sh`. Most bin scripts source from here.
- `bin/lib/helpers.sh` -- duplicate, now unused after write-iso fix.

**Stow flow:**
- `setup.sh` calls `run_logged "config/configs.sh"` which runs `stow --target=~/.config config`
- `update.sh` runs `stow --restow --target=~/.config config`
- Both clean existing targets first from `STOW_DIRS` list

**Package system:**
- Single package list: `install/packaging/packages.txt`
- Tagged packages: `[tag:thinkfan]`, `[tag:easyeffects]`, `[tag:howdy]`, `[tag:Hyprpm]`
- `packages` script: `extra` mode = untagged only, `extra --tag <tag>` = tagged only
- Bootstraps `yay` for AUR packages

**Plugins:** 16 Omarchy shell plugins in `config/omarchy/plugins/` (external ones use short ids, e.g. `bar-autohide`, not author-prefixed). Install sources in `install/plugins/` (some extras like `quickshell.spotify` only exist there).

**Themes:** 4 themes in `config/omarchy/themes/`: canvas, emerald, harbor, whitegold.

## Known Issues / TODO

- `bin/lib/helpers.sh` is now unused (nothing sources it). Can be deleted.
- `update.sh` references `install/services/reload.sh` but the reload is now inline (hyprctl + qs). Clean if needed.
- `config/Enha_YT.txt` is a loose file in config root -- gets stowed to `~/.config/Enha_YT.txt`. Verify this is intentional.
- The `packages` script no longer supports a "core" mode -- the `MODE` arg is effectively unused.