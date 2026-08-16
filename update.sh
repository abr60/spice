#!/usr/bin/env bash
# =============================================================================
# Archer - Update Script
# Remote-first: always overwrites local with remote state.
# Usage: bash ~/Archer/update.sh
# =============================================================================

set -uo pipefail

DOTS_DIR="$HOME/Archer"
export ARCHER_DIR="$HOME/.local/share/Archer"
INSTALL_DIR="$DOTS_DIR/install"
WALLPAPERS_DIR="$HOME/Wallpapers"
REPORT_DIR="$HOME/.local/state/Archer"
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
LOGO_FILE="$INSTALL_DIR/lib/logo.txt"
[[ -f "$LOGO_FILE" ]] && cat "$LOGO_FILE" && echo ""

gum style \
    --foreground 117 --border-foreground 117 --border rounded \
    --align center --width 50 --padding "0 1" \
    "ARCHER UPDATE"
echo ""

# ==========================================
# 3. FETCH & CHECK
# ==========================================
msg "Fetching remote changes..."
cd "$DOTS_DIR"

git fetch origin 2>/dev/null || die "Could not reach remote — check your network."

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/HEAD 2>/dev/null || \
         git rev-parse origin/main 2>/dev/null || \
         git rev-parse origin/master 2>/dev/null)
LOCAL_SHORT="${LOCAL:0:7}"
REMOTE_SHORT="${REMOTE:0:7}"

{
    echo "=============================================="
    echo " ARCHER UPDATE REPORT"
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

export INSTALL_MODE="complete"

section "Re-applying Scripts"
run_step "packaging/packages-pacman"   "Syncing pacman packages"
run_step "packaging/packages-aur"      "Syncing AUR packages"
run_step "config/fonts.sh"             "Syncing fonts"
run_step "config/applications.sh"      "Syncing applications"
run_step "services/system-services.sh" "Syncing system services"
run_step "services/user-services.sh"   "Syncing user services"

# ==========================================
# 7. RE-STOW CONFIG SYMLINKS
# ==========================================
section "Re-applying Config Symlinks"
msg "Running stow --restow..."

STOW_OUTPUT=$(stow --restow --target="$HOME/.config" config 2>&1) || true

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

# ==========================================
# 8. WALLPAPERS SYNC
# ==========================================
section "Wallpapers"

if [[ -d "$WALLPAPERS_DIR/.git" ]]; then
    msg "Pulling latest wallpapers..."
    if git -C "$WALLPAPERS_DIR" fetch origin && \
       git -C "$WALLPAPERS_DIR" reset --hard origin/HEAD 2>/dev/null; then
        ok "Wallpapers updated"
        echo " WALLPAPERS: Updated" >> "$REPORT_FILE"
    else
        warn "Wallpapers update failed — keeping existing"
        echo " WALLPAPERS: Update failed" >> "$REPORT_FILE"
    fi
else
    msg "Wallpapers not cloned on this machine — skipping"
    echo " WALLPAPERS: Not cloned — skipped" >> "$REPORT_FILE"
fi

# ==========================================
# 9. RELOAD
# ==========================================
run_step "services/reload.sh" "Reloading UI"

# ==========================================
# 10. DONE
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
