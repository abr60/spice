# YT Music Window Control

A binding-scoped YouTube Music WebApp drop-down for Omarchy Shell with
configurable geometry and compact bar controls.

The bar icon shows the YouTube Music brand. Left click toggles a drop-down
window that loads `music.youtube.com`. Right click opens alignment and size
settings.

## Features

- Drop-down YouTube Music WebApp window with configurable geometry
- Horizontal alignment: Left, Center, or Right
- Adjustable width and height (editable numeric fields with 50 px steps)
- Bar icon visibility toggle with confirmation
- Settings panel: alignment, window size, and icon visibility
- Geometry clamped to usable monitor area (handles transforms, scaling, and
  reserved margins)
- Remembers settings in `shell.json` via the shell's `updateEntryInline` API
- Recovery helper to restore a hidden or removed bar entry
- Keybinding integration: scans effective Lua bindings and rebinds the
  configured key to the drop-down adapter

## Requirements

- Omarchy Shell with the manifest-based plugin runtime
- Hyprland 0.55+ with the Lua provider
- `bash`, `jq`, `lua`, and `hyprctl`

## Install

```bash
omarchy plugin add https://github.com/ilyaZar/yt-music.git --enable
```

Or place it manually:

```bash
mkdir -p ~/.config/omarchy/plugins
cp -r yt-music ~/.config/omarchy/plugins/
omarchy-shell shell rescanPlugins
omarchy plugin enable yt-music
```

## Settings

Defaults are Center, 450 px wide, 800 px high, and icon visible. Settings are
stored inline on the widget's `shell.json` layout entry. The settings panel
right-click menu lets you cycle alignment and adjust dimensions.

| Setting | Type | Default | Description |
|---|---|---|---|
| `alignment` | `Left` / `Center` / `Right` | `Center` | Horizontal window placement |
| `windowWidth` | integer | `450` | Window width in logical pixels |
| `windowHeight` | integer | `800` | Window height in logical pixels |
| `iconVisible` | boolean | `true` | Show the bar icon |

## Keybinding

Stock Omarchy binds `Super+Shift+Alt+M` to the Music action. The plugin scans
the effective Lua configuration and rebinds the matching key to its drop-down
adapter while enabled. Disabling or removing the plugin reloads the Hyprland
configuration so the original action is restored.

## Geometry

The service reads `hyprctl clients -j` and `hyprctl monitors -j`. A present
client selects its reported monitor ID. Only an absent client falls back to the
focused monitor.

Hyprland reports monitor pixel dimensions before output transform. The plugin
swaps width and height for odd transforms, divides by scale, and applies the
reserved margins. Requested dimensions are clamped to the usable rectangle.

## Hide and recover

- **Hide icon** sets `iconVisible` to false. The widget consumes no bar gap and
  its enabled service keeps running.
- **Remove bar entry** removes the widget while leaving the installed plugin
  available.
- **Remove plugin** removes its checkout and shell registration.

Restore a hidden or removed bar entry:

```bash
~/.config/omarchy/plugins/yt-music/bin/yt-music-widget
```

The helper rescans plugins, idempotently puts the widget in its default right
section when absent, and clears `iconVisible`. It also supports `show`, `hide`,
and `status` subcommands.

Remove the plugin without leaving setup files behind:

```bash
omarchy plugin remove yt-music
```

## Validate

```bash
omarchy plugin validate .
bash -n bin/yt-music-widget lib/*.sh scripts/*.sh tests/*.sh *.sh
shellcheck bin/yt-music-widget lib/*.sh scripts/*.sh tests/*.sh *.sh
qmllint -I /usr/share/omarchy/shell Service.qml BarWidget.qml
```

## Structure

| File | Role |
|---|---|
| `BarWidget.qml` | Bar icon, settings panel, keyboard/pointer interaction |
| `Service.qml` | Geometry service, client tracking, Hyprland events |
| `scripts/toggle_cliamp.sh` | Drop-down adapter: launches or toggles the YouTube Music window |
| `scripts/apply_geometry.sh` | Applies alignment and size to the managed client |
| `scripts/sync_bindings.sh` | Scans and rebinds Hyprland keybindings |
| `lib/quake.sh` | Special-workspace toggle logic |
| `lib/geometry.sh` | Monitor geometry calculation and clamping |
| `lib/clients.sh` | Hyprland client filtering helpers |
| `bin/yt-music-widget` | Recovery helper for restoring the bar entry |

## License

MIT
