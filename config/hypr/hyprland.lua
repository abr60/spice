dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

require("default.hypr.omarchy")

require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")
require("hypr.rules")

require("default.hypr.toggles")
hl.env("XCURSOR_THEME", "Bibata-Original-Classic")
hl.env("HYPRCURSOR_THEME", "Bibata-Original-Classic")
hl.env("XCURSOR_SIZE", "32")
hl.env("HYPRCURSOR_SIZE", "32")
