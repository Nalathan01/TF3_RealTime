local react = ug_require "::/gui/main/react.lua"
local builtin = ug_require "::/gui/main/builtin.lua"
local engine_react_util = ug_require "::/gui/main/engine_react_util.tl"
local game_react_globals = ug_require "::/gui/main/game_react_globals.tl"
local game_bar_widgets = ug_require "::/gui/game_bar/game_bar_widgets.tl"

local FACTORS = { 1, 10, 60, 600, 3600 }
local SCRIPT_NAMES = { "nalathan_echtzeit::/echtzeit/echtzeit.gs", "::/echtzeit/echtzeit.gs" }

local function sendEvent(name, param)
	api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd("", "Echtzeit", name, param))
end

local function readScriptState()
	for __, scriptName in ipairs(SCRIPT_NAMES) do
		local ok, result = pcall(function()
			local entity = api.engine.system.gameScriptSystem.getEntityForGameScript(scriptName)
			local gameScript = api.engine.getComponent(entity, api.type.ComponentType.GAME_SCRIPT)
			return gameScript.state
		end)
		if ok and type(result) == "table" then
			return result
		end
	end
	return nil
end

local function makeStatus()
	local gameTime = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
	local date = api.engine.util.getCalendarDate(gameTime.gameTime)
	local scriptState = readScriptState()

	local factor = nil
	local active = false
	if scriptState ~= nil then
		active = scriptState.active == true
		factor = scriptState.factor
	end

	return {
		active = active,
		factor = factor or 1,
		timeOfDay = gameTime.timeOfDaySec,
		year = date.year,
		month = date.month,
		day = date.day,
	}
end

local function formatClock(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	return string.format("%02d:%02d:%02d", h, m, s)
end

local function formatDate(year, month, day)
	return api.util.formatDate(api.type.Date.new(year, month, day), api.type["enum"].DateFormat.MEDIUM)
end

local function parseDate(text)
	local d, m, y = string.match(text or "", "^%s*(%d%d?)%.(%d%d?)%.(%d%d%d%d)%s*$")
	if not d then
		return nil
	end
	d, m, y = tonumber(d), tonumber(m), tonumber(y)
	if m < 1 or m > 12 or y < 1800 or y > 5000 or d < 1 then
		return nil
	end
	if d > api.type.Date.new(y, m, 1):getEndOfMonth().day then
		return nil
	end
	return { year = y, month = m, day = d }
end

local function parseTime(text)
	local h, m = string.match(text or "", "^%s*(%d%d?)[:%.](%d%d)%s*$")
	if not h then
		return nil
	end
	h, m = tonumber(h), tonumber(m)
	if h > 23 or m > 59 then
		return nil
	end
	return h * 3600 + m * 60
end

local function makeInputRow(label, value, placeholder, onChange)
	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = {
			builtin.TextView{
				meta = { class = "font-scale-body, label" },
				text = label,
			},
			builtin.TextInputField{
				meta = { class = "no-clear-button" },
				value = value,
				placeholderText = placeholder,
				acceptOnFocusLoss = true,
				maxLength = 10,
				onTyping = onChange,
				onValueChange = onChange,
				virtualKeyboardTitle = label,
				virtualKeyboardDescription = placeholder,
			},
		},
	}
end

local EchtzeitPanel = react.RegisterRecipe("NalathanEchtzeitPanel", function()
	local status = engine_react_util.useStepState(makeStatus)
	local dateText = react.useStateLazy(function()
		local st = makeStatus()
		return string.format("%02d.%02d.%04d", st.day, st.month, st.year)
	end)
	local timeText = react.useStateLazy(function()
		local st = makeStatus()
		return string.format("%02d:%02d", math.floor(st.timeOfDay / 3600), math.floor((st.timeOfDay % 3600) / 60))
	end)

	local current = status:old()
	local date = parseDate(dateText:old())
	local seconds = parseTime(timeText:old())
	local valid = date ~= nil and seconds ~= nil

	local function usePcTime()
		local ok, now = pcall(function()
			return os.date("*t", api.util.getLocalTime())
		end)
		if ok and now then
			timeText:set(string.format("%02d:%02d", now.hour, now.min))
		end
	end

	local factorButtons = {}
	local selectedFactor = -1
	for i, f in ipairs(FACTORS) do
		factorButtons[i] = {
			meta = { tooltip = _("ECHTZEIT_LAPSE_" .. f) },
			content = builtin.TextView{
				meta = { class = "font-scale-body" },
				text = f .. "x",
			},
		}
		if f == current.factor then
			selectedFactor = i
		end
	end

	local statusText = _("ECHTZEIT_OFF")
	if current.active then
		statusText = formatDate(current.year, current.month, current.day) .. "   " .. formatClock(current.timeOfDay)
	end

	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Vertical,
		children = {
			builtin.TextView{
				meta = { class = "font-scale-headline" },
				text = statusText,
			},
			makeInputRow(_("ECHTZEIT_DATE"), dateText:old(), "TT.MM.JJJJ", function(v) dateText:set(v) end),
			makeInputRow(_("ECHTZEIT_TIME"), timeText:old(), "HH:MM", function(v) timeText:set(v) end),
			builtin.TextView{
				meta = { class = "font-scale-body" },
				text = valid and "" or _("ECHTZEIT_INVALID"),
			},
			builtin.BoxLayout{
				orientation = builtin.type.Orientation.Horizontal,
				children = {
					builtin.Button{
						meta = { class = "secondary" },
						content = builtin.TextView{ meta = { class = "font-scale-body" }, text = _("ECHTZEIT_PC_TIME") },
						onClick = usePcTime,
					},
					builtin.Button{
						meta = { class = "primary", enabled = valid },
						content = builtin.TextView{ meta = { class = "font-scale-body" }, text = _("ECHTZEIT_START") },
						onClick = function()
							if valid then
								sendEvent("EchtzeitSet", {
									year = date.year,
									month = date.month,
									day = date.day,
									seconds = seconds,
								})
							end
						end,
					},
				},
			},
			builtin.TextView{
				meta = { class = "font-scale-body" },
				text = _("ECHTZEIT_LAPSE"),
			},
			builtin.ToggleButtonGroup{
				buttons = factorButtons,
				selected = selectedFactor,
				deselectAllowed = selectedFactor == -1,
				onValueChange = function(index)
					if FACTORS[index] then
						sendEvent("EchtzeitFactor", { factor = FACTORS[index] })
					end
				end,
			},
			builtin.Button{
				meta = { class = "secondary", enabled = current.active },
				content = builtin.TextView{ meta = { class = "font-scale-body" }, text = _("ECHTZEIT_STOP") },
				onClick = function()
					sendEvent("EchtzeitStop", {})
				end,
			},
		},
	}
end)

local EchtzeitWindow
EchtzeitWindow = react.RegisterWrapperRecipe("NalathanEchtzeitWindow", builtin.Window, function(_params)
	return builtin.Window{
		title = _("ECHTZEIT_TITLE"),
		closable = true,
		id = "nalathanEchtzeitWindow",
		onClose = function()
			local windowApi = game_react_globals.getDefaultWindowApi()
			if windowApi then
				windowApi.removeAllWindows(EchtzeitWindow)
			end
		end,
		content = EchtzeitPanel({}),
	}
end)

local function openWindow()
	local windowApi = game_react_globals.getDefaultWindowApi()
	if windowApi then
		windowApi.removeAllWindows(EchtzeitWindow)
		windowApi.addSingletonWindow(EchtzeitWindow, {})
	end
end

local EchtzeitPlugin = react.RegisterPluginRecipe(game_bar_widgets.GameBarInfoDisplayExtension, "NalathanEchtzeitPlugin", function()
	local status = engine_react_util.useStepState(makeStatus)
	local current = status:old()

	local text = _("ECHTZEIT_OFF")
	if current.active then
		text = formatClock(current.timeOfDay)
		if current.factor ~= 1 then
			text = text .. "  " .. current.factor .. "x"
		end
	end

	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = {
			builtin.Button{
				meta = { class = "secondary", tooltip = _("ECHTZEIT_OPEN") },
				content = builtin.TextView{
					meta = { class = "font-scale-body" },
					text = text,
				},
				onClick = openWindow,
			},
		},
	}
end)

function data()
	return {
		EchtzeitPlugin = EchtzeitPlugin,
	}
end
