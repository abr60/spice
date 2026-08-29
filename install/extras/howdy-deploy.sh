#!/usr/bin/env bash
# =============================================================================
# extras/howdy-deploy.sh — Deploy Howdy omarchy commands
#
# Copies howdy-setup.sh / howdy-remove.sh into /usr/share/omarchy/bin/ so
# they appear as native omarchy commands:
#   omarchy setup security howdy   → howdy-setup.sh
#   omarchy remove security howdy  → howdy-remove.sh
#
# Called by setup.sh (Howdy step) and re-applied on omarchy updates.
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

section "Deploy Howdy Omarchy Commands"

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="/usr/bin"
OMARCHY_BIN_DIR="/usr/share/omarchy/bin"

SETUP_SRC="$SRC_DIR/howdy-setup.sh"
REMOVE_SRC="$SRC_DIR/howdy-remove.sh"
SETUP_DEST="$BIN_DIR/omarchy-setup-security-howdy"
REMOVE_DEST="$BIN_DIR/omarchy-remove-security-howdy"
LINK_SETUP="$OMARCHY_BIN_DIR/omarchy-setup-security-howdy"
LINK_REMOVE="$OMARCHY_BIN_DIR/omarchy-remove-security-howdy"

if [[ ! -f "$SETUP_SRC" ]]; then
  err "Source not found: $SETUP_SRC"
  exit 1
fi
if [[ ! -f "$REMOVE_SRC" ]]; then
  err "Source not found: $REMOVE_SRC"
  exit 1
fi

msg "Deploying Howdy commands to $BIN_DIR + $OMARCHY_BIN_DIR ..."

sudo cp "$SETUP_SRC" "$SETUP_DEST"
sudo cp "$REMOVE_SRC" "$REMOVE_DEST"
sudo chmod +x "$SETUP_DEST" "$REMOVE_DEST"

# Ensure omarchy bin symlinks (omarchy CLI scans OMARCHY_BIN_DIR)
sudo ln -sf "$SETUP_DEST" "$LINK_SETUP"
sudo ln -sf "$REMOVE_DEST" "$LINK_REMOVE"

ok "Deployed: omarchy setup security howdy  → $SETUP_DEST (→ $LINK_SETUP)"
ok "Deployed: omarchy remove security howdy → $REMOVE_DEST (→ $LINK_REMOVE)"

# Verify they are discoverable
if command -v omarchy &>/dev/null; then
  if omarchy commands 2>/dev/null | grep -q "howdy"; then
    ok "Verified: omarchy commands lists howdy"
  else
    warn "omarchy commands does not list howdy yet — try: omarchy setup security howdy --help"
  fi
fi
