#!/usr/bin/env bash
# =============================================================================
# config/fonts.sh — Install custom fonts
# Copies fonts from spice/fonts/ to ~/.local/share/fonts
# Rebuilds font cache and sets system monospace font
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

section "Fonts"

SPICE_DIR="${SPICE_DIR:-$HOME/spice}"
FONT_SOURCE="$SPICE_DIR/fonts"
FONT_DEST="$HOME/.local/share/fonts"

if [[ ! -d "$FONT_SOURCE" ]]; then
    warn "Font source not found at $FONT_SOURCE — skipping"
    exit 0
fi

mkdir -p "$FONT_DEST"

msg "Copying fonts to $FONT_DEST..."
cp -rf "$FONT_SOURCE"/. "$FONT_DEST/"
ok "Fonts copied"

# Rebuild font cache
fc-cache -f && ok "Font cache updated"

# Set JetBrains Mono NF as system monospace font via gsettings
if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface monospace-font-name \
        'JetBrainsMono Nerd Font Mono 11' 2>/dev/null && \
        ok "System monospace font set to JetBrainsMono Nerd Font Mono 11" || \
        warn "Could not set system monospace font via gsettings"
fi

ok "Font installation complete"
