return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#0e0e05",
        dark_bg    = "#0b0b04",
        darker_bg  = "#070703",
        lighter_bg = "#26261e",

        fg         = "#d6c3d8",
        dark_fg    = "#a192a2",
        light_fg   = "#dcccde",
        bright_fg  = "#e0d2e2",
        muted      = "#666760",

        red        = "#857960",
        yellow     = "#939670",
        orange     = "#978d78",
        green      = "#787e65",
        cyan       = "#989f87",
        blue       = "#bb9ca4",
        purple     = "#8e7c92",
        brown      = "#5b5548",

        bright_red    = "#aa9e7c",
        bright_yellow = "#b8bd8a",
        bright_green  = "#9ba382",
        bright_cyan   = "#bdc6a6",
        bright_blue   = "#c6a398",
        bright_purple = "#b59fbb",

        accent               = "#9ca4bb",
        cursor               = "#d6c3d8",
        foreground           = "#d6c3d8",
        background           = "#0e0e05",
        selection             = "#26261e",
        selection_foreground = "#d6c3d8",
        selection_background = "#26261e",
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
