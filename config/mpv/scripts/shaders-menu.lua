-- Registers a script-binding that opens the Video > Shaders submenu.
-- uosc builds submenu IDs as "Parent > Child" at runtime (Menu.lua:191).
mp.add_key_binding(nil, 'shaders-menu', function()
	mp.commandv('script-message', 'uosc', 'show-submenu', 'Video > Shaders')
end)
