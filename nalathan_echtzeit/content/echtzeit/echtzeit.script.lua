local DAY_SECONDS = 24 * 60 * 60
local REAL_DAY_MILLIS = DAY_SECONDS * 1000
local GAME_TIME_SCRIPT = "::/game_mechanics/game_time/game_time.gs"

local function getGameTime()
	return api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
end

local function sendCalendarSpeed(factor)
	api.cmd.sendCommand(api.cmd.makeGameSetCalendarSpeedCmd(math.floor(REAL_DAY_MILLIS / factor)))
end

local function getCurrentSeconds(s, gameTimeMs)
	return s.anchorSec + (gameTimeMs-s.anchorGameTime) / 1000 * s.factor
end

local function reanchor(s, gameTimeMs)
	s.anchorSec = getCurrentSeconds(s, gameTimeMs)
	s.anchorGameTime = gameTimeMs
end

local function normalizeDate(s)
	local days = math.floor(s.anchorSec / DAY_SECONDS)
	if days ~= 0 then
		local date = api.type.Date.new(s.year, s.month, s.day):addOffsetDays(days)
		s.year = date.year
		s.month = date.month
		s.day = date.day
		s.anchorSec = s.anchorSec-days * DAY_SECONDS
	end
end

local function getBaseTimeOfDayMode()
	local ok, mode = pcall(function()
		local entity = api.engine.system.gameScriptSystem.getEntityForGameScript(GAME_TIME_SCRIPT)
		local gameScript = api.engine.getComponent(entity, api.type.ComponentType.GAME_SCRIPT)
		return gameScript.state.timeOfDayMode
	end)
	if ok then
		return mode
	end
	return nil
end

local function syncEngine(s, gameTime)
	local current = api.engine.util.getCalendarDate(gameTime.gameTime)
	if current.year ~= s.year or current.month ~= s.month or current.day ~= s.day then
		api.cmd.sendCommand(api.cmd.makeGameSetDateCmd(api.type.Date.new(s.year, s.month, s.day)))
	end

	local timeOfDay = math.floor(getCurrentSeconds(s, gameTime.gameTime)) % DAY_SECONDS
	if timeOfDay ~= gameTime.timeOfDaySec then
		api.cmd.sendCommand(api.cmd.makeGameSetTimeOfDayCmd(timeOfDay))
	end

	local mode = getBaseTimeOfDayMode()
	if mode ~= nil and mode ~= "Constant" then
		api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd("", "GameTime", "SetMode", { mode = "Constant" }))
	end
end

local function update(_userParams, state, _dt)
	state:subscribeToEvent("EchtzeitSet")
	state:subscribeToEvent("EchtzeitFactor")
	state:subscribeToEvent("EchtzeitStop")

	local s = state:get()
	if s == nil or not s.active then
		return
	end

	local gameTime = getGameTime()
	if getCurrentSeconds(s, gameTime.gameTime) >= DAY_SECONDS then
		reanchor(s, gameTime.gameTime)
		normalizeDate(s)
		state:set(s)
	end

	syncEngine(s, gameTime)
end

local function handleEvent(_userParams, state, _src, id, name, param)
	if id ~= "Echtzeit" then
		return
	end

	local s = state:get() or {}
	local gameTime = getGameTime()

	if name == "EchtzeitSet" then
		s.active = true
		s.factor = s.factor or 1
		s.year = param.year
		s.month = param.month
		s.day = param.day
		s.anchorSec = param.seconds
		s.anchorGameTime = gameTime.gameTime
		normalizeDate(s)
		sendCalendarSpeed(s.factor)
		api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd("", "GameTime", "SetMode", { mode = "Constant" }))
		state:set(s)
	elseif name == "EchtzeitFactor" then
		if s.active then
			reanchor(s, gameTime.gameTime)
			normalizeDate(s)
		end
		s.factor = param.factor
		if s.active then
			sendCalendarSpeed(s.factor)
		end
		state:set(s)
	elseif name == "EchtzeitStop" then
		s.active = false
		api.cmd.sendCommand(api.cmd.makeGameSetCalendarSpeedCmd(api.util.getDefaultDayDuration()))
		state:set(s)
	end
end

function data()
	return {
		update = update,
		handleEvent = handleEvent,
	}
end
