#!/usr/bin/env bash
# =============================================================================
# install/themes/themes.sh — Install community Omarchy themes
#
# HOW TO ADD MORE THEMES:
#   1. Add the theme's git repo URL to the THEMES array below (one per line).
#   2. Re-run this script.
#
# Each theme is installed with omarchy's native `omarchy theme install`,
# which clones the repo to ~/.config/omarchy/themes/<name> and applies it.
# Already-installed themes are skipped; the previously active theme is
# restored afterwards so this script never hijacks your current look.
#
# To force-reinstall everything regardless of state:
#   FORCE=1 bash install/themes/themes.sh
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

# ─────────────────────────────────────────────────────────────────────────────
#  Community themes (add more URLs here)
# ─────────────────────────────────────────────────────────────────────────────
THEMES=(
    "https://github.com/HANCORE-linux/omarchy-whitegold-theme"
    "https://github.com/HANCORE-linux/omarchy-roseofdune-theme"
    "https://github.com/HANCORE-linux/omarchy-batou-theme"
    "https://github.com/HANCORE-linux/omarchy-thegreek-theme"
    "https://github.com/HANCORE-linux/omarchy-turbonite-theme"
    "https://github.com/HANCORE-linux/omarchy-harbor-theme"
    "https://github.com/HANCORE-linux/omarchy-inkypinky-theme"
)

command -v omarchy >/dev/null || die "omarchy CLI not found — is this an Omarchy system?"

CURRENT_THEME="$(omarchy theme current 2>/dev/null || true)"
section "Installing Community Themes"

theme_installed() {
    local url="$1" name
    name="$(basename "${url%/}")"
    name="${name#omarchy-}"
    name="${name%-theme}"
    omarchy theme list 2>/dev/null | grep -qi "^${name}$"
}

for url in "${THEMES[@]}"; do
    name="$(basename "${url%/}")"
    name="${name#omarchy-}"
    name="${name%-theme}"

    if [[ "${FORCE:-}" != "1" ]] && theme_installed "$url"; then
        ok "Theme '$name' already installed — skipping"
        continue
    fi

    msg "Installing theme: $name"
    if omarchy theme install "$url"; then
        ok "Installed: $name"
    else
        warn "Failed to install: $name — continuing"
    fi
done

# Restore the theme that was active before this script ran
if [[ -n "$CURRENT_THEME" ]] && [[ "$(omarchy theme current 2>/dev/null || true)" != "$CURRENT_THEME" ]]; then
    msg "Restoring previous theme: $CURRENT_THEME"
    omarchy theme set "$CURRENT_THEME" >/dev/null 2>&1 && ok "Theme restored" || \
        warn "Could not restore theme '$CURRENT_THEME' — apply it with: omarchy theme set"
fi

ok "All community themes installed"