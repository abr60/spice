hl.config({
  general = {
    layout      = "master",
    gaps_in     = 2,
    gaps_out    = 2,
    border_size = 2,
  },
})

hl.config({
  decoration = {
    rounding         = 6,
    active_opacity   = 0.92,
    inactive_opacity = 0.95,

    blur = {
      enabled           = true,
      size              = 4,
      passes            = 3,
      contrast          = 0.95,
      brightness        = 0.9,
      vibrancy          = 0.15,
      vibrancy_darkness = 0.25,
      noise             = 0.015,
      ignore_opacity    = true,
    },
  },
})

-- Cursor
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
