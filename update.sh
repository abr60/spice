#!/usr/bin/env bash
# =============================================================================
# spice - Update Script
# Remote-first: always overwrites local with remote state.
# Usage: bash ~/spice/update.sh
# =============================================================================

set -uo pipefail

SPICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$SPICE_DIR/install"
REPORT_DIR="$HOME/.local/state/spice"
REPORT_FILE="$REPORT_DIR/update-report.txt"

source "$INSTALL_DIR/lib/helpers.sh"

mkdir -p "$REPORT_DIR"
START_TIME=$SECONDS

# ==========================================
# 1. DEPENDENCY CHECK
# ==========================================
ensure_installed gum

# ==========================================
# 2. SHOW HEADER
# ==========================================
clear
LOGO_FILE="$INSTALL_DIR/lib/spice.txt"
[[ -f "$LOGO_FILE" ]] && cat "$LOGO_FILE" && echo ""

gum style \
    --foreground 117 --border-foreground 117 --border rounded \
    --align center --width 50 --padding "0 1" \
    "SPICE UPDATE"
echo ""

# ==========================================
# 3. FETCH & CHECK
# ==========================================
msg "Fetching remote changes..."
cd "$SPICE_DIR"

git fetch origin 2>/dev/null || die "Could not reach remote — check your network."

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/HEAD 2>/dev/null || \
         git rev-parse origin/main 2>/dev/null || \
         git rev-parse origin/master 2>/dev/null)
LOCAL_SHORT="${LOCAL:0:7}"
REMOTE_SHORT="${REMOTE:0:7}"

{
    echo "=============================================="
    echo " SPICE UPDATE REPORT"
    echo "=============================================="
    echo " Date     : $(date '+%Y-%m-%d %H:%M:%S')"
    echo " Hostname : $(cat /etc/hostname)"
    echo " Kernel   : $(uname -r)"
    echo " Local    : $LOCAL_SHORT"
    echo " Remote   : $REMOTE_SHORT"
    echo "=============================================="
} > "$REPORT_FILE"

if [[ "$LOCAL" == "$REMOTE" ]]; then
    ok "Already up to date ($LOCAL_SHORT). Nothing to do."
    echo " Status : Already up to date — no changes applied." >> "$REPORT_FILE"
    exit 0
fi

# ==========================================
# 4. SHOW DIFF SUMMARY
# ==========================================
section "Incoming Changes"
echo ""
git log HEAD..origin/HEAD --oneline --no-decorate 2>/dev/null || true

echo ""
CHANGED_FILES=$(git diff --name-only HEAD...origin/HEAD 2>/dev/null | head -20 || true)
if [[ -n "$CHANGED_FILES" ]]; then
    msg "Files that will change:"
    echo "$CHANGED_FILES" | while read -r f; do
        echo -e "  ${CYAN}~${NC} $f"
    done
fi

{
    echo ""
    echo " INCOMING CHANGES"
    git log HEAD..origin/HEAD --oneline --no-decorate 2>/dev/null || true
    echo ""
    echo " Files changed:"
    git diff --name-only HEAD...origin/HEAD 2>/dev/null | sed 's/^/   ~ /' || true
} >> "$REPORT_FILE"

# ==========================================
# 5. RESET & PULL
# ==========================================
echo ""
msg "Applying remote state (overwriting local)..."
OLD_COMMIT="$LOCAL"

git reset --hard "$REMOTE" || die "git reset --hard failed."
ok "Reset to remote state ($LOCAL_SHORT → $REMOTE_SHORT)"

{
    echo ""
    echo " RESET: $OLD_COMMIT → $REMOTE — Success"
} >> "$REPORT_FILE"

# ==========================================
# 6. RE-APPLY SCRIPTS
# ==========================================
run_step() {
    local script="$1"
    local label="$2"
    local full_path="$INSTALL_DIR/$script"

    echo ""
    msg "$label"

    if [[ ! -f "$full_path" ]]; then
        warn "$script not found — skipping"
        echo " SKIPPED: $label" >> "$REPORT_FILE"
        return
    fi

    chmod +x "$full_path"

    if bash "$full_path"; then
        ok "$label done"
        echo " OK: $label" >> "$REPORT_FILE"
    else
        warn "$label had errors — continuing"
        echo " WARN: $label had errors" >> "$REPORT_FILE"
    fi
}

section "Re-applying Scripts"
run_step "packaging/install-packages.sh"   "Syncing packages"
run_step "config/fonts.sh"            "Syncing fonts"
run_step "config/applications.sh"     "Syncing applications"
run_step "services/mpd-rmpc.sh"   "Syncing MPD/RMPC"
run_step "extras/wallpapers.sh"       "Syncing wallpapers"

# ==========================================
# 7. RE-STOW CONFIG SYMLINKS
# ==========================================
section "Re-applying Config Symlinks"
msg "Running stow --restow (omarchy excluded)..."

STOW_OUTPUT=$(stow --restow --target="$HOME/.config" --ignore='^omarchy$' config 2>&1) || true

if echo "$STOW_OUTPUT" | grep -qi "conflict\|error\|cannot"; then
    warn "Stow conflicts detected:"
    echo "$STOW_OUTPUT" | grep -i "conflict\|error\|cannot" | while read -r line; do
        warn "  $line"
    done
    echo " STOW: Conflicts detected — resolve manually" >> "$REPORT_FILE"
else
    ok "Config symlinks refreshed"
    echo " STOW: Config symlinks refreshed" >> "$REPORT_FILE"
fi

bash "$INSTALL_DIR/config/omarchy.sh"
echo " OMARCHY: content synced" >> "$REPORT_FILE"

# ==========================================
# 8. RELOAD
# ==========================================
section "Reloading UI"
if command -v hyprctl &>/dev/null; then
    hyprctl reload && ok "Hyprland reloaded" || warn "Hyprland reload failed"
fi
if command -v qs &>/dev/null; then
    qs -c reload && ok "Quickshell reloaded" || warn "Quickshell reload failed"
fi
echo " RELOAD: UI reloaded" >> "$REPORT_FILE"

# ==========================================
# 9. DONE
# ==========================================
DURATION=$(( SECONDS - START_TIME ))

{
    echo ""
    echo "=============================================="
    echo " SUMMARY"
    echo "=============================================="
    echo " Total duration : ${DURATION}s"
    echo " Rolled forward : $LOCAL_SHORT → $REMOTE_SHORT"
    echo "=============================================="
} >> "$REPORT_FILE"

echo ""
gum style \
    --foreground 82 --border-foreground 82 --border rounded \
    --align center --width 50 --padding "1 2" \
    "✓ UPDATE COMPLETE" \
    "$LOCAL_SHORT → $REMOTE_SHORT — ${DURATION}s"

echo ""
msg "Report saved to: $REPORT_FILE"