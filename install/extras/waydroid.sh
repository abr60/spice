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

# ─── System-python wrapper ────────────────────────────────────────────────────
# /usr/bin/waydroid starts with '#!/usr/bin/env python3'. When a mise/uv/conda
# python sits earlier in PATH it wins over Arch's /usr/bin/python3 (3.14), which
# is the only one with python-dbus installed, so waydroid dies with:
#   ModuleNotFoundError: No module named 'dbus'
# /usr/local/bin comes before /usr/bin in PATH and pacman never overwrites it,
# so this pins waydroid to the system interpreter for good.
WRAPPER="/usr/local/bin/waydroid"
WRAPPER_BODY='#!/bin/sh
# Managed by spice (install/extras/waydroid.sh) — do not edit.
# /usr/bin/waydroid uses "#!/usr/bin/env python3", which can resolve to a
# mise/uv/conda python without python-dbus. Force Arch system python.
exec /usr/bin/python3 /usr/bin/waydroid "$@"'

if [[ -x "$WRAPPER" ]] && [[ "$(cat "$WRAPPER")" == "$WRAPPER_BODY" ]]; then
    ok "waydroid system-python wrapper already installed"
else
    printf '%s\n' "$WRAPPER_BODY" | sudo tee "$WRAPPER" >/dev/null
    sudo chmod 0755 "$WRAPPER"
    ok "waydroid system-python wrapper installed ($WRAPPER)"
fi

# ─── virt_wifi kernel module ──────────────────────────────────────────────────
# Waydroid's Android side expects the virt_wifi module to exist at boot. Without
# it wificond logs "Can't get wlan0 index: No such device", WifiService stays
# disabled, and netd never brings up the default network — the container gets an
# IP but no default route, so every app reports "no internet".
# (Note: even with the module loaded, this kernel/packaging has no working wifi
# HAL — Android uses an emulated *Ethernet* network. That is fine: internet works,
# the Wifi toggle stays grey by design.)
MODULES_CONF="/etc/modules-load.d/waydroid.conf"
if ! lsmod | grep -q '^virt_wifi'; then
    sudo modprobe virt_wifi
    ok "virt_wifi module loaded"
else
    ok "virt_wifi module already loaded"
fi

if [[ -f "$MODULES_CONF" ]] && grep -qx 'virt_wifi' "$MODULES_CONF"; then
    ok "virt_wifi persistence already configured ($MODULES_CONF)"
else
    echo 'virt_wifi' | sudo tee "$MODULES_CONF" >/dev/null
    ok "virt_wifi will be loaded at boot ($MODULES_CONF)"
fi

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
