#!/usr/bin/env bash
# =============================================================================
# config/applications.sh
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

section "Applications"

ARCHER_DIR="${ARCHER_DIR:-$HOME/Archer}"

SRC="$ARCHER_DIR/applications"
DEST="$HOME/.local/share/applications"

BIN_SOURCE="$ARCHER_DIR/bin/batty"
BIN_DEST="$HOME/.cargo/bin"

# ─── batty binary ─────────────────────────────────────────────────────────────

if [[ -f "$BIN_SOURCE" ]]; then
    mkdir -p "$BIN_DEST"
    cp -f "$BIN_SOURCE" "$BIN_DEST/"
    chmod +x "$BIN_DEST/batty"
    ok "batty installed to $BIN_DEST"
else
    warn "batty binary not found at $BIN_SOURCE — skipping"
fi

# ─── Applications ─────────────────────────────────────────────────────────────

if [[ ! -d "$SRC" ]]; then
    warn "Applications directory not found: $SRC"
    exit 0
fi

mkdir -p "$DEST"

# Copy everything exactly as-is
cp -a "$SRC"/. "$DEST"/
ok "Copied Archer applications"

# Remove any top-level desktop files that also exist in hidden/
HIDDEN_DIR="$DEST/hidden"

if [[ -d "$HIDDEN_DIR" ]]; then
    while IFS= read -r -d '' hidden_file; do
        name="$(basename "$hidden_file")"
        target="$DEST/$name"

        if [[ -f "$target" ]]; then
            rm -f "$target"
            ok "Removed hidden application: $name"
        fi
    done < <(find "$HIDDEN_DIR" -type f -name '*.desktop' -print0)
fi

# ─── Update caches ────────────────────────────────────────────────────────────

update-desktop-database "$DEST" 2>/dev/null \
    && ok "Desktop database updated" \
    || true