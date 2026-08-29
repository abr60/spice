---
name: spice
description: >
  Spice is the user's personal dotfiles and system configuration toolkit for
  Arch Linux + Omarchy. Use when working with the spice repository at ~/spice
  (the source of truth; NOT the stale ~/Work/spice copy), running or debugging
  setup.sh / update.sh / install.sh, editing configs that are deployed from
  config/ into ~/.config (stow + omarchy.sh), using or modifying the custom
     bin/ scripts (comic-translate, dots-push, earbuds-status, hdd-status,
  hdd-unmount, media-download, mp4-to-gif, spotify-music-download,
  write-iso), managing Omarchy shell plugins/themes/hooks that live in the repo,
  editing hypr configs managed by spice, the opencode config at
  config/opencode/opencode.json, package lists (packages.txt), the system/
  dir, or the setup pipeline. Triggers: spice, dots-push, setup.sh, update.sh,
  install.sh, "my dotfiles", stow, packages.txt, custom theme, omarchy plugins,
  plugins.md, face.howdy, yt-music, omarr, netshare, thinkfan, abr.lock,
  hypr bindings in spice.
---

# Spice Skill

Manage the **Spice** project — the user's personal dotfiles and system
configuration toolkit layered on top of [Omarchy](https://omarchy.org/), an
Arch Linux distribution with Hyprland.

Spice is a git repo, remote at `git@github.com:abr60/spice.git`. On this
machine it lives at **`~/spice`** (`/home/abr/spice`). That is the **source of
truth**.

> 💡 **`~/.agents/skills/spice` is a SYMLINK to `~/spice/agents/skills/spice`**
> (installed there on Aug 20). When asked to edit this skill or its guides,
> edit the files at `/home/abr/spice/agents/skills/spice/` — never
> `~/.agents/skills/spice/` (same file, but the repo path is canonical and
> survives `update.sh`). The repo `agents/skills/` dir is listed in the
> MUST-USE triggers; the deployed copy is only a pointer.

> ⚠️ **`~/Work/spice` is a STALE COPY.** It is an old clone pointing at
> `git@github.com:drunk-particles/spice.git` and must NOT be treated as
> current. If the user asks about "spice", assume `~/spice` unless they
> explicitly say otherwise.

This skill is for working with and understanding the Spice repository and the
system state it manages. It is **not** for Omarchy end-user customization in
general — that is the `omarchy` skill's job. Use that skill when the request
is about the live `~/.config/` state; use this skill when the request is about
the Spice repo that provisions that state.

## When This Skill MUST Be Used

**ALWAYS invoke this skill when the request involves ANY of these:**

- Editing or understanding files inside the spice repository (`setup.sh`,
  `update.sh`, `install.sh`, `install/`, `config/`, `bin/`, `applications/`,
  `system/`, `CONTEXT.md`)
- Running, debugging, or extending `setup.sh`, `update.sh`, or `install.sh`
- Discussing how configs get from `config/` into `~/.config` (stow +
  `omarchy.sh`)
- Using, troubleshooting, or improving the custom scripts in `bin/`
- Editing Hyprland configs **as managed by spice** (the files in
  `config/hypr/`, not the live stowed copies)
- Managing Omarchy shell plugins, themes, or hooks **as stored in the repo**
- Package management via `install/packaging/` (`packages.txt`,
  `install-packages.sh`)
- The opencode agent config at `config/opencode/` (`opencode.json`, `tui.json`,
  `dcp.jsonc`, `smart-title.jsonc`, `plugin/vision-bridge.ts`)
- Editing the agent skills themselves (`agents/skills/spice/`)
- Working on **our** live-installed plugins — face.howdy, yt-music, omarr,
  netshare, thinkfan, abr.lock (see `plugins.md`)
- Editing `~/.config/omarchy/plugins/*` QML or bin scripts

**If you are about to touch a live config in `~/.config/`, that is the
`omarchy` skill's territory. If the request is about the repo that provisions
those configs, this is the `spice` skill's territory.**

## Critical Safety Rules

1. **`update.sh` is remote-first and destructive to local changes.** It runs
   `git fetch` then `git reset --hard <remote>` before re-applying install
   scripts. Any uncommitted local change in the repo is wiped. NEVER run it
   without warning the user and confirming they have no local changes they
   care about. Check `git -C ~/spice status` first.
2. **Config files are edited in the repo, not in `~/.config/`.** The `config/`
   directory is symlinked into `~/.config/` via stow (except `omarchy`,
   which is copied). Editing the live stowed target edits the repo file — that
   works, but changes must be committed in the repo to survive `update.sh`.
3. **`~/.config/omarchy` is NOT a stow symlink.** It is owned by Omarchy
   itself (it installs/manages themes and plugins there at runtime), so the
   whole directory can never be a symlink. Repo omarchy content is **copied**
   in by `install/config/omarchy.sh` (branding, hooks, plugins, themed,
   shell.json). Edits to `config/omarchy/**` in the repo must be re-pasted
   (re-run `omarchy.sh` or setup) to take effect live.
4. **Never edit files in `/usr/share/omarchy/`.** That is Omarchy package
   territory (see the `omarchy` skill). Spice overlays on top of it.
5. **Package lists use tags.** Lines in `packages.txt` marked
   `[tag:thinkfan]`, `[tag:easyeffects]`, `[tag:howdy]`, `[tag:Hyprpm]` are
   opt-in and only installed with `--tag <tag>`. Keep tagged packages tagged.
6. **Logs and state live in `~/.local/state/spice/`.** Setup logs:
   `~/.local/state/spice/logs/setup-*.log`. Package install logs:
   `~/.local/state/spice/logs/install-packages*.log`. Update report:
   `~/.local/state/spice/update-report.txt`.
7. **`config/opencode/` is the real opencode config** (stowed to
   `~/.config/opencode/`): `opencode.json` (agents, models, plugins),
   `tui.json`, `dcp.jsonc`, `smart-title.jsonc`, `plugin/vision-bridge.ts`,
   `package.json`. Changes need an opencode restart. See the
   `customize-opencode` skill before editing.
8. **NEVER commit or push without the magic word.** The user must explicitly
   say **"go ahead"** before ANY `git commit` or `git push` in this repo (or
   any repo). No exceptions, no interpretation — "go ahead" is the only
   permission. If the user asks for a commit/push without saying it, finish
   the work, show what would be committed, and wait for the exact phrase.
   This rule was added after an unsanctioned push (Aug 2026).
9. **After ANY plugin QML change, run `omarchy restart shell`.** Editing
   `~/.config/omarchy/plugins/*/Service.qml`, `BarWidget.qml`, `Panel.qml`
   etc. does NOT hot-reload. The shell's reload path dead-latches silently
   (local plugin watcher keeps firing reloads that never complete) — the OLD
   QML keeps running with ZERO errors, so it looks like nothing was deployed.
   This burned an entire day on face.howdy. After every edit: restart, then
   verify with `journalctl --user | grep -i quickshell` for real QML errors.
   See [`plugins.md`](plugins.md) for the plugin inventory and workflows.
10. **Snapshot before anything major or dangerous.** Before a redesign,
    core-logic refactor, privileged change (PAM/polkit/systemd/udev/pkexec),
    deletion/teardown, or multi-file plugin work, make a snapshot: use
    **`plugin-snapshot <id> <label>`** (`~/spice/bin/plugin-snapshot`, on
    PATH) or plain `git tag <id>-pre-<label>-$(date +%Y%m%d-%H%M%S)` for the
    git-backed plugins. It refuses on a dirty worktree, pushes the tag for
    abr60-owned remotes, copies `abr.lock` (git-less) to
    `~/plugin-backups/abr.lock/`, and supports `--config shell.json
    bindings.lua` for config bundles. Rollback paths are in
    [`plugins.md`](plugins.md) — "Snapshot & rollback".

## Project Structure

```
spice/                      # ~/spice — SOURCE OF TRUTH
├── setup.sh                # Interactive gum-based setup wizard
├── update.sh               # Remote-first update: reset --hard + re-apply scripts
├── install.sh              # Bootstrap installer (curl | bash entry point)
├── CONTEXT.md              # Session log: fixes, architecture notes, known issues
├── agents/                 # Agent skills (this skill, installed at ~/.agents/skills)
│   └── skills/spice/       #   SKILL.md, config.md, scripts.md, setup.md, plugins.md
├── applications/           # Desktop entries + icons
│   ├── cliamp.desktop
│   └── icons/
├── bin/                    # Custom user scripts (see scripts.md)
│   ├── lib/helpers.sh      # gum-based helpers (log_header, spinner, show_done, ...)
│   ├── comic-translate
│   ├── dots-push
│   ├── earbuds-status
│   ├── hdd-status
│   ├── hdd-unmount
│   ├── media-download
│   ├── mp4-to-gif
│   ├── spotify-music-download
│   └── write-iso
├── config/                 # Deployed to ~/.config/ (stow, omarchy = copy)
│   ├── hypr/               #   Hyprland config (hyprland.lua + requires)
│   ├── omarchy/            #   shell.json, plugins, hooks, themed, branding
│   ├── opencode/           #   opencode.json, tui.json, dcp.jsonc, smart-title.jsonc, plugin/
│   ├── calibre/ mpd/ rmpc/ sioyek/ uwsm/ yazi/ miscellaneous/
├── install/                # Installation pipeline (see setup.md)
│   ├── config/             #   stow.sh, omarchy.sh, applications.sh, fonts.sh, pam.sh, zsh.sh
│   ├── extras/             #   gpu-driver.sh, howdy.sh, thinkfan.sh, easyeffects.sh, waydroid.sh
│   ├── lib/                #   helpers.sh, spice.txt
│   ├── packaging/          #   install-packages.sh, packages.txt, webapps.sh
│   ├── services/           #   mpd-rmpc.sh
│   └── themes/             #   themes.sh, wallpapers.sh
└── system/                 # System-level configs (not stowed)
    ├── easyeffects/        #   presets (t14-dolby-*.json)
    └── thinkfan/           #   thinkfan.conf, hwmon fix service + script
```

## How Spice Relates to Omarchy

| Concern | Owned by |
|---------|----------|
| Base OS + packaged defaults | Omarchy (`/usr/share/omarchy/` — read-only) |
| Live user config | `~/.config/` (stowed/copied from spice `config/`) |
| `~/.config/omarchy/` runtime content | Omarchy itself (themes, plugins it installs) |
| Personal overlays, hooks, plugins, themed templates | Spice (`config/omarchy/`, copied via `omarchy.sh`) |
| Custom scripts and setup/update automation | Spice (`bin/`, `install/`) |
| System-level configs (not stowed) | Spice (`system/`) |

The rule of thumb: **Omarchy provides defaults; Spice provides the user's
personal layer.** When a config exists in both, the spice deploy wins.

## Quick Command Reference

```bash
bash ~/spice/install.sh                              # Bootstrap: clone/update + setup
bash ~/spice/setup.sh                                # Interactive setup wizard
bash ~/spice/update.sh                               # Fetch + reset --hard + re-apply scripts
bash ~/spice/install/packaging/install-packages.sh                       # untagged packages
bash ~/spice/install/packaging/install-packages.sh --tag thinkfan        # tagged opt-in packages
bash ~/spice/install/themes/themes.sh                                    # install community themes
FORCE=1 bash ~/spice/install/themes/themes.sh        # force-reinstall all themes
# Individual bin/ scripts — see scripts.md for full detail
comic-translate        dots-push               earbuds-status
hdd-status             hdd-unmount             media-download
mp4-to-gif             spotify-music-download  write-iso
```

## Topic Guides

Deeper instructions live next to this file. Read the matching guide before
starting:

- [`setup.md`](setup.md) — setup wizard, install pipeline, package
  management, stow + omarchy deploy, services, themes, extras, and update flow
- [`scripts.md`](scripts.md) — every custom script in `bin/`: purpose, usage,
  dependencies, and notable behavior
- [`config.md`](config.md) — config architecture: the Hyprland file chain,
  Omarchy shell layout, installed plugins, themed templates, hooks, opencode
  config, and system/
- [`plugins.md`](plugins.md) — **our** plugins (the ones we built/customized,
  vs the vendored ones in config.md): face.howdy, yt-music, omarr
  (Radarr+Sonarr), netshare, thinkfan, abr.lock — how each works, git
  remotes, the live-edit + `omarchy restart shell` workflow

## Example Requests

- "What does update.sh do to my local changes?" → Explain the
  `git reset --hard` behavior; check `git -C ~/spice status` first.
- "I want to add a keybinding for X" → Edit `config/hypr/bindings.lua`
  (see `config.md`).
- "How do I install only the Thinkpad fan packages?" → `install-packages.sh --tag thinkfan`.
- "The bar is missing my widget" → Check `config/omarchy/shell.json` layout
  and the plugin list in `config.md`; remember omarchy content is copied, not
  stowed — re-run `install/config/omarchy.sh`.
- "My theme colors are off after switching themes" → Check the hooks in
  `config/omarchy/hooks/theme-set.d/` (`update-yazi-theme`, `update-rmpc-theme`).
- "Is ~/Work/spice current?" → No. `~/spice` is the source of truth;
  `~/Work/spice` is a stale old clone.