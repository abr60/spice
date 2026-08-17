#!/usr/bin/env bash
# =============================================================================
# config/applications.sh
# =============================================================================

set -euo pipefail

# Path Definitions
SPICE_DIR="${SPICE_DIR:-$HOME/spice}"
APP_SRC="$SPICE_DIR/applications"
ICON_SRC="$APP_SRC/icons"

APP_DEST="$HOME/.local/share/applications"
ICON_DEST="$HOME/.local/share/icons/hicolor/256x256/apps"

WEBAPPS_SCRIPT="$SPICE_DIR/install/packaging/webapps.sh"

# ─── 1. Copy Icons ────────────────────────────────────────────────────────────

if [[ -d "$ICON_SRC" ]]; then
    mkdir -p "$ICON_DEST"
    # Copy all .png files directly into hicolor/256x256/apps
    cp -f "$ICON_SRC"/*.png "$ICON_DEST/" 2>/dev/null || true
    echo "Synced webapp icons to $ICON_DEST"
else
    echo "Warning: Icon directory not found at $ICON_SRC"
fi

# ─── 2. Copy Applications ─────────────────────────────────────────────────────

if [[ -d "$APP_SRC" ]]; then
    mkdir -p "$APP_DEST"
    
    # Copy desktop files into .local/share/applications
    find "$APP_SRC" -maxdepth 1 -type f -name "*.desktop" -exec cp -f {} "$APP_DEST/" \;
    echo "Synced .desktop files to $APP_DEST"
else
    echo "Warning: Applications directory not found at $APP_SRC"
    exit 0
fi

# ─── 3. Run Webapps Installation Script ────────────────────────────────────────

if [[ -x "$WEBAPPS_SCRIPT" ]]; then
    echo "Executing webapps installer..."
    "$WEBAPPS_SCRIPT"
elif [[ -f "$WEBAPPS_SCRIPT" ]]; then
    echo "Executing webapps installer via bash..."
    bash "$WEBAPPS_SCRIPT"
else
    echo "Warning: Webapps installer script not found at $WEBAPPS_SCRIPT"
fi

echo "Application and icon sync complete!"