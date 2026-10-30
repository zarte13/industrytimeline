-- Carte fictive : deux grappes de villes, 12 industries, une appartient au joueur (id 2).
local M = {}

M.playerId = 2
M.start = { year = 1900, month = 1, day = 1 }

local function ind(id, type_, name, x, y, player)
	return { id = id, type = type_, name = name, x = x, y = y, playerOwned = player or false, productivity = 1.0 }
end

function M.build()
	return {
		year = M.start.year, month = M.start.month, day = M.start.day,
		towns = {
			{ id = 77, name = "Valmont", x = 1000.0, y = -300.0 },
			{ id = 78, name = "Roche", x = 3000.0, y = 500.0 },
			{ id = 79, name = "Brenne", x = 20000.0, y = 0.0 },
			{ id = 80, name = "Sorel", x = 22500.0, y = 1500.0 },
		},
		industries = {
			ind(1, "steel_mill", "Aciérie de Valmont", 1200.0, -340.0),
			ind(2, "steel_mill", "Aciérie du Nord", 900.0, -100.0, true),
			ind(3, "steel_mill", "Aciérie de Brenne", 20300.0, 100.0),
			ind(4, "coal_mine", "Mine de charbon de Valmont", 700.0, -600.0),
			ind(5, "coal_mine", "Mine de charbon de Roche", 3200.0, 800.0),
			ind(6, "coal_mine", "Mine de charbon de Sorel", 22800.0, 1700.0),
			ind(7, "iron_ore_mine", "Mine de fer de Valmont", 1500.0, 100.0),
			ind(8, "iron_ore_mine", "Mine de fer de Brenne", 19500.0, -300.0),
			ind(9, "farm", "Ferme de Roche", 2800.0, 300.0),
			ind(10, "farm", "Ferme de Sorel", 22000.0, 1200.0),
			ind(11, "saw_mill", "Scierie de Brenne", 20100.0, 400.0),
			ind(12, "forest", "Forêt de Roche", 3400.0, 100.0),
		},
	}
end

-- Avance la date d'un trimestre (trois mois).
function M.advanceQuarter(world)
	world.month = world.month + 3
	if world.month > 12 then
		world.month = world.month - 12
		world.year = world.year + 1
	end
end

function M.findIndustry(world, id)
	for _, i in ipairs(world.industries) do
		if i.id == id then return i end
	end
end

return M
