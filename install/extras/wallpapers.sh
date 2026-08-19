#!/usr/bin/env bash
# =============================================================================
# extras/wallpapers.sh — Clone/update Walls repository and link wallpapers to themes
# =============================================================================
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

section "Walls"

WALLS_DIR="$HOME/Walls"
OMARCHY_BG_DIR="$HOME/.config/omarchy/backgrounds"
REPO_URL="https://github.com/drunk-particles/Walls.git"

# ─── Clone or Update ──────────────────────────────────────────────────────────
if [[ -d "$WALLS_DIR/.git" ]]; then
    msg "Walls repo found — pulling latest..."
    if git -C "$WALLS_DIR" pull; then
        ok "Walls updated"
    else
        warn "Pull failed — keeping existing Walls"
    fi
else
    if [[ -d "$WALLS_DIR" ]] && [[ -n "$(ls -A "$WALLS_DIR")" ]]; then
        warn "$WALLS_DIR exists and is not empty — skipping clone"
    else
        msg "Cloning Walls..."
        if git clone --progress "$REPO_URL" "$WALLS_DIR"; then
            ok "Walls cloned to $WALLS_DIR"
        else
            warn "Clone failed — check network connection"
            exit 1
        fi
    fi
fi

# ─── Ensure omarchy backgrounds folder exists ────────────────────────────────
if [[ ! -d "$OMARCHY_BG_DIR" ]]; then
    msg "Creating omarchy backgrounds directory: $OMARCHY_BG_DIR"
    mkdir -p "$OMARCHY_BG_DIR"
fi

# ─── Clean Obsolete Theme Folders ─────────────────────────────────────────────
msg "Checking for obsolete theme directories..."
if [[ -d "$OMARCHY_BG_DIR" ]]; then
    find "$OMARCHY_BG_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | while read -r -d '' active_theme_dir; do
        theme_name="$(basename "$active_theme_dir")"
        
        # Check if a matching folder does NOT exist in the Walls repository
        if [[ ! -d "$WALLS_DIR/$theme_name" ]]; then
            warn "Removing unmatched theme folder: $theme_name"
            rm -rf "$active_theme_dir"
        fi
    done
fi

# ─── Link wallpaper folders to matching themes ────────────────────────────────
msg "Linking wallpaper directories..."

# Using -print0 and read -d '' to robustly handle directory names with spaces
find "$WALLS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name ".git" -print0 | while read -r -d '' source_dir; do
    theme_name="$(basename "$source_dir")"
    target_theme_dir="$OMARCHY_BG_DIR/$theme_name"
    target_link="$target_theme_dir/Walls"

    # Automatically create the missing theme name folder
    if [[ ! -d "$target_theme_dir" ]]; then
        mkdir -p "$target_theme_dir"
    fi

    # Generate or overwrite the active symlink 
    ln -sfn "$source_dir" "$target_link"
    ok "Linked $theme_name -> $target_link"
done

ok "Wallpaper links are up to date."
msg "Add 'Walls' to a theme via: omarchy theme background <theme> ~/.config/omarchy/backgrounds/<theme>/Walls"