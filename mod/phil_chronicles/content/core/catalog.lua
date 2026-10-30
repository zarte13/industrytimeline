-- Catalogue : constantes de la crise sectorielle et noms français des secteurs.
local M = {}

M.kind = "sector_crisis"
M.maxDuration = 10          -- 1 + 1 + 4 + 4 trimestres
M.rumorLength = 1
M.announceLength = 1
M.troughMin = 2
M.troughMax = 4
M.crisisMultiplier = 0.6
M.recoveryStep = 0.1
M.recoveryQuarters = 3      -- 0.7, 0.8, 0.9 puis retour à 1.0 (phase done)
M.maxIndustriesPerEvent = 3
M.maxActivePerRegion = 2
M.keepFinished = 40
M.maxCatchUp = 8
M.defaultFrequency = 0.25
M.defaultCooldown = 4

-- Les 33 types d'industrie de TF3 (base/content/industries/*.zip), relevés le 2026-10-30.
-- noun : « l'acier », of : « de l'acier », name : « Acier »
M.sectors = {
	brewery = { noun = "la brasserie", of = "de la brasserie", name = "Brasserie" },
	bricks_works = { noun = "la briqueterie", of = "de la briqueterie", name = "Briqueterie" },
	cement_plant = { noun = "le ciment", of = "du ciment", name = "Cimenterie" },
	chemical_plant = { noun = "la chimie", of = "de la chimie", name = "Chimie" },
	clay_pit = { noun = "l'argile", of = "de l'argile", name = "Argilière" },
	coal_mine = { noun = "le charbon", of = "du charbon", name = "Charbon" },
	cotton_farm = { noun = "le coton", of = "du coton", name = "Coton" },
	dredging_platform = { noun = "le dragage", of = "du dragage", name = "Dragage" },
	farm = { noun = "l'agriculture", of = "de l'agriculture", name = "Agriculture" },
	fishing_grounds = { noun = "la pêche", of = "de la pêche", name = "Pêche" },
	food_factory = { noun = "l'agroalimentaire", of = "de l'agroalimentaire", name = "Agroalimentaire" },
	forest = { noun = "la forêt", of = "de la forêt", name = "Forêt" },
	furniture_factory = { noun = "le meuble", of = "du meuble", name = "Ameublement" },
	glass_works = { noun = "la verrerie", of = "de la verrerie", name = "Verrerie" },
	iron_ore_mine = { noun = "le minerai de fer", of = "du minerai de fer", name = "Minerai de fer" },
	livestock_farm = { noun = "l'élevage", of = "de l'élevage", name = "Élevage" },
	machine_factory = { noun = "la mécanique", of = "de la mécanique", name = "Mécanique" },
	oil_platform = { noun = "le pétrole en mer", of = "du pétrole en mer", name = "Pétrole en mer" },
	oil_refinery = { noun = "le raffinage", of = "du raffinage", name = "Raffinage" },
	oil_well = { noun = "le pétrole", of = "du pétrole", name = "Pétrole" },
	paper_mill = { noun = "la papeterie", of = "de la papeterie", name = "Papeterie" },
	printing_press = { noun = "l'imprimerie", of = "de l'imprimerie", name = "Imprimerie" },
	quarry = { noun = "la pierre", of = "de la pierre", name = "Carrière" },
	rubber_farm = { noun = "le caoutchouc", of = "du caoutchouc", name = "Caoutchouc" },
	sand_excavator = { noun = "le sable", of = "du sable", name = "Sablière" },
	sand_pit = { noun = "le sable", of = "du sable", name = "Sablière" },
	saw_mill = { noun = "le sciage", of = "du sciage", name = "Scierie" },
	steel_mill = { noun = "l'acier", of = "de l'acier", name = "Acier" },
	textile_factory = { noun = "le textile", of = "du textile", name = "Textile" },
	tire_factory = { noun = "le pneumatique", of = "du pneumatique", name = "Pneumatique" },
	tool_factory = { noun = "l'outillage", of = "de l'outillage", name = "Outillage" },
	vehicle_factory = { noun = "l'automobile", of = "de l'automobile", name = "Automobile" },
	weaving_mill = { noun = "le tissage", of = "du tissage", name = "Tissage" },
}

-- Entrée de secteur ; un type inconnu (industrie d'un autre mod) devient « l'industrie », jamais le nom brut.
function M.sector(sectorType)
	local s = M.sectors[sectorType]
	if s then return s end
	return { noun = "l'industrie", of = "de l'industrie", name = "Industrie" }
end

return M
