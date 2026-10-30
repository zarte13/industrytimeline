-- Lit le moteur du jeu et produit la photo de la partie (format : notes/mvp-design.md).
-- Seul module, avec effects.lua, qui lit l'API du jeu.

local M = {}

local function center(entity)
	local bv = api.engine.getComponent(entity, api.type.ComponentType.BOUNDING_VOLUME)
	if bv == nil or bv.bbox == nil then
		return 0.0, 0.0
	end
	return (bv.bbox.min.x + bv.bbox.max.x) * 0.5, (bv.bbox.min.y + bv.bbox.max.y) * 0.5
end

-- « industries/coal_mine/coal_mine.con » ou « ::/industries/... » -> « coal_mine »
local function industryType(fileName)
	if fileName == nil then
		return "unknown"
	end
	return tostring(fileName):match("([^/]+)%.con$") or tostring(fileName)
end

-- propriétaire posé sur l'industrie ou sur sa construction (le jeu lit l'un ou l'autre)
local function isPlayerOwned(entity, construction, player)
	for __, e in ipairs({ entity, construction }) do
		if e ~= nil and e >= 0 then
			local po = api.engine.getComponent(e, api.type.ComponentType.PLAYER_OWNED)
			if po ~= nil and po.player == player then
				return true
			end
		end
	end
	return false
end

-- l'entité INDUSTRY pointe vers son STOCK_LIST (parfois elle-même)
function M.getProductivity(entity)
	local industry = api.engine.getComponent(entity, api.type.ComponentType.INDUSTRY)
	local stockEntity = (industry ~= nil and industry.stockList ~= nil) and industry.stockList or entity
	local stockList = api.engine.getComponent(stockEntity, api.type.ComponentType.STOCK_LIST)
	if stockList == nil or stockList.modifiers == nil then
		return nil
	end
	return stockList.modifiers.productivity
end

function M.readDate()
	local gameTime = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
	local d = api.engine.util.getCalendarDate(gameTime.gameTime)
	return d.year, d.month, d.day
end

function M.read()
	local world = { industries = {}, towns = {} }
	world.year, world.month, world.day = M.readDate()

	local player = api.engine.util.getPlayer()
	for __, entity in ipairs(api.engine.getEntitiesWithComponent(api.type.ComponentType.INDUSTRY)) do
		local industry = api.engine.getComponent(entity, api.type.ComponentType.INDUSTRY)
		local construction = industry and industry.construction or -1
		local con = (construction ~= nil and construction >= 0)
			and api.engine.getComponent(construction, api.type.ComponentType.CONSTRUCTION) or nil
		local x, y = center(entity)
		world.industries[#world.industries + 1] = {
			id = entity,
			type = industryType(con and con.fileName),
			name = api.engine.util.getEntityName(entity) or ("#" .. tostring(entity)),
			x = x, y = y,
			playerOwned = isPlayerOwned(entity, construction, player),
			productivity = M.getProductivity(entity) or 1.0,
		}
	end

	for __, entity in ipairs(api.engine.getEntitiesWithComponent(api.type.ComponentType.TOWN)) do
		local x, y = center(entity)
		world.towns[#world.towns + 1] = {
			id = entity,
			name = api.engine.util.getEntityName(entity) or ("#" .. tostring(entity)),
			x = x, y = y,
		}
	end
	return world
end

return M
