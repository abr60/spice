# Our Plugins Guide (`plugins.md`)

The plugins **we** built, customized, or run on this machine. These live under
`~/.config/omarchy/plugins/` and are DIFFERENT from the 15 repo-vendored
Omarchy plugins documented in [`config.md`](config.md). Every plugin except
`abr.lock` is now a git worktree of an `abr60` repo; `abr.lock` stays
git-less in the live dir (deploy-lock recreates it) so its backups are
file copies. See the **Snapshot & rollback** section below.

> 💡 This guide is a companion to the shell-restart rule in
> `SKILL.md` (Critical Safety Rules #9): **after ANY plugin QML change, run
> `omarchy restart shell`.** The hot-reload path dead-latches silently — old
> QML keeps running with zero errors and you'll swear nothing changed.

## Plugin inventory

| Plugin | Kind | Dir | Git remote? | Origin |
|---|---|---|---|---|
| **face.howdy** | overlay (wizard) | `face.howdy` | ✅ `git@github.com:abr60/oma-face-howdy.git` | ours, built from scratch |
| **yt-music** | service + bar-widget | `yt-music` | ✅ `git@github.com:abr60/yt-music.git` | vendored by us (ilyaZar, MIT), rewritten |
| **omarr** (Radarr + Sonarr) | bar-widget ×2 | `io.github.boyoyooo.omarr` | ✅ upstream `https://github.com/boyoyooo/omarr.git` | third-party, two instances configured in shell.json |
| **netshare** | bar-widget | `abr.netshare` | ✅ `git@github.com:abr60/netshare.git` | ours (lineage: stock `omarchy.network` clone, heavily customized) |
| **thinkfan** | bar-widget | `thinkfan` | ✅ `git@github.com:abr60/thinkfan.git` | ours, built for the ThinkPad |
| **abr.lock** | service (lock screen) | `abr.lock` | ⚠️ repo `git@github.com:abr60/abr.lock.git` exists, BUT live dir is git-less | runtime clone of `omarchy.lock`, PAM-patched |

`allowMultiple` is true only for **omarr** (Radarr instance + Sonarr instance).
Everything else is single-instance.

All first-party plugins (face.howdy, yt-music, netshare, thinkfan — and the
`abr60/abr.lock` repo) are `fork: false` standalone repos under **abr60**,
verified via `gh api repos/abr60/<name>`; none are GitHub forks. The live
dirs of netshare/thinkfan were re-attached to their repos (`git init` →
remote → `reset --hard origin/main`, zero-diff) on `Aug 29` — they are now
proper worktrees like face.howdy.

**Only `abr.lock` remains truly git-less in the live dir**: deploy-lock
reconciles its `Service.qml` from stock omarchy.lock + re-applies the howdy
patch on every deploy, so a git worktree there would be churned. Its live
state is backed up by file copy only. The `abr60/abr.lock` repo happens to
hold the patched version (11 `howdyConfigured` refs) as a manual baseline.

## The live-edit workflow (face.howdy + yt-music)

- Work directly in `~/.config/omarchy/plugins/<id>/` — this IS the working
  clone now (the old separate `~/face.howdy` was merged here `Aug 29`).
- Edit → `git add/commit` → `git push` → **`omarchy restart shell`**.
- Do NOT rely on `omarchy plugin update` / hot reload to pick up QML changes
  — see the dead-latch note above. After a restart the plugin loads fresh and
  journal shows any real QML error (`journalctl --user | grep quickshell`).
- face.howdy rollback markers: tag `pre-redesign-ac903c7` (pushed + local),
  plus file backups in `~/face-howdy-backups/.backup-pre-redesign/`.
- omarr is upstream-tracked; config lives in shell.json (below), code edits
  stay local unless you push to boyoyooo's fork.

## Snapshot & rollback (do this BEFORE anything major)

Snapshot **every time we do something major or dangerous**: a full QML
redesign/rewrite, core-logic refactor (Service.qml state machines, bin/
scripts), anything privileged (PAM, polkit, systemd, udev, pkexec flows,
`/proc`), deletions/teardowns, multi-file changes, or widget-config changes
(shell.json). Heuristic: **more than one file, or anything privileged →
snapshot first.**

One command handles it — **`plugin-snapshot <id> <label>`** (in `spice/bin/`,
on PATH, deployed with dotfiles):

- git-backed plugin (face.howdy, yt-music, netshare, thinkfan): **refuses if
  the worktree is dirty** (commit/stash first), then tags
  `<id>-pre-<label>-<YYYYMMDD-HHMMSS>` and pushes the tag (omarr/upstream
  remotes are tag-local-only).
- `abr.lock` (git-less): copies the live dir to
  `~/plugin-backups/abr.lock/snap-<ts>-<label>/`.
- `--config shell.json bindings.lua` bundles those config files into the same
  snapshot (bare names resolve; anything else resolves against `$HOME`).
- `--no-push` keeps the tag local.
- Always prints the exact rollback one-liner when done.

Storage: `~/plugin-backups/<id>/snap-<ts>-<label>/` — deliberately OUTSIDE
the plugin dirs, because plugin dirs get wiped on re-add/clone/reconcile.
First precedent: the face.howdy redesign used tag
`pre-redesign-ac903c7` + dir `~/face-howdy-backups/.backup-pre-redesign/`.

Rollback procedure (docs-level, per plugin type):

1. **git-backed**: `git -C <dir> reset --hard <tag>` (or `git revert`).
2. **abr.lock / configs**: `rsync -a <snapshot>/plugin/ <dir>/` and restore
   config copies into `~/.config/omarchy/` as needed.
3. If the change touched system level, re-run the idempotent setup
   (face.howdy `omarchy-howdy-setup-system all`, thinkfan `setup-system`)
   instead of restoring half-applied state.
4. Always finish with `omarchy restart shell` and verify via
   `journalctl --user | grep quickshell`.

Failing fast beats losing work: a snapshot costs seconds and makes every
experiment reversible.

## face.howdy — the Howdy face-unlock wizard

Overlay plugin (`keepLoaded: true`, entryPoint `Service.qml`), bound to
**SUPER+H**. UI adapts to 5 states: not installed / installing / needs
attention / active / remove. v2 UI is deliberately **glyph-free** — accent
left-bars, state dots, and the native `FaceHowdyIcon.qml`
(QtQuick.Shapes MDI path). The `\uXXXX` escape trap: QML escapes are exactly
4 hex digits, so 5-digit Nerd Font PUA codepoints (U+F0000+) silently render
wrong glyphs — never write them as string literals.

All privileged work goes through pkexec → bundled `bin/` scripts:

| Script | Privilege | Job |
|---|---|---|
| `omarchy-howdy-status` | user | emits `key=value` status (howdy_pkg, leire_pkg, pam_howdy_sudo, lock_pam, ir_udev, models, enrolled, active_lock) |
| `omarchy-howdy-setup-system` | pkexec root | phases: `packages` (installs as the invoking user via PKEXEC_UID, not root — AUR builds fail as root), `ir` (v4l2 scan → udev rule + IR services), `models` (ONNX + config.ini), `pam` (inserts pam_howdy + IR `pam_exec` lines ONCE — `0,/addr/` sed range, the old `sed /addr/i` tripled the lines) |
| `omarchy-howdy-deploy-lock` | user | clones stock omarchy.lock → `abr.lock`, patches in `howdyConfigured`, swaps shell.json, adds SUPER+H + lid-switch binds |
| `omarchy-howdy-restore-lock` | user | reversible: restores stock lock, strips marker-guarded binds from `bindings.lua` |
| `omarchy-howdy-teardown-system` | pkexec root | `keep-pkgs` (PAM + lock patch only) / `delete-pkgs` (also removes packages, IR, /etc/howdy) |
| `omarchy-howdy-refresh-state` | root | writes `/etc/omarchy/face-howdy/enrolled` |

PAM wiring: 1× `pam_howdy.so` + 1× IR `pam_exec` line in `/etc/pam.d/`
sudo, sddm, polkit-1, plus `/etc/pam.d/omarchy-lock-howdy`. The lid-open
handler is in `bindings.lua` under `face.howdy` markers. Live system state:
IR emitter on `/dev/v4l/by-path/pci-0000:00:14.0-usb-0:4:1.2-video-index0`
(VENDOR 04f2, PRODUCT b6d0), ONNX models in `/usr/share/howdy/models/`.

## yt-music — YouTube Music drop-down

Service + bar-widget pair (`Service.qml` + `BarWidget.qml`). The service
manages a **quake-style drop-down** for the YouTube Music webapp: toggling
launches `omarchy-launch-or-focus-webapp "music.youtube.com"` and matches the
window by its class (`music.youtube.com`), then floats/resizes/moves it via
hyprctl `hl.dsp.window.*` eval expressions (alignment Left/Center/Right,
window width 450 / height 800 default). Supporting pieces:
`bin/yt-music-widget` (main helper), `lib/clients.sh` (window discovery) /
`lib/geometry.sh` (geometry math), `scripts/apply_geometry.sh` /
`scripts/toggle_cliamp.sh` / `scripts/sync_bindings.sh` (one-shot actions
from the bar), `open-keybindings.sh`. Legacy naming: the quake mechanics were
first built for the **cliamp** terminal music player (hence
`org.omarchy.cliamp.quake` class + script names) and reused for YT Music. The
bar widget is a toggle button with alignment/size controls and a
hide-confirm state.

## omarr — Radarr (movies) + Sonarr (TV) in the bar

Third-party widget (`io.github.boyoyooo.omarr`, MIT) run as **two instances**
in `~/.config/omarchy/shell.json`, browsing/searching/adding to the *arr
stack and showing the combined download queue from the bar. Config:

- **Radarr**: `url http://localhost:7878`, `apiKeyFile
  ~/.config/omarchy/arr/radarr-apikey`, `qualityProfileId 4` (HD-1080p),
  `rootFolderPath /movies`
- **Sonarr**: `url http://localhost:8989`, `apiKeyFile
  ~/.config/omarchy/arr/sonarr-apikey`, `qualityProfileId 6` (HD-720p/1080p),
  `rootFolderPath /tv`, `seasonFolder true`, `monitorMode all`
- both: `interval 60` (poll seconds), `label` Radarr / Sonarr

The apps themselves are a docker-compose stack (`~/arr/docker-compose.yml`,
rebuilt with `bash ~/spice/install/extras/arr.sh`): qbittorrent :8080,
radarr :7878, sonarr :8989, prowlarr :9696, flaresolverr :8191, jellyfin :8096
(/dev/dri), jellyseerr :5055, bazarr :6767. All mount `/home/abr/media`
(downloads → hardlink-import). `~/arr/README.md` has addresses and **API
keys/passwords — never push it**. Connection details, quality profile IDs and
indexer notes are in that README; `media-notify.service` (user timer, 15s)
polls Radarr+Sonarr history for download toasts.

## netshare — Wi-Fi + hotspot panel

Bar-widget fork of `omarchy.network` (`Panel.qml` 2447 lines + `Model.js` +
`hotspot.sh`). Shows Wi-Fi list, current connection state, upload/download
speed, frequency band, and — the customization — **hotspot sharing via a
second Wi-Fi adapter** (USB dongle, `wlx*` or USB sysfs path detected
automatically; `WIFI_IFACE`/`WIFI_BAND` env overrides). `hotspot.sh` wraps
`nmcli` with `status | on <ssid> <pwd> | off | set <ssid> <pwd> | clients`
on subnet `10.42.0.0/24`. `Model.js` parses `nmcli` output into panel models
(connection kind, signal strength → Nerd Font wifi glyphs, speeds/freq
formatting). Uses NetworkManager — no systemd services.

## thinkfan — ThinkPad fan control

Bar-widget with per-profile fan control. `BarWidget.qml` shows live profile,
fan speeds (RPM) and temps; profile switching calls `pkexec
/usr/local/libexec/omarchy-thinkfan-profile <automatic|smart|full>` — a polkit
rule (`system/90-omarchy-thinkfan.rules`, installed by `setup-system`) makes
that **passwordless**. Profiles are written straight to the kernel interface
`/proc/acpi/ibm/fan` — no thinkfan package:

- `automatic` — `level auto`, hand control back to the EC/BIOS curve
- `smart` — spawns `omarchy-thinkfan-smart` (root daemon, temp-driven level
  every 4 s, sensors auto-detected via coretemp/x86_pkg_temp, log
  `/tmp/omarchy-thinkfan-smart.log`)
- `full` — `level disengaged` (max speed)

`fan-profile` is a status script (smart if the daemon pidfile + cmdline
checks pass). `setup-system` installs the libexec helpers + polkit rule;
`teardown-system` reverses. Requires `thinkpad_acpi fan_control=1`.

## abr.lock — the lock screen

`keepLoaded` service, runtime clone of stock `omarchy.lock` (then patched by
face.howdy's deploy-lock with the `howdyConfigured` marker — 11 refs in
`Service.qml`). Not a git repo: re-deploying face.howdy's lock recreates it,
but standalone edits are ephemeral. `Service.qml` drives **three PAM flows**
via `Quickshell.Services.Pam`: password, fingerprint, and howdy face unlock
(patched). `LockView.qml` is the UI (password field with dynamic dot
scaling/fingerprint reserve, error state borders via
`Border.surfaceSpec("lock", ...)`).

## Rules of thumb

1. Any QML edit → `omarchy restart shell` (never trust hot reload).
2. face.howdy/yt-music/netshare/thinkfan commits need the user's **"go
   ahead"** magic word, same as spice (SKILL.md rule 8).
3. **Snapshot before anything major or dangerous** — git tag it or
   `plugin-snapshot <id> <label>`; only `abr.lock` (+ configs when touched)
   needs file copies to `~/plugin-backups/` (it has no live worktree).
4. `~/.config/omarchy/shell.json` widget config is copied-from-spice
   territory (config.md rule 3): edit the repo copy
   (`config/omarchy/shell.json`) and re-run `install/config/omarchy.sh`
   (then `omarchy restart shell`) for repo-persistent changes.
5. `~/arr/README.md` contains secrets — keep it out of git forever.