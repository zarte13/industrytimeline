-- Sondes de l'étape 0 de la v10 : vérifient en jeu ce que la recherche n'a lu que dans les fichiers du jeu
-- (notes/v10-design.md, « Restent à vérifier en jeu »). Chaque sonde écrit ce qu'elle obtient avec trace(ligne).
-- Elles ne servent qu'au débogage : rien ici n'est utilisé par les événements du mod.

local M = {}

local SPAWN_TYPES = { "saw_mill", "forest", "coal_mine", "quarry", "sand_pit", "farm" }
local LOG_NAMES = { "itemsLoaded", "itemsUnloaded", "itemsProduced", "itemsConsumed" }
local SPAWN_NOTIFICATION = "::/game_mechanics/notifications/types/industry_spawn.script"
local CLOSE_NOTIFICATION = "::/game_mechanics/notifications/types/industry_close.script"

-- résultats des rappels de commandes : arrivent hors du pas du script, recopiés dans l'état par drain()
M.pending = {}

local function now()
	local gt = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
	return gt.gameTime
end

-- durée d'un trimestre en ms de jeu à la vitesse actuelle du calendrier ; figé = durée par défaut
function M.quarterMs()
	local gs = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_SPEED)
	local mpd = gs and gs.millisPerDay or 0
	if mpd == nil or mpd <= 0 then
		return api.util.getDefaultYearDuration() / 4, true
	end
	return api.util.getYearDuration(mpd) / 4, false
end

local function name(entity)
	return api.engine.util.getEntityName(entity) or ("#" .. tostring(entity))
end

-- même forme que entity_util.makeEntityAndRevision0 du jeu (attendue par les notifications d'industrie)
local function entityAndRevision0(entity)
	if not api.engine.entityExists(entity) then return nil end
	local rev = api.engine.getRevision(entity)
	return { entity = entity, revision = { num = { rev.num[1], 0, 0 } } }
end

local function notify(kind, industry, resName)
	local notification = {
		type = kind,
		params = { entity = entityAndRevision0(industry), resName = resName },
		autoDismissDuration = 60000,
	}
	api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd("", "Notifications", "add", notification))
end

local function has(entity, componentType)
	return api.engine.getComponent(entity, componentType) ~= nil
end

-- l'entité renvoyée par une construction : l'industrie elle-même, ou la construction qui la contient ?
local function industryOf(entity)
	if has(entity, api.type.ComponentType.INDUSTRY) then return entity end
	local con = api.engine.getComponent(entity, api.type.ComponentType.CONSTRUCTION)
	if con ~= nil and con.industries ~= nil and con.industries[1] ~= nil then return con.industries[1] end
	return nil
end

local function constructionFileName(industry)
	local ind = api.engine.getComponent(industry, api.type.ComponentType.INDUSTRY)
	local con = ind and api.engine.getComponent(ind.construction, api.type.ComponentType.CONSTRUCTION)
	return con and con.fileName or ""
end

-- la ville qui a le plus de gares : vraisemblablement au cœur du réseau du joueur
function M.busiestTown()
	local best, bestCount = nil, -1
	for __, town in ipairs(api.engine.getEntitiesWithComponent(api.type.ComponentType.TOWN)) do
		local count = #(api.engine.system.stationSystem.getStations(town) or {})
		if count > bestCount then best, bestCount = town, count end
	end
	return best, bestCount
end

-- 1. créer une industrie près de la ville la plus desservie
function M.spawn(trace)
	local town, stations = M.busiestTown()
	trace("ESSAI création : ville " .. (town and name(town) or "aucune") .. " (" .. tostring(stations) .. " gare(s))")
	for __, typeTag in ipairs(SPAWN_TYPES) do
		local proposal = api.engine.util.proposal.makeIndustrySpawnProposal(typeTag, town)
		if proposal ~= nil then
			trace("ESSAI création : proposition trouvée pour " .. typeTag .. ", construction envoyée")
			api.cmd.sendCommand(api.cmd.makeWorldBuildProposalCmd(proposal, nil, false, false),
				function(_data, success, resultEntities)
					local ids = {}
					for __, pair in ipairs(resultEntities or {}) do ids[#ids + 1] = pair[1] end
					M.pending[#M.pending + 1] = { kind = "spawn", typeTag = typeTag, success = success, ids = ids }
				end)
			return
		end
		trace("ESSAI création : aucune place pour " .. typeTag)
	end
	trace("ESSAI création : ÉCHEC, aucune proposition pour les types essayés")
end

-- recopie les résultats des rappels ; renvoie vrai si l'état a changé
function M.drain(s, trace)
	local changed = false
	while #M.pending > 0 do
		local r = table.remove(M.pending, 1)
		changed = true -- au moins une ligne d'activité
		if r.kind == "spawn" then
			local parts = {}
			for __, id in ipairs(r.ids) do
				parts[#parts + 1] = "#" .. id .. " (industrie " .. (has(id, api.type.ComponentType.INDUSTRY) and "oui" or "non") ..
					", construction " .. (has(id, api.type.ComponentType.CONSTRUCTION) and "oui" or "non") .. ")"
			end
			trace("ESSAI création : réussite " .. tostring(r.success) .. ", entités renvoyées : " ..
				(#parts > 0 and table.concat(parts, ", ") or "aucune"))
			local industry = nil
			for __, id in ipairs(r.ids) do industry = industry or industryOf(id) end
			if industry ~= nil then
				s.debug.probe = s.debug.probe or {}
				s.debug.probe.industry = industry
				trace("ESSAI création : industrie " .. name(industry) .. " (#" .. industry .. ") ; une notification « industrie fondée » est envoyée, cliquer dessus pour la voir")
				notify(SPAWN_NOTIFICATION, industry, constructionFileName(industry))
			else
				trace("ESSAI création : aucune entité industrie trouvée dans le résultat")
			end
		end
	end
	return changed
end

-- 2. et 4. ultimatum d'un trimestre sur l'industrie créée (ou une autre), avec la notification du jeu
function M.ultimatum(s, trace, industry)
	industry = industry or (s.debug.probe and s.debug.probe.industry)
	if industry == nil or not api.engine.entityExists(industry) then
		trace("ESSAI fermeture : pas d'industrie, cliquer d'abord « Créer une industrie »")
		return
	end
	local q, frozen = M.quarterMs()
	local at = math.floor(now() + q)
	api.cmd.sendCommand(api.cmd.makeIndustrySetManualDevelopmentCmd(industry, true))
	api.cmd.sendCommand(api.cmd.makeIndustrySetDespawnTimeCmd(industry, at))
	notify(CLOSE_NOTIFICATION, industry, constructionFileName(industry))
	s.debug.probe = s.debug.probe or {}
	s.debug.probe.ultimatum = { industry = industry, at = at, quarter = q, name = name(industry), checked = false }
	trace("ESSAI fermeture : " .. name(industry) .. " en développement manuel, fermeture dans 1 trimestre (" ..
		math.floor(q / 1000) .. " s de jeu" .. (frozen and ", calendrier figé : durée par défaut" or "") ..
		") ; une notification « fermeture » est envoyée")
end

-- 3. compteurs du LOG_BOOK, sur l'industrie et sur son stockList
local function counters(entity)
	local book = api.engine.getComponent(entity, api.type.ComponentType.LOG_BOOK)
	if book == nil then return "pas de LOG_BOOK" end
	local parts = {}
	for __, logName in ipairs(LOG_NAMES) do
		local ok, text = pcall(function()
			local log = book.name2log_native:find(logName)
			if log == nil then return logName .. " absent" end
			local n = log.values_native:size()
			if n == 0 then return logName .. " vide" end
			return logName .. " = " .. tostring(log.values_native:at(n)) .. " (" .. n .. " entrées, dernière à " ..
				math.floor(log.times_native:at(n) / 1000) .. " s)"
		end)
		parts[#parts + 1] = ok and text or (logName .. " : erreur " .. tostring(text))
	end
	return table.concat(parts, " ; ")
end

function M.readCounters(trace, industry)
	if industry == nil or not api.engine.entityExists(industry) then
		trace("ESSAI compteurs : industrie introuvable")
		return
	end
	local ind = api.engine.getComponent(industry, api.type.ComponentType.INDUSTRY)
	trace("ESSAI compteurs : " .. name(industry) .. " à " .. math.floor(now() / 1000) .. " s : " .. counters(industry))
	if ind ~= nil and ind.stockList ~= nil and ind.stockList ~= industry then
		trace("ESSAI compteurs : son stockList #" .. ind.stockList .. " : " .. counters(ind.stockList))
	end
end

function M.watchCounters(s, trace, industry)
	s.debug.probe = s.debug.probe or {}
	s.debug.probe.watch = industry
	trace("ESSAI compteurs : suivi de " .. name(industry) .. " à chaque trimestre")
	M.readCounters(trace, industry)
end

-- 5. faire grandir une ville par l'expérience du jeu
local function townSize(town)
	local t = api.engine.getComponent(town, api.type.ComponentType.TOWN)
	local factors = {}
	for __, f in ipairs(t and t.sizeFactors or {}) do factors[#factors + 1] = string.format("%.2f", f) end
	local residents = api.engine.util.logbook.getLogValueMostRecent(town, "townResidentialCount")
	return "facteurs de taille " .. table.concat(factors, " / ") .. ", résidentiel " .. tostring(residents) ..
		", croissance " .. tostring(t and t.developmentActive)
end

function M.growTown(s, trace)
	local town = M.busiestTown()
	if town == nil then
		trace("ESSAI ville : aucune ville")
		return
	end
	trace("ESSAI ville : " .. name(town) .. " avant : " .. townSize(town))
	api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd("", "Towns", "addExperiencePercentage",
		{ townEntity = town, amount = 1.0, source = "subvention" }))
	s.debug.probe = s.debug.probe or {}
	s.debug.probe.town = town
	trace("ESSAI ville : expérience ajoutée (un niveau entier) ; relevé au prochain trimestre")
end

-- calendrier : vitesse, durée d'un trimestre, date
function M.calendar(trace)
	local gs = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_SPEED)
	local mpd = gs and gs.millisPerDay or 0
	local day = api.util.getDefaultDayDuration()
	local q, frozen = M.quarterMs()
	local d = api.engine.util.getCalendarDate(now())
	trace("ESSAI calendrier : simulation ×" .. tostring(gs and gs.speedup) .. ", millisPerDay " .. tostring(mpd) ..
		" (jour par défaut " .. tostring(day) .. ", facteur " .. (mpd > 0 and string.format("%.2f", day / mpd) or "figé") ..
		"), trimestre = " .. math.floor(q / 1000) .. " s de jeu" .. (frozen and " (par défaut)" or "") ..
		", date " .. d.year .. "-" .. d.month .. "-" .. d.day .. ", année par défaut " .. api.util.getDefaultYearDuration() .. " ms")
end

-- suivi à chaque pas : sort de l'ultimatum ; à chaque trimestre : compteurs et ville
function M.watch(s, trace, newQuarter)
	local p = s.debug.probe
	if p == nil then return false end
	local changed = false
	local u = p.ultimatum
	if u ~= nil then
		local ind = api.engine.getComponent(u.industry, api.type.ComponentType.INDUSTRY)
		if not api.engine.entityExists(u.industry) or ind == nil then
			trace("ESSAI fermeture : " .. u.name .. " a disparu à " .. math.floor(now() / 1000) .. " s (échéance " ..
				math.floor(u.at / 1000) .. " s) : le jeu supprime bien une industrie en développement manuel")
			p.ultimatum = nil
			changed = true
		else
			if not u.checked then
				trace("ESSAI fermeture : horodatage relu " .. tostring(ind.closureTimeStamp) .. " (attendu " .. u.at .. ")" ..
					(ind.closureTimeStamp == 0 and " : REMIS À 0, le jeu a annulé l'ultimatum" or ""))
				u.checked = true
				changed = true
			end
			if now() > u.at + u.quarter then
				trace("ESSAI fermeture : " .. u.name .. " toujours là 1 trimestre après l'échéance (horodatage " ..
					tostring(ind.closureTimeStamp) .. ") : le mod devra la supprimer lui-même")
				p.ultimatum = nil
				changed = true
			end
		end
	end
	if newQuarter then
		if p.watch ~= nil then M.readCounters(trace, p.watch) end
		if p.town ~= nil and api.engine.entityExists(p.town) then
			trace("ESSAI ville : " .. name(p.town) .. " après : " .. townSize(p.town))
			p.town = nil
			changed = true
		end
	end
	return changed
end

return M
