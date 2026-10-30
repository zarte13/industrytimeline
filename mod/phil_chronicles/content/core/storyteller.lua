-- Conteur : décide s'il y a une crise ce trimestre et laquelle.
-- deps = { rng, catalog, guardrails } fournis par le moteur (pas de require ici).
local M = {}

-- Tirage du trimestre. Renvoie lancer (booléen), le nouvel état du générateur et info :
-- { wait = n } (recharge en cours, tirage dans n trimestres) ou { value = f, threshold = p }.
function M.roll(rngState, state, quarter, params, deps)
	local cooldown = params.cooldown or deps.catalog.defaultCooldown
	if state.lastLaunch and quarter - state.lastLaunch < cooldown then
		return false, rngState, { wait = cooldown - (quarter - state.lastLaunch) }
	end
	local seuil = params.frequency or deps.catalog.defaultFrequency
	local f, s = deps.rng.next(rngState)
	return f < seuil, s, { value = f, threshold = seuil }
end

-- Choisit région, secteur et industries. filter : { industryId?, sector?, regionId? }
-- Renvoie plan = { sector, regionId, regionName, industries = {ids} } ou nil, raison ; puis l'état rng.
function M.select(rngState, world, info, state, filter, deps)
	local guardrails, rng, catalog = deps.guardrails, deps.rng, deps.catalog
	local busy = guardrails.busySet(state)
	local target
	filter = filter or {}
	local sector, regionId = filter.sector, filter.regionId
	if filter.industryId then
		for _, ind in ipairs(world.industries) do
			if ind.id == filter.industryId then target = ind end
		end
		if not target then return nil, "industrie introuvable", rngState end
		local ok, why = guardrails.isEligible(target, busy)
		if not ok then return nil, why, rngState end
		sector, regionId = target.type, info.of[target.id]
	end

	-- régions candidates avec leurs secteurs éligibles
	local cands = {}
	local saturee = false
	for _, rid in ipairs(info.order) do
		if regionId == nil or rid == regionId then
			if guardrails.regionHasRoom(state, rid, catalog) then
				local types, seen = {}, {}
				for _, ind in ipairs(info.industries[rid]) do
					if (sector == nil or ind.type == sector) and guardrails.isEligible(ind, busy) and not seen[ind.type] then
						seen[ind.type] = true
						types[#types + 1] = ind.type
					end
				end
				if #types > 0 then cands[#cands + 1] = { rid = rid, types = types } end
			else
				saturee = true
			end
		end
	end
	if #cands == 0 then
		return nil, saturee and "région saturée" or "aucune industrie éligible", rngState
	end

	local c, st = rng.pick(rngState, cands)
	local chosen
	chosen, st = rng.pick(st, c.types)
	local ids = {}
	if target then ids[1] = target.id end
	for _, ind in ipairs(info.industries[c.rid]) do
		if #ids >= catalog.maxIndustriesPerEvent then break end
		if ind.type == chosen and (not target or ind.id ~= target.id) and guardrails.isEligible(ind, busy) then
			ids[#ids + 1] = ind.id
		end
	end
	return { sector = chosen, regionId = c.rid, regionName = info.names[c.rid], industries = ids }, nil, st
end

return M
