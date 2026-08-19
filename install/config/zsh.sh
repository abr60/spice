#!/usr/bin/env bash
# =============================================================================
# config/zsh.sh — Install Oh My Zsh, plugins, symlink zshrc, set default shell
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

section "Zsh Setup"

SPICE_DIR="${SPICE_DIR:-$HOME/spice}"
ZSH_DOTS_DIR="$SPICE_DIR/zshrc"
ZSHRC_LINK="$HOME/zshrc"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ─── Oh My Zsh ────────────────────────────────────────────────────────────────
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    msg "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh My Zsh installed"
else
    ok "Oh My Zsh already installed"
fi

# ─── Plugins ──────────────────────────────────────────────────────────────────
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    spinner "Installing zsh-autosuggestions..." \
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    ok "zsh-autosuggestions installed"
else
    ok "zsh-autosuggestions already installed"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ]]; then
    spinner "Installing fast-syntax-highlighting..." \
        git clone --depth=1 https://github.com/zdharma-continuum/fast-syntax-highlighting \
        "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
    ok "fast-syntax-highlighting installed"
else
    ok "fast-syntax-highlighting already installed"
fi

# ─── Symlink ~/zshrc → spice/zshrc ───────────────────────────────────────────
if [[ -d "$ZSH_DOTS_DIR" ]]; then
    remove_path "$ZSHRC_LINK"
    ln -sf "$ZSH_DOTS_DIR" "$ZSHRC_LINK"
    ok "Symlinked ~/zshrc → $ZSH_DOTS_DIR"
else
    warn "zshrc folder not found at $ZSH_DOTS_DIR — skipping"
fi

# ─── Symlink ~/.zshrc → ~/zshrc/rc ───────────────────────────────────────────
if [[ -f "$ZSHRC_LINK/rc" ]]; then
    [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]] && rm "$HOME/.zshrc"
    ln -sf "$ZSHRC_LINK/rc" "$HOME/.zshrc"
    ok "Symlinked ~/.zshrc → ~/zshrc/rc"
else
    warn "rc file not found at $ZSHRC_LINK/rc — skipping"
fi

# ─── Default shell ────────────────────────────────────────────────────────────
ZSH_PATH=$(command -v zsh 2>/dev/null || true)
if [[ -z "$ZSH_PATH" ]]; then
    warn "zsh not found — skipping shell change"
    exit 0
fi

if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    sudo chsh -s "$ZSH_PATH" "$USER" && ok "Default shell set to $ZSH_PATH"
else
    ok "Shell already set to zsh"
fi
