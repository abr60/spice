o.bind("ALT + comma", "Unmount",   "hdd-unmount")

o.bind("XF86NotificationCenter", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })
o.bind("XF86Favorites", "Calibre", { launch = "ebook-viewer '/home/$USER/Calibre Library'" })

o.bind("ALT + C", "RMPC Music", "[float; center] foot --title=rmpc-full -e rmpc")
o.bind("ALT + X", "Study",      "[float; size 700 200; center] foot --override=class=Yazi --title=Yazi -e timeout 30s yazi \"~/media/tv/Breaking Bad/Season 3/\"")

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

hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "Claude", { webapp = "https://claude.ai/new" })

hl.unbind("SUPER + SPACE")
hl.unbind("SUPER + ALT + SPACE")
o.bind("SUPER + SPACE", "Apps menu", "omarchy-menu toggle apps")
o.bind("SUPER + ALT + SPACE", "Omarchy menu", "omarchy-menu toggle")

hl.unbind("SUPER + SHIFT + CTRL + SPACE")
o.bind("ALT + SPACE", "Theme menu", "omarchy-menu toggle theme")
o.bind("switch:on:Lid Switch", "Howdy Lid Open", "omarchy-shell lock howdyRetry")
o.bind("switch:off:Lid Switch", "Howdy Lid Open", "omarchy-shell lock howdyRetry")


o.bind("switch:off:Lid Switch", "Howdy Lid Close", "omarchy-shell lock howdyRetry")

o.bind("switch:off:Lid Switch", "Howdy Lid Close", "omarchy-shell lock howdyRetry")

