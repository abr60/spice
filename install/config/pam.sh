#!/usr/bin/env bash
# =============================================================================
# config/pam.sh — Copy PAM configuration files
# Backs up existing files before overwriting
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/backup.sh"

section "PAM Configuration"

PAM_SOURCE="$HOME/.config/hypr/assets/pam.d"
PAM_DEST="/etc/pam.d"

if [[ ! -d "$PAM_SOURCE" ]]; then
    warn "PAM source not found at $PAM_SOURCE — skipping"
    exit 0
fi

load_backup_session

for f in "$PAM_SOURCE"/*; do
    fname=$(basename "$f")
    backup_file "$PAM_DEST/$fname"
done

msg "Copying PAM files → $PAM_DEST"
sudo cp "$PAM_SOURCE/"* "$PAM_DEST/"
sudo chmod 644 "$PAM_DEST/"*

ok "PAM files installed"
