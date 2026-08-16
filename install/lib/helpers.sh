#!/usr/bin/env bash
# =============================================================================
# lib/helpers.sh — Shared helper functions for Archer install scripts
# Source at the top of every install script:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"
# =============================================================================

# ── Archer color palette — Forest green + cream (from wallpaper) ──────────────
# Hex values; gum supports #rrggbb directly.
C_PRIMARY="#94c97a"    # bright canopy green  — headers, section titles, logo
C_ACCENT="#e8dfc8"     # train cream/ivory    — warnings, highlights, prompts
C_TEAL="#4a8f6f"       # mid-tone foliage     — info, keys, links
C_SUCCESS="#6db85c"    # lighter leaf green   — ok, done, checkmarks
C_ERROR="#c47a5a"      # rust/bridge warm     — errors, fatal
C_MUTED="#3d5240"      # dark understory      — descriptions, hints
C_BORDER="#94c97a"     # match primary        — all borders

# TTY background (used by setup.sh before gum is available)
C_TTY_BG="0d1a0f"      # deep forest shadow (no # — used in printf escape)

# ── ANSI fallbacks (for non-gum output) ──────────────────────────────────────
_GREEN='\033[0;32m'
_BLUE='\033[0;34m'
_YELLOW='\033[1;33m'
_RED='\033[0;31m'
_CYAN='\033[0;36m'
_BOLD='\033[1m'
_NC='\033[0m'

# ── Terminal dimensions ────────────────────────────────────────────────────────
# Uses stty via /dev/tty (reliable across TTY, sourced, and piped contexts)
if [[ -e /dev/tty ]]; then
    _TERM_SIZE=$(stty size 2>/dev/null </dev/tty)
    if [[ -n "$_TERM_SIZE" ]]; then
        export TERM_HEIGHT=$(echo "$_TERM_SIZE" | cut -d' ' -f1)
        export TERM_WIDTH=$(echo  "$_TERM_SIZE" | cut -d' ' -f2)
    else
        export TERM_WIDTH=80
        export TERM_HEIGHT=24
    fi
else
    export TERM_WIDTH=80
    export TERM_HEIGHT=24
fi

term_width()  { echo "$TERM_WIDTH"; }
term_height() { echo "$TERM_HEIGHT"; }

# ── Logo geometry ─────────────────────────────────────────────────────────────
LOGO_FILE="${INSTALL_DIR:-$HOME/Archer/install}/lib/logo.txt"

export LOGO_WIDTH=$(awk '{ if (length > max) max = length } END { print max+0 }' "$LOGO_FILE" 2>/dev/null || echo 0)
export LOGO_HEIGHT=$(wc -l < "$LOGO_FILE" 2>/dev/null || echo 0)
export PADDING_LEFT=$(( (TERM_WIDTH - LOGO_WIDTH) / 2 ))
export PADDING_LEFT_SPACES=$(printf "%*s" "$PADDING_LEFT" "")

# ── Global gum theme (exported once — all gum calls inherit automatically) ────
export GUM_CONFIRM_PROMPT_FOREGROUND="$C_ACCENT"
export GUM_CONFIRM_SELECTED_FOREGROUND="#0d1a0f"
export GUM_CONFIRM_SELECTED_BACKGROUND="$C_PRIMARY"
export GUM_CONFIRM_UNSELECTED_FOREGROUND="$C_MUTED"
export GUM_CONFIRM_UNSELECTED_BACKGROUND=""

export GUM_CHOOSE_CURSOR_FOREGROUND="$C_PRIMARY"
export GUM_CHOOSE_SELECTED_FOREGROUND="$C_PRIMARY"
export GUM_CHOOSE_ITEM_FOREGROUND="$C_ACCENT"
export GUM_CHOOSE_HEADER_FOREGROUND="$C_MUTED"

export GUM_FILTER_INDICATOR_FOREGROUND="$C_PRIMARY"
export GUM_FILTER_SELECTED_PREFIX_FOREGROUND="$C_PRIMARY"
export GUM_FILTER_MATCH_FOREGROUND="$C_ACCENT"
export GUM_FILTER_PROMPT_FOREGROUND="$C_TEAL"

export GUM_INPUT_PROMPT_FOREGROUND="$C_PRIMARY"
export GUM_INPUT_CURSOR_FOREGROUND="$C_PRIMARY"
export GUM_INPUT_PLACEHOLDER_FOREGROUND="$C_MUTED"

export GUM_SPIN_SPINNER_FOREGROUND="$C_PRIMARY"
export GUM_SPIN_TITLE_FOREGROUND="$C_ACCENT"

# Padding — all gum widgets inherit left alignment from PADDING_LEFT
_PAD="0 0 0 $PADDING_LEFT"
export GUM_CONFIRM_PADDING="$_PAD"
export GUM_CHOOSE_PADDING="$_PAD"
export GUM_FILTER_PADDING="$_PAD"
export GUM_INPUT_PADDING="$_PAD"
export GUM_SPIN_PADDING="$_PAD"
export GUM_TABLE_PADDING="$_PAD"

# ── Logo renderer ─────────────────────────────────────────────────────────────
# Clears screen, prints logo in primary green, auto-centered via PADDING_LEFT.
print_logo() {
    printf "\033[H\033[2J"   # clear + cursor to top-left (works in TTY too)
    if [[ -f "$LOGO_FILE" ]]; then
        gum style \
            --foreground "$C_PRIMARY" \
            --padding "1 0 0 $PADDING_LEFT" \
            "$(<"$LOGO_FILE")"
        echo ""
    fi
}

# ── Logging ───────────────────────────────────────────────────────────────────
msg()     { echo -e "${_BLUE}==>${_NC} $1"; }
ok()      { echo -e "${_GREEN} ✓${_NC} $1"; }
warn()    { echo -e "${_YELLOW} !${_NC} $1"; }
err()     { echo -e "${_RED} ✗${_NC} $1"; }
die()     { echo -e "${_RED}ERR${_NC} $1"; exit 1; }
section() { echo -e "\n${_BOLD}${_CYAN}--- $1 ---${_NC}"; }

# ── Gum helpers ───────────────────────────────────────────────────────────────
has_gum() { command -v gum &>/dev/null; }

spinner() {
    local title="$1"; shift
    if has_gum; then
        gum spin --spinner dot --title "$title" --show-error -- "$@"
    else
        echo -e "${_CYAN}⟳${_NC} $title"
        "$@"
    fi
}

ask_yes_no() {
    local prompt="$1"
    if has_gum; then
        gum confirm "$prompt" && return 0 || return 1
    else
        while true; do
            read -rp "$prompt [y/n]: " yn
            case $yn in
                [Yy]*) return 0 ;;
                [Nn]*) return 1 ;;
                *) echo "Please answer y or n." ;;
            esac
        done
    fi
}

gum_input() {
    local placeholder="$1"
    if has_gum; then
        gum input --placeholder "$placeholder"
    else
        read -rp "$placeholder: " val
        echo "$val"
    fi
}

# ── Package helpers ───────────────────────────────────────────────────────────
is_installed() { pacman -Q "$1" &>/dev/null; }

ensure_installed() {
    local pkg="$1"
    if ! is_installed "$pkg"; then
        msg "Installing $pkg..."
        sudo pacman -S --needed --noconfirm "$pkg"
        ok "$pkg installed"
    fi
}

# ── Filesystem helpers ────────────────────────────────────────────────────────
remove_path() {
    local target="$1"
    if [[ -L "$target" ]]; then
        rm -f "$target"
    elif [[ -e "$target" ]]; then
        rm -rf "$target"
    fi
}

ensure_dir() { mkdir -p "$1"; }

# ── Hardware detection ────────────────────────────────────────────────────────
is_laptop() {
    ls /sys/class/power_supply/BAT* &>/dev/null || \
    [[ -d /sys/class/power_supply/battery ]]
}

detect_hardware_type() { is_laptop && echo "laptop" || echo "desktop"; }
has_battery() { is_laptop; }

# ── Archer paths ──────────────────────────────────────────────────────────────
ARCHER_DIR="${ARCHER_DIR:-$HOME/.local/share/Archer}"
ARCHER_BIN="$ARCHER_DIR/bin"
archer_bin_present() { [[ -x "$ARCHER_BIN/$1" ]]; }

# ── Systemd helpers ───────────────────────────────────────────────────────────
unit_exists_system() { systemctl cat "$1" &>/dev/null; }
unit_exists_user()   { systemctl --user cat "$1" &>/dev/null; }
is_enabled_system()  { systemctl is-enabled "$1" &>/dev/null; }
is_enabled_user()    { systemctl --user is-enabled "$1" &>/dev/null; }

enable_system_service() {
    local svc="$1"
    if ! unit_exists_system "$svc"; then warn "$svc not found — skipping"; return; fi
    if is_enabled_system "$svc"; then ok "$svc already enabled"; return; fi
    sudo systemctl enable "$svc" && ok "Enabled $svc" || warn "Failed to enable $svc"
}

enable_user_service() {
    local svc="$1"
    if ! unit_exists_user "$svc"; then warn "$svc (user) not found — skipping"; return; fi
    if is_enabled_user "$svc"; then ok "$svc (user) already enabled"; return; fi
    systemctl --user enable "$svc" && ok "Enabled $svc (user)" || warn "Failed to enable $svc (user)"
}

# ── Shared run_step ───────────────────────────────────────────────────────────
# Usage: run_step <relative-script> <label> [critical:true|false] [log_file]
run_step() {
    local script="$1"
    local label="$2"
    local critical="${3:-false}"
    local log_file="${4:-}"

    local install_dir="${INSTALL_DIR:-$HOME/Archer/install}"
    local full_path="$install_dir/$script"

    echo ""
    section "$label"

    if [[ ! -f "$full_path" ]]; then
        warn "$script not found — skipping"
        return
    fi

    chmod +x "$full_path"

    local ret=0
    if [[ -n "$log_file" ]]; then
        bash "$full_path" >> "$log_file" 2>&1 || ret=$?
    else
        bash "$full_path" || ret=$?
    fi

    if [[ $ret -ne 0 ]]; then
        if [[ "$critical" == "true" ]]; then
            die "$label failed. Stopping."
        else
            warn "$label had errors — continuing"
        fi
    else
        ok "$label done"
    fi
}