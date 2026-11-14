# Waydroid on omarchy — setup notes & failure modes

> **Machine:** omarchy (Arch, kernel `7.2.15-1-omarchy`, Hyprland/Wayland)
> **Last verified:** 2026-11-11 · waydroid 1.6.3-1 · LineageOS 20 GAPPS (system `20.0-20260927`, vendor `20.0-20261022` MAINLINE, x86_64)
> **Source of truth for the automation:** `install/extras/waydroid.sh`

---

## TL;DR — state of the box

| Thing | State |
| --- | --- |
| `waydroid` CLI | works via `/usr/local/bin/waydroid` wrapper (system python) |
| Images | `/var/lib/waydroid/images/{system.img,vendor.img}` (~2.5 G + 537 M), GAPPS |
| `waydroid-container.service` | enabled + active |
| `virt_wifi` | loaded, persisted in `/etc/modules-load.d/waydroid.conf` |
| Internet inside Android | works — presented as **Ethernet** (validated, default network) |
| WiFi toggle inside Android | **always grey/disabled — by design**, not a bug |
| Launcher entries `waydroid.*.desktop` | hidden via `NoDisplay=true` (`hide_waydroid`) |

Start it:

```bash
waydroid session start &        # per-session; container is a systemd service
waydroid show-full-ui           # or launch "Waydroid" from the app launcher
waydroid status                 # expect Session: RUNNING / Container: RUNNING + IP
```

---

## Failure 1 — `ModuleNotFoundError: No module named 'dbus'` (waydroid won't start at all)

**Symptom**

```
Traceback (most recent call last):
  File "/usr/bin/waydroid", line 7, in <module>
    import tools
  File "/usr/lib/waydroid/tools/__init__.py", line 8, in <module>
    import dbus.mainloop.glib
ModuleNotFoundError: No module named 'dbus'
```

**Cause:** `/usr/bin/waydroid` uses `#!/usr/bin/env python3`. A mise-managed python
(`~/.local/share/mise/installs/python/3.13/bin`, global via `~/.config/mise/config.toml`)
comes first in PATH, so `env python3` picks 3.13 — which has **no `python-dbus`**.
Arch's `python-dbus` is built for the system python (`/usr/bin/python3`, 3.14).
Diagnosis one-liner: `/usr/bin/python3 -c "import dbus"` succeeds, `python3 -c "import dbus"` fails.

**Fix (applied, permanent):** `/usr/local/bin/waydroid` wrapper that forces the system interpreter:

```sh
#!/bin/sh
exec /usr/bin/python3 /usr/bin/waydroid "$@"
```

`/usr/local/bin` precedes `/usr/bin` in PATH **and** in sudo's `secure_path`, and pacman
never overwrites it — so it survives waydroid upgrades and mise version bumps.
Installed idempotently by `install/extras/waydroid.sh`.

> Don't "fix" this by editing the shebang of `/usr/bin/waydroid` — that is pacman-owned and
> gets reverted on upgrade. Don't `pip install dbus-python` into mise's python either.

---

## Failure 2 — "not initialized" / missing images

`waydroid status` → `Waydroid is not initialized, run "waydroid init"`, and
`/var/lib/waydroid` does not exist. Nothing was ever downloaded.

```bash
sudo /usr/bin/python3 /usr/bin/waydroid init -s GAPPS   # vanilla = drop -s GAPPS
sudo systemctl enable --now waydroid-container.service
```

Notes:
- Images come from `ota.waydro.id` → SourceForge redirects, ~1.19 GB system + 190 MB vendor,
  roughly 1–5 MB/s here: allow **20–45 min**.
- `waydroid init` **restarts the download from zero** if it is interrupted — do not kill it.
  Run it detached (`setsid nohup ... >log 2>&1 &`) if your shell may time out.
- Progress lines use `\r`, so pipe through a file, not a pager.
- Verify with `ls -lh /var/lib/waydroid/images` (system.img ~2.5 G, vendor.img ~537 M).

---

## Failure 3 — "Waydroid has no internet / no WiFi"

**Symptoms:** container has an IP (e.g. `192.168.240.112`) but apps report no connection;
`dumpsys connectivity` → `Active default network: none`; inside the container
`ip route` shows only `192.168.240.0/24 dev eth0` (no default route).

**What is actually broken:** netd never brought the Ethernet network up as the default
network. Root of it was `virt_wifi` not being loaded at container start — inside the
Android side that shows up as:

```
E wificond: Can't get wlan0 index: No such device
E wificond: Failed to get wiphy index
```

**Fix (applied):**

```bash
sudo modprobe virt_wifi
echo virt_wifi | sudo tee /etc/modules-load.d/waydroid.conf   # persist across reboots
sudo systemctl restart waydroid-container.service               # then start a new session
```

**Verify:** `sudo waydroid shell -- dumpsys connectivity | head -20` must show

```
Active default network: 100
NetworkAgentInfo{... ni{Ethernet CONNECTED ...}  nc{[ Transports: ETHERNET
  Capabilities: NOT_METERED&INTERNET&...&VALIDATED ...
```

and `sudo waydroid shell -- ping -c2 8.8.8.8` plus a DNS lookup (`ping google.com`
resolves; Google drops ICMP, so 0 replies is normal).

**About the Wifi toggle:** Android inside Waydroid has **no wifi hardware** and no working
wifi HAL on this kernel (`ip link add wlan0 type virt_wifi` → `RTNETLINK answers: Invalid
argument`, on the host too). Connectivity is emulated as *Ethernet*. So "Wifi is disabled" in
Settings and the absent wifi list are cosmetic; anything that only checks
`ConnectivityManager` INTERNET capability works fine. Do not chase this again.

---

## Hotkey-free housekeeping

- Hide freshly installed Android apps from the launcher: `hide_waydroid`
  (function in `zshrc/functions`, called from `zshrc/init`, inserts `NoDisplay=true`
  into `~/.local/share/applications/waydroid.*.desktop`).
- Android shell as root (needed for most diagnostics — `waydroid shell` alone complains
  about `--details-to-stdout`): `sudo waydroid shell -- sh -c '...'`
- Confusing but normal: `systemctl is-active waydroid-container` = `active` while
  the *container* is stopped — the LXC container only runs while a session is running.
  `waydroid session stop` leaves the service up; start a session again to get it back.
- Container logs: `/var/lib/waydroid/waydroid.log`; session log is whatever you redirect it to.
- Play Protect certification (GAPPS only, optional): register the device ID from
  `sqlite3 /data/data/com.google.android.gsf/databases/gservices.db "select * from main"`.

## Gotchas that cost time here

1. `sudo` on this box triggers the face-auth PAM module → every sudo prints camera warnings
   (`Failed to open camera device`, `WARN: ... VIDEOIO(V4L2)`). Ignore them; filter with
   `grep -v -E 'WARN:|dark|Camera'`.
2. `sudo` needs a password interactively — an agent cannot type it. Either ask the user, or
   `echo '<pw>' | sudo -S ...` when the user has supplied it for that session.
3. `waydroid` from a shell without `WAYLAND_DISPLAY` fails to start the session; propagate
   `WAYLAND_DISPLAY` / `XDG_RUNTIME_DIR=/run/user/1000` when launching it detached.
4. `waydroid init` writes `waydroid.cfg` before the images finish — a `waydroid.cfg` alone
   does **not** mean "initialized". Check `images/` too.
