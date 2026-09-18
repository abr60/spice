#!/usr/bin/env bash
# spes-lib.sh — shared helpers for ~/spice/bin/android-flash/* (device detection, state, sha, confirm)
# keep plain bash (no gum) to match extract-boot style; sourcing file must stay silent on stdout

# shellcheck disable=SC2034

# --- adb/fastboot presence helpers ---
_has_adb()  { command -v adb &>/dev/null; }
_has_fastboot() { command -v fastboot &>/dev/null; }

# --- device state: system / recovery / fastboot / none (+ unauthorized/offline passthrough) ---
spes_state_raw() {
  _has_adb || { echo "none"; return; }
  local out
  out="$(adb devices 2>/dev/null | awk 'NR>1 && NF{print $2}' | head -n1)"
  case "$out" in
    device)    echo "system" ;;
    recovery)  echo "recovery" ;;
    unauthorized|offline|"") echo "$out" ;;
    sideload)  echo "sideload" ;;
    *)         echo "${out:-none}" ;;
  esac
  # fastboot fallback: if no adb device and fastboot sees one, report fastboot
  if [[ "$(spes_state_raw 2>/dev/null)" == "none" || -z "$out" ]]; then
    if _has_fastboot && fastboot devices 2>/dev/null | head -n1 | grep -q .; then
      # caller will call spes_state again; keep raw fastboot hint via separate fn
      :
    fi
  fi
}

spes_state() {
  local s
  s="$(adb devices 2>/dev/null | awk 'NR>1 && NF{print $2}' | head -n1)"
  case "$s" in
    device) echo "system"; return ;;
    recovery) echo "recovery"; return ;;
    unauthorized) echo "unauthorized"; return ;;
    offline) echo "offline"; return ;;
    sideload) echo "sideload"; return ;;
  esac
  if _has_fastboot && fastboot devices 2>/dev/null | grep -q .; then
    echo "fastboot"; return
  fi
  [[ -z "$s" ]] && echo "none" || echo "$s"
}

spes_wait_for() {
  local want="$1" timeout="${2:-40}"
  local i
  for ((i=0;i<timeout;i++)); do
    [[ "$(spes_state)" == "$want" ]] && return 0
    sleep 2
  done
  return 1
}

# --- props (only valid in system/recovery) ---
_getprop() {
  local k="$1"
  adb shell getprop "$k" 2>/dev/null | tr -d '\r\n'
}

# --- cached device info (call once, then reuse globals) ---
# globals: DEV_STATE, DEV_SLOT, DEV_AB, DEV_INITBOOT, DEV_RECOVERY_BLOCK, DEV_CODENAME, etc.
device_info() {
  DEV_STATE="$(spes_state)"
  DEV_SLOT="" ; DEV_AB="unknown" ; DEV_CODENAME="" ; DEV_MODEL="" ; DEV_ANDROID="" ; DEV_PATCH=""
  DEV_SLOT_RAW="" ; DEV_INITBOOT="unknown" ; DEV_RECOVERY_BLOCK="unknown"

  if [[ "$DEV_STATE" == "system" || "$DEV_STATE" == "recovery" ]]; then
    DEV_SLOT_RAW="$(_getprop ro.boot.slot_suffix)"
    DEV_SLOT="${DEV_SLOT_RAW:-}"
    local ab
    ab="$(_getprop ro.build.ab_update 2>/dev/null)"
    [[ "$ab" == "true" ]] && DEV_AB="A/B" || [[ "$ab" == "false" ]] && DEV_AB="A-only" || {
      [[ -n "$DEV_SLOT_RAW" ]] && DEV_AB="A/B" || DEV_AB="A-only"
    }
    DEV_CODENAME="$(_getprop ro.product.device)"
    DEV_MODEL="$(_getprop ro.product.model)"
    DEV_ANDROID="$(_getprop ro.build.version.release)"
    DEV_PATCH="$(_getprop ro.build.version.security_patch)"
    # root check (fast, non-interactive)
    if adb shell "su -c 'id' 2>/dev/null" | grep -q "uid=0"; then
      DEV_ROOT="yes"
    else
      DEV_ROOT="no"
    fi
    # init_boot / recovery partition presence — needs root in system/recovery; best-effort
    if adb shell "su -c 'ls /dev/block/by-name/init_boot' 2>/dev/null" | grep -q init_boot; then
      DEV_INITBOOT="yes"
    else
      DEV_INITBOOT="no"
    fi
    if adb shell "su -c 'ls /dev/block/by-name/recovery' 2>/dev/null" | grep -q recovery; then
      DEV_RECOVERY_BLOCK="yes"
    else
      DEV_RECOVERY_BLOCK="no"
    fi
    DEV_PRODUCT="$(_getprop ro.build.product 2>/dev/null)"
    DEV_ORANGEFOX="$(_getprop ro.orangefox.version 2>/dev/null)"
    if [[ -z "$DEV_ORANGEFOX" ]]; then DEV_ORANGEFOX="$(_getprop ro.twrp.version 2>/dev/null)"; fi
  elif [[ "$DEV_STATE" == "fastboot" ]]; then
    DEV_AB="A/B? (query fastboot)"
    if _has_fastboot; then
      local slot
      slot="$(fastboot getvar current-slot 2>&1 | grep -oE 'current-slot: [ab]' | awk '{print $2}')"
      [[ -n "$slot" ]] && DEV_SLOT="_$slot"
      # init_boot via fastboot variable; 'partition-type:init_boot' prints a line if it exists
      if fastboot getvar partition-type:init_boot 2>&1 | grep -q "partition-type:init_boot:"; then
        # empty value means not present vs 'boot'? on some devices it prints "partition-type:init_boot: boot"
        local v
        v="$(fastboot getvar partition-type:init_boot 2>&1 | grep "partition-type:init_boot")"
        # if it mentions "FAILED" then no such partition
        if echo "$v" | grep -qi FAILED; then DEV_INITBOOT="no"; else DEV_INITBOOT="yes? ($v)"; fi
      else
        DEV_INITBOOT="no"
      fi
    fi
  fi
}

print_device_info() {
  device_info
  echo "state:      $DEV_STATE"
  if [[ "$DEV_STATE" != "none" && "$DEV_STATE" != "offline" && "$DEV_STATE" != "unauthorized" ]]; then
    echo "slot:       ${DEV_SLOT:-${DEV_SLOT_RAW:-—}}"
    echo "partition:  $DEV_AB | init_boot=$DEV_INITBOOT | recovery-block=$DEV_RECOVERY_BLOCK"
    [[ -n "$DEV_CODENAME" ]] && echo "device:     ${DEV_CODENAME} (${DEV_MODEL:-—})"
    [[ -n "$DEV_ANDROID" ]] && echo "android:    ${DEV_ANDROID}  patch ${DEV_PATCH:-—}"
    echo "root:       ${DEV_ROOT:-—}"
    [[ -n "$DEV_ORANGEFOX" ]] && echo "recovery:   $DEV_ORANGEFOX"
  fi
}

sha_check() {
  local file="$1" expect="${2:-}"
  [[ -f "$file" ]] || { echo "Not found: $file" >&2; return 1; }
  local got
  got="$(sha256sum "$file" 2>/dev/null | awk '{print $1}')"
  echo "sha256: $got  $(basename "$file")"
  if [[ -n "$expect" ]]; then
    expect="$(echo "$expect" | tr -d ' \r\n\t' | tr '[:upper:]' '[:lower:]')"
    got="$(echo "$got" | tr '[:lower:]' '[:lower:]')"
    if [[ "$got" == "$expect"* || "$expect" == "$got"* ]]; then
      echo "sha OK (matches expected $expect)"
      return 0
    else
      echo "sha MISMATCH — expected $expect, got $got" >&2
      return 2
    fi
  fi
  return 0
}

confirm_danger() {
  local msg="$1"
  echo
  echo "⚠️  $msg"
  echo "   Type 'yes' to continue, anything else to cancel."
  read -rp "   confirm> " ans
  [[ "$ans" == "yes" ]]
}

# ensure adb/fastboot
ensure_tools() {
  local missing=()
  _has_adb || missing+=("android-tools (adb)")
  _has_fastboot || missing+=("android-tools (fastboot)")
  if (( ${#missing[@]} )); then
    echo "Missing: ${missing[*]} — sudo pacman -S android-tools" >&2
    return 1
  fi
}
