-- API du jeu simulée (N2 hors jeu) : fournit ug_require, log et api pour exécuter le script de jeu.
-- Les commandes sont mises en file par sendCommand et appliquées au début du update suivant,
-- comme dans le moteur réel (asynchrone).
local M = {}

local CONTENT = "mod/phil_chronicles/content/"
M.SCRIPT = CONTENT .. "game_mechanics/chronicles/chronicles.script.lua"
M.NOTIFICATION_SCRIPT = CONTENT .. "game_mechanics/chronicles/chronicles_notification.script.lua"
M.PLAYER = 1
M.WORLD = 1

local function deepcopy(v)
	if type(v) ~= "table" then return v end
	local c = {}
	for k, x in pairs(v) do c[deepcopy(k)] = deepcopy(x) end
	return c
end
M.deepcopy = deepcopy

-- Carte : 8 industries (la 102 est au joueur), 3 villes.
local INDUSTRIES = {
	{ id = 101, type = "steel_mill", name = "Aciérie de Valmont", x = 1200, y = -340 },
	{ id = 102, type = "steel_mill", name = "Aciérie du Nord", x = 900, y = -100, player = true },
	{ id = 103, type = "steel_mill", name = "Aciérie de Brenne", x = 20300, y = 100, otherOwner = true },
	{ id = 104, type = "coal_mine", name = "Mine de charbon de Valmont", x = 700, y = -600 },
	{ id = 105, type = "coal_mine", name = "Mine de charbon de Roche", x = 3200, y = 800 },
	{ id = 106, type = "iron_ore_mine", name = "Mine de fer de Valmont", x = 1500, y = 100 },
	{ id = 107, type = "farm", name = "Ferme de Roche", x = 2800, y = 300 },
	{ id = 108, type = "saw_mill", name = "Scierie de Brenne", x = 20100, y = 400, selfStock = true },
}
local TOWNS = {
	{ id = 301, name = "Valmont", x = 1000, y = -300 },
	{ id = 302, name = "Roche", x = 3000, y = 500 },
	{ id = 303, name = "Brenne", x = 20000, y = 0 },
}
M.industryIds = {}
for _, i in ipairs(INDUSTRIES) do M.industryIds[#M.industryIds + 1] = i.id end
M.playerIndustry = 102

local function bbox(x, y)
	return { min = { x = x - 50, y = y - 50 }, max = { x = x + 50, y = y + 50 } }
end

function M.new()
	local mock = {
		logs = {}, notifications = {}, queue = {}, history = {}, commands = 0,
		date = { year = 1900, month = 1, day = 1 },
		gameTime = 0,
	}
	local entities, names, ofType = {}, {}, { INDUSTRY = {}, TOWN = {} }
	local function comp(id, ctype, value)
		entities[id] = entities[id] or {}
		entities[id][ctype] = value
	end

	for _, i in ipairs(INDUSTRIES) do
		local con, stock = i.id + 100, i.id + 300
		local stockEntity = i.selfStock and i.id or stock
		comp(i.id, "INDUSTRY", { stockList = (not i.selfStock) and stock or nil, construction = con })
		comp(i.id, "BOUNDING_VOLUME", { bbox = bbox(i.x, i.y) })
		comp(con, "CONSTRUCTION", { fileName = "industries/" .. i.type .. "/" .. i.type .. ".con" })
		comp(stockEntity, "STOCK_LIST", { modifiers = { productivity = 1.0, capacity = 1.0 } })
		if i.player then comp(con, "PLAYER_OWNED", { player = M.PLAYER }) end
		if i.otherOwner then comp(i.id, "PLAYER_OWNED", { player = 0 }) end
		names[i.id] = i.name
		ofType.INDUSTRY[#ofType.INDUSTRY + 1] = i.id
	end
	for _, t in ipairs(TOWNS) do
		comp(t.id, "TOWN", {})
		comp(t.id, "BOUNDING_VOLUME", { bbox = bbox(t.x, t.y) })
		names[t.id] = t.name
		ofType.TOWN[#ofType.TOWN + 1] = t.id
	end
	comp(M.WORLD, "GAME_TIME", { gameTime = 0 })

	-- état de script : get() et set() copient en profondeur, comme GameScriptState
	local state = { data = nil, subs = {}, sets = 0 }
	function state:get() return deepcopy(self.data) end
	function state:set(t) self.data = deepcopy(t); self.sets = self.sets + 1 end
	function state:hasEventSubscriptions() return #self.subs > 0 end
	function state:subscribeToEvent(name) self.subs[#self.subs + 1] = name end
	mock.state = state

	local function stockEntityOf(entity)
		local ind = entities[entity] and entities[entity].INDUSTRY
		return (ind and ind.stockList) or entity
	end

	local api = {
		engine = {
			getComponent = function(entity, ctype)
				local e = entities[entity]
				local c = e and e[ctype]
				if ctype == "GAME_TIME" and c then
					return { gameTime = mock.gameTime }
				end
				return c
			end,
			getEntitiesWithComponent = function(ctype) return deepcopy(ofType[ctype] or {}) end,
			entityExists = function(entity) return entities[entity] ~= nil end,
			util = {
				getWorld = function() return M.WORLD end,
				getPlayer = function() return M.PLAYER end,
				getEntityName = function(entity) return names[entity] end,
				getCalendarDate = function(gameTime)
					assert(type(gameTime) == "number", "getCalendarDate : gameTime numérique attendu")
					return { year = mock.date.year, month = mock.date.month, day = mock.date.day }
				end,
			},
		},
		type = {
			ComponentType = {
				INDUSTRY = "INDUSTRY", CONSTRUCTION = "CONSTRUCTION", BOUNDING_VOLUME = "BOUNDING_VOLUME",
				PLAYER_OWNED = "PLAYER_OWNED", STOCK_LIST = "STOCK_LIST", GAME_TIME = "GAME_TIME", TOWN = "TOWN",
			},
			StockList = { Modifiers = { new = function(copyFrom)
				return copyFrom and deepcopy(copyFrom) or { productivity = 1.0 }
			end } },
		},
		cmd = {
			makeStockListSetModifiersCmd = function(entity, modifiers)
				return { kind = "setModifiers", entity = entity, modifiers = deepcopy(modifiers) }
			end,
			makeScriptingSendEventCmd = function(src, id, name, param)
				return { kind = "event", src = src, id = id, name = name, param = deepcopy(param) }
			end,
			sendCommand = function(cmd)
				mock.commands = mock.commands + 1
				mock.queue[#mock.queue + 1] = cmd
			end,
		},
	}
	mock.api = api

	local function logger(level)
		return function(text)
			mock.logs[#mock.logs + 1] = { level = level, text = tostring(text) }
		end
	end
	mock.log = { message = logger("message"), warning = logger("warning"), error = logger("error") }

	local cache = {}
	function mock.ug_require(path)
		local rel = path:match("^phil_chronicles::/(.+)$")
		assert(rel, "ug_require : chemin inconnu " .. tostring(path))
		if cache[rel] == nil then cache[rel] = dofile(CONTENT .. rel) end
		return cache[rel]
	end

	-- ---- commandes asynchrones
	function mock.flush()
		local queue = mock.queue
		mock.queue = {}
		for _, cmd in ipairs(queue) do
			if cmd.kind == "setModifiers" then
				assert(entities[cmd.entity], "commande sur une entité inexistante : " .. tostring(cmd.entity))
				assert(type(cmd.modifiers.productivity) == "number", "productivité non numérique")
				entities[stockEntityOf(cmd.entity)].STOCK_LIST.modifiers = cmd.modifiers
				local h = mock.history[cmd.entity] or {}
				h[#h + 1] = cmd.modifiers.productivity
				mock.history[cmd.entity] = h
			elseif cmd.kind == "event" and cmd.id == "Notifications" and cmd.name == "add" then
				mock.notifications[#mock.notifications + 1] = cmd.param
			end
		end
		return #queue
	end

	-- ---- accès de test
	function mock.productivity(id) return entities[stockEntityOf(id)].STOCK_LIST.modifiers.productivity end
	function mock.setProductivity(id, v) entities[stockEntityOf(id)].STOCK_LIST.modifiers.productivity = v end
	function mock.modifiers(id) return entities[stockEntityOf(id)].STOCK_LIST.modifiers end
	function mock.quarterIndex() return mock.date.year * 4 + (mock.date.month - 1) // 3 end
	function mock.advanceQuarter()
		mock.date.month = mock.date.month + 3
		if mock.date.month > 12 then
			mock.date.month = mock.date.month - 12
			mock.date.year = mock.date.year + 1
		end
	end
	function mock.hasLog(sub, level)
		for _, l in ipairs(mock.logs) do
			if (level == nil or l.level == level) and l.text:find(sub, 1, true) then return true, l.text end
		end
		return false
	end
	function mock.errorLogs()
		local out = {}
		for _, l in ipairs(mock.logs) do if l.level == "error" then out[#out + 1] = l.text end end
		return out
	end

	-- ---- globaux et script
	_G.ug_require = mock.ug_require
	_G.log = mock.log
	_G.api = api
	mock.script = dofile(M.SCRIPT)

	function mock.update(dt)
		mock.gameTime = mock.gameTime + math.floor((dt or 0) * 1000)
		mock.flush()
		mock.script.update({}, state, dt)
	end
	function mock.handle(name, param, id)
		mock.script.handleEvent({}, state, "", id or "PhilChronicles", name, param)
	end
	return mock
end

return M
