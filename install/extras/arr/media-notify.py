#!/usr/bin/env python3
"""
media-notify: polls Radarr/Sonarr history APIs and shows desktop toasts
when something is grabbed (download started) or imported (ready to watch).

Host -> container direction only, so it works even when a firewall blocks
container -> host webhooks. Runs as a systemd user service.
"""
import json
import os
import subprocess
import time
import urllib.request

RADARR = {"url": "http://localhost:7878", "key": "~/.config/omarchy/arr/radarr-apikey"}
SONARR = {"url": "http://localhost:8989", "key": "~/.config/omarchy/arr/sonarr-apikey"}
POLL_INTERVAL = 15  # seconds
STATE_FILE = os.path.expanduser("~/.local/state/spice/media-notify-state.json")


def load_key(path):
    with open(os.path.expanduser(path)) as f:
        return f.read().strip()


def notify(summary, body, urgency="normal", icon="video"):
    try:
        subprocess.run(["notify-send", "-u", urgency, "-i", icon, summary, body],
                       check=False, timeout=10)
    except Exception as e:
        print(f"notify-send failed: {e}")


def fetch_history(app):
    url = app["url"] + "/api/v3/history?pageSize=25&sortKey=date&sortDirection=descending"
    req = urllib.request.Request(url, headers={"X-Api-Key": load_key(app["key"])})
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read())
    return data.get("records", [])


def load_state():
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except Exception:
        return {}


def save_state(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)


def describe_event(app_name, rec):
    """Return (summary, body) for a history record, or None to skip."""
    etype = rec.get("eventType", "")
    title = rec.get("sourceTitle", "?")
    quality = ((rec.get("data") or {}).get("quality") or "").replace(" ", "")
    indexer = (rec.get("data") or {}).get("indexer", "")

    if etype == "grabbed" or etype == "Grab":
        return (f"⬇️ Grabbing: {title}", f"{quality} from {indexer}" if indexer else "Starting download…")
    if etype in ("downloadFolderImported", "downloadImported", "Download", "Import", "ImportComplete"):
        return (f"✅ Ready: {title}", f"{quality} — play it on Jellyfin")
    if etype in ("upgraded", "Upgrade"):
        return (f"⬆️ Upgraded: {title}", f"{quality}")
    return None


def poll_once(state):
    for name, app in (("radarr", RADARR), ("sonarr", SONARR)):
        try:
            records = fetch_history(app)
        except Exception as e:
            print(f"{name}: fetch failed: {e}")
            continue
        last_id = state.get(name, 0)
        new_records = [r for r in records if r.get("id", 0) > last_id]
        # only keep the most recent few to avoid toast floods on first run
        for rec in reversed(new_records[:3]):
            desc = describe_event(name, rec)
            if desc:
                notify(*desc)
        if records:
            state[name] = max(r.get("id", 0) for r in records)
    return state


if __name__ == "__main__":
    print(f"media-notify poller started (every {POLL_INTERVAL}s)")
    state = load_state()
    while True:
        state = poll_once(state)
        save_state(state)
        time.sleep(POLL_INTERVAL)