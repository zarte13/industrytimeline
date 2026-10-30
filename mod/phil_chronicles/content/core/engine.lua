-- Moteur : orchestre les modules du cœur. Aucun accès au jeu, tout passe par state et world.
local M = {}

function M.new(mods)
	local rng, catalog, lifecycle = mods.rng, mods.catalog, mods.lifecycle
	local guardrails, storyteller, regions, journal = mods.guardrails, mods.storyteller, mods.regions, mods.journal
	local deps = { rng = rng, catalog = catalog, guardrails = guardrails }
	if journal.setCatalog then journal.setCatalog(catalog) end

	local E = {}

	function E.quarterIndex(year, month)
		return year * 4 + math.floor((month - 1) / 3) -- pas de « // » : le jeu est en Lua 5.2
	end

	function E.newState(seed)
		return {
			version = 1, seed = seed, rng = seed, lastQuarter = nil, nextEventId = 1,
			events = {}, baseProductivity = {},
			debug = { fastQuarter = false, verbose = false },
		}
	end

	-- Deux décimales, virgule française.
	local function virgule(x)
		return (string.format("%.2f", x):gsub("%.", ","))
	end

	local function newResult(state)
		return { state = state, targets = {}, notifications = {}, log = {}, processed = 0 }
	end

	local function indexIndustries(world)
		local byId = {}
		for _, ind in ipairs(world.industries or {}) do byId[ind.id] = ind end
		return byId
	end

	-- Productivités visées des industries d'événements actifs.
	function E.targets(state)
		local t = {}
		for _, ev in ipairs(state.events) do
			if ev.phase ~= "done" then
				for _, id in ipairs(ev.industries) do
					local base = state.baseProductivity[tostring(id)]
					if base then t[id] = base * ev.multiplier end
				end
			end
		end
		return t
	end

	-- Retire les productivités de base des industries qu'aucun événement actif ne touche.
	local function nettoieBase(state)
		local busy = guardrails.busySet(state)
		for key in pairs(state.baseProductivity) do
			if not busy[key] then state.baseProductivity[key] = nil end
		end
	end

	local function elague(state)
		local nbFinis = 0
		for _, ev in ipairs(state.events) do
			if ev.phase == "done" then nbFinis = nbFinis + 1 end
		end
		local i = 1
		while nbFinis > catalog.keepFinished and i <= #state.events do
			if state.events[i].phase == "done" then
				table.remove(state.events, i)
				nbFinis = nbFinis - 1
			else
				i = i + 1
			end
		end
	end

	-- Notifications et log pour un changement de phase ; restore reçoit les bases à rétablir.
	local function transition(state, result, restore, ev, phase)
		result.notifications[#result.notifications + 1] = {
			kind = phase, eventId = ev.id, text = journal.notification(phase, ev),
		}
		result.log[#result.log + 1] = journal.headline(ev)
		if phase == "done" then
			for _, id in ipairs(ev.industries) do
				local base = state.baseProductivity[tostring(id)]
				if base then restore[id] = base end
			end
		end
	end

	local function launch(state, world, plan, quarter, result, restore)
		local byId = indexIndustries(world)
		local trough
		trough, state.rng = rng.int(state.rng, catalog.troughMin, catalog.troughMax)
		local ev = lifecycle.new(state.nextEventId, plan.sector, plan.regionId, plan.regionName,
			plan.industries, trough, quarter, catalog)
		state.nextEventId = state.nextEventId + 1
		for _, id in ipairs(plan.industries) do
			local key = tostring(id)
			if state.baseProductivity[key] == nil then
				state.baseProductivity[key] = (restore and restore[id]) or (byId[id] and byId[id].productivity) or 1.0
			end
		end
		state.events[#state.events + 1] = ev
		state.lastLaunch = quarter
		if result then
			local texte = journal.notification("rumor", ev)
			result.log[#result.log + 1] = texte
			result.notifications[#result.notifications + 1] = { kind = "rumor", eventId = ev.id, text = texte }
		end
		return ev
	end

	local function currentQuarter(state, world)
		return E.quarterIndex(world.year, world.month)
	end

	function E.forceEvent(state, world, opts)
		local info = regions.build(world)
		local plan, why
		plan, why, state.rng = storyteller.select(state.rng, world, info, state, opts or {}, deps)
		if not plan then return nil, why end
		return launch(state, world, plan, currentQuarter(state, world))
	end

	-- Un trimestre : industries disparues, avancement des événements, tirage du conteur.
	local function processQuarter(state, world, quarter, params, result, restore)
		local byId = indexIndustries(world)
		for _, ev in ipairs(state.events) do
			if ev.phase ~= "done" then
				local kept = {}
				for _, id in ipairs(ev.industries) do
					if byId[id] then
						kept[#kept + 1] = id
					else
						state.baseProductivity[tostring(id)] = nil
					end
				end
				ev.industries = kept
			end
		end

		for _, ev in ipairs(state.events) do
			if ev.phase ~= "done" then
				local new = lifecycle.step(ev, quarter, catalog)
				if not new and guardrails.overdue(ev, quarter, catalog) then
					new = lifecycle.finish(ev, quarter, catalog)
				end
				if new then transition(state, result, restore, ev, new) end
			end
		end
		nettoieBase(state)

		local go, tirage
		go, state.rng, tirage = storyteller.roll(state.rng, state, quarter, params, deps)
		if tirage.wait then
			result.log[#result.log + 1] = "Conteur : attente, prochain tirage dans " .. tirage.wait .. " trimestre(s)"
		else
			local debut = "Conteur : tirage " .. virgule(tirage.value) .. " pour un seuil de " .. virgule(tirage.threshold)
			if not go then
				result.log[#result.log + 1] = debut .. ", pas de crise"
			else
				local info = regions.build(world)
				local plan, why
				plan, why, state.rng = storyteller.select(state.rng, world, info, state, nil, deps)
				if plan then
					local ev = launch(state, world, plan, quarter, result, restore)
					-- la ligne du conteur précède celle de la rumeur
					table.insert(result.log, #result.log, debut .. ", crise lancée : " .. journal.headline(ev))
				else
					result.log[#result.log + 1] = "Conteur : tirage " .. virgule(tirage.value) ..
						" réussi mais aucune crise possible (" .. tostring(why) .. ")"
				end
			end
		end
		elague(state)
	end

	-- Calcule les cibles finales d'un résultat : actives, plus les bases rétablies.
	local function finalise(state, result, restore)
		result.targets = E.targets(state)
		for id, base in pairs(restore) do
			if result.targets[id] == nil then result.targets[id] = base end
		end
		return result
	end

	function E.tick(state, world, params)
		params = params or {}
		local result = newResult(state)
		local restore = {}
		if params.forceEvent then E.forceEvent(state, world, params.forceEvent) end
		local q = currentQuarter(state, world)
		if state.lastQuarter == nil then
			state.lastQuarter = q
		elseif q > state.lastQuarter then
			local n = q - state.lastQuarter
			if n > catalog.maxCatchUp then n = catalog.maxCatchUp end
			for i = n - 1, 0, -1 do
				processQuarter(state, world, q - i, params, result, restore)
				result.processed = result.processed + 1
			end
			state.lastQuarter = q
		end
		return finalise(state, result, restore)
	end

	-- État du conteur après le trimestre donné : wait = trimestres avant le prochain tirage
	-- (0 = tirage au prochain trimestre), chance = probabilité du tirage.
	function E.storytellerStatus(state, quarter, params)
		params = params or {}
		local cooldown = params.cooldown or catalog.defaultCooldown
		local wait = 0
		if state.lastLaunch then wait = math.max(0, cooldown - (quarter + 1 - state.lastLaunch)) end
		return { wait = wait, chance = params.frequency or catalog.defaultFrequency }
	end

	-- Fait avancer tous les événements actifs d'une phase (débogage).
	function E.nextPhase(state, world)
		local result = newResult(state)
		local restore = {}
		local quarter = state.lastQuarter or currentQuarter(state, world)
		local actifs = {}
		for _, ev in ipairs(state.events) do
			if ev.phase ~= "done" then actifs[#actifs + 1] = ev end
		end
		for _, ev in ipairs(actifs) do
			local new = lifecycle.skip(ev, quarter, catalog)
			if new then transition(state, result, restore, ev, new) end
		end
		nettoieBase(state)
		elague(state)
		return finalise(state, result, restore)
	end

	-- Rend les productivités de base de toutes les industries touchées et vide les événements.
	function E.resetAll(state)
		local t = {}
		for key, base in pairs(state.baseProductivity) do t[tonumber(key) or key] = base end
		state.events = {}
		state.baseProductivity = {}
		state.lastLaunch = nil
		return t
	end

	return E
end

return M
