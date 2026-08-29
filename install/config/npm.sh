#!/usr/bin/env bash
# =============================================================================
# install/config/npm.sh — Harmonize npm globals with Omarchy
# Omarchy expects user binaries in ~/.local/bin (already in bar's PATH).
# mise's node puts `npm install -g` bins in .../mise/installs/node/.../bin
# which the bar (quickshell) never sees. Fix: point npm prefix to ~/.local
# so `td` and other globals land where Omarchy looks.
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

section "NPM — Omarchy harmony"

# Ensure npm global prefix is ~/.local (bar-visible)
if command -v npm &>/dev/null; then
    npm config set prefix "$HOME/.local" --location=user 2>/dev/null || true
    npm config set allow-scripts=@doist/todoist-cli --location=user 2>/dev/null || true
    ok "npm prefix → ~/.local (was $(npm config get prefix 2>/dev/null))"
else
    warn "npm not found — skipping prefix fix"
fi

# Migrate any existing mise-installed td that is invisible to bar
MISE_TD="$HOME/.local/share/mise/installs/node/26.7.0/bin/td"
LOCAL_TD="$HOME/.local/bin/td"
if [[ -f "$MISE_TD" && ! -e "$LOCAL_TD" ]]; then
    ln -sf "$MISE_TD" "$LOCAL_TD"
    ok "Migrated td → ~/.local/bin/td"
fi

# Ensure future stowed npmrc is applied (stow.sh will handle linking on next run)
ok "NPM harmony done"
