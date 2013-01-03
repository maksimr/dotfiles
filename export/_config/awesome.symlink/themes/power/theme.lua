---------------------------
-- Default awesome theme --
---------------------------

require("awful.util")

local themename = "/power"

local home = os.getenv("home")
local config = awful.util.getdir("config")
local shared = "/usr/share/awesome"

if not awful.util.file_readable(shared .. "/icons/awesome16.png") then
    shared = "/usr/share/local/awesome"
end

local sharedicons = shared .. "/icons"
local sharedthemes  = shared .. "/themes"

local themes = config.."/themes"
local themedir = themes..themename

theme = {}

theme.font          = "monospace 11"

theme.bg_normal     = "#3c3b37"
theme.bg_focus      = "#54534f"
theme.bg_urgent     = "#ff0000"
theme.bg_minimize   = "#444444"

theme.fg_normal     = "#aaaaaa"
theme.fg_focus      = "#ffffff"
theme.fg_urgent     = "#ffffff"
theme.fg_minimize   = "#ffffff"

theme.border_width  = "2"
theme.border_normal = "#343434"
theme.border_focus  = "#EF5656"
theme.border_marked = "#343434"


-- {{ Taglist
theme.taglist_fg_focus = "#E42F2F"
theme.taglist_bg_focus = "#343434"

-- Display the taglist squares
theme.taglist_squares_sel   = themedir.."/taglist/squarefw.png"
theme.taglist_squares_unsel = themedir.."/taglist/squarew.png"
-- }}

-- {{ Tasklist
theme.tasklist_floating_icon = themedir.."/tasklist/floating.png"
-- }}

-- {{ Misc
-- Variables set for theming the menu:
theme.menu_submenu_icon = sharedthemes.."/default/submenu.png"
theme.menu_height = "15"
theme.menu_width  = "100"

-- Awesome logotip icon 16px
theme.awesome_icon = themedir.."/awesome-icon.png"
-- }}

-- {{ Titlebar
theme.titlebar_close_button_normal              = sharedthemes.."/default/titlebar/close_normal.png"
theme.titlebar_close_button_focus               = sharedthemes.."/default/titlebar/close_focus.png"

theme.titlebar_ontop_button_normal_inactive     = sharedthemes.."/default/titlebar/ontop_normal_inactive.png"
theme.titlebar_ontop_button_focus_inactive      = sharedthemes.."/default/titlebar/ontop_focus_inactive.png"
theme.titlebar_ontop_button_normal_active       = sharedthemes.."/default/titlebar/ontop_normal_active.png"
theme.titlebar_ontop_button_focus_active        = sharedthemes.."/default/titlebar/ontop_focus_active.png"

theme.titlebar_sticky_button_normal_inactive    = sharedthemes.."/default/titlebar/sticky_normal_inactive.png"
theme.titlebar_sticky_button_focus_inactive     = sharedthemes.."/default/titlebar/sticky_focus_inactive.png"
theme.titlebar_sticky_button_normal_active      = sharedthemes.."/default/titlebar/sticky_normal_active.png"
theme.titlebar_sticky_button_focus_active       = sharedthemes.."/default/titlebar/sticky_focus_active.png"

theme.titlebar_floating_button_normal_inactive  = sharedthemes.."/default/titlebar/floating_normal_inactive.png"
theme.titlebar_floating_button_focus_inactive   = sharedthemes.."/default/titlebar/floating_focus_inactive.png"
theme.titlebar_floating_button_normal_active    = sharedthemes.."/default/titlebar/floating_normal_active.png"
theme.titlebar_floating_button_focus_active     = sharedthemes.."/default/titlebar/floating_focus_active.png"

theme.titlebar_maximized_button_normal_inactive = sharedthemes.."/default/titlebar/maximized_normal_inactive.png"
theme.titlebar_maximized_button_focus_inactive  = sharedthemes.."/default/titlebar/maximized_focus_inactive.png"
theme.titlebar_maximized_button_normal_active   = sharedthemes.."/default/titlebar/maximized_normal_active.png"
theme.titlebar_maximized_button_focus_active    = sharedthemes.."/default/titlebar/maximized_focus_active.png"
-- }}

-- {{ Wallpaper
-- You can use your own command to set your wallpaper
--theme.wallpaper_cmd = { "awsetbg -f "..themedir.."/background.png" }
theme.wallpaper_cmd = { "awsetbg "..themedir.."/background.png" }
-- }}

-- {{ Layout
-- You can use your own layout icons like this:
theme.layout_fairh      = themedir.."/layouts/fairhw.png"
theme.layout_fairv      = themedir.."/layouts/fairvw.png"
theme.layout_floating   = themedir.."/layouts/floatingw.png"
theme.layout_magnifier  = themedir.."/layouts/magnifierw.png"
theme.layout_max        = themedir.."/layouts/maxw.png"
theme.layout_fullscreen = themedir.."/layouts/fullscreenw.png"
theme.layout_tilebottom = themedir.."/layouts/tilebottomw.png"
theme.layout_tileleft   = themedir.."/layouts/tileleftw.png"
theme.layout_tile       = themedir.."/layouts/tilew.png"
theme.layout_tiletop    = themedir.."/layouts/tiletopw.png"
theme.layout_spiral     = themedir.."/layouts/spiralw.png"
theme.layout_dwindle    = themedir.."/layouts/dwindlew.png"
-- }}

return theme
-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
