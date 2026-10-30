-- Applique les productivités visées : n'envoie une commande que si l'écart dépasse la tolérance,
-- et recopie les autres modificateurs de l'industrie.

local world_reader = ug_require "phil_chronicles::/adapters/world_reader.lua"

local M = {}

M.tolerance = 0.005

-- targets : { [entité] = productivité visée } ; renvoie le nombre de commandes envoyées
function M.apply(targets)
	local sent = 0
	for key, target in pairs(targets) do
		local entity = tonumber(key)
		if entity ~= nil and api.engine.entityExists(entity) then
			local current = world_reader.getProductivity(entity)
			if current ~= nil and math.abs(current - target) > M.tolerance then
				local industry = api.engine.getComponent(entity, api.type.ComponentType.INDUSTRY)
				local stockEntity = (industry ~= nil and industry.stockList ~= nil) and industry.stockList or entity
				local stockList = api.engine.getComponent(stockEntity, api.type.ComponentType.STOCK_LIST)
				local modifiers = api.type.StockList.Modifiers.new(stockList.modifiers)
				modifiers.productivity = target
				api.cmd.sendCommand(api.cmd.makeStockListSetModifiersCmd(entity, modifiers))
				sent = sent + 1
			end
		end
	end
	return sent
end

return M
