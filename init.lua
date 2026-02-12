local waywall = require("waywall")
local helpers = require("waywall.helpers")

local config_dir = os.getenv("HOME") .. "/.config/waywall/"
local state_file_path = config_dir .. "layout_state.lua"
local res_state = config_dir .. ".waywall_state"

local function get_current_state()
	local file = io.open(state_file_path, "r")
	if file then
		local state = file:read("*a")
		file:close()
		if state == "dvorak" then
			return "dvorak"
		end
	end
	return "mcsr"
end

local function set_new_state(new_state)
	local file = io.open(state_file_path, "w")
	if file then
		file:write(new_state)
		file:close()
		print("Switching state to " .. new_state .. ". Reloading config...")
	end
end

local current_state = get_current_state()

local function switch_state()
	local new_state = (current_state == "mcsr") and "dvorak" or "mcsr"
	set_new_state(new_state)
end

local config = {
	input = {
		sensitivity = 3.7,
		repeat_rate = 50,
		repeat_delay = 225,
	},
	-- theme = { background_png = config_dir .. "robotech.png" },
	theme = { background = "#000000" },
}

if current_state == "mcsr" then
	config.input.layout = "mcsr"
	config.input.variant = ""

	config.input.remaps = {
		["m5"] = "f3",
		["capslock"] = "0",

		["LeftShift"] = "LeftCtrl",
		["LeftCtrl"] = "LeftShift",
		["D"] = "Backspace",
		["Grave"] = "Tab",
		["Tab"] = "Dot",
	}
else
	config.input.layout = "us"
	config.input.variant = "dvorak"
	config.input.remaps = {}
end

local make_image = function(path, dst)
	local this = nil

	return function(enable)
		if enable and not this then
			this = waywall.image(path, { dst = dst })
		elseif this and not enable then
			this:close()
			this = nil
		end
	end
end

local make_mirror = function(options)
	local this = nil

	return function(enable)
		if enable and not this then
			this = waywall.mirror(options)
		elseif this and not enable then
			this:close()
			this = nil
		end
	end
end

local make_res = function(width, height, enable, disable)
	return function()
		local active_width, active_height = waywall.active_res()

		if active_width == width and active_height == height then
			os.execute('echo "' .. 0 .. "x" .. 0 .. '" > ~/.res_state.lua')
			disable()
			waywall.sleep(17)
			waywall.set_resolution(0, 0)
		else
			os.execute('echo "' .. width .. "x" .. height .. '" > ~/.res_state.lua')
			enable()
			waywall.sleep(17)
			waywall.set_resolution(width, height)
		end
	end
end

-- Mirrors and resolution toggles
local mirrors = {
	eye_measure = make_mirror({
		src = { x = 130, y = 7902, w = 60, h = 580 },
		dst = { x = 0, y = 315, w = 800, h = 450 },
	}),
	tall_pie = make_mirror({
		src = { x = 0, y = 15980, w = 320, h = 260 },
		dst = { x = 480, y = 765, w = 320, h = 260 },
	}),

	f3_ccache = make_mirror({
		src = { x = 101, y = 55, w = 27, h = 9 },
		dst = { x = 1120, y = 504, w = 0, h = 0 },
		color_key = { input = "#dddddd", output = "#ffffff" },
	}),
	f3_ecount = make_mirror({
		src = { x = 0, y = 36, w = 50, h = 9 },
		dst = { x = 1138, y = 50, w = 200, h = 36 },
		color_key = { input = "#dddddd", output = "#ff33ff" },
	}),

	-- ==== FLAT PIE CHART LAYERS ====
	pie_layer_entities = make_mirror({
		src = { x = 227, y = 16163, w = 33, h = 42 },
		dst = { x = 1340, y = 200, w = 198, h = 251 },
		color_key = { input = "#e145c2", output = "#A8A8A8" },
	}),
	pie_layer_blockentities = make_mirror({
		src = { x = 227, y = 16163, w = 33, h = 42 },
		dst = { x = 1340, y = 200, w = 198, h = 251 },
		color_key = { input = "#e96d4d", output = "#00FF00" }, -- Green for Block Entities
	}),
	pie_layer_unspec = make_mirror({
		src = { x = 227, y = 16163, w = 33, h = 42 },
		dst = { x = 1340, y = 200, w = 198, h = 251 },
		color_key = { input = "#45cb65", output = "#A8A8A8" },
	}),

	-- ==== PERCENTAGE TEXT LAYERS ====
	-- These capture the text area and recolor them to match the pie slices
	percent_sum_others = make_mirror({
		src = { x = 257, y = 16163, w = 33, h = 25 }, -- Source for top percentages
		dst = { x = 1340, y = 460, w = 198, h = 150 }, -- Positioned above block entities
		color_key = {
			input = "#45cb65", -- Captures "unspecified" text color
			output = "#A8A8A8", -- Matches the grey pie slices
		},
	}),
	percent_blockentities = make_mirror({
		src = { x = 257, y = 16163, w = 33, h = 25 },
		dst = { x = 1340, y = 540, w = 198, h = 150 }, -- Positioned at the bottom
		color_key = {
			input = "#e96d4d", -- Captures "block entities" text color
			output = "#00FF00", -- Matches the green pie slice
		},
	}),
}

local images = {
	overlay = make_image(config_dir .. "overlay.png", { x = 0, y = 315, w = 800, h = 450 }),
}

local show_mirrors = function(eye, f3, tall, thin, lowest)
	images.overlay(eye)
	mirrors.eye_measure(eye)
	mirrors.tall_pie(eye)

	mirrors.f3_ccache(f3)
	mirrors.f3_ecount(f3)

	local show_hud = tall or thin or lowest

	-- Pie Chart Layers
	mirrors.pie_layer_entities(show_hud)
	mirrors.pie_layer_blockentities(show_hud)
	mirrors.pie_layer_unspec(show_hud)

	-- Percentage Text Layers
	mirrors.percent_sum_others(show_hud)
	mirrors.percent_blockentities(show_hud)
end

local thin_enable = function()
	os.execute('echo "320x1080" > ' .. res_state)
	waywall.set_sensitivity(0)
	show_mirrors(false, true, false, true, false)
end

local thin_disable = function()
	os.execute('echo "1920x1080" > ' .. res_state)
	show_mirrors(false, false, false, false, false)
end

local tall_enable = function()
	os.execute('echo "320x16384" > ' .. res_state)
	waywall.set_sensitivity(0.003 * config.input.sensitivity)
	show_mirrors(true, true, true, false, false)
end

local tall_disable = function()
	os.execute('echo "1920x1080" > ' .. res_state)
	waywall.set_sensitivity(0)
	show_mirrors(false, false, false, false, false)
end

local wide_enable = function()
	os.execute('echo "1920x300" > ' .. res_state)
	waywall.set_sensitivity(0)
	show_mirrors(false, false, false, false, false)
end

local wide_disable = function()
	os.execute('echo "1920x1080" > ' .. res_state)
end

local lowest_enable = function()
	os.execute('echo "320x16384" > ' .. res_state)
	waywall.set_sensitivity(0)
	show_mirrors(false, true, true, false, false)
end

local lowest_disable = function()
	os.execute('echo "1920x1080" > ' .. res_state)
	waywall.set_sensitivity(0)
	show_mirrors(false, false, false, false, false)
end

local semithin_enable = function()
	os.execute('echo "328x1080" > ' .. res_state)
	waywall.set_sensitivity(0)
	show_mirrors(false, false, false, false, false)
end

local semithin_disable = function()
	os.execute('echo "1920x1080" > ' .. res_state)
end

local resolutions = {
	thin = make_res(320, 1080, thin_enable, thin_disable),
	tall = make_res(320, 16384, tall_enable, tall_disable),
	wide = make_res(1920, 300, wide_enable, wide_disable),
	semithin = make_res(328, 1080, semithin_enable, semithin_disable),
	lowest = make_res(320, 16384, lowest_enable, lowest_disable),
}

-- helpers.res_image("topfgrad.png", { dst = { x = 0, y = 0, w = 1920, h = 390 } }, 1920, 300)
-- helpers.res_image("botfgrad.png", { dst = { x = 0, y = 690, w = 1920, h = 390 } }, 1920, 300)

local function exec(x)
	return function()
		waywall.exec(x)
	end
end

config.actions = {
	["*-m4"] = resolutions.thin,
	["*-shift-m4"] = resolutions.wide,
	["*-f1"] = resolutions.tall,
	["*-ctrl-4"] = resolutions.lowest,
	["*-ctrl-shift-k"] = exec("ninjabrain-bot"),
	["*-ctrl-6"] = switch_state,
	["*-ctrl-k"] = helpers.toggle_floating,
}

return config
