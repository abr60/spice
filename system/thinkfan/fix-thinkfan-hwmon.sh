#!/usr/bin/env bash
# =============================================================================
# fix-thinkfan-hwmon.sh — Rewrites /etc/thinkfan.conf with the current
# coretemp hwmon path. The hwmonN index can change across reboots, so this
# runs before thinkfan.service starts via a systemd drop-in.
# =============================================================================

set -euo pipefail

HWMON_PATH=""
for dir in /sys/devices/platform/coretemp.0/hwmon/hwmon*; do
    if [[ -d "$dir" ]]; then
        HWMON_PATH="$dir"
        break
    fi
done

if [[ -z "$HWMON_PATH" ]]; then
    echo "fix-thinkfan-hwmon: coretemp hwmon path not found" >&2
    exit 1
fi

# Replace any existing hwmonN path with the current one
sed -i -E "s|/sys/devices/platform/coretemp\.0/hwmon/hwmon[0-9]+|${HWMON_PATH}|" /etc/thinkfan.conf

echo "fix-thinkfan-hwmon: set hwmon path to ${HWMON_PATH}"
