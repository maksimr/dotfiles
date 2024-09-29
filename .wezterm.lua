local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.switch_to_last_active_tab_when_closing_tab = true
config.use_fancy_tab_bar = false
config.enable_scroll_bar = false
config.enable_tab_bar = false

local font_size = 28.0
config.font = wezterm.font 'JetBrains Mono Thin'
config.font_size = font_size
config.command_palette_font_size = font_size

local opacity = 0.65
local blur = 7
config.window_background_opacity = opacity
config.text_background_opacity = opacity
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

config.default_cursor_style = "SteadyBlock"

config.colors = {
  -- The default text color
  foreground = '#c7c7c7',
  -- The default background color
  background = '#333333',

  -- Overrides the cell background color when the current cell is occupied by the
  -- cursor and the cursor style is set to Block
  cursor_bg = '#52ad70',
  -- Overrides the text color when the current cell is occupied by the cursor
  cursor_fg = '#feffff',
  -- Specifies the border color of the cursor when the cursor style is set to Block,
  -- or the color of the vertical or horizontal bar when the cursor style is set to
  -- Bar or Underline.
  cursor_border = '#52ad70',

  -- the foreground color of selected text
  selection_fg = 'black',
  -- the background color of selected text
  selection_bg = '#c6dcfc',

  -- The color of the scrollbar "thumb"; the portion that represents the current viewport
  scrollbar_thumb = '#222222',

  -- The color of the split lines between panes
  split = '#444444',

  ansi = {
    '#000000', -- Black
    '#b83019', -- Red
    '#51bf37', -- Green
    '#c6c43d', -- Yellow
    '#0c24bf', -- Blue
    '#b93ec1', -- Magenta
    '#53c2c5', -- Cyan
    '#c7c7c7', -- White
  },
  brights = {
    '#676767', -- Black
    '#ef766d', -- Red
    '#8cbc87', -- Green
    '#fefb7e', -- Yellow
    '#6a71f6', -- Blue
    '#f07ef8', -- Magenta
    '#95d2d4', -- Cyan
    '#feffff', -- White
  },

  -- Arbitrary colors of the palette in the range from 16 to 255
  indexed = { [136] = '#af8700' },

  -- Since: 20220319-142410-0fcdea07
  -- When the IME, a dead key or a leader key are being processed and are effectively
  -- holding input pending the result of input composition, change the cursor
  -- to this color to give a visual cue about the compose state.
  compose_cursor = 'orange',

  -- Colors for copy_mode and quick_select
  -- available since: 20220807-113146-c2fee766
  -- In copy_mode, the color of the active text is:
  -- 1. copy_mode_active_highlight_* if additional text was selected using the mouse
  -- 2. selection_* otherwise
  copy_mode_active_highlight_bg = { Color = '#000000' },
  -- use `AnsiColor` to specify one of the ansi color palette values
  -- (index 0-15) using one of the names "Black", "Maroon", "Green",
  --  "Olive", "Navy", "Purple", "Teal", "Silver", "Grey", "Red", "Lime",
  -- "Yellow", "Blue", "Fuchsia", "Aqua" or "White".
  copy_mode_active_highlight_fg = { AnsiColor = 'Black' },
  copy_mode_inactive_highlight_bg = { Color = '#52ad70' },
  copy_mode_inactive_highlight_fg = { AnsiColor = 'White' },

  quick_select_label_bg = { Color = 'peru' },
  quick_select_label_fg = { Color = '#ffffff' },
  quick_select_match_bg = { AnsiColor = 'Navy' },
  quick_select_match_fg = { Color = '#ffffff' },
}

-- override opacity by cmd+u
config.keys = {
  {key="u", mods="CMD", action=wezterm.action.EmitEvent("toggle-opacity")},
}

-- maximize the window right away
wezterm.on('gui-startup', function()
 local tab, pane, window = wezterm.mux.spawn_window({})
 window:gui_window():maximize()
end)

return config
