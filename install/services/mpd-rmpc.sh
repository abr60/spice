#!/usr/bin/env bash
# =============================================================================
# install/services/mpd-rmpc.sh — Enable and start MPD + mpd-mpris (rmpc backend)
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

section "MPD + RMPC"

# =============================================================================
# Prerequisites
# =============================================================================
# MPD needs its state dirs and a music directory to exist or it fails to start.
ensure_dir "$HOME/.local/share/mpd/playlists"
ensure_dir "$HOME/.local/share/mpd"
if [[ ! -d "$HOME/Music" ]]; then
    msg "Creating ~/Music (MPD music directory)..."
    ensure_dir "$HOME/Music"
fi

# =============================================================================
# User services (MPD + MPRIS bridge + rmpc backend)
# =============================================================================
section "User Services"

systemctl --user daemon-reload

enable_user_service mpd.service
enable_user_service mpd-mpris.service

# =============================================================================
# mpd-mpris ordering (drop-in override)
# =============================================================================
# The packaged unit (/usr/lib/systemd/user/mpd-mpris.service) ships with
# After=mpd.service but no Requires=, so it can start before MPD binds and
# the MPRIS bridge silently dies on cold boot. We can't edit /usr/lib (gets
# wiped on package updates), so drop a user override that forces ordering.
MPRIS_DROP="$HOME/.config/systemd/user/mpd-mpris.service.d/override.conf"
if [[ ! -f "$MPRIS_DROP" ]]; then
    ensure_dir "$(dirname "$MPRIS_DROP")"
    cat > "$MPRIS_DROP" <<'EOF'
[Unit]
Requires=mpd.service
EOF
    ok "mpd-mpris drop-in override written ($MPRIS_DROP)"
    systemctl --user daemon-reload
else
    msg "mpd-mpris drop-in override already present"
fi

# =============================================================================
# Ensure MPD is actually running
# =============================================================================
if ! systemctl --user is-active mpd.service &>/dev/null; then
    msg "Starting mpd.service..."
    systemctl --user start mpd.service && ok "mpd started" || warn "mpd failed to start — check 'systemctl --user status mpd'"
fi

# MPD creates the cava FIFO on start; wait briefly for it
if systemctl --user is-active mpd.service &>/dev/null; then
    for _ in {1..10}; do
        [[ -e /tmp/mpd.fifo ]] && break
        sleep 0.5
    done
    [[ -e /tmp/mpd.fifo ]] && ok "MPD cava FIFO ready (/tmp/mpd.fifo)" || \
        warn "MPD FIFO not found — cava visualizer may not work"

    if command -v mpc &>/dev/null; then
        mpc update &>/dev/null || true
        ok "MPD database updated"
    fi

    if command -v rmpc &>/dev/null; then
        CONN=$(rmpc debuginfo 2>/dev/null | grep "Connection")
        if [[ "$CONN" == *Success* ]]; then
            ok "MPD reachable by rmpc"
        else
            warn "rmpc could not reach MPD"
        fi
    fi
fi

ok "MPD + RMPC setup complete"