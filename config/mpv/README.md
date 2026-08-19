# 🎬 mpv config — Adnan's Setup

A clean, snappy **mpv** configuration for the **Lenovo ThinkPad T14 Gen 2 (Intel i5 / Iris Xe)** running **Omarchy Linux** (Arch + Hyprland / Wayland). Built around uosc, automated subtitle fetching, and a position-aware navigation system. No heavy shaders — optimized to stay fast on laptop hardware.

> Inspired by and adapted from **[HongYue1/mpv-config](https://github.com/HongYue1/mpv-config)**
>
> Amazing autosub from **[davidde/mpv-autosub](https://github.com/davidde/mpv-autosub/tree/master)**

---

## ✨ Highlights

- **Visuals:** `gpu-next` + Vulkan API + `ewa_lanczossharp` — sharp upscaling, no shader overhead
- **Hardware decode:** VA-API on Intel Iris Xe (AV1, HEVC, H.264)
- **Wayland-native:** `gpu-context=auto` for clean Hyprland integration
- **UI:** uosc with Everforest theme + FiraCode Nerd Font
- **Navigation:** Position-aware double-click (seek edges / fullscreen center)
- **Audio:** Dynamic normalization tuned for dialogue clarity
- **Subtitles:** Auto-fetched via subliminal (movies) + yt-dlp (YouTube)

---

## 🖼️ Preview

> Demo screenshots were removed from the repo to keep it lean. See the
> [uosc](https://github.com/tomasklaen/uosc) and [mpv](https://mpv.io) docs
> for what the UI looks like.

---

## ⌨️ Key Bindings

### Playback

| Key | Action |
|:----|:-------|
| `SPACE` | Play / Pause |
| `→` | Seek +5s (hold to fast-forward, bilibili-style via `evafast`) |
| `←` | Seek -5s |
| `Shift+→` / `Shift+←` | Seek ±1s exact |
| `Bs` | Reset speed |
| `Left Click` | Play / Pause |
| `Double Click (outer 15%)` | Seek ±10s |
| `Double Click (center 70%)` | Toggle fullscreen |
| `Right Click` | uosc menu |
| `Scroll` | Volume ±2 |

### Video

| Key | Action |
|:----|:-------|
| `e` | Cycle aspect ratios: 16:9 → 4:3 → 2.35:1 → 21:9 → Auto → 16:9 |
| `Alt+i` | Toggle motion interpolation |
| `D` | Toggle debanding |
| `d` | Toggle deinterlace |
| `Ctrl+→` / `Ctrl+←` | Rotate clockwise / anti-clockwise |
| `!` / `@` | Flip vertical / horizontal |
| `Alt+t` | Toggle always-on-top |
| `Alt+p` | Toggle Picture-in-Picture |

### Subtitles

| Key | Action |
|:----|:-------|
| `j` | Select subtitle track |
| `s` | Cycle subtitle tracks |
| `v` | Toggle visibility |
| `u` | Toggle ASS style override |
| `z` / `x` | Shift timing ±42ms |
| `r` / `t` | Move subtitles up / down |
| `Shift+g` / `Shift+f` | Scale up / down |
| `Shift+BS` | Reset all subtitle settings |
| `Alt+y` | YouTube autosubs (auto, needs video ID in filename) |
| `Alt+Shift+y` | YouTube autosubs (manual — paste URL when prompted) |
| `b` / `n` | Download English / Bangla subtitles (subliminal) |

### Shaders

| Key | Action |
|:----|:-------|
| `Ctrl+1` | Anime4K Mode A — sharp lines |
| `Ctrl+2` | Anime4K Mode B — soft/blurry |
| `Ctrl+3` | Anime4K Mode C — noisy/compressed |
| `Ctrl+0` | Anime4K off |

### File & Misc

| Key | Action |
|:----|:-------|
| `p` | Open file browser |
| `Ctrl+v` | Open URL from clipboard |
| `h` | Open recent files |
| `Shift+o` | Load external subtitles |
| `w` | Show file in directory |
| `Ctrl+r` | Reload file |
| `e` | Cycle aspect ratio |
| `L` / `l` | Toggle loop / A-B loop |
| `i` / `Shift+i` | Stats / toggle stats |
| `?` | Show all keybindings |
| `` ` `` | Open console |
| `Shift+s` | Screenshot |
| `q` / `Shift+q` | Quit / Quit saving position |

---

## 📂 Installation

```bash
cp -r . ~/.config/mpv/
```

---

## 🚀 mpv-launch script

GPU-aware wrapper — detects Intel/AMD/NVIDIA and sets optimal hwdec and gpu-api automatically.

```bash
mkdir -p ~/.config/hypr/scripts/Precious
cp ~/spice/bin/mpv-launch ~/.config/hypr/scripts/Precious/
chmod +x ~/.config/hypr/scripts/Precious/mpv-launch
```

**Debug mode:**
```bash
MPV_DEBUG=1 ~/.config/hypr/scripts/Precious/mpv-launch /path/to/video
```

Kept in `~/.config/hypr/scripts/Precious/` so Omarchy updates never overwrite it.

---

## 🎬 Subtitle Setup

### Movies — automatic via subliminal

Subtitles are fetched automatically when a video opens **only if no subtitle track
is already present** (embedded or external). Auto-download is **English-only**;
Bangla must be triggered manually. Requires `subliminal`:

```bash
pip install subliminal --break-system-packages
```

Configured for **English + Bengali**, using your OpenSubtitles account (`script-opts/autosub.conf`).

**Right-click menu (uosc):** `Subtitles > Download English` (auto) and
`Subtitles > Download Bangla` (manual) trigger a download on demand.
Keybindings: `b` = English, `n` = Bangla.

### YouTube videos — download subs at download time (recommended)

The best workflow — save subtitles alongside the video when downloading:

```bash
yt-dlp --write-subs --write-auto-subs --sub-langs "en,bn" -o "%(title)s.%(ext)s" "URL"
```

MPV picks up the `.en.vtt` / `.bn.vtt` files automatically. No keybind needed.

### YouTube videos — fetch manually during playback

If you know the original URL, press `Alt+Shift+y` and paste it when prompted.

---

## 🔧 Profiles

| Profile | Activates on | Notes |
|:--------|:------------|:------|
| `[hd]` | 720p / 1080p | HighQuality scalers |
| `[sdtv-ntsc]` | SD (480p/540p/576p) | HighQuality scalers |
| `[HighQuality]` | Base for above | HDR peak detection, catmull_rom downscale |
| `[Fast]` | Manual | Bilinear everything, minimal processing |
| `[wallpaper]` | Manual (`--profile=wallpaper`) | Loops forever, no audio, minimal CPU |
| `[pip]` / `[pip-off]` | `Alt+p` toggle | Compact floating window |
| `[Downmix_Audio_5_1/7_1]` | Auto on surround source | Stereo downmix (comment out for surround system) |

---

## 📦 Requirements

```bash
# Core
sudo pacman -S mpv python-pip yt-dlp

# Subtitles
pip install subliminal --break-system-packages

# Hardware decode (Intel)
sudo pacman -S intel-media-driver libva-utils
```

Verify VA-API:
```bash
vainfo
```
