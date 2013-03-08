screens = {
	['default'] = {
		['connected'] = function (xrandrOutput)
			return '--output ' .. xrandrOutput .. ' --auto --same-as LVDS1'
		end,
		['disconnected'] = function (xrandrOutput)
			return '--output ' .. xrandrOutput .. ' --off --output LVDS1 --auto'
		end
	},
	['55250827610'] = {
		['connected'] = function (xrandrOutput)
                        --return '--output ' .. VGA1 .. '--mode 1920x1080 --pos 0x0 --rotate normal'
                        --return '--output ' .. LVDS1 .. '--mode 1366x768 --pos 1920x0 --rotate normal'
			return '--output ' .. xrandrOutput .. ' --auto --above LVDS1'
		end,
		['disconnected'] = nil
	}
}

