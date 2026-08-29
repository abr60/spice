#!/usr/bin/env bash
# =============================================================================
# extras/mpv.sh — MPV config bootstrap (clone abr60/mpv-config to ~/.config/mpv)
#
# mpv config no longer lives inside spice (detached 2026-08-29). It is its own
# repo — github.com/abr60/mpv-config — and its source of truth is that repo.
# This script gets a fresh Omarchy box to the same state:
#
#   git clone https://github.com/abr60/mpv-config.git ~/.config/mpv
#
# It is idempotent / safe to re-run:
#   * already a git repo  →  set a sane origin + `git pull --ff-only`
#   * exists but NOT git  →  back it up, then clone fresh (never clobber data)
#   * absent              →  clone
#
# Runtime files (memo-history.log, watch_later/) are gitignored — created on
# first use, NOT part of the repo.
#
# Usage:  bash ~/spice/install/extras/mpv.sh
# Requires: outbound HTTPS to github.com (works before any SSH key is added).
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

section "MPV Config"

# --- config -----------------------------------------------------------------
REPO="https://github.com/abr60/mpv-config.git"
# Deploy URL used when we clone or fix the origin. HTTPS-read is picked on
# purpose: a fresh box can fetch a public repo without an SSH key. Editing/
# pushing from ~/.config/mpv uses whatever remote the user sets later (SSH
# git@github.com:abr60/mpv-config.git works too — mpv.sh never "fixes" an
# existing origin against a different protocol).
DEPLOY_URL="https://github.com/abr60/mpv-config.git"
TARGET="${MPV_TARGET:-$HOME/.config/mpv}"
TS="$(date +%Y%m%d-%H%M%S)"

# --- 1. existing git repo ---------------------------------------------------
if [[ -d "$TARGET/.git" ]]; then
    msg "$TARGET already exists as a git repo"
    if ! git -C "$TARGET" remote get-url origin >/dev/null 2>&1; then
        msg "no origin set — adding $DEPLOY_URL"
        git -C "$TARGET" remote add origin "$DEPLOY_URL"
    fi
    # A working tree with uncommitted changes → pull refuses. Surface that
    # rather than silently losing work (update.sh-style remote-first is NOT
    # wanted here — the live config is editable).
    # Ensure the current branch tracks origin before pulling (a repo created
    # via `git init -b main + reset --hard origin/main` has no upstream set).
    _branch="$(git -C "$TARGET" symbolic-ref --short HEAD 2>/dev/null || echo main)"
    if ! git -C "$TARGET" rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
        msg "no upstream configured for $_branch — setting it to origin/$_branch"
        git -C "$TARGET" branch --set-upstream-to="origin/$_branch" "$_branch"
    fi
    git -C "$TARGET" pull --ff-only
    ok "mpv config up to date at $TARGET (HEAD: $(git -C "$TARGET" rev-parse --short HEAD))"
    exit 0
fi

# --- 2. existing non-git dir → back it up -----------------------------------
if [[ -e "$TARGET" ]]; then
    msg "$TARGET exists but is not a git repo (e.g. an old stow symlink/plain dir)"
    SAVED="$(dirname "$TARGET")/$(basename "$TARGET").saved-$TS"
    msg "backing it up to $SAVED"
    mv "$TARGET" "$SAVED"
    ok "backed up old config -> $SAVED (delete it once you're happy)"
fi

# --- 3. absent → clone ------------------------------------------------------
if ! command -v git >/dev/null 2>&1; then
    die "git is not installed (setup should have installed it as a base package)"
fi

msg "cloning $REPO -> $TARGET"
git clone "$REPO" "$TARGET"
mkdir -p "$TARGET/watch_later"   # gitignored runtime dir, ensure it exists
ok "mpv config installed. Runtime files (memo-history.log, watch_later/) are gitignored and created on use."
