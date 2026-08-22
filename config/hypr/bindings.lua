o.bind("ALT + comma", "Unmount",   "hdd-unmount")

o.bind("XF86NotificationCenter", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })
o.bind("XF86Favorites", "Calibre", { launch = "ebook-viewer '/home/$USER/Calibre Library'" })

o.bind("ALT + C", "RMPC Music", "[float; center] foot --title=rmpc-full -e rmpc")
o.bind("ALT + X", "Study",      "[float; size 700 200; center] foot --override=class=Yazi --title=Yazi -e timeout 30s yazi \"~/media/downloads/Breaking.Bad.SEASON.01.S01.COMPLETE.1080p.10bit.BluRay.6CH.x265.HEVC-PSA/\"")

o.bind("SUPER + M", "Comic (Latin)", "comic-translate lat")
o.bind("SUPER + N", "Comic (Asian)", "comic-translate cjk")

hl.unbind("SUPER + grave")
o.bind("SUPER + grave", "Overview", "omarchy-shell shell toggle overview")

o.bind("SUPER + A", "AI Agent", "omarchy-agent")

if o.cmd_present("voxtype") then
  o.bind("ALT + Z", "Toggle dictation", "voxtype record toggle")
  o.bind("F9", "Start dictation (push-to-talk)", "voxtype record start")
  o.bind("F9", "Stop dictation (push-to-talk)", "voxtype record stop", { release = true })
end


