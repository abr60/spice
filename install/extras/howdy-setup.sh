#!/bin/bash

# omarchy:summary=Set up Howdy face recognition for sudo, login, and lock screen
# omarchy:requires-sudo=true

set -euo pipefail

# =============================================================================
# omarchy-setup-security-howdy — Face recognition via Howdy + IR emitter
#
# Source: ~/spice/install/extras/howdy-setup.sh
# Deployed to: /usr/share/omarchy/bin/omarchy-setup-security-howdy
# Run via: omarchy setup security howdy
#
# Auth order:
#   sudo/sddm/polkit: pam_exec (IR emitter) → pam_howdy → pam_fprintd → password
#   lock screen: omarchy-lock-howdy (pam_howdy) + omarchy-lock-password
#
# IR emitter strategy (linux-enable-ir-emitter v6.x):
#   - udev rule  → fires on every camera device-add (boot, resume, lid-open)
#   - pam_exec   → fires before each Howdy auth (belt-and-suspenders)
#   - resume service → fires after suspend/hibernate (udev has no add event)
# =============================================================================

# ── helpers (standalone, no spice helpers) ───────────────────────────────────
msg()  { echo -e "\e[34m==>\e[0m $1"; }
ok()   { echo -e "\e[32m ✓\e[0m $1"; }
warn() { echo -e "\e[33m !\e[0m $1"; }
err()  { echo -e "\e[31m ✗\e[0m $1"; }

is_installed() { pacman -Q "$1" &>/dev/null; }

ask_yes_no() {
  local prompt="$1"
  if command -v gum &>/dev/null; then
    gum confirm "$prompt" && return 0 || return 1
  else
    while true; do
      read -rp "$prompt [y/n]: " yn
      case $yn in [Yy]*) return 0 ;; [Nn]*) return 1 ;; *) echo "Please answer y or n." ;; esac
    done
  fi
}

# ── 1. Hardware check ────────────────────────────────────────────────────────
echo -e "\e[32mSetting up Howdy face recognition.\n\e[0m"

# Ensure v4l-utils for camera detection
if ! is_installed v4l-utils; then
  msg "Installing v4l-utils..."
  if command -v omarchy-pkg-add &>/dev/null; then
    omarchy-pkg-add v4l-utils
  else
    sudo pacman -S --needed --noconfirm v4l-utils
  fi
fi

# ── 2. Package install ───────────────────────────────────────────────────────
msg "Installing Howdy packages..."
if command -v omarchy-pkg-aur-add &>/dev/null; then
  omarchy-pkg-aur-add howdy-next-git linux-enable-ir-emitter-git
else
  # fallback: use yay directly
  if ! is_installed howdy-next-git || ! is_installed linux-enable-ir-emitter-git; then
    if command -v yay &>/dev/null; then
      yay -S --needed --noconfirm howdy-next-git linux-enable-ir-emitter-git
    else
      err "yay not found — cannot install AUR packages. Install yay first."
      exit 1
    fi
  fi
fi
ok "Howdy packages installed"

if ! is_installed howdy-next-git || ! is_installed linux-enable-ir-emitter-git; then
  err "Packages failed to install — aborting"
  exit 1
fi

# Resolve IR emitter binary path
LEIRE_BIN=$(command -v linux-enable-ir-emitter 2>/dev/null || echo "")
if [[ -z "$LEIRE_BIN" ]]; then
  err "linux-enable-ir-emitter binary not found in PATH after install"
  exit 1
fi
ok "IR emitter binary: $LEIRE_BIN"

# ── 3. IR camera detection ───────────────────────────────────────────────────
echo ""
msg "Detecting IR camera..."

IR_DEVICE=""
IR_PATH="/dev/v4l/by-path/pci-0000:00:14.0-usb-0:4:1.2-video-index0"

if [[ -e "$IR_PATH" ]]; then
  FORMAT=$(v4l2-ctl --device="$IR_PATH" --list-formats 2>/dev/null | grep -i grey || true)
  if [[ -n "$FORMAT" ]]; then
    IR_DEVICE="$IR_PATH"
    ok "IR camera confirmed: $IR_DEVICE"
  fi
fi

if [[ -z "$IR_DEVICE" ]]; then
  warn "Stable by-path not found — scanning /dev/video* for IR camera..."
  for dev in /dev/video*; do
    [[ -e "$dev" ]] || continue
    FORMAT=$(v4l2-ctl --device="$dev" --list-formats 2>/dev/null | grep -i grey || true)
    if [[ -n "$FORMAT" ]]; then
      IR_DEVICE="$dev"
      ok "IR camera found at: $IR_DEVICE"
      warn "Consider using by-path symlink for stability"
      break
    fi
  done
fi

if [[ -z "$IR_DEVICE" ]]; then
  err "No IR camera detected — cannot configure Howdy"
  err "Make sure your IR camera is connected and v4l2-ctl can see it."
  exit 1
fi

# ── 4. IR emitter configuration ──────────────────────────────────────────────
echo ""
msg "Configuring IR emitter..."

LEIRE_CONF_DIR="/root/.config"
if sudo ls "$LEIRE_CONF_DIR"/linux-enable-ir-emitter*.toml &>/dev/null 2>&1; then
  ok "IR emitter already configured — skipping"
else
  msg "The IR emitter needs to be configured once for your camera."
  msg "A TUI will open — follow the prompts and look at the camera when asked."
  echo ""
  if ask_yes_no "Configure IR emitter now?"; then
    sudo "$LEIRE_BIN" configure
    leire_exit=$?
    if [[ $leire_exit -lt 3 ]]; then
      ok "IR emitter configured"
    else
      warn "Configuration reported issues — continuing"
      warn "Run manually: sudo $LEIRE_BIN configure"
    fi
  else
    warn "Skipping IR emitter configuration — Howdy will not work well without it"
    warn "Run manually: sudo $LEIRE_BIN configure"
  fi
fi

# Try legacy systemd service if present
LEIRE_SERVICE="linux-enable-ir-emitter.service"
if systemctl list-unit-files "$LEIRE_SERVICE" &>/dev/null 2>&1; then
  sudo systemctl enable --now "$LEIRE_SERVICE" \
    && ok "linux-enable-ir-emitter.service enabled (legacy)" \
    || warn "Service enable failed — udev+pam_exec will cover it"
else
  warn "linux-enable-ir-emitter.service not found — expected in v6.x (deprecated upstream)"
fi

# ── 5. udev rule + systemd oneshot services ─────────────────────────────────
echo ""
msg "Installing udev rule and systemd services for IR emitter..."

IR_REAL=$(readlink -f "$IR_DEVICE" 2>/dev/null || echo "$IR_DEVICE")
IR_KERNEL=$(basename "$IR_REAL")

VENDOR=$(udevadm info --query=property --name="$IR_REAL" 2>/dev/null | grep "ID_VENDOR_ID" | cut -d= -f2 || echo "")
PRODUCT=$(udevadm info --query=property --name="$IR_REAL" 2>/dev/null | grep "ID_MODEL_ID" | cut -d= -f2 || echo "")

if [[ -n "$VENDOR" && -n "$PRODUCT" ]]; then
  ok "IR camera USB IDs: vendor=$VENDOR product=$PRODUCT"
  UDEV_MATCH="SUBSYSTEM==\"video4linux\", ATTRS{idVendor}==\"$VENDOR\", ATTRS{idProduct}==\"$PRODUCT\""
else
  warn "Could not resolve USB IDs — falling back to kernel name match ($IR_KERNEL)"
  UDEV_MATCH="SUBSYSTEM==\"video4linux\", KERNEL==\"$IR_KERNEL\""
fi

IR_SERVICE_FILE="/etc/systemd/system/ir-emitter.service"
sudo tee "$IR_SERVICE_FILE" > /dev/null << SVCFILE
[Unit]
Description=Enable IR Emitter for Howdy

[Service]
Type=oneshot
Environment=HOME=/root
ExecStart=$LEIRE_BIN run
SVCFILE
ok "ir-emitter.service written: $IR_SERVICE_FILE"

IR_RESUME_SERVICE_FILE="/etc/systemd/system/ir-emitter-resume.service"
sudo tee "$IR_RESUME_SERVICE_FILE" > /dev/null << RESUMESVC
[Unit]
Description=Re-enable IR Emitter after resume
After=suspend.target hibernate.target hybrid-sleep.target

[Service]
Type=oneshot
Environment=HOME=/root
ExecStart=$LEIRE_BIN run

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target
RESUMESVC

sudo systemctl daemon-reload
sudo systemctl enable ir-emitter-resume.service 2>/dev/null || true
ok "ir-emitter-resume.service enabled"

UDEV_RULE_FILE="/etc/udev/rules.d/99-howdy-ir-emitter.rules"
sudo tee "$UDEV_RULE_FILE" > /dev/null << UDEVRULE
# Auto re-apply IR emitter when IR camera appears (boot, resume, lid-open).
# Generated by omarchy-setup-security-howdy — do not edit manually.
ACTION=="add", ${UDEV_MATCH}, TAG+="systemd", ENV{SYSTEMD_WANTS}="ir-emitter.service"
UDEVRULE

sudo systemctl daemon-reload
sudo udevadm control --reload-rules 2>/dev/null || true
sudo udevadm trigger --subsystem-match=video4linux --action=add 2>/dev/null || true
ok "udev rule installed: $UDEV_RULE_FILE"

# ── 6. ONNX models ───────────────────────────────────────────────────────────
echo ""
msg "Checking Howdy face models..."

MODELS_DIR="/usr/share/howdy/models"
if sudo ls "$MODELS_DIR"/*.onnx &>/dev/null 2>&1; then
  ok "ONNX models already present in $MODELS_DIR"
else
  msg "Downloading Howdy face models..."
  sudo howdy download-models && ok "Models downloaded" || {
    err "Failed to download models — run manually: sudo howdy download-models"
    exit 1
  }
fi

# ── 7. Howdy config ──────────────────────────────────────────────────────────
echo ""
msg "Writing Howdy configuration..."

[[ -f /etc/howdy/config.ini ]] && sudo cp /etc/howdy/config.ini /etc/howdy/config.ini.bak && ok "Existing config backed up"

sudo tee /etc/howdy/config.ini > /dev/null << HOWDYCONF
[core]
detection_notice = false
timeout_notice = true
no_confirmation = true
suppress_unknown = true
abort_if_ssh = true
abort_if_lid_closed = false
disabled = false

[video]
timeout = 5
device_path = $IR_DEVICE
warn_no_device = true
max_height = 240
frame_width = 320
frame_height = 320
dark_threshold = 70
force_mjpeg = false
exposure = -1
device_fps = 0
rotate = 0

[face]
yunet_model = default
sface_model = default
yunet_score_threshold = 0.8845
yunet_nms_threshold = 0.3
yunet_top_k = 1000
sface_metric = cosine
sface_threshold = 0.6942

[snapshots]
save_failed = false
save_successful = false

[debug]
end_report = false
HOWDYCONF

ok "Howdy config written to /etc/howdy/config.ini"

# ── 8. Face enrollment ───────────────────────────────────────────────────────
echo ""
msg "Face model enrollment..."

HOWDY_MODELS="/etc/howdy/models"
sudo mkdir -p "$HOWDY_MODELS"

if [[ -n "$(sudo ls -A "$HOWDY_MODELS" 2>/dev/null | grep -v '\.onnx')" ]]; then
  # Only clear .dat face models, not .onnx detection models
  if sudo ls "$HOWDY_MODELS"/*.dat &>/dev/null 2>&1; then
    msg "Clearing existing face models for fresh enrollment..."
    sudo howdy clear -y 2>/dev/null || sudo rm -f "$HOWDY_MODELS"/*.dat 2>/dev/null || true
    ok "Old face models cleared"
  fi
fi

msg "Ready to enroll your face — look directly at the IR camera when prompted."
echo ""
if ask_yes_no "Enroll your face now?"; then
  sudo howdy add && ok "Face enrolled successfully" || {
    err "Enrollment failed — run manually: sudo howdy add"
  }
  msg "Testing face recognition..."
  sudo howdy test && ok "Face recognition working" || \
    warn "Test failed — check camera position and lighting"
else
  warn "Face enrollment skipped — run manually: sudo howdy add"
fi

# ── 9. PAM configuration (sed injection, idempotent) ────────────────────────
echo ""
msg "Configuring PAM for Howdy..."

PAM_EXEC_LINE="auth optional pam_exec.so /usr/bin/env HOME=/root $LEIRE_BIN run"

inject_pam_howdy() {
  local pam_file="$1"
  local label="$2"

  if [[ ! -f "$pam_file" ]]; then
    warn "$label: $pam_file not found — skipping"
    return
  fi

  if grep -q "pam_howdy" "$pam_file" 2>/dev/null; then
    ok "$label: pam_howdy already in $pam_file — skipping"
    # Still ensure pam_exec is present before howdy
    if ! grep -qF "$LEIRE_BIN run" "$pam_file" 2>/dev/null; then
      sudo sed -i "/pam_howdy\\.so/i $PAM_EXEC_LINE" "$pam_file" \
        && ok "$label: pam_exec injected into $pam_file" \
        || warn "$label: failed to inject pam_exec into $pam_file"
    fi
    return
  fi

  # Insert pam_howdy before pam_fprintd if present, otherwise before system-auth include, otherwise at top
  if grep -q "pam_fprintd" "$pam_file" 2>/dev/null; then
    sudo sed -i "/pam_fprintd\\.so/i auth       sufficient   pam_howdy.so" "$pam_file" \
      && ok "$label: pam_howdy inserted before pam_fprintd in $pam_file" \
      || warn "$label: failed to inject pam_howdy into $pam_file"
  elif grep -q "system-auth" "$pam_file" 2>/dev/null; then
    sudo sed -i "/system-auth/i auth       sufficient   pam_howdy.so" "$pam_file" \
      && ok "$label: pam_howdy inserted before system-auth in $pam_file" \
      || warn "$label: failed to inject pam_howdy into $pam_file"
  else
    sudo sed -i "1i auth       sufficient   pam_howdy.so" "$pam_file" \
      && ok "$label: pam_howdy inserted at top of $pam_file" \
      || warn "$label: failed to inject pam_howdy into $pam_file"
  fi

  # Inject pam_exec before howdy
  if ! grep -qF "$LEIRE_BIN run" "$pam_file" 2>/dev/null; then
    sudo sed -i "/pam_howdy\\.so/i $PAM_EXEC_LINE" "$pam_file" \
      && ok "$label: pam_exec injected into $pam_file" \
      || warn "$label: failed to inject pam_exec into $pam_file"
  fi
}

inject_pam_howdy "/etc/pam.d/sudo" "sudo"
inject_pam_howdy "/etc/pam.d/sddm" "sddm"

# polkit (optional)
if [[ -f /etc/pam.d/polkit-1 ]]; then
  inject_pam_howdy "/etc/pam.d/polkit-1" "polkit"
else
  msg "polkit-1 PAM not found — creating with Howdy support..."
  # shellcheck disable=SC2024
  sudo tee /etc/pam.d/polkit-1 > /dev/null << EOF
$PAM_EXEC_LINE
auth       sufficient   pam_howdy.so
auth       required     pam_unix.so

account    required     pam_unix.so
password   required     pam_unix.so
session    required     pam_unix.so
EOF
  ok "polkit-1 created with Howdy support"
fi

# Lock screen PAM — dedicated service like omarchy-lock-fingerprint
# Note: Omarchy's lock screen (quickshell) uses omarchy-lock-password +
# omarchy-lock-fingerprint. Howdy needs a separate service until the lock
# plugin is extended. We create it here; a patched lock plugin can consume it.
msg "Configuring lock screen PAM..."
sudo tee /etc/pam.d/omarchy-lock-howdy > /dev/null << 'EOF'
#%PAM-1.0
auth       required                    pam_howdy.so
account    include                     system-local-login
EOF
ok "Lock screen PAM created: /etc/pam.d/omarchy-lock-howdy"

# Re-apply omarchy lock config (ensures omarchy-lock-password stays valid)
if command -v omarchy-apply-lock &>/dev/null; then
  omarchy-apply-lock 2>/dev/null || sudo omarchy-apply-lock 2>/dev/null || warn "omarchy-apply-lock failed — run manually"
fi

# Check if lock plugin is cloned and needs patching
LOCK_PLUGIN_QML="$HOME/.config/omarchy/plugins/lock/Service.qml"
if [[ -f "$LOCK_PLUGIN_QML" ]]; then
  if ! grep -q "omarchy-lock-howdy" "$LOCK_PLUGIN_QML" 2>/dev/null; then
    warn "Lock plugin is cloned but not patched for Howdy."
    warn "To enable face unlock on the lock screen, patch $LOCK_PLUGIN_QML"
    warn "or re-run: omarchy plugin clone lock  (then re-apply Howdy patch)"
  else
    ok "Lock plugin already supports Howdy"
  fi
else
  warn "Lock screen face unlock requires the lock plugin to be cloned:"
  warn "  omarchy plugin clone lock"
  warn "Then patch Service.qml to add omarchy-lock-howdy support."
  warn "sudo/polkit/sddm face unlock works without this."
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "\e[32mHowdy setup complete!\e[0m"
ok "IR camera    : $IR_DEVICE"
ok "IR binary    : $LEIRE_BIN"
ok "udev rule    : $UDEV_RULE_FILE"
ok "IR service   : $IR_SERVICE_FILE"
ok "Resume svc   : $IR_RESUME_SERVICE_FILE"
ok "Models       : $MODELS_DIR"
ok "Config       : /etc/howdy/config.ini"
ok "PAM          : sudo, sddm, polkit-1, omarchy-lock-howdy"
echo ""
warn "If face recognition fails   : sudo howdy test"
warn "To re-enroll                : sudo howdy clear -y && sudo howdy add"
warn "If IR emitter not flashing  : sudo $LEIRE_BIN run"
warn "To reconfigure IR emitter   : sudo $LEIRE_BIN configure"
warn "To remove Howdy             : omarchy remove security howdy"
