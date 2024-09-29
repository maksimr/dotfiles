local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.switch_to_last_active_tab_when_closing_tab = true

config.use_fancy_tab_bar = false

config.font = wezterm.font 'JetBrains Mono Thin'
config.font_size = 28.0
config.command_palette_font_size = 28.0

config.enable_scroll_bar = false
config.enable_tab_bar = false

local opacity = 0.50
config.window_background_opacity = opacity
config.text_background_opacity = opacity
local blur = 7
config.macos_window_background_blur = blur

wezterm.on("toggle-opacity", function(window, _)
  local overrides = window:get_config_overrides() or {}
  local is_empty = not overrides.window_background_opacity
  if overrides.window_background_opacity == opacity or is_empty  then
    overrides.window_background_opacity = 1.0
    overrides.text_background_opacity = 1.0
    overrides.macos_window_background_blur = 0
  else
    overrides.window_background_opacity = opacity
    overrides.text_background_opacity = opacity
    overrides.macos_window_background_blur = blur
  end
  window:set_config_overrides(overrides)
end)

config.window_decorations = "MACOS_FORCE_DISABLE_SHADOW|RESIZE"
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}
config.window_close_confirmation = "NeverPrompt"

-- override opacity by cmd+u
config.keys = {
  {key="u", mods="CMD", action=wezterm.action.EmitEvent("toggle-opacity")},
}

return config
