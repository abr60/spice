# Spice Custom Scripts (`bin/`)

Reference for every custom script in the spice repo's `bin/` directory. The
interactive scripts source `bin/lib/helpers.sh` (gum-based: `log_header`,
`log_step`, `log_info`, `log_success`, `log_error`, `log_detail`, `spinner`,
`ask_yes_no`, `log_progress`, `show_done`). Branding logos are read from
`config/hypr/assets/branding/`.

Note: there is **no `battery-monitor`** in the current repo (it existed in the
stale `~/Work/spice` copy but was removed).

---

## comic-translate

OCR + translate comic/manga text from a screen region.

- **Behavior:**
  1. Screenshot selection via `grim -g "$(slurp)"`.
  2. OCR with tesseract — Latin scripts first (`eng+tur+spa`), falling back to
     East Asian (`jpn+kor+chi_sim+spa+tur+eng`) if too little text detected.
  3. Joins lines, compresses whitespace, translates to English with
     translate-shell (`trans -b :en`).
  4. Shows the result in a notification; cleans up the temp image.
- **Dependencies:** grim, slurp, tesseract (+ language data), `trans`
  (translate-shell), notify-send.
- **Usage:** bound in `config/hypr/bindings.lua` — `SUPER+M` (Latin),
  `SUPER+N` (CJK). No arguments.

---

## dots-push

Interactive **force-push** of the user's dotfiles repos to GitHub.

- **Behavior:**
  - Shows a guard screen warning about force-pushing, requires `gum confirm`.
  - `gum choose` menu: **spice (dotfiles)**, **Walls**, **Assets**,
    **Open Lazygit**, **Cancel** (older repos — Archer, Waybar — were removed
    from the menu).
  - For each repo: `git add .`, commit (prompted, default message), then
    `git push --force origin main`.
  - Skips commit if nothing changed (still pushes).
- **Dependencies:** gum, git, lazygit.
- **Helpers:** `bin/lib/helpers.sh`; logo from
  `config/hypr/assets/branding/push.txt`.
- **Caution:** force-push overwrites the remote. Confirm before running.

---

## earbuds-status

Bluetooth device connection/battery **notifier** (polling loop).

- **Behavior:**
  - Polls `bluetoothctl devices Connected` every 5 seconds.
  - On a new connection: notifies with device name + battery % (if reported).
  - On disconnection: notifies.
- **Dependencies:** bluetoothctl, notify-send.
- **Log:** `/tmp/bluetooth_notifier.log`.
- **Usage:** run as a daemon; not interactive.

---

## hdd-status

Status output for the Omarchy bar (JSON widget data).

- **Behavior:**
  - Resolves the external storage drive by UUID
    (`56bad8bd-ec6d-4f9c-8c01-8b49f476ce6e`, label `Storage`).
  - Emits bar JSON: `{"text":" Storage","tooltip":"...","class":"hdd-mounted"}`
    when mounted, or `hdd-unmounted` when connected but not mounted.
  - Exits silently (empty output) when the drive isn't connected.
- **Dependencies:** blkid, lsblk, mountpoint.
- **Usage:** invoked by the bar widget; pair with `hdd-unmount` (bound to
  `ALT+comma`).

---

## hdd-unmount

Safely unmounts the external storage drive.

- **Behavior:**
  - Notifies if drive not connected / already unmounted.
  - Checks for processes using the mount path with `lsof +D`; if busy, shows a
    critical notification listing them and refuses to unmount (does **not** kill).
  - Unmounts via `udisksctl unmount --no-user-interaction`; confirms with a
    notification on success.
- **Dependencies:** blkid, lsof, udisksctl, notify-send.
- **Usage:** bound to `ALT+comma` in `config/hypr/bindings.lua`.

---

## media-download

Interactive **yt-dlp** downloader (video and music modes).

- **Behavior:**
  - Pre-fills URL from clipboard (`wl-paste`) when it looks like a URL.
  - **Every yt-dlp call uses cookies:** `--cookies-from-browser
    chromium::GNOMEKEYRING` (avoids YouTube bot detection).
  - **Rate-limit retry:** failed attempts sleep 5s (3s for playlist detection)
    then retry once with the same command. Error output is captured to a temp
    file and shown on failure (no more silent failures).
  - **Video mode:** folder picker rooted at `~/Videos/Downloaded Videos`
    (can create new folders), quality menu (1080p/720p/480p/360p/best),
    always downloads English subs into a `.subtitles/` folder.
  - **Music mode:** FLAC (preset max compression) / Opus / M4A / MP3, bitrate
    menu (320k/192k/128k), embeds thumbnail + metadata, saves to `~/Music`,
    playlist layout under `~/Music/<playlist>/`.
  - Runs `mpc update` at the end to refresh the MPD library.
- **Dependencies:** yt-dlp, gum, wl-paste, mpc, ffmpeg (for audio extraction).
- **Helpers:** `bin/lib/helpers.sh`; logo from
  `config/hypr/assets/branding/grabber.txt`.
- **Usage:** interactive; run from terminal.

---

## mp4-to-gif

Interactive video → GIF converter (ffmpeg + gifsicle).

- **Behavior:**
  - Pre-fills input file from clipboard if it's a real file path; validates it
    is a video with ffprobe; shows duration + resolution.
  - Options: clip range (full or custom start/duration), output width
    (original/640/480/320/custom), FPS (24/15/10/custom), gifsicle
    optimization (O3/O2/O1/none).
  - Two-pass palette render (palettegen + paletteuse, bayer dithering);
    summarizes the plan and confirms before converting.
  - Shows ffmpeg/gifsicle error tails on failure; reports output size; offers
    to preview with `mpv --loop`.
- **Dependencies:** ffmpeg, gifsicle, gum (verified with a dependency check).
- **Helpers:** `bin/lib/helpers.sh`; logo from
  `config/hypr/assets/branding/mp4-to-gif.txt`.
- **Usage:** interactive; run from terminal.

---

## mpv-launch

GPU-aware MPV wrapper.

- **Behavior:**
  - Detects GPU via `lspci -mm` (VGA/3D/display):
    - NVIDIA / AMD → `hwdec=vulkan`, `gpu-api=vulkan`, `vo=gpu-next`
    - Intel → `hwdec=vaapi`, `gpu-api=vulkan` (falls back to `auto` hwdec if
      `vainfo` shows no VAProfile)
    - Unknown / no lspci → safe `auto` defaults
  - Strips trailing empty arguments; `mpv-launch` with no args shows `mpv --version`.
- **Debug:** `MPV_DEBUG=1 mpv-launch ...` prints detection details to stderr.
- **Usage:** `mpv-launch [file/URL ...]`.

---

## spotify-music-download

Interactive Spotify downloader (track / album / playlist).

- **Behavior:**
  - Pre-fills clipboard URL when it matches `https://open.spotify.com*`;
    validates the URL prefix.
  - Downloads with `spotifydl embedded <url>` (cover art + lyrics embedded).
  - **Before/after snapshot:** lists audio files in `~/Music` (and CWD, for
    spotifydl's fallback behavior) before and after, then moves only the new
    files into `~/Music/Spotify/` via `comm -13`.
  - **Retry:** if spotifydl fails, waits 5s and retries once; shows captured
    stderr on failure.
  - Runs `mpc update` to refresh the MPD library.
- **Dependencies:** spotifydl, gum, wl-paste, mpc, find.
- **Helpers:** `bin/lib/helpers.sh`; logo from
  `config/hypr/assets/branding/grabber.txt`.
- **Usage:** interactive; run from terminal.

---

## write-iso

Interactive **ISO → USB** writer.

- **Behavior:**
  - Lists USB devices via `lsblk -d -n -o NAME,SIZE,TRAN,MODEL` (grep `usb`);
    `gum choose` to select.
  - Picks an ISO with `fzf` (searches `$HOME` for `*.iso`).
  - Warns the device will be erased; requires confirmation.
  - Refreshes sudo in the background; unmounts mounted partitions on the target.
  - Writes with `dd bs=4M oflag=sync`, using `pv` for progress when available.
  - Runs `sync` (without sudo to avoid PAM/fingerprint timeouts) and ejects.
- **Dependencies:** lsblk, gum, fzf, dd, pv (optional), eject, sudo.
- **Helpers:** `bin/lib/helpers.sh`.
- **Caution:** destructive to the selected USB device.

---

## Quick Reference Table

| Script | Interactive | Daemon | Deps (notable) | Key detail |
|--------|:-----------:|:------:|----------------|------------|
| `comic-translate` | ✗ | ✗ | grim, slurp, tesseract, trans | Latin → CJK OCR fallback |
| `dots-push` | ✅ | ✗ | gum, git | Force-pushes to main; spice/Walls/Assets/Lazygit |
| `earbuds-status` | ✗ | ✅ | bluetoothctl | Polls every 5s |
| `hdd-status` | ✗ | ✗ | blkid, lsblk | Bar widget JSON |
| `hdd-unmount` | ✗ | ✗ | udisksctl, lsof | Refuses when busy |
| `media-download` | ✅ | ✗ | yt-dlp, mpc | Cookies via chromium; 5s rate-limit retry |
| `mp4-to-gif` | ✅ | ✗ | ffmpeg, gifsicle | Two-pass palette render |
| `mpv-launch` | ✗ | ✗ | mpv, lspci | GPU-aware hwdec selection |
| `spotify-music-download` | ✅ | ✗ | spotifydl, mpc | Before/after snapshot move |
| `write-iso` | ✅ | ✗ | dd, fzf, pv | Destructive to USB |