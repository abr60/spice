#!/usr/bin/env bash
# =============================================================================
# extras/waydroid.sh — Configure Waydroid UFW rules and Hyprland integration
# Only runs if waydroid is installed
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

section "Waydroid"

if ! command -v waydroid &>/dev/null; then
    warn "Waydroid not installed — skipping"
    exit 0
fi

ok "Waydroid detected"

# ─── UFW rules ────────────────────────────────────────────────────────────────
if is_installed ufw; then
    if ! sudo ufw status | grep -q "Status: active"; then
        sudo ufw --force enable
    fi
    sudo ufw allow 53
    sudo ufw allow 67
    sudo ufw default allow FORWARD
    sudo ufw reload
    ok "Waydroid UFW rules applied"
fi

# ─── Hyprland window rule ─────────────────────────────────────────────────────
HYPR_RULES="$HOME/.config/hypr/rules.conf"
HYPR_RULE="windowrule = fullscreen on, match:class ^(Waydroid)$"

if [[ -f "$HYPR_RULES" ]] && grep -qF "$HYPR_RULE" "$HYPR_RULES"; then
    ok "Hyprland Waydroid rule already present"
elif [[ -f "$HYPR_RULES" ]]; then
    echo "$HYPR_RULE" >> "$HYPR_RULES"
    ok "Hyprland Waydroid window rule added"
fi

# ─── Zsh hide_waydroid function ───────────────────────────────────────────────
SPICE_DIR="${SPICE_DIR:-$HOME/spice}"
ZSH_FUNCTIONS="$SPICE_DIR/zshrc/functions"
FUNC_MARKER="hide_waydroid()"

if [[ -f "$ZSH_FUNCTIONS" ]] && grep -qF "$FUNC_MARKER" "$ZSH_FUNCTIONS"; then
    ok "hide_waydroid function already present"
else
    cat >> "$ZSH_FUNCTIONS" << 'EOF'

# Waydroid — hide app icons from launcher
hide_waydroid() {
    find "$HOME/.local/share/applications" -name "waydroid.*.desktop" \
        -exec grep -L "NoDisplay=true" {} + | \
        xargs -I {} sed -i "/\[Desktop Entry\]/a NoDisplay=true" {} 2>/dev/null
}
EOF
    ok "hide_waydroid function added to zshrc/functions"
fi

# ─── Zsh init call ────────────────────────────────────────────────────────────
ZSH_INIT="$SPICE_DIR/zshrc/init"
INIT_MARKER="hide_waydroid >/dev/null 2>&1"

if [[ -f "$ZSH_INIT" ]] && grep -qF "$INIT_MARKER" "$ZSH_INIT"; then
    ok "hide_waydroid init call already present"
else
    echo "" >> "$ZSH_INIT"
    echo "hide_waydroid >/dev/null 2>&1 &!" >> "$ZSH_INIT"
    ok "hide_waydroid init call added to zshrc/init"
fi

ok "Waydroid setup complete"
