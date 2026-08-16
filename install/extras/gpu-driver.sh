#!/usr/bin/env bash
# =============================================================================
# extras/gpu-driver.sh — Detect GPU and install appropriate drivers
# Handles Intel (with generation detection), AMD, and NVIDIA
# Adapted from omarchy's vulkan.sh, video-acceleration.sh, and nvidia.sh
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

section "GPU Driver Detection"

# ─── Helper ───────────────────────────────────────────────────────────────────
pkg_add() {
    local pkgs=("$@")
    sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

# ─── Detect GPUs ──────────────────────────────────────────────────────────────
HAS_INTEL=false
HAS_AMD=false
HAS_NVIDIA=false

lspci | grep -iE '(VGA|Display|3D)' | while read -r line; do
    echo "  Detected: $line"
done

lspci | grep -iE '(VGA|Display|3D).*Intel'  &>/dev/null && HAS_INTEL=true
lspci | grep -iE '(VGA|Display|3D).*AMD'    &>/dev/null && HAS_AMD=true
lspci | grep -iE '(VGA|Display|3D).*NVIDIA' &>/dev/null && HAS_NVIDIA=true

# ─── Vulkan ───────────────────────────────────────────────────────────────────
section "Vulkan Drivers"

VULKAN_PKGS=()
$HAS_INTEL  && VULKAN_PKGS+=(vulkan-intel)
$HAS_AMD    && VULKAN_PKGS+=(vulkan-radeon)

if [[ ${#VULKAN_PKGS[@]} -gt 0 ]]; then
    pkg_add "${VULKAN_PKGS[@]}"
    ok "Vulkan drivers installed: ${VULKAN_PKGS[*]}"
else
    warn "No Intel/AMD GPU detected for Vulkan — skipping"
fi

# ─── Intel Video Acceleration ─────────────────────────────────────────────────
section "Intel Video Acceleration"

if $HAS_INTEL; then
    INTEL_GPU=$(lspci | grep -iE '(VGA|Display|3D)' | grep -i intel || true)
    INTEL_LOWER="${INTEL_GPU,,}"

    if [[ "$INTEL_LOWER" =~ (hd\ graphics|uhd\ graphics|xe|iris|arc) ]]; then
        pkg_add intel-media-driver libvpl vpl-gpu-rt
        ok "Intel media driver installed (HD/UHD/Xe/Iris/Arc)"
    elif [[ "$INTEL_LOWER" =~ gma ]]; then
        pkg_add libva-intel-driver
        ok "Legacy Intel VA driver installed (GMA)"
    else
        # Default — T14 Gen 2 has Intel Xe integrated
        pkg_add intel-media-driver
        ok "Intel media driver installed (default)"
    fi
else
    warn "No Intel GPU detected — skipping video acceleration"
fi

# ─── AMD ──────────────────────────────────────────────────────────────────────
section "AMD Drivers"

if $HAS_AMD; then
    pkg_add mesa libva-mesa-driver mesa-vdpau
    ok "AMD Mesa drivers installed"
else
    warn "No AMD GPU detected — skipping"
fi

# ─── NVIDIA ───────────────────────────────────────────────────────────────────
section "NVIDIA Drivers"

if $HAS_NVIDIA; then
    # Detect kernel and get headers package
    KERNEL=$(pacman -Qqs '^linux(-zen|-lts|-hardened)?$' | head -1)
    KERNEL_HEADERS="${KERNEL}-headers"

    # Detect GSP firmware support (Turing+ = RTX 20xx and newer)
    # GSP-capable cards have device IDs >= 0x1e00
    NVIDIA_ID=$(lspci -nn | grep -i nvidia | grep -oP '10de:\K[0-9a-f]+' | head -1 || true)
    GSP_SUPPORTED=false

    if [[ -n "$NVIDIA_ID" ]]; then
        # Turing (1e00+), Ampere (2200+), Ada (2600+), Hopper (2300+)
        if (( 16#$NVIDIA_ID >= 16#1e00 )); then
            GSP_SUPPORTED=true
        fi
    fi

    if $GSP_SUPPORTED; then
        msg "NVIDIA Turing+ detected — installing open kernel modules"
        NVIDIA_PKGS=(
            "$KERNEL_HEADERS"
            nvidia-open-dkms
            nvidia-utils
            lib32-nvidia-utils
            libva-nvidia-driver
        )
        GPU_ARCH="turing_plus"
    else
        msg "NVIDIA Maxwell/Pascal/Volta detected — installing proprietary modules"
        NVIDIA_PKGS=(
            "$KERNEL_HEADERS"
            nvidia-dkms
            nvidia-utils
            lib32-nvidia-utils
        )
        GPU_ARCH="legacy"
    fi

    pkg_add "${NVIDIA_PKGS[@]}"
    ok "NVIDIA packages installed"

    # Early KMS modprobe config
    sudo tee /etc/modprobe.d/nvidia.conf > /dev/null << 'MODPROBE'
options nvidia_drm modeset=1
MODPROBE
    ok "NVIDIA modprobe config written"

    # mkinitcpio early loading
    sudo mkdir -p /etc/mkinitcpio.conf.d
    sudo tee /etc/mkinitcpio.conf.d/nvidia.conf > /dev/null << 'MKINIT'
MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
MKINIT
    ok "NVIDIA mkinitcpio config written"

    # Rebuild initramfs
    msg "Rebuilding initramfs..."
    sudo mkinitcpio -P && ok "Initramfs rebuilt" || warn "mkinitcpio failed — run manually"

    # Hyprland env vars
    ENVS_CONF="$HOME/.config/hypr/envs.conf"
    if [[ -f "$ENVS_CONF" ]] && ! grep -q 'NVIDIA' "$ENVS_CONF"; then
        if [[ "$GPU_ARCH" == "turing_plus" ]]; then
            cat >> "$ENVS_CONF" << 'ENVEOF'

# NVIDIA (Turing+ with GSP firmware)
env = NVD_BACKEND,direct
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
ENVEOF
        else
            cat >> "$ENVS_CONF" << 'ENVEOF'

# NVIDIA (Maxwell/Pascal/Volta)
env = NVD_BACKEND,egl
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
ENVEOF
        fi
        ok "NVIDIA environment vars added to envs.conf"
    fi
else
    warn "No NVIDIA GPU detected — skipping"
fi

ok "GPU driver setup complete"
