#!/bin/bash

# omarchy:summary=Remove Howdy face recognition from authentication
# omarchy:requires-sudo=true

set -euo pipefail

# =============================================================================
# omarchy-remove-security-howdy — Clean removal of Howdy + IR emitter
#
# Source: ~/spice/install/extras/howdy-remove.sh
# Deployed to: /usr/share/omarchy/bin/omarchy-remove-security-howdy
# Run via: omarchy remove security howdy
# =============================================================================

msg()  { echo -e "\e[34m==>\e[0m $1"; }
ok()   { echo -e "\e[32m ✓\e[0m $1"; }
warn() { echo -e "\e[33m !\e[0m $1"; }
err()  { echo -e "\e[31m ✗\e[0m $1"; }

echo -e "\e[32mRemoving Howdy face recognition.\n\e[0m"

# ── PAM cleanup ──────────────────────────────────────────────────────────────
remove_pam_howdy() {
  local pam_file="$1"
  local label="$2"

  if [[ ! -f "$pam_file" ]]; then
    return
  fi

  if grep -q "pam_howdy\|linux-enable-ir-emitter" "$pam_file" 2>/dev/null; then
    msg "Removing Howdy from $label ($pam_file)..."
    # Remove pam_howdy line
    sudo sed -i '/pam_howdy\.so/d' "$pam_file" 2>/dev/null || true
    # Remove pam_exec line for IR emitter (only the one with linux-enable-ir-emitter)
    sudo sed -i '/linux-enable-ir-emitter.*run/d' "$pam_file" 2>/dev/null || true
    ok "Cleaned $label"
  fi
}

remove_pam_howdy "/etc/pam.d/sudo" "sudo"
remove_pam_howdy "/etc/pam.d/sddm" "sddm"
remove_pam_howdy "/etc/pam.d/sddm-greeter" "sddm-greeter"
remove_pam_howdy "/etc/pam.d/polkit-1" "polkit"
remove_pam_howdy "/etc/pam.d/hyprlock" "hyprlock"
remove_pam_howdy "/etc/pam.d/system-auth" "system-auth"

# ── Lock screen PAM ─────────────────────────────────────────────────────────
if [[ -f /etc/pam.d/omarchy-lock-howdy ]]; then
  msg "Removing lock screen PAM..."
  sudo rm -f /etc/pam.d/omarchy-lock-howdy
  ok "Removed /etc/pam.d/omarchy-lock-howdy"
fi

# Re-apply omarchy lock config to clean up
if command -v omarchy-apply-lock &>/dev/null; then
  omarchy-apply-lock 2>/dev/null || sudo omarchy-apply-lock 2>/dev/null || true
fi

# ── Systemd services ─────────────────────────────────────────────────────────
msg "Removing IR emitter services..."

for svc in ir-emitter.service ir-emitter-resume.service; do
  if systemctl is-enabled "$svc" &>/dev/null 2>&1; then
    sudo systemctl disable "$svc" 2>/dev/null || true
    ok "Disabled $svc"
  fi
  if [[ -f "/etc/systemd/system/$svc" ]]; then
    sudo rm -f "/etc/systemd/system/$svc"
    ok "Removed /etc/systemd/system/$svc"
  fi
done

# Legacy service if present
if systemctl is-enabled linux-enable-ir-emitter.service &>/dev/null 2>&1; then
  sudo systemctl disable linux-enable-ir-emitter.service 2>/dev/null || true
fi

sudo systemctl daemon-reload 2>/dev/null || true

# ── udev rule ────────────────────────────────────────────────────────────────
UDEV_RULE="/etc/udev/rules.d/99-howdy-ir-emitter.rules"
if [[ -f "$UDEV_RULE" ]]; then
  msg "Removing udev rule..."
  sudo rm -f "$UDEV_RULE"
  sudo udevadm control --reload-rules 2>/dev/null || true
  ok "Removed $UDEV_RULE"
fi

# ── Howdy config + models ────────────────────────────────────────────────────
if [[ -d /etc/howdy ]] || [[ -d /usr/share/howdy ]]; then
  echo ""
  warn "Howdy config lives in /etc/howdy/ and models in /usr/share/howdy/"
  if command -v gum &>/dev/null; then
    if gum confirm "Remove Howdy config and face models?"; then
      sudo rm -rf /etc/howdy 2>/dev/null || true
      ok "Removed /etc/howdy/"
      # Keep ONNX models — they're large downloads; only remove face .dat files
      if [[ -d /usr/share/howdy/models ]]; then
        sudo rm -f /usr/share/howdy/models/*.dat 2>/dev/null || true
        ok "Removed face models from /usr/share/howdy/models/"
      fi
    else
      warn "Kept Howdy config and models"
    fi
  else
    warn "Kept Howdy config — remove manually: sudo rm -rf /etc/howdy"
  fi
fi

# ── Packages ─────────────────────────────────────────────────────────────────
echo ""
msg "Removing Howdy packages..."

if command -v omarchy-pkg-drop &>/dev/null; then
  omarchy-pkg-drop howdy-next-git linux-enable-ir-emitter-git 2>/dev/null || true
  # Also try AUR variant name
  sudo pacman -Rns --noconfirm howdy-next-git linux-enable-ir-emitter-git 2>/dev/null || true
else
  sudo pacman -Rns --noconfirm howdy-next-git linux-enable-ir-emitter-git 2>/dev/null || {
    warn "Failed to remove packages — remove manually:"
    warn "  sudo pacman -Rns howdy-next-git linux-enable-ir-emitter-git"
  }
fi

ok "Howdy packages removed (v4l-utils kept)"

echo ""
echo -e "\e[32mHowdy has been completely removed.\e[0m"
warn "You may want to reboot to ensure PAM is fully clean."
