#!/usr/bin/env bash
# =============================================================================
# extras/howdy.sh — Set up Howdy face recognition for ThinkPad T14 Gen 2i
#
# Auth order configured:
#   Graphical (hyprlock/sddm): howdy → fingerprint → password
#   Terminal (sudo):           howdy → password → fingerprint
#
# Requires: howdy-next-git, linux-enable-ir-emitter-git, v4l-utils
# PAM configuration is handled separately by config/pam.sh
#
# IR emitter activation strategy (linux-enable-ir-emitter v6.x):
#   - Systemd service is deprecated upstream; not relied upon here.
#   - Two complementary triggers ensure the emitter is always on:
#       1. udev rule  → fires `leire run` on every camera device-add event
#                       (covers boot, resume, lid-open, USB reconnect)
#       2. pam_exec   → fires `leire run` immediately before each Howdy auth
#                       (belt-and-suspenders: catches anything udev missed)
#
# Notes:
#   - configure UI is TUI (ncurses), no display/xhost needed.
#   - ONNX model check uses glob, not hardcoded filenames (upstream changes them).
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

section "Howdy Face Recognition Setup"

# ─── Install packages ─────────────────────────────────────────────────────────
if ! is_installed howdy-next-git || ! is_installed linux-enable-ir-emitter-git; then
    bash "$(dirname "${BASH_SOURCE[0]}")/../packaging/packages" extra --tag howdy
fi

ensure_installed v4l-utils

# ─── Resolve IR emitter binary path ───────────────────────────────────────────
# Arch AUR installs to /usr/bin; upstream tarball uses /usr/local/bin.
# Resolve at runtime so pam_exec and udev get the correct absolute path.
LEIRE_BIN=$(command -v linux-enable-ir-emitter 2>/dev/null || echo "")
if [[ -z "$LEIRE_BIN" ]]; then
    err "linux-enable-ir-emitter binary not found in PATH after install"
    exit 1
fi
ok "IR emitter binary: $LEIRE_BIN"

# ─── Detect IR camera ─────────────────────────────────────────────────────────
section "IR Camera Detection"

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
    exit 1
fi

# ─── IR Emitter Configuration ─────────────────────────────────────────────────
section "IR Emitter Configuration"

# Config lives in /root/.config/ because configure is run as root.
# Check for any .toml file there as the "already configured" signal.
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
        warn "Skipping IR emitter configuration — Howdy will not work"
        warn "Run manually: sudo $LEIRE_BIN configure"
    fi
fi

# Try to enable the deprecated systemd service if it still ships in this version.
# This is a soft attempt only — failure is not fatal.
LEIRE_SERVICE="linux-enable-ir-emitter.service"
if systemctl list-unit-files "$LEIRE_SERVICE" &>/dev/null 2>&1; then
    sudo systemctl enable --now "$LEIRE_SERVICE" \
        && ok "linux-enable-ir-emitter.service enabled (legacy)" \
        || warn "Service enable failed — udev+pam_exec will cover it"
else
    warn "linux-enable-ir-emitter.service not found — expected in v6.x (deprecated upstream)"
fi

# ─── udev Rule ────────────────────────────────────────────────────────────────
# Fires `linux-enable-ir-emitter run` every time the IR camera device node
# appears: boot, resume from suspend, lid-open, USB reconnect.
# Uses the USB vendor/product from the ThinkPad T14 Gen 2i IR camera.
# If the by-path resolves to a different USB ID on your machine, update below.
section "udev Rule for IR Emitter"

UDEV_RULE_FILE="/etc/udev/rules.d/99-howdy-ir-emitter.rules"

# Resolve the USB vendor/product IDs for the detected IR camera device.
# Fall back to matching on the stable by-path kernel name if lookup fails.
IR_REAL=$(readlink -f "$IR_DEVICE" 2>/dev/null || echo "$IR_DEVICE")
IR_KERNEL=$(basename "$IR_REAL")   # e.g. video2

VENDOR=$(udevadm info --query=property --name="$IR_REAL" 2>/dev/null \
    | grep "ID_VENDOR_ID" | cut -d= -f2 || echo "")
PRODUCT=$(udevadm info --query=property --name="$IR_REAL" 2>/dev/null \
    | grep "ID_MODEL_ID" | cut -d= -f2 || echo "")

if [[ -n "$VENDOR" && -n "$PRODUCT" ]]; then
    ok "IR camera USB IDs: vendor=$VENDOR product=$PRODUCT"
    UDEV_MATCH="SUBSYSTEM==\"video4linux\", ATTRS{idVendor}==\"$VENDOR\", ATTRS{idProduct}==\"$PRODUCT\""
else
    warn "Could not resolve USB IDs — falling back to kernel name match ($IR_KERNEL)"
    UDEV_MATCH="SUBSYSTEM==\"video4linux\", KERNEL==\"$IR_KERNEL\""
fi

# udev RUN+= strips the environment — binary calls fail with exit code 1.
# Instead, trigger a systemd oneshot service which has a full environment.
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

# Resume service — fires after suspend/hibernate resume via systemd targets.
# The camera device does NOT re-add on resume (no udev add event), so a
# dedicated resume service is required alongside the udev-triggered one.
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
sudo systemctl enable ir-emitter-resume.service
ok "ir-emitter-resume.service enabled: $IR_RESUME_SERVICE_FILE"

sudo tee "$UDEV_RULE_FILE" > /dev/null << UDEVRULE
# Automatically re-apply IR emitter configuration whenever the IR camera
# device is added (boot, resume, lid-open, USB reconnect).
# Generated by Archer howdy.sh — do not edit manually.
# Uses systemd service instead of RUN+= to avoid stripped udev environment.
ACTION=="add", ${UDEV_MATCH}, TAG+="systemd", ENV{SYSTEMD_WANTS}="ir-emitter.service"
UDEVRULE

sudo systemctl daemon-reload
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=video4linux --action=add
ok "udev rule installed: $UDEV_RULE_FILE"

# ─── Download ONNX models ─────────────────────────────────────────────────────
section "Howdy ONNX Models"

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

# ─── Howdy config ─────────────────────────────────────────────────────────────
section "Howdy Configuration"

[[ -f /etc/howdy/config.ini ]] && \
    sudo cp /etc/howdy/config.ini /etc/howdy/config.ini.bak && \
    ok "Existing config backed up"

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

# ─── Face Enrollment ──────────────────────────────────────────────────────────
section "Face Model Enrollment"

HOWDY_MODELS="/etc/howdy/models"
sudo mkdir -p "$HOWDY_MODELS"

if [[ -n "$(sudo ls -A "$HOWDY_MODELS" 2>/dev/null)" ]]; then
    msg "Clearing existing face models for fresh enrollment..."
    sudo howdy clear -y 2>/dev/null || sudo rm -f "$HOWDY_MODELS"/*.dat 2>/dev/null || true
    ok "Old models cleared"
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

# ─── PAM Configuration ────────────────────────────────────────────────────────
# pam.sh handles the main Howdy PAM wiring (hyprlock, sddm, sudo, etc.).
# Here we inject pam_exec BEFORE each howdy line so linux-enable-ir-emitter
# run fires at auth time — belt-and-suspenders alongside the udev rule.
section "PAM Configuration"

PAM_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/../config/pam.sh"

if [[ -f "$PAM_SCRIPT" ]]; then
    bash "$PAM_SCRIPT" && ok "PAM configured" || warn "PAM configuration had errors"
else
    warn "pam.sh not found at $PAM_SCRIPT — configure manually"
fi

# Inject pam_exec line before every howdy auth line in /etc/pam.d/*
# This ensures the IR emitter is triggered at auth time even if udev missed it.
PAM_EXEC_LINE="auth optional pam_exec.so /usr/bin/env HOME=/root $LEIRE_BIN run"
HOWDY_PAM_FILES=$(grep -rl "howdy" /etc/pam.d/ 2>/dev/null || true)

if [[ -n "$HOWDY_PAM_FILES" ]]; then
    for pam_file in $HOWDY_PAM_FILES; do
        # Skip if pam_exec line already present
        if grep -qF "$LEIRE_BIN run" "$pam_file" 2>/dev/null; then
            ok "pam_exec already in $pam_file — skipping"
            continue
        fi
        # Insert pam_exec line before the first howdy auth line
        sudo sed -i "/auth.*howdy/i $PAM_EXEC_LINE" "$pam_file" \
            && ok "pam_exec injected into $pam_file" \
            || warn "Failed to inject pam_exec into $pam_file"
    done
else
    warn "No PAM files mention howdy yet — pam_exec injection skipped"
    warn "Re-run this script after pam.sh has configured Howdy PAM files"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
section "Howdy Setup Complete"
ok "IR camera    : $IR_DEVICE"
ok "IR binary    : $LEIRE_BIN"
ok "udev rule    : $UDEV_RULE_FILE"
ok "IR service   : $IR_SERVICE_FILE"
ok "Resume svc  : $IR_RESUME_SERVICE_FILE"
ok "Models       : $MODELS_DIR"
ok "Config       : /etc/howdy/config.ini"
ok "PAM          : configured via config/pam.sh + pam_exec injection"
echo ""
warn "If face recognition fails   : sudo howdy test"
warn "To re-enroll                : sudo howdy clear -y && sudo howdy add"
warn "If IR emitter not flashing  : sudo $LEIRE_BIN run"
warn "To reconfigure IR emitter   : sudo $LEIRE_BIN configure"