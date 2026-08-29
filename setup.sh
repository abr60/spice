#!/usr/bin/env bash
# =============================================================================
# spice - Unified Setup Script
# https://github.com/abr60/spice.git
# Usage: bash ~/spice/setup.sh
# =============================================================================

set -uo pipefail

SPICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$SPICE_DIR/install"
LOG_DIR="$HOME/.local/state/spice/logs"
LOG_FILE="$LOG_DIR/setup-$(date '+%Y%m%d-%H%M%S').log"
STATE_DIR="$HOME/.local/state/spice/setup"

mkdir -p "$LOG_DIR" "$STATE_DIR"

source "$INSTALL_DIR/lib/helpers.sh"

# =============================================================================
# LOGGING (borrowed from Omarchy)
# =============================================================================

log_line() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

run_logged() {
    local script="$1"
    local label="$2"
    local full_path="$INSTALL_DIR/$script"

    log_line "Starting: $label"

    if [[ ! -f "$full_path" ]]; then
        log_line "SKIPPED: $label — script not found ($full_path)"
        warn "$label — script not found, skipping"
        return
    fi

    chmod +x "$full_path"

    if bash "$full_path" 2>&1 | tee -a "$LOG_FILE"; then
        log_line "Completed: $label"
        ok "$label done"
    else
        log_line "Failed: $label"
        warn "$label had errors — check $LOG_FILE"
    fi
}

# =============================================================================
# SPLASH
# =============================================================================
clear
[[ -f "$INSTALL_DIR/lib/spice.txt" ]] && cat "$INSTALL_DIR/lib/spice.txt" && echo ""

gum style \
    --foreground 117 --border-foreground 117 --border rounded \
    --align center --width 50 --padding "0 1" \
    "SPICE SETUP" \
    "github.com/abr60/spice"

echo ""

# =============================================================================
# MULTI-SELECT
# =============================================================================
ITEMS=(
    "Packages	Install all packages from packages.txt"
    "Configs	Symlink config/ → ~/.config via Stow"
    "Plugins	Install enabled Omarchy shell plugins from shell.json"
    "Applications	Set up desktop applications"
    "MPD + RMPC	Enable and start MPD + mpd-mpris (rmpc backend)"
    "Themes	Install community Omarchy themes"
    "Fonts	Install fonts"
    "Zsh	Set up Zsh shell"
    "GPU Drivers	Install drivers for your hardware"
    "MPV Config	Clone abr60/mpv-config to ~/.config/mpv"
    "Thinkfan	Fan curve control (ThinkPad)"
    "EasyEffects	Audio presets and plugins"
    "Waydroid	Android container"
    "Wallpapers	Clone wallpapers to ~/Wallpapers"
)

echo ""
SELECTED=$(printf '%s\n' "${ITEMS[@]}" | gum choose \
    --no-limit \
    --header "  space to toggle  ·  enter to confirm" \
    --height 20)

if [[ -z "$SELECTED" ]]; then
    msg "Nothing selected — exiting."
    exit 0
fi

# =============================================================================
# SUMMARY
# =============================================================================
clear
[[ -f "$INSTALL_DIR/lib/spice.txt" ]] && cat "$INSTALL_DIR/lib/spice.txt" && echo ""

gum style --foreground 117 --padding "0 0 0 2" "  Selected steps:"
echo ""
echo "$SELECTED" | while IFS=$'\t' read -r name desc; do
    gum style --foreground 245 "    • $name — $desc"
done

echo ""
gum confirm "Run it?" || { msg "Aborted."; exit 0; }

# =============================================================================
# EXECUTE
# =============================================================================
clear
[[ -f "$INSTALL_DIR/lib/spice.txt" ]] && cat "$INSTALL_DIR/lib/spice.txt" && echo ""

TOTAL=$(echo "$SELECTED" | wc -l)
STEP=0
START_TIME=$(date +%s)
NEEDS_REBOOT=false

log_line "=== Spice Setup Started ==="
log_line "Selected: $(echo "$SELECTED" | awk -F'\t' '{print $1}' | tr '\n' ' ')"

step_header() {
    (( STEP++ ))
    echo ""
    gum style --foreground 117 --padding "0 0 0 2" \
        "  [$STEP/$TOTAL] $1"
    log_line "--- $1 ---"
}

grep -q "^Packages"     <<< "$SELECTED" && {
    step_header "Packages"
    run_logged "packaging/install-packages.sh" "Packages"
}

grep -q "^Configs"      <<< "$SELECTED" && {
    step_header "Configs"
    run_logged "config/stow.sh" "Configs"
}

grep -q "^Plugins"      <<< "$SELECTED" && {
    step_header "Plugins"
    # shell.json is pasted by the Configs step above — Plugins reads it.
    run_logged "extras/plugins.sh" "Plugins"
}

grep -q "^Applications" <<< "$SELECTED" && {
    step_header "Applications"
    run_logged "config/applications.sh" "Applications"
}

grep -q "^MPD + RMPC"  <<< "$SELECTED" && {
    step_header "MPD + RMPC"
    run_logged "services/mpd-rmpc.sh" "MPD + RMPC"
}

grep -q "^Themes"      <<< "$SELECTED" && {
    step_header "Themes"
    run_logged "themes/themes.sh" "Themes"
}

grep -q "^Fonts"        <<< "$SELECTED" && {
    step_header "Fonts"
    run_logged "config/fonts.sh" "Fonts"
}

grep -q "^Zsh"          <<< "$SELECTED" && {
    step_header "Zsh"
    run_logged "config/zsh.sh" "Zsh"
}

grep -q "^GPU Drivers"  <<< "$SELECTED" && {
    step_header "GPU Drivers"
    run_logged "extras/gpu-driver.sh" "GPU Drivers"
    NEEDS_REBOOT=true
}

grep -q "^MPV Config"   <<< "$SELECTED" && {
    step_header "MPV Config"
    run_logged "extras/mpv.sh" "MPV Config"
}

grep -q "^Thinkfan"     <<< "$SELECTED" && {
    step_header "Thinkfan"
    run_logged "extras/thinkfan.sh" "Thinkfan"
}

grep -q "^EasyEffects"  <<< "$SELECTED" && {
    step_header "EasyEffects"
    run_logged "extras/easyeffects.sh" "EasyEffects"
}

grep -q "^Waydroid"     <<< "$SELECTED" && {
    step_header "Waydroid"
    run_logged "extras/waydroid.sh" "Waydroid"
    NEEDS_REBOOT=true
}

grep -q "^Wallpapers"   <<< "$SELECTED" && {
    step_header "Wallpapers"
    run_logged "themes/wallpapers.sh" "Wallpapers"
}

# =============================================================================
# DONE
# =============================================================================
END_TIME=$(date +%s)
DURATION=$(( END_TIME - START_TIME ))
MINS=$(( DURATION / 60 ))
SECS=$(( DURATION % 60 ))

log_line "=== Spice Setup Completed in ${MINS}m ${SECS}s ==="

echo ""
gum style \
    --foreground 82 --border-foreground 82 --border rounded \
    --align center --width 50 --padding "1 2" \
    "✓ SETUP COMPLETE" \
    "Finished in ${MINS}m $(printf "%02d" "$SECS")s"

echo ""
gum style --foreground 245 --padding "0 0 0 2" \
    "  Log saved to: $LOG_FILE" \
    "  Re-run anytime: bash ~/spice/setup.sh"

if [[ "$NEEDS_REBOOT" == true ]]; then
    echo ""
    gum style --foreground 214 --padding "0 0 0 2" \
        "  ↻  Reboot recommended to apply GPU/Waydroid changes."
    echo ""
    gum confirm "Reboot now?" && sudo reboot || msg "Reboot skipped."
fi

echo ""
