#!/usr/bin/env bash
# =============================================================================
# install/config/omarchy.sh — Paste repo omarchy content into ~/.config/omarchy
#
# ~/.config/omarchy is owned by Omarchy itself: it installs and manages
# themes (and plugins) in that directory at runtime, so the whole folder is
# NEVER symlinked from the repo. Instead only the content we manage is copied
# in — branding, hooks, plugins, themed, shell.json — leaving everything else
# (like themes/) untouched.
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

SPICE_REAL="$(realpath "$HOME/spice")"
OMARCHY_SRC="$SPICE_REAL/config/omarchy"
OMARCHY_DEST="$HOME/.config/omarchy"

section "Omarchy Content"

[[ ! -d "$OMARCHY_SRC" ]] && die "$OMARCHY_SRC not found — cannot continue"

ensure_dir "$OMARCHY_DEST"

for item in branding hooks plugins themed shell.json; do
    src="$OMARCHY_SRC/$item"
    if [[ ! -e "$src" ]]; then
        warn "Repo omarchy/$item missing — skipping"
        continue
    fi
    if [[ -d "$src" ]]; then
        cp -rf "$src/." "$OMARCHY_DEST/$item"
    else
        cp -f "$src" "$OMARCHY_DEST/$item"
    fi
    ok "Pasted: $item"
done

ok "Omarchy content synced"