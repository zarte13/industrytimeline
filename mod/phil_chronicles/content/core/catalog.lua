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
M.keepFinished = 20
M.maxCatchUp = 8
M.defaultFrequency = 0.25
M.defaultCooldown = 4

-- noun : « l'acier », of : « de l'acier », name : « Acier »
M.sectors = {
	steel_mill = { noun = "l'acier", of = "de l'acier", name = "Acier" },
	coal_mine = { noun = "le charbon", of = "du charbon", name = "Charbon" },
	iron_ore_mine = { noun = "le minerai de fer", of = "du minerai de fer", name = "Minerai de fer" },
	farm = { noun = "l'agriculture", of = "de l'agriculture", name = "Agriculture" },
	saw_mill = { noun = "le sciage", of = "du sciage", name = "Scierie" },
	forest = { noun = "la forêt", of = "de la forêt", name = "Forêt" },
	oil_refinery = { noun = "le raffinage", of = "du raffinage", name = "Raffinage" },
	oil_well = { noun = "le pétrole", of = "du pétrole", name = "Pétrole" },
	food_processing_plant = { noun = "l'agroalimentaire", of = "de l'agroalimentaire", name = "Agroalimentaire" },
	stone_quarry = { noun = "la pierre", of = "de la pierre", name = "Carrière" },
	construction_material = { noun = "les matériaux de construction", of = "des matériaux de construction", name = "Matériaux" },
}

-- Entrée de secteur, avec repli sur le type brut.
function M.sector(sectorType)
	local s = M.sectors[sectorType]
	if s then return s end
	return { noun = sectorType, of = "de " .. sectorType, name = sectorType }
end

return M
