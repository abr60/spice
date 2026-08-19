#!/usr/bin/env bash
# =============================================================================
# spice - Package Installer
# Usage:
#   bash install-packages            # installs untagged packages (packages.txt)
#   bash install-packages --tag <tag>  # installs only lines tagged [tag:<tag>]
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAG=""

# Parse --tag argument (may be $1 or $2 for backwards compatibility)
for arg in "$@"; do
    if [[ "$arg" == "--tag" ]]; then
        TAG_FLAG=true
        continue
    fi
    [[ "${TAG_FLAG:-}" == true ]] && { TAG="$arg"; break; }
done

LOG_DIR="$HOME/.local/state/spice/logs"
LOG_FILE="$LOG_DIR/install-packages${TAG:+-$TAG}.log"

mkdir -p "$LOG_DIR"

source "$(dirname "$SCRIPT_DIR")/lib/helpers.sh"

# =============================================================================
# Select package list
# =============================================================================
PKG_LIST="$SCRIPT_DIR/packages.txt"
LIST_LABEL="PACKAGES${TAG:+ [tag:$TAG]}"

if [[ ! -f "$PKG_LIST" ]]; then
    die "Package list not found: $PKG_LIST"
fi

# =============================================================================
# Parse package list
# =============================================================================
if [[ -n "$TAG" ]]; then
    # Only lines containing [tag:<TAG>]
    mapfile -t PKGS < <(grep "\[tag:${TAG}\]" "$PKG_LIST" | grep -v '^\s*#' | grep -v '^\s*$' | awk '{print $1}')
else
    # Only untagged lines (no [tag:...] present)
    mapfile -t PKGS < <(grep -v '^\s*#' "$PKG_LIST" | grep -v '^\s*$' | grep -v '\[tag:' | awk '{print $1}')
fi

if [[ ${#PKGS[@]} -eq 0 ]]; then
    die "No packages found in $PKG_LIST"
fi

# =============================================================================
# Display packages to be installed
# =============================================================================
echo ""
gum style \
    --foreground 117 --border-foreground 117 --border rounded \
    --align center --width 50 --padding "0 1" \
    "$LIST_LABEL PACKAGES TO INSTALL" \
    "${#PKGS[@]} packages"

echo ""
cols=3
count=0
row=""
for pkg in "${PKGS[@]}"; do
    row+="$(printf "  %-30s" "$pkg")"
    (( count++ ))
    if (( count % cols == 0 )); then
        gum style --foreground 245 "$row"
        row=""
    fi
done
[[ -n "$row" ]] && gum style --foreground 245 "$row"

echo ""
gum confirm "Proceed with installation?" || { msg "Aborted."; exit 0; }

# Start timer after user confirmation
START_TIME=$(date +%s)

# =============================================================================
# Install packages
# =============================================================================
INSTALLED=()
FAILED=()
SKIPPED=()

pkg_is_installed() {
    pacman -Q "$1" &>/dev/null
}

pkg_in_pacman() {
    pacman -Si "$1" &>/dev/null 2>&1
}

bootstrap_yay() {
    if ! command -v yay &>/dev/null; then
        echo -e "  \033[33m[....]\033[0m 'yay' not found. Bootstrapping AUR helper..."
        
        # Ensure base-devel and git are present first
        sudo pacman -S --noconfirm --needed base-devel git >> "$LOG_FILE" 2>&1
        
        local tmp_dir
        tmp_dir=$(mktemp -d)
        
        if git clone https://aur.archlinux.org/yay-bin.git "$tmp_dir" >> "$LOG_FILE" 2>&1; then
            (
                cd "$tmp_dir" || exit 1
                makepkg -si --noconfirm >> "$LOG_FILE" 2>&1
            )
            
            if command -v yay &>/dev/null; then
                echo -e "\r  \033[32m[ ok ]\033[0m 'yay' successfully installed"
                return 0
            fi
        fi
        
        echo -e "\r  \033[31m[fail]\033[0m Failed to install 'yay'. AUR packages will fail."
        return 1
    fi
}

install_pkg() {
    local pkg="$1"

    if pkg_is_installed "$pkg"; then
        SKIPPED+=("$pkg")
        echo -e "  \033[90m[skip]\033[0m $pkg already installed"
        return 0
    fi

    echo -ne "  \033[33m[....]\033[0m $pkg"

    if pkg_in_pacman "$pkg"; then
        if sudo pacman -S --noconfirm --needed "$pkg" >> "$LOG_FILE" 2>&1; then
            if pkg_is_installed "$pkg"; then
                INSTALLED+=("$pkg")
                echo -e "\r  \033[32m[ ok ]\033[0m $pkg"
                return 0
            fi
        fi
    else
        if yay -S --noconfirm --needed "$pkg" >> "$LOG_FILE" 2>&1; then
            if pkg_is_installed "$pkg"; then
                INSTALLED+=("$pkg")
                echo -e "\r  \033[32m[ ok ]\033[0m $pkg \033[90m(aur)\033[0m"
                return 0
            fi
        fi
    fi

    FAILED+=("$pkg")
    echo -e "\r  \033[31m[fail]\033[0m $pkg"
    echo "FAILED: $pkg" >> "$LOG_FILE"
}

echo ""
section "Installing $LIST_LABEL packages"
echo "Install started: $(date)" >> "$LOG_FILE"

# Bootstrap yay first so it's ready for any AUR packages
bootstrap_yay

for pkg in "${PKGS[@]}"; do
    install_pkg "$pkg"
done

# =============================================================================
# Summary
# =============================================================================
echo ""
gum style \
    --foreground 82 --border-foreground 82 --border rounded \
    --align center --width 50 --padding "0 1" \
    "PACKAGE INSTALL SUMMARY"

echo ""
gum style --foreground 82  "  ✓ Installed : ${#INSTALLED[@]}"
gum style --foreground 245 "  - Skipped   : ${#SKIPPED[@]} (already present)"
gum style --foreground 196 "  ✗ Failed    : ${#FAILED[@]}"

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    gum style --foreground 196 "  Failed packages:"
    for pkg in "${FAILED[@]}"; do
        gum style --foreground 196 "    • $pkg"
    done
    echo ""
    gum style --foreground 245 "  See full log: $LOG_FILE"
fi

echo ""
echo "Install finished: $(date)" >> "$LOG_FILE"
echo "Installed: ${INSTALLED[*]:-none}" >> "$LOG_FILE"
echo "Failed: ${FAILED[*]:-none}" >> "$LOG_FILE"

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
MINUTES=$((TOTAL_TIME / 60))
SECONDS_LEFT=$((TOTAL_TIME % 60))

echo "Total Time: ${MINUTES}m ${SECONDS_LEFT}s (${TOTAL_TIME} seconds)" >> "$LOG_FILE"

# =============================================================================
# Performance Summary
# =============================================================================
echo ""

gum style --foreground 141 \
"⏱️ Total time: ${MINUTES}m $(printf "%02d" "$SECONDS_LEFT")s (${TOTAL_TIME} seconds)"

if (( ${#INSTALLED[@]} == 0 )); then
    gum style --foreground 244 \
    "✓ Nothing needed installing. All packages were already present."
elif (( TOTAL_TIME <= 30 )); then
    gum style --foreground 46 \
    "⚡ Holy speed! Installation finished in a flash."
    gum style --foreground 46 \
    "🚀 Your internet connection is absolutely elite. Keep flexing that bandwidth!"
elif (( TOTAL_TIME <= 60 )); then
    gum style --foreground 153 \
    "🏹 Nice! That was quick."
    gum style --foreground 153 \
    "📦 Pacman barely had time to unpack its bags."
elif (( TOTAL_TIME <= 180 )); then
    gum style --foreground 214 \
    "☕ Not bad."
    gum style --foreground 214 \
    "📦 Just enough time to grab a coffee while Arch did its thing."
elif (( TOTAL_TIME <= 300 )); then
    gum style --foreground 208 \
    "🐢 Well... that took a hot minute."
    gum style --foreground 208 \
    "📡 Either your mirror was taking a nap or the AUR was compiling the universe."
else
    gum style --foreground 196 \
    "💀 Congratulations. You witnessed geological time."
    gum style --foreground 196 \
    "📶 Your Wi-Fi connection straight up sucks. Are you stealing internet from a toaster?"
    gum style --foreground 244 \
    "📡 If it wasn't the Wi-Fi, blame the mirrors. They can defend themselves."
    gum style --foreground 226 \
    "💡 Suggestion: Fix your router, yell at your ISP, or move closer to civilization."
fi

echo ""

[[ ${#FAILED[@]} -gt 0 ]] && exit 1 || exit 0