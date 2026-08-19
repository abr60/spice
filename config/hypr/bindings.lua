o.bind("ALT + SPACE", "Select theme",  "rofi-set-theme")
o.bind("ALT + B",     "Set wallpaper", "rofi-set-bg")

o.bind("ALT + comma", "Unmount",   "hdd-unmount")

o.bind("XF86NotificationCenter", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })
o.bind("XF86Favorites", "Calibre", { launch = "ebook-viewer '/home/$USER/Calibre Library'" })

o.bind("ALT + C", "RMPC Music", "[float; center] foot --title=rmpc-full -e rmpc")
o.bind("ALT + X", "Study",      "[float; size 700 200; center] foot --override=class=Yazi --title=Yazi -e timeout 30s yazi \"~/Videos/Cowboy-Bebop\"")

o.bind("SUPER + M", "Comic (Latin)", "comic-translate lat")
o.bind("SUPER + N", "Comic (Asian)", "comic-translate cjk")

hl.unbind("SUPER + grave")
o.bind("SUPER + grave", "Overview", "omarchy-shell shell toggle overview")

if o.cmd_present("voxtype") then
  o.bind("ALT + Z", "Toggle dictation", "voxtype record toggle")
  o.bind("F9", "Start dictation (push-to-talk)", "voxtype record start")
  o.bind("F9", "Stop dictation (push-to-talk)", "voxtype record stop", { release = true })
end

-- >>> blizl.voxtype-osd keybindings (managed; removed by bin/uninstall) >>>
o.bind("SUPER + E", "VoxType engine picker", "mkdir -p $XDG_RUNTIME_DIR/voxtype && touch $XDG_RUNTIME_DIR/voxtype/engine-picker.flag")
hl.unbind("SUPER + M")
o.bind("SUPER + M", "VoxType meeting controls", "mkdir -p $XDG_RUNTIME_DIR/voxtype && touch $XDG_RUNTIME_DIR/voxtype/meeting-controls.flag")
-- <<< blizl.voxtype-osd keybindings <<<
