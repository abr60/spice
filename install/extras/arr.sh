#!/usr/bin/env bash
# =============================================================================
# extras/arr.sh — Full portable *arr media stack (one-command setup)
#
# Brings up on a FRESH Omarchy box: Radarr + Sonarr + qBittorrent + Prowlarr
# + FlareSolverr + Jellyfin + Jellyseerr + Bazarr, configures everything via
# their APIs, installs the omARR bar widget, and enables desktop toasts.
#
# Usage:  bash ~/spice/install/extras/arr.sh
# Safe to re-run (sections skip when already configured).
# Requires: interactive session (prompts for passwords) + pkexec for installs.
# =============================================================================

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"

section "Media Stack (*arr)"

SPICE_DIR="${SPICE_DIR:-$HOME/spice}"
ARR_DIR="$HOME/arr"
MEDIA_DIR="$HOME/media"
KEY_DIR="$HOME/.config/omarchy/arr"

# ── helper: prompt (gum when available, plain read otherwise) ───────────────
ask() { # ask <var> <prompt> <default>
    local _var=$1 _prompt=$2 _default=${3:-}
    if command -v gum >/dev/null && [[ -t 0 ]]; then
        printf -v "$_var" "%s" "$(gum input --prompt "$_prompt " --placeholder "$_default")"
    else
        read -r -p "$_prompt${_default:+ [$_default]}: " "$_var"
    fi
    if [[ -z "${!_var:-}" ]]; then printf -v "$_var" "%s" "$_default"; fi
}

# ── 1. Docker ────────────────────────────────────────────────────────────────
if ! command -v docker >/dev/null; then
    warn "docker not found — installing (pkexec, enter password in the dialog)"
    pkexec pacman -S --noconfirm --needed docker docker-compose-plugin
fi
if ! systemctl is-active docker >/dev/null 2>&1; then
    pkexec systemctl enable --now docker
fi
if ! groups | tr ' ' '\n' | grep -qx docker; then
    pkexec usermod -aG docker "$USER"
    warn "Added $USER to docker group — log out/in once for it to apply"
fi
# Docker group membership only takes effect at the NEXT login. If we just
# added the user (fresh box), the current session still can't talk to the
# daemon — bail early with clear instructions instead of dying mid-script.
if ! docker ps &>/dev/null 2>&1; then
    if groups | tr ' ' '\n' | grep -qx docker; then
        warn "Docker daemon not reachable — is the docker service running? (sudo systemctl status docker)"
    else
        warn "Docker daemon not reachable (docker group needs a re-login)"
    fi
    warn "Log out and back in, then re-run: bash $0"
    exit 0
fi
ok "Docker ready: $(docker --version)"

# ── 2. Media directories ─────────────────────────────────────────────────────
mkdir -p "$MEDIA_DIR/movies" "$MEDIA_DIR/tv" "$MEDIA_DIR/downloads"
ok "Media dirs: $MEDIA_DIR/{movies,tv,downloads}"

# ── 3. Compose file + start ──────────────────────────────────────────────────
ask QB_PASS "qBittorrent web UI password" "torrentisabliss"
HOST_TZ=$(timedatectl show -p Timezone --value 2>/dev/null || echo "UTC")
mkdir -p "$ARR_DIR"
cp -f "$SPICE_DIR/install/extras/arr/docker-compose.yml" "$ARR_DIR/docker-compose.yml"
# inject the chosen password + host timezone into the compose file (applies on first boot)
python3 - "$ARR_DIR/docker-compose.yml" "$QB_PASS" "$HOST_TZ" <<'PYEOF'
import re, sys
path, pw, tz = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    content = f.read()
content = re.sub(r'WEBUI_PASSWORD=.*', f'WEBUI_PASSWORD={pw}', content)
content = re.sub(r'TZ=.*', f'TZ={tz}', content)
with open(path, "w") as f:
    f.write(content)
PYEOF
(cd "$ARR_DIR" && docker compose up -d)
ok "Containers started (first pull may take a while)"

# wait for API readiness
wait_api() { # wait_api <url> <keyfile-or-empty>
    local url=$1 keyfile=$2 tries=0
    while (( tries < 60 )); do
        if [[ -n $keyfile ]] && [[ -f $keyfile ]]; then
            curl -sf -H "X-Api-Key: $(cat "$keyfile")" "$url" >/dev/null && return 0
        else
            curl -sf "$url" >/dev/null && return 0
        fi
        sleep 5; tries=$((tries+1))
    done
    return 1
}

# ── 4. Extract API keys (auto-generated on first boot) ───────────────────────
# Containers need time to boot and write their config.xml — poll for keys.
mkdir -p "$KEY_DIR"
for _ in $(seq 1 60); do
    RADARR_KEY=$(docker exec radarr cat /config/config.xml 2>/dev/null | grep -oP '(?<=<ApiKey>)[^<]+' || true)
    SONARR_KEY=$(docker exec sonarr cat /config/config.xml 2>/dev/null | grep -oP '(?<=<ApiKey>)[^<]+' || true)
    PROWLARR_KEY=$(docker exec prowlarr cat /config/config.xml 2>/dev/null | grep -oP '(?<=<ApiKey>)[^<]+' || true)
    if [[ -n $RADARR_KEY && -n $SONARR_KEY && -n $PROWLARR_KEY ]]; then
        break
    fi
    sleep 5
done
if [[ -z $RADARR_KEY || -z $SONARR_KEY || -z $PROWLARR_KEY ]]; then
    err "Failed to extract API keys (radarr=${RADARR_KEY:+ok} sonarr=${SONARR_KEY:+ok} prowlarr=${PROWLARR_KEY:+ok}) — containers may not have booted, check: docker compose -f $ARR_DIR/docker-compose.yml logs"
    exit 1
fi
[[ -n $RADARR_KEY ]] && { printf '%s' "$RADARR_KEY" > "$KEY_DIR/radarr-apikey"; chmod 600 "$KEY_DIR/radarr-apikey"; }
[[ -n $SONARR_KEY ]] && { printf '%s' "$SONARR_KEY" > "$KEY_DIR/sonarr-apikey"; chmod 600 "$KEY_DIR/sonarr-apikey"; }
[[ -n $PROWLARR_KEY ]] && { printf '%s' "$PROWLARR_KEY" > "$KEY_DIR/prowlarr-apikey"; chmod 600 "$KEY_DIR/prowlarr-apikey"; }
ok "API keys saved to $KEY_DIR"

wait_api "http://localhost:7878/api/v3/system/status" "$KEY_DIR/radarr-apikey" || { err "Radarr not ready"; exit 1; }
wait_api "http://localhost:8989/api/v3/system/status" "$KEY_DIR/sonarr-apikey" || { err "Sonarr not ready"; exit 1; }
wait_api "http://localhost:9696/api/v1/system/status" "$KEY_DIR/prowlarr-apikey" || { err "Prowlarr not ready"; exit 1; }
ok "Radarr + Sonarr + Prowlarr APIs ready"

# ── 5. Radarr config: root folder + download client ──────────────────────────
RKEY="$RADARR_KEY"
if ! curl -sf -H "X-Api-Key: $RKEY" "http://localhost:7878/api/v3/rootfolder" \
    | jq -e '.[] | select(.path == "/media/movies")' >/dev/null 2>&1; then
    curl -sf -H "X-Api-Key: $RKEY" -H "Content-Type: application/json" \
        -d '{"path":"/media/movies"}' "http://localhost:7878/api/v3/rootfolder" >/dev/null || warn "Radarr root folder create failed"
fi
ok "Radarr root folder /media/movies"

if ! curl -sf -H "X-Api-Key: $RKEY" "http://localhost:7878/api/v3/downloadclient" \
        | jq -e '.[] | select(.name == "qBittorrent")' >/dev/null 2>&1; then
    curl -sf -H "X-Api-Key: $RKEY" -H "Content-Type: application/json" \
        -d "{\"enable\":true,\"name\":\"qBittorrent\",\"implementation\":\"QBittorrent\",\"configContract\":\"QBittorrentSettings\",\"fields\":[{\"name\":\"host\",\"value\":\"qbittorrent\"},{\"name\":\"port\",\"value\":8080},{\"name\":\"username\",\"value\":\"abr\"},{\"name\":\"password\",\"value\":\"$QB_PASS\"},{\"name\":\"movieCategory\",\"value\":\"radarr\"}]}" \
        "http://localhost:7878/api/v3/downloadclient" >/dev/null || warn "Radarr download client create failed"
fi
ok "Radarr download client → qBittorrent"

# ── 6. Sonarr config: root folder + download client ──────────────────────────
SKEY="$SONARR_KEY"
if ! curl -sf -H "X-Api-Key: $SKEY" "http://localhost:8989/api/v3/rootfolder" \
    | jq -e '.[] | select(.path == "/media/tv")' >/dev/null 2>&1; then
    curl -sf -H "X-Api-Key: $SKEY" -H "Content-Type: application/json" \
        -d '{"path":"/media/tv"}' "http://localhost:8989/api/v3/rootfolder" >/dev/null || warn "Sonarr root folder create failed"
fi
ok "Sonarr root folder /media/tv"

if ! curl -sf -H "X-Api-Key: $SKEY" "http://localhost:8989/api/v3/downloadclient" \
        | jq -e '.[] | select(.name == "qBittorrent")' >/dev/null 2>&1; then
    curl -sf -H "X-Api-Key: $SKEY" -H "Content-Type: application/json" \
        -d "{\"enable\":true,\"name\":\"qBittorrent\",\"implementation\":\"QBittorrent\",\"configContract\":\"QBittorrentSettings\",\"fields\":[{\"name\":\"host\",\"value\":\"qbittorrent\"},{\"name\":\"port\",\"value\":8080},{\"name\":\"username\",\"value\":\"abr\"},{\"name\":\"password\",\"value\":\"$QB_PASS\"},{\"name\":\"tvCategory\",\"value\":\"sonarr\"}]}" \
        "http://localhost:8989/api/v3/downloadclient" >/dev/null || warn "Sonarr download client create failed"
fi
ok "Sonarr download client → qBittorrent"

# ── 7. Prowlarr: FlareSolverr proxy + indexers + applications ────────────────
PKEY="$PROWLARR_KEY"
PKURL="http://localhost:9696/api/v1"

# FlareSolverr proxy (only if container is up)
if docker ps --format '{{.Names}}' | grep -qx flaresolverr; then
    if ! curl -sf -H "X-Api-Key: $PKEY" "$PKURL/indexerproxy" | jq -e '.[] | select(.name == "FlareSolverr")' >/dev/null 2>&1; then
        curl -sf -H "X-Api-Key: $PKEY" -H "Content-Type: application/json" \
            -d '{"name":"FlareSolverr","implementation":"FlareSolverr","configContract":"FlareSolverrSettings","fields":[{"name":"host","value":"http://flaresolverr:8191/"},{"name":"requestTimeout","value":60}]}' \
            "$PKURL/indexerproxy" >/dev/null
    fi
    ok "FlareSolverr proxy configured"
fi

# tag for proxy linkage (proxyId field is ignored; tags link them)
TAG_ID=$(curl -sf -H "X-Api-Key: $PKEY" "$PKURL/tag" | jq -r '.[] | select(.label=="flare") | .id' 2>/dev/null | head -1)
if [[ -z $TAG_ID ]]; then
    TAG_ID=$(curl -sf -H "X-Api-Key: $PKEY" -H "Content-Type: application/json" \
        -d '{"label":"flare"}' "$PKURL/tag" | jq -r '.id // empty')
    FPROXY_ID=$(curl -sf -H "X-Api-Key: $PKEY" "$PKURL/indexerproxy" | jq -r '.[0].id // empty')
    if [[ -n $FPROXY_ID ]]; then
        curl -sf -X PUT -H "X-Api-Key: $PKEY" -H "Content-Type: application/json" \
            -d "{\"tags\":[$TAG_ID]}" "$PKURL/indexerproxy/$FPROXY_ID" >/dev/null
    fi
fi

add_indexer() { # add_indexer <name> <definitionFile> <baseUrl> <tag-id-or-empty>
    local name=$1 df=$2 base=$3 tag=${4:-}
    if curl -sf -H "X-Api-Key: $PKEY" "$PKURL/indexer" | jq -e --arg n "$name" '.[] | select(.name == $n)' >/dev/null 2>&1; then
        return 0
    fi
    local body
    if [[ -n $tag ]]; then
        body=$(jq -nc --arg n "$name" --arg d "$df" --arg b "$base" --argjson t "$tag" \
            '{name:$n,implementation:"Cardigann",configContract:"CardigannSettings",appProfileId:1,priority:10,enable:true,tags:[$t],fields:[{name:"definitionFile",value:$d},{name:"baseUrl",value:$b},{name:"baseSettings.limitsUnit",value:0},{name:"torrentBaseSettings.preferMagnetUrl",value:false}]}')
    else
        body=$(jq -nc --arg n "$name" --arg d "$df" --arg b "$base" \
            '{name:$n,implementation:"Cardigann",configContract:"CardigannSettings",appProfileId:1,priority:10,enable:true,fields:[{name:"definitionFile",value:$d},{name:"baseUrl",value:$b},{name:"baseSettings.limitsUnit",value:0},{name:"torrentBaseSettings.preferMagnetUrl",value:false}]}')
    fi
    curl -sf -H "X-Api-Key: $PKEY" -H "Content-Type: application/json" \
        -d "$body" "$PKURL/indexer" >/dev/null || { warn "Failed to add indexer $name ($df) — check Prowlarr logs"; return 0; }
}

add_indexer "Knaben" "knaben" "https://knaben.org/"
add_indexer "The Pirate Bay" "thepiratebay" "https://thepiratebay.org/"
add_indexer "YTS" "yts" "https://yts.gg/"
add_indexer "LimeTorrents" "limetorrents" "https://www.limetorrents.fun/"
add_indexer "Nyaa" "nyaasi" "https://nyaa.si/"
add_indexer "EZTV" "eztv" "https://eztvx.to/" "$TAG_ID"
ok "Prowlarr indexers: Knaben, TPB, YTS, LimeTorrents, Nyaa, EZTV"

# applications → Radarr + Sonarr (fullSync)
if ! curl -sf -H "X-Api-Key: $PKEY" "$PKURL/applications" | jq -e '.[] | select(.name == "Radarr")' >/dev/null 2>&1; then
    curl -sf -H "X-Api-Key: $PKEY" -H "Content-Type: application/json" \
        -d "{\"name\":\"Radarr\",\"implementation\":\"Radarr\",\"configContract\":\"RadarrSettings\",\"syncLevel\":\"fullSync\",\"fields\":[{\"name\":\"prowlarrUrl\",\"value\":\"http://prowlarr:9696\"},{\"name\":\"baseUrl\",\"value\":\"http://radarr:7878\"},{\"name\":\"apiKey\",\"value\":\"$RADARR_KEY\"},{\"name\":\"syncCategories\",\"value\":[2000,2030,2040,2050,2060,2070,2080]}]}" \
        "$PKURL/applications" >/dev/null
fi
if ! curl -sf -H "X-Api-Key: $PKEY" "$PKURL/applications" | jq -e '.[] | select(.name == "Sonarr")' >/dev/null 2>&1; then
    curl -sf -H "X-Api-Key: $PKEY" -H "Content-Type: application/json" \
        -d "{\"name\":\"Sonarr\",\"implementation\":\"Sonarr\",\"configContract\":\"SonarrSettings\",\"syncLevel\":\"fullSync\",\"fields\":[{\"name\":\"prowlarrUrl\",\"value\":\"http://prowlarr:9696\"},{\"name\":\"baseUrl\",\"value\":\"http://sonarr:8989\"},{\"name\":\"apiKey\",\"value\":\"$SONARR_KEY\"},{\"name\":\"syncCategories\",\"value\":[5000,5010,5020,5030,5040,5045,5050,5060,5070]}]}" \
        "$PKURL/applications" >/dev/null
fi
ok "Prowlarr → Radarr + Sonarr applications linked"

# ── 8. Jellyfin admin ─────────────────────────────────────────────────────────
ask JF_PASS "Jellyfin admin password" "MediaPass123!"
JF_USER=$(curl -sf "http://localhost:8096/Startup/User" 2>/dev/null | jq -r '.Name // empty' 2>/dev/null || true)
if [[ -z $JF_USER ]]; then
    # fresh install: complete startup wizard
    curl -sf -X POST "http://localhost:8096/Startup/User" -H "Content-Type: application/json" \
        -d "{\"Name\":\"admin\"}" >/dev/null || true
    curl -sf -X POST "http://localhost:8096/Startup/Configuration" -H "Content-Type: application/json" \
        -d '{}' >/dev/null || true
    curl -sf -X POST "http://localhost:8096/Startup/Complete" >/dev/null || true
    # wait for real login to work (poll the public API until it accepts auth)
    for _ in $(seq 1 60); do
        if curl -sf "http://localhost:8096/System/Info/Public" >/dev/null 2>&1; then
            sleep 5  # give the auth subsystem a beat after the wizard completes
            break
        fi
        sleep 5
    done
    JF_USER="admin"
fi
# set/reset admin password via API (needs token)
JF_TOKEN=$(curl -sf -X POST "http://localhost:8096/Users/AuthenticateByName" \
    -H "Content-Type: application/json" \
    -H "X-Emby-Authorization: MediaBrowser Client=\"omarr-setup\", Device=\"omarr-setup\", DeviceId=\"omarr-setup\", Version=\"1.0\"" \
    -d "{\"Username\":\"admin\",\"Pw\":\"$JF_PASS\"}" 2>/dev/null | jq -r '.AccessToken' 2>/dev/null || true)
if [[ -z $JF_TOKEN ]]; then
    # fresh admin has NO password yet → authenticate with empty pw
    JF_TOKEN=$(curl -sf -X POST "http://localhost:8096/Users/AuthenticateByName" \
        -H "Content-Type: application/json" \
        -H "X-Emby-Authorization: MediaBrowser Client=\"omarr-setup\", Device=\"omarr-setup\", DeviceId=\"omarr-setup\", Version=\"1.0\"" \
        -d "{\"Username\":\"admin\",\"Pw\":\"\"}" 2>/dev/null | jq -r '.AccessToken' 2>/dev/null || true)
fi
if [[ -n $JF_TOKEN ]]; then
    JF_ADMIN_ID=$(curl -sf -H "X-Emby-Token: $JF_TOKEN" "http://localhost:8096/Users" | jq -r '.[] | select(.Name=="admin") | .Id' | head -1)
    curl -sf -X POST -H "X-Emby-Token: $JF_TOKEN" -H "Content-Type: application/json" \
        -d "{\"Id\":\"$JF_ADMIN_ID\",\"NewPw\":\"$JF_PASS\",\"ResetPassword\":false}" \
        "http://localhost:8096/Users/$JF_ADMIN_ID/Password" >/dev/null || true
    ok "Jellyfin admin password set"
else
    warn "Could not reach Jellyfin auth — set admin password at http://localhost:8096 manually"
fi

# ── 9. Jellyseerr ────────────────────────────────────────────────────────────
JERR_OK=false
if wait_api "http://localhost:5055/api/v1/status" ""; then
    JERR_COOKIE="/tmp/jerr-cookies.txt"
    JERR_USER=$(curl -s -c "$JERR_COOKIE" -X POST "http://localhost:5055/api/v1/auth/jellyfin" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"admin\",\"password\":\"$JF_PASS\",\"hostname\":\"jellyfin\",\"port\":8096,\"useSsl\":false,\"urlBase\":\"\",\"email\":\"$USER@localhost\",\"serverType\":2}" \
        | jq -r '.id // empty' 2>/dev/null || true)
    if [[ -n $JERR_USER ]]; then
        JERR_OK=true
        ok "Jellyseerr authed with Jellyfin"
        # finish onboarding so the API accepts config writes
        curl -s -b "$JERR_COOKIE" -X POST "http://localhost:5055/api/v1/settings/initialize" >/dev/null 2>&1 || true
        curl -s -b "$JERR_COOKIE" -X POST "http://localhost:5055/api/v1/settings/main" \
            -H "Content-Type: application/json" -d '{"locale":"en"}' >/dev/null 2>&1 || true
        # sync + enable Jellyfin libraries (movies + shows)
        LIB_IDS=$(curl -s -b "$JERR_COOKIE" "http://localhost:5055/api/v1/settings/jellyfin/library?sync=true" \
            | jq -r '[.[] | select(.type == "movie" or .type == "show") | .id] | join(",")' 2>/dev/null || true)
        if [[ -n $LIB_IDS ]]; then
            curl -s -b "$JERR_COOKIE" "http://localhost:5055/api/v1/settings/jellyfin/library?enable=$LIB_IDS" >/dev/null 2>&1 || true
        fi
        # connect Radarr (profile 4 = HD-1080p, root /media/movies)
        curl -s -b "$JERR_COOKIE" -X POST "http://localhost:5055/api/v1/settings/radarr" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"Radarr\",\"hostname\":\"radarr\",\"port\":7878,\"apiKey\":\"$RADARR_KEY\",\"useSsl\":false,\"baseUrl\":\"\",\"activeProfileId\":4,\"activeProfileName\":\"HD-1080p\",\"activeDirectory\":\"/media/movies\",\"is4k\":false,\"minimumAvailability\":\"announced\",\"isDefault\":true,\"syncEnabled\":true,\"preventSearch\":false}" \
            >/dev/null 2>&1 || true
        # connect Sonarr (profile 6 = HD-720p/1080p, root /media/tv)
        curl -s -b "$JERR_COOKIE" -X POST "http://localhost:5055/api/v1/settings/sonarr" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"Sonarr\",\"hostname\":\"sonarr\",\"port\":8989,\"apiKey\":\"$SONARR_KEY\",\"useSsl\":false,\"baseUrl\":\"\",\"activeProfileId\":6,\"activeProfileName\":\"HD - 720p/1080p\",\"activeDirectory\":\"/media/tv\",\"activeLanguageProfileId\":1,\"enableSeasonFolders\":true,\"is4k\":false,\"isDefault\":true,\"syncEnabled\":true,\"preventSearch\":false}" \
            >/dev/null 2>&1 || true
        # full library scan
        curl -s -b "$JERR_COOKIE" -X POST "http://localhost:5055/api/v1/settings/jellyfin/sync" \
            -H "Content-Type: application/json" -d '{"start":true}' >/dev/null 2>&1 || true
        ok "Jellyseerr configured (libraries + Radarr + Sonarr)"
    else
        warn "Jellyseerr auth failed (Jellyfin pw correct?) — configure at http://localhost:5055"
    fi
else
    warn "Jellyseerr not up — skipping"
fi

# ── 10. Bazarr ────────────────────────────────────────────────────────────────
BAZARR_OK=false
if wait_api "http://localhost:6767/" ""; then
    BKEY=$(docker exec bazarr cat /config/config.yaml 2>/dev/null | grep -oP '(?<=apikey:\s).*' | head -1 | tr -d '"' || true)
    if [[ -n $BKEY ]]; then
        BAZARR_OK=true
        BURL="http://localhost:6767/api"
        # enable providers + connect radarr/sonarr
        curl -s -X POST -H "X-API-KEY: $BKEY" "$BURL/system/settings" \
            --data-urlencode "settings-general-use_radarr=true" \
            --data-urlencode "settings-general-use_sonarr=true" \
            --data-urlencode "settings-radarr-apikey=$RADARR_KEY" \
            --data-urlencode "settings-radarr-ip=radarr" \
            --data-urlencode "settings-radarr-port=7878" \
            --data-urlencode "settings-sonarr-apikey=$SONARR_KEY" \
            --data-urlencode "settings-sonarr-ip=sonarr" \
            --data-urlencode "settings-sonarr-port=8989" \
            --data-urlencode "languages-enabled=en" \
            --data-urlencode "settings-general-enabled_providers=yifysubtitles" \
            --data-urlencode "settings-general-enabled_providers=tvsubtitles" \
            --data-urlencode "settings-general-enabled_providers=subs4free" \
            --data-urlencode "settings-general-enabled_providers=subscenter" \
            --data-urlencode "settings-general-enabled_providers=subf2m" \
            --data-urlencode "settings-subf2m-user_agent=Mozilla/5.0 (X11; Linux x86_64; rv:126.0) Gecko/20100101 Firefox/126.0" \
            --data-urlencode "settings-general-movie_default_profile=1" \
            --data-urlencode "settings-general-serie_default_profile=1" \
            --data-urlencode "languages-profiles=[{\"profileId\":1,\"name\":\"English\",\"cutoff\":1,\"items\":[{\"id\":1,\"language\":\"en\",\"audio_exclude\":false,\"audio_only_include\":false,\"hi\":false,\"forced\":false,\"original_format\":false}],\"mustContain\":\"\",\"mustNotContain\":\"\",\"originalFormat\":false,\"tag\":null}]" \
            >/dev/null 2>&1 && ok "Bazarr configured (English subs, 5 free providers)" || warn "Bazarr config POST failed — configure at http://localhost:6767"
    else
        warn "Bazarr API key not found — configure at http://localhost:6767"
    fi
else
    warn "Bazarr not up — skipping"
fi

# ── 11. omARR bar widget ──────────────────────────────────────────────────────
if [[ ! -d "$HOME/.config/omarchy/plugins/io.github.boyoyooo.omarr" ]]; then
    omarchy plugin clone io.github.boyoyooo.omarr || warn "omarr plugin clone failed — clone manually"
fi
SHELL_JSON="$HOME/.config/omarchy/shell.json"
if ! grep -q '"label": "Radarr"' "$SHELL_JSON" 2>/dev/null; then
    # insert two configured entries into bar.layout.right (before closing ])
    python3 - "$SHELL_JSON" <<'PYEOF'
import json, sys, copy
path = sys.argv[1]
with open(path) as f:
    cfg = json.load(f)
right = cfg["bar"]["layout"]["right"]
base = {"type": "widget", "plugin": "io.github.boyoyooo.omarr", "interval": 60}
radarr = copy.deepcopy(base); radarr.update({"app": "radarr", "label": "Radarr", "url": "http://localhost:7878", "apiKeyFile": "/home/" + __import__('getpass').getuser() + "/.config/omarchy/arr/radarr-apikey", "qualityProfileId": 4, "rootFolderPath": "/media/movies"})
sonarr = copy.deepcopy(base); sonarr.update({"app": "sonarr", "label": "Sonarr", "url": "http://localhost:8989", "apiKeyFile": "/home/" + __import__('getpass').getuser() + "/.config/omarchy/arr/sonarr-apikey", "qualityProfileId": 6, "rootFolderPath": "/media/tv", "seasonFolder": True, "monitorMode": "all"})
right.extend([sonarr, radarr])
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
PYEOF
    omarchy restart shell || warn "omarchy restart shell failed — run manually"
    ok "omARR widget added to bar (Radarr + Sonarr)"
else
    ok "omARR widget already in shell.json"
fi

# ── 12. media-notify toasts ───────────────────────────────────────────────────
cp -f "$SPICE_DIR/install/extras/arr/media-notify.py" "$ARR_DIR/media-notify.py"
chmod +x "$ARR_DIR/media-notify.py"
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/media-notify.service" <<EOF
[Unit]
Description=media-notify poller (Radarr/Sonarr desktop toasts)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $ARR_DIR/media-notify.py
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now media-notify.service 2>/dev/null || true
ok "media-notify toasts enabled"

# ── 13. Jellyfin Desktop app (native client; NOT a webapp) ───────────────────
if ! command -v flatpak >/dev/null; then
    warn "flatpak not found — installing (pkexec)"
    pkexec pacman -S --noconfirm --needed flatpak
fi
if ! flatpak remotes 2>/dev/null | grep -qx flathub; then
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || \
        pkexec flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi
if flatpak list --app 2>/dev/null | grep -q org.jellyfin.JellyfinDesktop; then
    ok "Jellyfin Desktop app already installed"
else
    flatpak install -y --system flathub org.jellyfin.JellyfinDesktop >/dev/null 2>&1 || \
        flatpak install -y flathub org.jellyfin.JellyfinDesktop || warn "Jellyfin Desktop flatpak install failed"
    ok "Jellyfin Desktop app installed"
fi

# ── 14. Summary ───────────────────────────────────────────────────────────────
section "Stack URLs"
cat <<EOF
  Radarr      http://localhost:7878   (movies)
  Sonarr      http://localhost:8989   (TV)
  qBittorrent http://localhost:8080   (abr / $QB_PASS)
  Prowlarr    http://localhost:9696   (indexers)
  Jellyfin    http://localhost:8096   (admin / $JF_PASS)
  Jellyseerr  http://localhost:5055   (requests)
  Bazarr      http://localhost:6767   (subtitles)
  omARR widget on bar → Radarr + Sonarr; toasts via media-notify
EOF
ok "Media stack ready!"