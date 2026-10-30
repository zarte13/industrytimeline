-- Régions : la région d'une industrie est la ville la plus proche.
local M = {}

M.defaultId = 0
M.defaultName = "Campagne"

-- info = { of = {[industryId]=regionId}, names = {[regionId]=nom},
--          order = {regionId...}, industries = {[regionId]={industrie...}} }
function M.build(world)
	local info = { of = {}, names = {}, order = {}, industries = {} }
	local towns = world.towns or {}
	for _, t in ipairs(towns) do
		info.names[t.id] = t.name
		info.order[#info.order + 1] = t.id
		info.industries[t.id] = {}
	end
	if #towns == 0 then
		info.names[M.defaultId] = M.defaultName
		info.order[1] = M.defaultId
		info.industries[M.defaultId] = {}
	end
	for _, ind in ipairs(world.industries or {}) do
		local rid = M.defaultId
		local best
		for _, t in ipairs(towns) do
			local dx, dy = t.x - ind.x, t.y - ind.y
			local d = dx * dx + dy * dy
			if not best or d < best then best = d rid = t.id end
		end
		info.of[ind.id] = rid
		local list = info.industries[rid]
		list[#list + 1] = ind
	end
	return info
end

return M
