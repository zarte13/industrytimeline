-- Cycle de vie d'un événement : rumor -> announce -> trough -> recovery -> done.
-- Les fonctions modifient l'événement en place ; catalog est passé en paramètre.
local M = {}

local SUIVANTE = { rumor = "announce", announce = "trough", trough = "recovery", recovery = "done" }

local function dixieme(x)
	return math.floor(x * 10 + 0.5) / 10
end

-- Entre dans une phase et fixe le multiplicateur correspondant.
local function entre(ev, phase, quarter, catalog)
	ev.phase = phase
	ev.quartersInPhase = 0
	ev.history = ev.history or {} -- anciennes sauvegardes : l'historique commence ici
	ev.history[#ev.history + 1] = { phase = phase, quarter = quarter }
	if phase == "announce" or phase == "trough" then
		ev.multiplier = catalog.crisisMultiplier
	elseif phase == "recovery" then
		ev.multiplier = dixieme(catalog.crisisMultiplier + catalog.recoveryStep)
	else
		ev.multiplier = 1.0
		if phase == "done" then ev.endQuarter = quarter end
	end
	if ev.minMultiplier == nil or ev.multiplier < ev.minMultiplier then ev.minMultiplier = ev.multiplier end
end

function M.new(id, sector, regionId, regionName, industries, troughLength, quarter, catalog)
	return {
		id = id, kind = catalog.kind, sector = sector,
		regionId = regionId, regionName = regionName,
		industries = industries,
		phase = "rumor", quartersInPhase = 0,
		troughLength = troughLength, multiplier = 1.0,
		startQuarter = quarter, endQuarter = nil,
		history = { { phase = "rumor", quarter = quarter } }, minMultiplier = 1.0,
	}
end

function M.isActive(ev)
	return ev.phase ~= "done"
end

-- Un trimestre de plus. Renvoie la nouvelle phase si elle change, sinon nil.
function M.step(ev, quarter, catalog)
	if ev.phase == "done" then return nil end
	ev.quartersInPhase = ev.quartersInPhase + 1
	local phase = ev.phase
	if phase == "rumor" then
		if ev.quartersInPhase >= catalog.rumorLength then entre(ev, "announce", quarter, catalog) return "announce" end
	elseif phase == "announce" then
		if ev.quartersInPhase >= catalog.announceLength then entre(ev, "trough", quarter, catalog) return "trough" end
	elseif phase == "trough" then
		if ev.quartersInPhase >= (ev.troughLength or catalog.troughMin) then entre(ev, "recovery", quarter, catalog) return "recovery" end
	elseif phase == "recovery" then
		local m = dixieme(ev.multiplier + catalog.recoveryStep)
		if m >= 1.0 - 1e-9 then entre(ev, "done", quarter, catalog) return "done" end
		ev.multiplier = m
	end
	return nil
end

-- Saute directement à la phase suivante (débogage). Renvoie la nouvelle phase ou nil.
function M.skip(ev, quarter, catalog)
	local nxt = SUIVANTE[ev.phase]
	if not nxt then return nil end
	entre(ev, nxt, quarter, catalog)
	return nxt
end

-- Termine l'événement d'office (garde-fou de durée maximale).
function M.finish(ev, quarter, catalog)
	if ev.phase == "done" then return nil end
	entre(ev, "done", quarter, catalog)
	return "done"
end

return M
