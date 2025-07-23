local waywall = require("waywall")
local helpers = require("waywall.helpers")

local config_dir = os.getenv("HOME") .. "/.config/waywall/"
local state_file_path = config_dir .. "layout_state.txt"

-- Function to read the current state from the file
local function get_current_state()
	local file = io.open(state_file_path, "r")
	if file then
		local state = file:read("*a")
		file:close()
		-- Ensure the state is valid, otherwise default to "mcsr"
		if state == "dvorak" then
			return "dvorak"
		end
	end
	return "mcsr"
end

-- Function to write the new state to the file, triggering a hot-reload
local function set_new_state(new_state)
	local file = io.open(state_file_path, "w")
	if file then
		file:write(new_state)
		file:close()
		-- The file write will cause waywall to reload this entire script.
		print("Switching state to " .. new_state .. ". Reloading config...")
	else
		print("ERROR: Could not write to state file at: " .. state_file_path)
	end
end

-- Read the state when the script loads
local current_state = get_current_state()

-- Initialize the Config table
local config = {
	-- Basic input settings that are common to both modes
	input = {
		sensitivity = 1.0,
		repeat_rate = 50,
		repeat_delay = 225,
	},
	theme = {
		background_png = "/home/joshammer/.config/nixos/modules/stylix/wallpapers/space.png",
		ninb_anchor = "topleft",
	},
}

-- Configure Mode-Specific Settings
if current_state == "mcsr" then
	-- ### MCSR MODE ###
	-- Remaps are ENABLED
	print("Loading MCSR profile.")

	config.input.layout = "mcsr"
	config.input.variant = ""

	-- This is your list of remaps that will be ACTIVE in this mode.
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
	-- ### DVORAK MODE ###
	print("Loading Dvorak profile.")

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
			disable()
			waywall.sleep(17)
			waywall.set_resolution(0, 0)
		else
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
		color_key = {
			input = "#dddddd",
			output = "#ffffff",
		},
	}),
	f3_ecount = make_mirror({
		src = { x = 0, y = 36, w = 50, h = 9 },
		dst = { x = 1338, y = 144, w = 200, h = 36 },
		color_key = {
			input = "#dddddd",
			output = "#ffffff",
		},
	}),

	tall_pie_entities = make_mirror({
		src = { x = 227, y = 16163, w = 33, h = 42 },
		dst = { x = 1340, y = 200, w = 198, h = 251 },
		color_key = {
			input = "#e145c2",
			output = "#323AA3",
		},
	}),
	tall_pie_blockentities = make_mirror({
		src = { x = 227, y = 16163, w = 33, h = 42 },
		dst = { x = 1340, y = 200, w = 198, h = 251 },
		color_key = {
			input = "#e96d4d",
			output = "#83046c",
		},
	}),
	tall_pie_unspec = make_mirror({
		src = { x = 227, y = 16163, w = 33, h = 42 },
		dst = { x = 1340, y = 200, w = 198, h = 251 },
		color_key = {
			input = "#45cb65",
			output = "#ffffff",
		},
	}),

	lowest_pie_entities = make_mirror({
		src = { x = 227, y = 16163, w = 33, h = 42 },
		dst = { x = 1340, y = 200, w = 198, h = 251 },
		color_key = {
			input = "#e145c2",
			output = "#323AA3",
		},
	}),
	lowest_pie_blockentities = make_mirror({
		src = { x = 227, y = 16163, w = 33, h = 42 },
		dst = { x = 1340, y = 200, w = 198, h = 251 },
		color_key = {
			input = "#e96d4d",
			output = "#83046c",
		},
	}),
	lowest_pie_unspec = make_mirror({
		src = { x = 227, y = 16163, w = 33, h = 42 },
		dst = { x = 1340, y = 200, w = 198, h = 251 },
		color_key = {
			input = "#45cb65",
			output = "#ffffff",
		},
	}),

	thin_pie_entities = make_mirror({
		src = { x = 227, y = 859, w = 33, h = 42 },
		dst = { x = 1340, y = 200, w = 198, h = 251 },
		color_key = {
			input = "#e145c2",
			output = "#323AA3",
		},
	}),
	thin_pie_blockentities = make_mirror({
		src = { x = 227, y = 859, w = 33, h = 42 },
		dst = { x = 1340, y = 200, w = 198, h = 251 },
		color_key = {
			input = "#e96d4d",
			output = "#83046c",
		},
	}),
	thin_pie_unspec = make_mirror({
		src = { x = 227, y = 859, w = 33, h = 42 },
		dst = { x = 1340, y = 200, w = 198, h = 251 },
		color_key = {
			input = "#45cb65",
			output = "#000000",
		},
	}),
}

local images = {
	overlay = make_image("/home/joshammer/documents/gh/mcsr/overlay.png", { x = 0, y = 315, w = 800, h = 450 }),
}

local show_mirrors = function(eye, f3, tall, thin, lowest)
	images.overlay(eye)
	mirrors.eye_measure(eye)
	mirrors.tall_pie(eye)

	mirrors.f3_ccache(f3)
	mirrors.f3_ecount(f3)

	mirrors.tall_pie_entities(tall)
	mirrors.tall_pie_blockentities(tall)
	mirrors.tall_pie_unspec(tall)

	mirrors.thin_pie_entities(thin)
	mirrors.thin_pie_blockentities(thin)
	mirrors.thin_pie_unspec(thin)

	mirrors.lowest_pie_entities(lowest)
	mirrors.lowest_pie_blockentities(lowest)
	mirrors.lowest_pie_unspec(lowest)
end

local thin_enable = function()
	os.execute('echo "320x1080" > ~/.waywall_state')
	waywall.set_sensitivity(0)
	show_mirrors(false, true, false, true, false)
end

local thin_disable = function()
	os.execute('echo "1920x1080" > ~/.waywall_state')
	show_mirrors(false, false, false, false, false)
end

local tall_enable = function()
	os.execute('echo "320x16384" > ~/.waywall_state')
	waywall.set_sensitivity(0.02)
	show_mirrors(true, true, true, false, false)
end

local tall_disable = function()
	os.execute('echo "1920x1080" > ~/.waywall_state')
	waywall.set_sensitivity(0)
	show_mirrors(false, false, false, false, false)
end

local wide_enable = function()
	os.execute('echo "1920x300" > ~/.waywall_state')
	waywall.set_sensitivity(0)
	show_mirrors(false, false, false, false, false)
end

local wide_disable = function()
	os.execute('echo "1920x1080" > ~/.waywall_state')
end

local lowest_enable = function()
	os.execute('echo "320x16384" > ~/.waywall_state')
	waywall.set_sensitivity(0)
	show_mirrors(true, true, true, false, false)
end

local lowest_disable = function()
	os.execute('echo "1920x1080" > ~/.waywall_state')
	waywall.set_sensitivity(0)
	show_mirrors(false, false, false, false, false)
end

local semithin_enable = function()
	os.execute('echo "328x1080" > ~/.waywall_state')
	waywall.set_sensitivity(0)
	show_mirrors(false, false, false, false, false)
end

local semithin_disable = function()
	os.execute('echo "1920x1080" > ~/.waywall_state')
end

local resolutions = {
	thin = make_res(320, 1080, thin_enable, thin_disable),
	tall = make_res(320, 16384, tall_enable, tall_disable),
	wide = make_res(1920, 300, wide_enable, wide_disable),
	semithin = make_res(328, 1080, semithin_enable, semithin_disable),
	lowest = make_res(320, 16384, lowest_enable, lowest_disable),
}

local exec_ninb = function()
	waywall.exec("ninjabrain-bot")
end

config.actions = {
	["*-m4"] = resolutions.thin,
	["*-shift-m4"] = resolutions.wide,
	["*-f1"] = resolutions.tall,
	["*-ctrl-k"] = helpers.toggle_floating,
	["*-ctrl-n"] = exec_ninb,
	["Win-Grave"] = function()
		local new_state = (current_state == "mcsr") and "dvorak" or "mcsr"
		set_new_state(new_state)
	end,
}

return config
