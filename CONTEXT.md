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

**Plugins:** 16 Omarchy shell plugins in `config/omarchy/plugins/`. Install sources in `install/plugins/` (some extras like `quickshell.spotify` only exist there).

**Themes:** 4 themes in `config/omarchy/themes/`: canvas, emerald, harbor, whitegold.

## Known Issues / TODO

- `bin/lib/helpers.sh` is now unused (nothing sources it). Can be deleted.
- `update.sh` references `install/services/reload.sh` but the reload is now inline (hyprctl + qs). Clean if needed.
- `config/Enha_YT.txt` is a loose file in config root -- gets stowed to `~/.config/Enha_YT.txt`. Verify this is intentional.
- The `packages` script no longer supports a "core" mode -- the `MODE` arg is effectively unused.