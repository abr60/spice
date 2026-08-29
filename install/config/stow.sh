#!/usr/bin/env bash
# =============================================================================
# install/config/stow.sh — Symlink config/ → ~/.config
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

section "Config Symlinks"

SPICE_REAL="$(realpath "$HOME/spice")"
CONFIG_SRC="$SPICE_REAL/config"
CONFIG_DEST="$HOME/.config"

ensure_installed stow

[[ ! -d "$CONFIG_SRC" ]] && die "$CONFIG_SRC not found — cannot continue"

# =============================================================================
# 1. WIPE EXISTING TARGETS — then stow everything
# =============================================================================
# NOTE: omarchy is intentionally NOT stowed — ~/.config/omarchy is owned by
# Omarchy (it installs/manages themes at runtime), so the whole dir can't be a
# symlink. Its content is handled separately below via omarchy.sh.
STOW_DIRS=(
    calibre
    hypr
    mpd
    npm
    rmpc
    sioyek
    uwsm
    yazi
)

msg "Clearing existing config targets..."
for dir in "${STOW_DIRS[@]}"; do
    target="$CONFIG_DEST/$dir"
    if [[ -e "$target" || -L "$target" ]]; then
        rm -rf "$target"
        ok "Cleared: $target"
    fi
done

cd "$SPICE_REAL"
stow --target="$CONFIG_DEST" --ignore='^omarchy$' --ignore='^opencode$' --verbose=1 config
ok "Stow complete"

# =============================================================================
# 2. PASTE OMARCHY CONTENT (never symlink the whole dir)
# =============================================================================
bash "$(dirname "${BASH_SOURCE[0]}")/omarchy.sh"

# =============================================================================
# 3. REGENERATE THEME-DERIVED LINKS
# =============================================================================
# yazi/theme.toml is a symlink to the active omarchy theme and is gitignored.
# Regenerate it from the theme-set hook if present.
section "Regenerating theme-derived config"

YAZI_HOOK="$CONFIG_DEST/omarchy/hooks/theme-set.d/update-yazi-theme"
if [[ -x "$YAZI_HOOK" ]]; then
    if bash "$YAZI_HOOK"; then
        ok "Yazi theme regenerated"
    else
        warn "Yazi theme regeneration failed — apply a theme with 'omarchy theme set'"
    fi
else
    warn "Yazi theme hook not found — apply a theme with 'omarchy theme set'"
fi

RMPC_HOOK="$CONFIG_DEST/omarchy/hooks/theme-set.d/update-rmpc-theme"
if [[ -x "$RMPC_HOOK" ]]; then
    if bash "$RMPC_HOOK"; then
        ok "RMPC theme regenerated"
    else
        warn "RMPC theme regeneration failed — apply a theme with 'omarchy theme set'"
    fi
else
    warn "RMPC theme hook not found — apply a theme with 'omarchy theme set'"
fi

# =============================================================================
# 4. RELOAD
# =============================================================================
section "Reloading"

hyprctl reload && ok "Hyprland reloaded" || warn "Hyprland reload failed"
qs -c reload && ok "Quickshell reloaded" || warn "Quickshell reload failed"