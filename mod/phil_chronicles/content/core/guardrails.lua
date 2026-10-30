-- Garde-fous : industries du joueur, plafond par région, exclusivité des industries.
local M = {}

-- Ensemble des industries (clé = tostring(id)) prises par un événement actif.
function M.busySet(state)
	local busy = {}
	for _, ev in ipairs(state.events) do
		if ev.phase ~= "done" then
			for _, id in ipairs(ev.industries) do busy[tostring(id)] = true end
		end
	end
	return busy
end

function M.regionActive(state, regionId)
	local n = 0
	for _, ev in ipairs(state.events) do
		if ev.phase ~= "done" and ev.regionId == regionId then n = n + 1 end
	end
	return n
end

function M.regionHasRoom(state, regionId, catalog)
	return M.regionActive(state, regionId) < catalog.maxActivePerRegion
end

-- Une industrie est éligible si elle n'est pas au joueur et pas déjà touchée.
function M.isEligible(industry, busy)
	if industry.playerOwned then return false, "industrie du joueur" end
	if busy[tostring(industry.id)] then return false, "industrie déjà touchée" end
	return true
end

-- Trop long : l'événement doit être terminé d'office.
function M.overdue(ev, quarter, catalog)
	return ev.phase ~= "done" and quarter - ev.startQuarter >= catalog.maxDuration
end

return M
