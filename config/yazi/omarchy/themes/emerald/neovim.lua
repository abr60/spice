return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#000b01",
        dark_bg    = "#000801",
        darker_bg  = "#000601",
        lighter_bg = "#1a231a",

        fg         = "#d2dcc3",
        dark_fg    = "#9ea592",
        light_fg   = "#d9e1cc",
        bright_fg  = "#dde5d2",
        muted      = "#5a5f5a",

        red        = "#6e8d6c",
        yellow     = "#a3ae83",
        orange     = "#849e82",
        green      = "#85a27f",
        cyan       = "#6aae9e",
        blue       = "#579789",
        purple     = "#609d8f",
        brown      = "#4f5f4e",

        bright_red    = "#8fb488",
        bright_yellow = "#c6d49b",
        bright_green  = "#a7ca9c",
        bright_cyan   = "#89d6c1",
        bright_blue   = "#75beac",
        bright_purple = "#7fc5b2",

        accent               = "#579789",
        cursor               = "#d2dcc3",
        foreground           = "#d2dcc3",
        background           = "#000b01",
        selection             = "#1a231a",
        selection_foreground = "#d2dcc3",
        selection_background = "#1a231a",
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
