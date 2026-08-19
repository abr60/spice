-- Gestures
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "up",   action = "fullscreen", scale = 1.5 })
hl.gesture({ fingers = 4, direction = "down",  action = "fullscreen", scale = 0.5 })
hl.gesture({
  fingers = 3,
  direction = "up",
  action = function()
    hl.exec_cmd("omarchy-shell shell toggle overview")
  end,
})
