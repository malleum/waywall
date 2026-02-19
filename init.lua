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
		sensitivity = 3.7385416219369882,
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
		src = { x = 162, y = 7902, w = 60, h = 580 },
		dst = { x = 0, y = 326, w = 760, h = 428 },
	}),

	f3_ccache = make_mirror({
		src = { x = 101, y = 55, w = 27, h = 9 },
		dst = { x = 1120, y = 504, w = 0, h = 0 },
		color_key = { input = "#dddddd", output = "#ffffff" },
	}),
	f3_ecount = make_mirror({
		src = { x = 0, y = 36, w = 50, h = 9 },
		dst = { x = 1340, y = 252, w = 200, h = 36 },
		color_key = { input = "#dddddd", output = "#A8A8A8" },
	}),

	-- ==== TALL PIE CHART LAYERS (384x16384) ====
	tall_pie_blockentities = make_mirror({
		src = { x = 44, y = 15978, w = 340, h = 178 },
		dst = { x = 1340, y = 415, w = 198, h = 251 },
		color_key = { input = "#EC6E4E", output = "#00FF00" },
	}),
	tall_pie_unspecified = make_mirror({
		src = { x = 44, y = 15978, w = 340, h = 178 },
		dst = { x = 1340, y = 415, w = 198, h = 251 },
		color_key = { input = "#46CE66", output = "#A8A8A8" },
	}),
	tall_pie_destroyProgress = make_mirror({
		src = { x = 44, y = 15978, w = 340, h = 178 },
		dst = { x = 1340, y = 415, w = 198, h = 251 },
		color_key = { input = "#CC6C46", output = "#A8A8A8" },
	}),
	tall_pie_prepare = make_mirror({
		src = { x = 44, y = 15978, w = 340, h = 178 },
		dst = { x = 1340, y = 415, w = 198, h = 251 },
		color_key = { input = "#464C46", output = "#A8A8A8" },
	}),
	tall_pie_entities = make_mirror({
		src = { x = 44, y = 15978, w = 340, h = 178 },
		dst = { x = 1340, y = 415, w = 198, h = 251 },
		color_key = { input = "#E446C4", output = "#A8A8A8" },
	}),

	-- ==== THIN PIE CHART LAYERS (340x1080) ====
	thin_pie_blockentities = make_mirror({
		src = { x = 0, y = 674, w = 340, h = 178 },
		dst = { x = 1340, y = 415, w = 198, h = 251 },
		color_key = { input = "#EC6E4E", output = "#00FF00" },
	}),
	thin_pie_unspecified = make_mirror({
		src = { x = 0, y = 674, w = 340, h = 178 },
		dst = { x = 1340, y = 415, w = 198, h = 251 },
		color_key = { input = "#46CE66", output = "#A8A8A8" },
	}),
	thin_pie_destroyProgress = make_mirror({
		src = { x = 0, y = 674, w = 340, h = 178 },
		dst = { x = 1340, y = 415, w = 198, h = 251 },
		color_key = { input = "#CC6C46", output = "#A8A8A8" },
	}),
	thin_pie_prepare = make_mirror({
		src = { x = 0, y = 674, w = 340, h = 178 },
		dst = { x = 1340, y = 415, w = 198, h = 251 },
		color_key = { input = "#464C46", output = "#A8A8A8" },
	}),
	thin_pie_entities = make_mirror({
		src = { x = 0, y = 674, w = 340, h = 178 },
		dst = { x = 1340, y = 415, w = 198, h = 251 },
		color_key = { input = "#E446C4", output = "#A8A8A8" },
	}),

	-- ==== TALL PERCENTAGE TEXT LAYERS (384x16384) ====
	tall_percent_blockentities = make_mirror({
		src = { x = 291, y = 16163, w = 33, h = 25 },
		dst = { x = 1340, y = 735, w = 198, h = 150 },
		color_key = { input = "#E96D4D", output = "#00FF00" },
	}),
	tall_percent_unspecified = make_mirror({
		src = { x = 291, y = 16163, w = 33, h = 25 },
		dst = { x = 1340, y = 735, w = 198, h = 150 },
		color_key = { input = "#45CB65", output = "#A8A8A8" },
	}),

	-- ==== THIN PERCENTAGE TEXT LAYERS (340x1080) ====
	thin_percent_blockentities = make_mirror({
		src = { x = 247, y = 859, w = 33, h = 25 },
		dst = { x = 1340, y = 735, w = 198, h = 150 },
		color_key = { input = "#E96D4D", output = "#00FF00" },
	}),
	thin_percent_unspecified = make_mirror({
		src = { x = 247, y = 859, w = 33, h = 25 },
		dst = { x = 1340, y = 735, w = 198, h = 150 },
		color_key = { input = "#45CB65", output = "#A8A8A8" },
	}),
}

local images = {
	overlay = make_image(config_dir .. "overlay.png", { x = 0, y = 326, w = 760, h = 428 }),
}

local show_mirrors = function(eye, f3, tall, thin, lowest)
	images.overlay(eye)
	mirrors.eye_measure(eye)

	mirrors.f3_ccache(f3)
	mirrors.f3_ecount(f3)

	local show_tall = tall or lowest

	-- Tall pie chart layers (384x16384)
	mirrors.tall_pie_blockentities(show_tall)
	mirrors.tall_pie_unspecified(show_tall)
	mirrors.tall_pie_destroyProgress(show_tall)
	mirrors.tall_pie_prepare(show_tall)
	mirrors.tall_pie_entities(show_tall)

	-- Thin pie chart layers (340x1080)
	mirrors.thin_pie_blockentities(thin)
	mirrors.thin_pie_unspecified(thin)
	mirrors.thin_pie_destroyProgress(thin)
	mirrors.thin_pie_prepare(thin)
	mirrors.thin_pie_entities(thin)

	-- Tall percentage text layers
	mirrors.tall_percent_blockentities(show_tall)
	mirrors.tall_percent_unspecified(show_tall)

	-- Thin percentage text layers
	mirrors.thin_percent_blockentities(thin)
	mirrors.thin_percent_unspecified(thin)
end

local thin_enable = function()
	os.execute('echo "340x1080" > ' .. res_state)
	waywall.set_sensitivity(0)
	show_mirrors(false, true, false, true, false)
end

local thin_disable = function()
	os.execute('echo "1920x1080" > ' .. res_state)
	show_mirrors(false, false, false, false, false)
end

local tall_enable = function()
	os.execute('echo "384x16384" > ' .. res_state)
	waywall.set_sensitivity(0.25219978149188543)
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
	os.execute('echo "384x16384" > ' .. res_state)
	show_mirrors(false, true, true, false, false)
end

local lowest_disable = function()
	os.execute('echo "1920x1080" > ' .. res_state)
	show_mirrors(false, false, false, false, false)
end

local resolutions = {
	thin = make_res(340, 1080, thin_enable, thin_disable),
	tall = make_res(384, 16384, tall_enable, tall_disable),
	wide = make_res(1920, 300, wide_enable, wide_disable),
	lowest = make_res(384, 16384, lowest_enable, lowest_disable),
}

-- helpers.res_image("topfgrad.png", { dst = { x = 0, y = 0, w = 1920, h = 390 } }, 1920, 300)
-- helpers.res_image("botfgrad.png", { dst = { x = 0, y = 690, w = 1920, h = 390 } }, 1920, 300)

local click_times = {}
local cps_display = nil
local cps_running = false

local start_cps = function()
	if cps_running then
		cps_running = false
		return
	end
	cps_running = true

	while cps_running do
		local now = waywall.current_time()
		local window_start = now - 300
		local new_times = {}
		local clicks_in_window = 0

		for i = 1, #click_times do
			if click_times[i] > window_start then
				clicks_in_window = clicks_in_window + 1
				new_times[#new_times + 1] = click_times[i]
			end
		end
		click_times = new_times

		local current_cps = math.floor(clicks_in_window * 10 / 3 + 0.5)

		if cps_display then
			cps_display:close()
			cps_display = nil
		end

		if current_cps > 0 then
			local r, g, b
			if current_cps <= 16 then
				-- Black to grey
				local t = (current_cps - 1) / 15
				local v = math.floor(26 + t * 102)
				r, g, b = v, v, v
			elseif current_cps <= 33 then
				-- Grey to yellow
				local t = (current_cps - 17) / 16
				r = math.floor(128 + t * 127)
				g = math.floor(128 + t * 127)
				b = math.floor(128 - t * 128)
			else
				-- Yellow to green
				local t = math.min(1, (current_cps - 34) / 16)
				r = math.floor(255 - t * 255)
				g = 255
				b = 0
			end
			local hex_color = string.format("#%02x%02x%02x", r, g, b)
			cps_display = waywall.text(tostring(current_cps), { x = 1850, y = 20, size = 2, color = hex_color })
		end

		waywall.sleep(50)
	end

	if cps_display then
		cps_display:close()
		cps_display = nil
	end
end

local function cps()
	table.insert(click_times, waywall.current_time())
	return false
end

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
	["*-rmb"] = cps,
	["*-ctrl-0"] = start_cps,
}

waywall.listen("load", function()
	waywall.exec("ninjabrain-bot")
	start_cps()
end)

return config
