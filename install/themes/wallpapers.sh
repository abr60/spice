#!/usr/bin/env bash
set -euo pipefail

WALLS_DIR="$HOME/Wallpapers"
REPO_URL="https://github.com/abr60/Walls.git"

if [[ ! -d "$WALLS_DIR" ]]; then
    git clone "$REPO_URL" "$WALLS_DIR"
fi
