#!/usr/bin/env bash
# =============================================================================
# extras/easyeffects.sh — Install EasyEffects DSP presets for ThinkPad T14 Gen 2
# Downloads Dolby IRS files and installs presets
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

section "EasyEffects DSP"

ARCHER_DIR="${ARCHER_DIR:-$HOME/.local/share/Archer}"
PRESET_SOURCE="$ARCHER_DIR/system/easyeffects/presets"
IRS_DEST="$HOME/.local/share/easyeffects/irs"
PRESET_DEST="$HOME/.local/share/easyeffects/output"
IRS_BASE_URL="https://github.com/shuhaowu/linux-thinkpad-speaker-improvements/raw/main/ThinkPadT14Gen1"

# ─── Install EasyEffects packages via the tagged package list ─────────────────
if ! command -v easyeffects &>/dev/null; then
    msg "Installing EasyEffects packages..."
    bash "$(dirname "${BASH_SOURCE[0]}")/../packaging/packages" extra --tag easyeffects
fi

mkdir -p "$IRS_DEST" "$PRESET_DEST"

# ─── Download IRS files ───────────────────────────────────────────────────────
msg "Downloading Dolby IRS files for ThinkPad T14..."

declare -A IRS_FILES=(
    ["T14-Dolby-Music.irs"]="DolbyMusicBalanced.irs"
    ["T14-Dolby-Movie.irs"]="DolbyMovieBalanced.irs"
    ["T14-Dolby-Game.irs"]="DolbyGameBalanced.irs"
    ["T14-Dolby-Voice.irs"]="DolbyVoiceBalanced.irs"
)

for local_name in "${!IRS_FILES[@]}"; do
    remote_name="${IRS_FILES[$local_name]}"
    dest="$IRS_DEST/$local_name"
    if [[ -f "$dest" ]]; then
        ok "Already exists: $local_name"
    else
        if spinner "Downloading $local_name..." \
            curl -fsSL "$IRS_BASE_URL/$remote_name" -o "$dest"; then
            ok "Downloaded $local_name"
        else
            warn "Failed to download $local_name"
        fi
    fi
done

# ─── Copy presets ─────────────────────────────────────────────────────────────
if [[ -d "$PRESET_SOURCE" ]]; then
    shopt -s nullglob
    jsons=("$PRESET_SOURCE"/*.json)
    if [[ ${#jsons[@]} -gt 0 ]]; then
        cp "${jsons[@]}" "$PRESET_DEST/"
        ok "EasyEffects presets installed"
    else
        warn "No .json presets found in $PRESET_SOURCE"
    fi
    shopt -u nullglob
else
    warn "Preset source not found at $PRESET_SOURCE — skipping"
fi

ok "EasyEffects setup complete"
