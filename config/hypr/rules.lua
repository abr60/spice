hl.window_rule({ fullscreen = true, match = { class = "^(Waydroid)$" } })

hl.window_rule({ float = true,      match = { class = "^(foot)$", title = "^(Yazi)$" } })
hl.window_rule({ size = "700 200",  match = { class = "^(foot)$", title = "^(Yazi)$" } })
hl.window_rule({ center = true,     match = { class = "^(foot)$", title = "^(Yazi)$" } })

hl.window_rule({ float = true,      match = { class = "^(foot)$", title = "^(media-download)$" } })
hl.window_rule({ size = "900 400",  match = { class = "^(foot)$", title = "^(media-download)$" } })
hl.window_rule({ center = true,     match = { class = "^(foot)$", title = "^(media-download)$" } })

hl.window_rule({ float = true,      match = { class = "^(foot)$", title = "^(rmpc-full)$" } })
hl.window_rule({ size = "900 600",  match = { class = "^(foot)$", title = "^(rmpc-full)$" } })
hl.window_rule({ center = true,     match = { class = "^(foot)$", title = "^(rmpc-full)$" } })

hl.window_rule({ float = true,      match = { class = "^(foot)$", title = "^(wifi-qr)$" } })
hl.window_rule({ size = "336 416",  match = { class = "^(foot)$", title = "^(wifi-qr)$" } })
hl.window_rule({ move = "940 45",   match = { class = "^(foot)$", title = "^(wifi-qr)$" } })
hl.window_rule({ pin = true,        match = { class = "^(foot)$", title = "^(wifi-qr)$" } })

hl.window_rule({ float = true, match = { class = "^(audacious)$" } })
hl.window_rule({ move = "13 515", match = { class = "^(audacious)$" } })
hl.window_rule({ size = "500 300", match = { class = "^(audacious)$" } })

-- Overview layer rules
hl.layer_rule({ blur = true,        match = { namespace = "^(omarchy-overview)$" } })
hl.layer_rule({ ignore_alpha = 0.2, match = { namespace = "^(omarchy-overview)$" } })
