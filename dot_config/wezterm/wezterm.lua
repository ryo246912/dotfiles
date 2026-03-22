local wezterm = require "wezterm"

local config = wezterm.config_builder and wezterm.config_builder() or {}
local is_darwin = wezterm.target_triple:find("darwin") ~= nil

wezterm.on("gui-startup", function(cmd)
  local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)

local keys = {}

local function send_string_binding(key, mods, value)
  table.insert(keys, {
    key = key,
    mods = mods,
    action = wezterm.action.SendString(value),
  })
end

config.term = "xterm-256color"
config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"
config.font = wezterm.font("HackGen35 Console NF")
config.font_size = 11.0
config.window_background_opacity = 0.95
config.window_decorations = "RESIZE"
config.window_close_confirmation = "NeverPrompt"
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.disable_default_key_bindings = true
config.colors = {
  foreground = "#ffffff",
  background = "#191724",
  cursor_bg = "#ffffff",
  cursor_fg = "#E0DEF4",
  ansi = {
    "#000000",
    "#fe0100",
    "#33ff00",
    "#feff00",
    "#0066ff",
    "#cc00ff",
    "#00ffff",
    "#d0d0d0",
  },
  brights = {
    "#808080",
    "#fe0100",
    "#33ff00",
    "#feff00",
    "#0066ff",
    "#cc00ff",
    "#00ffff",
    "#ffffff",
  },
}

if is_darwin then
  config.default_prog = { "/bin/zsh", "--login" }
  config.send_composed_key_when_left_alt_is_pressed = false
  config.send_composed_key_when_right_alt_is_pressed = false

  send_string_binding("d", "CMD", "\x02%")
  send_string_binding("d", "CMD|SHIFT", '\x02"')
  send_string_binding("c", "CMD", "\x02[")
  send_string_binding("e", "CMD", "\x02 ")
  send_string_binding("e", "CMD|SHIFT", "\x02Q")
  send_string_binding("f", "CMD", "\x02\x06")
  send_string_binding("l", "CMD", "\x02s")
  send_string_binding("l", "CMD|SHIFT", "\x02w")
  send_string_binding("o", "CMD", "\x02R")
  send_string_binding("p", "CMD", "\x02\x10")
  send_string_binding("r", "CMD", "\x02r")
  send_string_binding("s", "CMD", "\x02e")
  send_string_binding("r", "CMD|SHIFT", "\x02\x12")
  send_string_binding("s", "CMD|SHIFT", "\x02\x13")
  send_string_binding("t", "CMD", "\x02c")
  send_string_binding("w", "CMD", "\x02x")
  send_string_binding("w", "CMD|SHIFT", "\x02d")
  send_string_binding("z", "CMD", "\x02z")
  send_string_binding("LeftArrow", "CMD", "\x02h")
  send_string_binding("DownArrow", "CMD", "\x02j")
  send_string_binding("UpArrow", "CMD", "\x02k")
  send_string_binding("RightArrow", "CMD", "\x02l")
  send_string_binding("LeftArrow", "CMD|SHIFT", "\x02\x08")
  send_string_binding("DownArrow", "CMD|SHIFT", "\x02\x09")
  send_string_binding("UpArrow", "CMD|SHIFT", "\x02\x0b")
  send_string_binding("RightArrow", "CMD|SHIFT", "\x02\x0c")
  send_string_binding("UpArrow", "CMD|SHIFT|OPT", "\x02{")
  send_string_binding("DownArrow", "CMD|SHIFT|OPT", "\x02}")
  send_string_binding("[", "CMD", "\x02\x09")
  send_string_binding("]", "CMD", "\x02\x1d")
  send_string_binding("{", "CMD|SHIFT", "\x02p")
  send_string_binding("}", "CMD|SHIFT", "\x02n")
  send_string_binding("{", "CMD|SHIFT|OPT", "\x02\x18")
  send_string_binding("}", "CMD|SHIFT|OPT", "\x02\x19")
  send_string_binding("Space", "CMD", "\x02 ")
  send_string_binding("1", "CMD", "\x021")
  send_string_binding("2", "CMD", "\x022")
  send_string_binding("3", "CMD", "\x023")
  send_string_binding("4", "CMD", "\x024")
  send_string_binding("5", "CMD", "\x025")
  send_string_binding("6", "CMD", "\x026")
  send_string_binding("7", "CMD", "\x027")
  send_string_binding("8", "CMD", "\x028")
  send_string_binding("9", "CMD", "\x029")
  table.insert(keys, {
    key = "v",
    mods = "CMD",
    action = wezterm.action.PasteFrom("Clipboard"),
  })
  table.insert(keys, {
    key = "p",
    mods = "CMD|SHIFT",
    action = wezterm.action.ActivateCommandPalette,
  })
  table.insert(keys, {
    key = "q",
    mods = "CMD",
    action = wezterm.action.QuitApplication,
  })
else
  config.default_prog = { "wsl.exe", "~", "-d", "Ubuntu-20.04" }
end

config.keys = keys

return config
