#!/usr/bin/env bash
# =============================================================================
# extras/plugins.sh — Install the Omarchy shell plugins enabled in shell.json
#
# The spice config/omarchy/shell.json is the source of truth for which Omarchy
# shell plugins should be present. On a fresh Omarchy machine the first-party
# omarchy.* plugins ship with the system, but every third-party plugin in the
# bar/plugins must be downloaded and installed. That is what this script does:
#
#   * reads the enabled plugin ids out of ~/.config/omarchy/shell.json
#     (already pasted there by install/config/omarchy.sh during the Configs step)
#   * clones each known third-party repo, validates it, and installs it into
#     ~/.config/omarchy/plugins/<id>
#   * rewrites the manifest id to the exact id shell.json references (so the
#     short ids used in the layout always match)
#   * enables it WITHOUT a placement prompt — shell.json already owns the
#     left/center/right layout
#
# It is idempotent and fresh-install only: an already-installed plugin is
# skipped, never updated or clobbered. abr.lock is not a git repo of its own —
# it is the stock omarchy.lock cloned/patched by the face.howdy plugin's
# omarchy-howdy-deploy-lock, so that plugin is wired up last.
#
# Unknown third-party ids (present in shell.json but with no repo entry here)
# are reported and skipped, never silently misfired.
#
# Usage:  bash ~/spice/install/extras/plugins.sh
# Called by: setup.sh (Plugins step); safe to run standalone / re-run.
# Requires: git, jq, outbound HTTPS/SSH to the plugin repos.
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

section "Omarchy Shell Plugins"

# ---------------------------------------------------------------------------
# The id → repo map. Keys are the ids referenced in config/omarchy/shell.json;
# values are the upstream git URLs. Add a line here whenever shell.json gains a
# third-party plugin so a fresh machine can fetch it.
# ---------------------------------------------------------------------------
declare -A PLUGIN_REPOS=(
  [yt-music]="https://github.com/abr60/yt-music.git"
  [agx.screen-time]="https://github.com/ax1g/quickshell-screentime-plugin.git"
  [omaplug]="https://github.com/fross100/omaplug.git"
  [io.github.boyoyooo.omarr]="https://github.com/boyoyooo/omarr.git"
  [thinkfan]="https://github.com/abr60/thinkfan.git"
  [io.github.argusguardian.freemodels]="https://github.com/ArgusGuardian/omarchy-freemodels.git"
  [io.github.elevate08.ynab-glance]="https://github.com/Elevate08/qs-ynab-api.git"
  [io.github.silouanwright.look-elsewhere]="https://github.com/silouanwright/lookelsewhere.git"
  [omapets]="https://github.com/yesmeck/OmaPets.git"
  [io.github.thisisgm.cliampui]="https://github.com/thisisgm/omarchy-cliampui.git"
  [jvb.omafocus]="https://github.com/jvanbaarsen/omafocus.git"
  [abran-labs.notification-center]="https://github.com/abran-labs/omarchy-notification-center.git"
  [maduki-tech.omado]="https://github.com/maduki-tech/omado.git"
  [io.github.grichard99.omaproton-vpn]="https://github.com/grichard99/omaproton-vpn.git"
  [andrewbacon.daynight]="https://github.com/RamenPacket84/DayNight.git"
  [wian47.removable-drives]="https://github.com/Wian47/omarchy-removable-drives.git"
  [activity-monitor]="https://github.com/stappmus/omarchy-activity-monitor.git"
  [abr.netshare]="https://github.com/abr60/netshare.git"
  [overview]="https://github.com/AyushKr2003/omarchy-overview.git"
  [cursor-style]="https://github.com/taxin-404/oma-cursor-style.git"
  [omapets-desktop]="https://github.com/abr60/omapets-desktop.git"
  [face.howdy]="https://github.com/abr60/oma-face-howdy.git"
  [prettyletto.prettyzap]="https://github.com/prettyletto/prettyzap.git"
)

SHELL_JSON="${1:-$HOME/.config/omarchy/shell.json}"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"

# ---------------------------------------------------------------------------
# 0. Locate the shell.json that lists the enabled plugins.
# ---------------------------------------------------------------------------
if [[ ! -f "$SHELL_JSON" ]]; then
  warn "No shell.json at $SHELL_JSON — run the Configs step first (omarchy.sh)."
  warn "Skipping plugin install."
  exit 0
fi

command -v git >/dev/null || die "git not found — needed to clone plugins"
command -v jq  >/dev/null || die "jq not found — needed to read plugin manifests"

ensure_dir "$PLUGINS_DIR"

# ---------------------------------------------------------------------------
# 1. Collect every plugin id referenced anywhere in shell.json.
# ---------------------------------------------------------------------------
mapfile -t REFERENCED < <(jq -r '.. | objects | .id? // empty' "$SHELL_JSON" | sort -u)

if (( ${#REFERENCED[@]} == 0 )); then
  warn "No plugin ids found in $SHELL_JSON"
  exit 0
fi

install_plugin() {
  local id="$1"
  local url="$2"
  local target="$PLUGINS_DIR/$id"

  msg "Installing $id …"
  local stage="$PLUGINS_DIR/.install.tmp.$$"
  rm -rf "$stage"
  if ! git clone --quiet --depth 1 -- "$url" "$stage"; then
    rm -rf "$stage"
    err "failed to clone $url for $id — skipping"
    return 1
  fi

  if ! omarchy-plugin-validate "$stage" >/dev/null 2>&1; then
    rm -rf "$stage"
    err "validation failed for $id — skipping"
    return 1
  fi

  # Rewrite the manifest id to match the id shell.json references.
  local upstream_id
  upstream_id="$(jq -r '.id // empty' "$stage/manifest.json")"
  if [[ -n "$upstream_id" && "$upstream_id" != "$id" ]]; then
    jq --arg id "$id" '.id = $id' "$stage/manifest.json" > "$stage/manifest.json.tmp"
    mv "$stage/manifest.json.tmp" "$stage/manifest.json"
    msg "  manifest id $upstream_id → $id"
  fi

  if ! mv "$stage" "$target"; then
    rm -rf "$stage"
    err "failed to move $id into place — skipping"
    return 1
  fi

  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

  local out
  out="$(omarchy-plugin-enable "$id" 2>&1)" || {
    err "could not enable $id: $out"
    return 1
  }
  ok "installed $id"
}

installed=0
skipped=0
errors=0
face_installed=0

for id in "${REFERENCED[@]}"; do
  case "$id" in
    omarchy.*)
      # First-party — ships with Omarchy, nothing to fetch.
      continue
      ;;
    abr.lock)
      # Handled via face.howdy's deploy-lock (clone + patch of omarchy.lock).
      continue
      ;;
    abr.network)
      # Old name — superseded by abr.netshare. Nothing to install.
      warn "  $id is the old name (now abr.netshare) — ignoring"
      continue
      ;;
  esac

  if [[ -z "${PLUGIN_REPOS[$id]:-}" ]]; then
    warn "  $id referenced in shell.json but has no repo entry — add it to plugins.sh"
    errors=$((errors + 1))
    continue
  fi

  if [[ -e "$PLUGINS_DIR/$id" || -L "$PLUGINS_DIR/$id" ]]; then
    msg "  $id already installed — skipping"
    skipped=$((skipped + 1))
    continue
  fi

  if install_plugin "$id" "${PLUGIN_REPOS[$id]}"; then
    installed=$((installed + 1))
    [[ "$id" == "face.howdy" ]] && face_installed=1
  else
    errors=$((errors + 1))
  fi
done

# ---------------------------------------------------------------------------
# 2. abr.lock: built from stock omarchy.lock by face.howdy's deploy-lock.
# ---------------------------------------------------------------------------
if [[ " ${REFERENCED[*]} " == *" abr.lock "* ]]; then
  if (( face_installed )) || [[ -x "$PLUGINS_DIR/face.howdy/bin/omarchy-howdy-deploy-lock" ]]; then
    msg "Wiring abr.lock (clone + patch stock omarchy.lock) via face.howdy…"
    if bash "$PLUGINS_DIR/face.howdy/bin/omarchy-howdy-deploy-lock"; then
      ok "abr.lock wired"
    else
      err "abr.lock deploy-lock failed"
      errors=$((errors + 1))
    fi
  else
    warn "abr.lock needs face.howdy — install face.howdy first (re-run this step)"
    errors=$((errors + 1))
  fi
fi

# ---------------------------------------------------------------------------
# 3. Summary.
# ---------------------------------------------------------------------------
section "Plugin Summary"
msg "installed: $installed"
[[ "$skipped" -gt 0 ]] && msg "skipped (already present): $skipped"

if (( errors > 0 )); then
  warn "$errors issue(s) — review above"
  exit 0  # non-fatal within setup; errors already shown
fi
ok "All shell plugins present"
