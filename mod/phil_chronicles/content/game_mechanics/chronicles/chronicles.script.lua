-- Script de jeu des Chroniques économiques : détecte le changement de trimestre, appelle le cœur,
-- applique les productivités, sauvegarde l'état, reçoit les commandes de l'onglet Débogage.
-- Écrit en Lua (le jeu accepte .script.lua) : le cœur est du Lua pur testé hors jeu.

local MOD = "phil_chronicles::/"
local EVENT_ID = "PhilChronicles"
local EVENT_NAMES = { "forceEvent", "nextPhase", "fastQuarter", "dumpState", "resetAll", "runSelfTest",
	"prepareSaveTest", "checkSaveTest", "runWitness" }
-- à augmenter quand EVENT_NAMES change : les abonnements sont gardés dans la sauvegarde
local SUBSCRIPTIONS_VERSION = 3
local NOTIFICATION_TYPE = "phil_chronicles::/game_mechanics/chronicles/chronicles_notification.script"

local REASSERT_SECONDS = 10.0 -- le script des travailleurs du jeu peut réécrire la productivité
local FAST_QUARTER_SECONDS = 5.0
local SELFTEST_POLLS = 20 -- en jeu, le script reçoit un pas toutes les 2 à 4 secondes environ
local COST_LIMIT_MS = 50 -- mesuré en jeu : 1,0 ms pour 22 industries et 35 villes (v6)
local GHOST_ENTITY = 2147480000 -- entité qui n'existe pas, pour simuler une industrie disparue
-- partie témoin accélérée : 10 ans = 40 trimestres, au moins 2 crises complètes attendues
local WITNESS_QUARTERS = 40
local WITNESS_QUARTER_SECONDS = 2.0
local WITNESS_MIN_COMPLETED = 2

local engine, journal, world_reader, effects

local function loadModules()
	if engine ~= nil then
		return
	end
	local function load(path) return ug_require(MOD .. path) end
	journal = load("core/journal.lua")
	engine = load("core/engine.lua").new({
		rng = load("core/rng.lua"),
		catalog = load("core/catalog.lua"),
		lifecycle = load("core/lifecycle.lua"),
		guardrails = load("core/guardrails.lua"),
		storyteller = load("core/storyteller.lua"),
		regions = load("core/regions.lua"),
		journal = journal,
	})
	world_reader = load("adapters/world_reader.lua")
	effects = load("adapters/effects.lua")
end

-- minuteries en mémoire seulement (pas dans la sauvegarde)
local clock = { reassert = 0.0, fast = 0.0 }
local selftest = nil

local function say(line)
	log.message("[chronicles] " .. line)
end

-- ---------------------------------------------------------------- état

local function serialize(v, out)
	local t = type(v)
	if t == "table" then
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		out[#out + 1] = "{"
		for __, k in ipairs(keys) do
			out[#out + 1] = tostring(k) .. "="
			serialize(v[k], out)
			out[#out + 1] = ","
		end
		out[#out + 1] = "}"
	elseif t == "string" then
		out[#out + 1] = string.format("%q", v)
	else
		out[#out + 1] = tostring(v)
	end
	return out
end

local function dump(s)
	local text = table.concat(serialize(s, {}))
	local hash = 5381
	for i = 1, #text do
		hash = (hash * 33 + text:byte(i)) % 4294967296
	end
	return text, string.format("%08x", hash)
end

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in pairs(v) do
		out[k] = deepCopy(x)
	end
	return out
end

-- empreinte de l'état sans la marque du test de sauvegarde elle-même
local function saveHash(s)
	local copy = deepCopy(s)
	copy.debug.saveCheck = nil
	local __, hash = dump(copy)
	return hash
end

local function ensureState(s)
	if s == nil or s.version == nil then
		local gameTime = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
		s = engine.newState((gameTime.gameTime % 2147483647) + 1)
		s.debug.quarterOffset = 0
		say("état initial créé, graine " .. tostring(s.seed))
	end
	s.debug = s.debug or {}
	s.debug.quarterOffset = s.debug.quarterOffset or 0
	return s
end

-- la photo, avec la date décalée par le trimestre accéléré
local function readWorld(s)
	local world = world_reader.read()
	local offset = s.debug.quarterOffset or 0
	if offset ~= 0 then
		local q = engine.quarterIndex(world.year, world.month) + offset
		world.year = math.floor(q / 4)
		world.month = (q % 4) * 3 + 1
	end
	return world
end

local function notify(n)
	local title = n.title or (n.kind == "announce" and "Crise annoncée" or "Reprise")
	local notification = {
		type = NOTIFICATION_TYPE,
		params = { kind = n.kind, title = title, description = n.text },
		autoDismissDuration = 15000,
	}
	api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd("", "Notifications", "add", notification))
end

-- textes lus par l'interface : lignes du Journal, manchettes des événements en cours (onglet Économie)
local function refreshJournal(s, world)
	s.journal = journal.describe(s, world)
	s.headlines = {}
	for __, ev in ipairs(s.events) do
		if ev.phase ~= "done" then
			s.headlines[#s.headlines + 1] = journal.headline(ev)
		end
	end
end

-- applique un résultat du cœur : cibles, notifications, log, texte du journal
local function applyResult(s, world, result)
	local sent = effects.apply(result.targets)
	for __, n in ipairs(result.notifications) do
		notify(n)
	end
	for __, line in ipairs(result.log) do
		say(line)
	end
	refreshJournal(s, world)
	if sent > 0 and s.debug.verbose then
		say(tostring(sent) .. " commande(s) de productivité")
	end
end

-- ---------------------------------------------------------------- autotest (N2)

local function industryFree(s, id)
	for __, ev in ipairs(s.events) do
		if ev.phase ~= "done" then
			for __, other in ipairs(ev.industries) do
				if other == id then return false end
			end
		end
	end
	return true
end

local function report(name, ok, detail)
	say("TEST " .. name .. (ok and " OK" or (" ÉCHEC " .. (detail or ""))))
	selftest.results[#selftest.results + 1] = ok
end

local function near(a, b)
	return a ~= nil and b ~= nil and math.abs(a - b) <= 0.01
end

-- avance d'une étape ; les commandes du jeu s'appliquent au pas suivant, d'où les attentes
local function stepSelfTest(s)
	local t = selftest
	if t.wait > 0 then
		t.wait = t.wait - 1
		return true
	end
	local world = readWorld(s)

	if t.step == "start" then
		local candidate, player = nil, nil
		for __, ind in ipairs(world.industries) do
			if ind.playerOwned then
				player = player or ind
			elseif candidate == nil and industryFree(s, ind.id) then
				candidate = ind
			end
		end
		if player ~= nil then
			local ev = engine.forceEvent(s, world, { industryId = player.id })
			report("Industries du joueur intactes", ev == nil, "crise lancée sur " .. player.name)
		else
			say("TEST Industries du joueur intactes SAUTÉ (aucune industrie du joueur)")
		end
		if candidate == nil then
			report("Cycle complet d'une crise", false, "aucune industrie libre")
			t.step = "end"
			return true
		end
		t.industry = candidate.id
		t.before = world_reader.getProductivity(candidate.id)
		local ev, why = engine.forceEvent(s, world, { industryId = candidate.id })
		if ev == nil then
			report("Cycle complet d'une crise", false, "refusée : " .. tostring(why))
			t.step = "end"
			return true
		end
		t.event = ev.id
		say("autotest sur " .. candidate.name .. ", productivité " .. tostring(t.before))
		applyResult(s, world, engine.nextPhase(s, world)) -- rumeur -> annonce
		t.step, t.polls = "announced", 0

	-- les commandes s'appliquent quelques pas plus tard : on relit à chaque pas, au plus SELFTEST_POLLS fois
	elseif t.step == "announced" then
		local target = engine.targets(s)[t.industry]
		local actual = world_reader.getProductivity(t.industry)
		if near(actual, target) or t.polls >= SELFTEST_POLLS then
			report("Productivité appliquée", near(actual, target),
				"visée " .. tostring(target) .. ", relue " .. tostring(actual) .. " après " .. t.polls .. " pas")
			t.step = "finishing"
		else
			t.polls = t.polls + 1
		end

	elseif t.step == "finishing" then
		-- toutes les phases restantes dans le même pas : nextPhase ne dépend pas des commandes
		local ev, steps = nil, 0
		repeat
			ev = nil
			for __, e in ipairs(s.events) do
				if e.id == t.event then ev = e end
			end
			if ev ~= nil and ev.phase ~= "done" then
				applyResult(s, world, engine.nextPhase(s, world))
				steps = steps + 1
			end
		until ev == nil or ev.phase == "done" or steps >= 12
		report("Cycle complet d'une crise", ev ~= nil and ev.phase == "done",
			"phase " .. tostring(ev and ev.phase) .. " après " .. steps .. " étapes")
		t.step, t.polls = "restored", 0

	elseif t.step == "restored" then
		local actual = world_reader.getProductivity(t.industry)
		if near(actual, t.before) or t.polls >= SELFTEST_POLLS then
			report("Retour exact à la normale", near(actual, t.before),
				"avant " .. tostring(t.before) .. ", relue " .. tostring(actual) .. " après " .. t.polls .. " pas")
			t.step = "reset"
		else
			t.polls = t.polls + 1
		end

	-- « Tout rétablir » : une crise appliquée, puis resetAll doit rendre la productivité d'avant
	elseif t.step == "reset" then
		local ev = engine.forceEvent(s, world, { industryId = t.industry })
		if ev == nil then
			report("Tout rétablir", false, "crise refusée sur l'industrie de l'autotest")
			t.step = "vanish"
		else
			applyResult(s, world, engine.nextPhase(s, world))
			t.step, t.polls = "resetApplied", 0
		end

	elseif t.step == "resetApplied" then
		local target = engine.targets(s)[t.industry]
		local actual = world_reader.getProductivity(t.industry)
		if near(actual, target) or t.polls >= SELFTEST_POLLS then
			say("autotest : « Tout rétablir » efface aussi les autres événements en cours")
			effects.apply(engine.resetAll(s))
			refreshJournal(s, world)
			t.step, t.polls = "resetDone", 0
		else
			t.polls = t.polls + 1
		end

	elseif t.step == "resetDone" then
		local actual = world_reader.getProductivity(t.industry)
		if (near(actual, t.before) and #s.events == 0) or t.polls >= SELFTEST_POLLS then
			report("Tout rétablir", near(actual, t.before) and #s.events == 0,
				"avant " .. tostring(t.before) .. ", relue " .. tostring(actual) .. ", " .. #s.events .. " événement(s)")
			t.step = "vanish"
		else
			t.polls = t.polls + 1
		end

	-- coût d'un trimestre : lecture du monde + tick du cœur sur une copie de l'état, au trimestre suivant
	-- industrie disparue en pleine crise : simulée sur une copie de l'état avec une entité qui n'existe pas,
	-- pour ne rien démolir dans la partie (même chemin qu'une industrie rasée ou fermée par le jeu)
	elseif t.step == "vanish" then
		local okRun, err = pcall(function()
			local copy = deepCopy(s)
			local w = world_reader.read()
			local ev, why = engine.forceEvent(copy, w, { industryId = t.industry })
			if ev == nil then error("crise refusée : " .. tostring(why)) end
			ev.industries[#ev.industries + 1] = GHOST_ENTITY
			copy.baseProductivity[tostring(GHOST_ENTITY)] = 1.0
			effects.apply({ [GHOST_ENTITY] = 0.6 }) -- l'adaptateur doit ignorer une entité absente
			local q = engine.quarterIndex(w.year, w.month) + (s.debug.quarterOffset or 0) + 1
			w.year, w.month = math.floor(q / 4), (q % 4) * 3 + 1
			engine.tick(copy, w, { frequency = 0, cooldown = 4 })
			for __, id in ipairs(ev.industries) do
				if id == GHOST_ENTITY then error("industrie disparue gardée dans l'événement") end
			end
			if copy.baseProductivity[tostring(GHOST_ENTITY)] ~= nil then error("productivité de base gardée") end
			if ev.phase == "rumor" then error("l'événement n'a pas continué son cycle") end
		end)
		report("Industrie disparue en cours de crise", okRun, tostring(err))
		t.step = "cost"

	elseif t.step == "cost" then
		if os == nil or os.clock == nil then
			say("TEST Coût d'un trimestre SAUTÉ (os.clock indisponible)")
		else
			local start = os.clock()
			local w = world_reader.read()
			local copy = deepCopy(s)
			local q = engine.quarterIndex(w.year, w.month) + (s.debug.quarterOffset or 0) + 1
			w.year, w.month = math.floor(q / 4), (q % 4) * 3 + 1
			engine.tick(copy, w, { frequency = 1, cooldown = 0 })
			local ms = (os.clock() - start) * 1000
			report("Coût d'un trimestre", ms <= COST_LIMIT_MS,
				string.format("%.1f ms pour %d industries (seuil %d ms)", ms, #w.industries, COST_LIMIT_MS))
			say(string.format("mesure : un trimestre coûte %.1f ms pour %d industries et %d villes", ms, #w.industries, #w.towns))
		end
		local __, hash = dump(s)
		say("TEST empreinte de l'état " .. hash)
		t.step = "end"

	else
		local ok, ko = 0, 0
		for __, r in ipairs(t.results) do
			if r then ok = ok + 1 else ko = ko + 1 end
		end
		local summary = ok .. " OK, " .. ko .. " ÉCHEC"
		say("AUTOTEST fin : " .. summary)
		-- la notification dit au joueur qu'il peut quitter, et vérifie l'affichage du type de notification
		notify({ kind = ko == 0 and "done" or "announce", title = "Autotest terminé", text = summary .. " (détail dans stdout.txt)" })
		selftest = nil
	end
	return true
end

-- ---------------------------------------------------------------- partie témoin accélérée

-- compte les trimestres de la partie témoin ; au bout de WITNESS_QUARTERS, bilan et retour au rythme normal
local function stepWitness(s, processed)
	local w = s.debug.witness
	if w == nil then
		return
	end
	w.remaining = w.remaining - processed
	if w.remaining > 0 then
		return
	end
	local launched, completed = s.nextEventId - w.firstEventId, 0
	for __, ev in ipairs(s.events) do
		if ev.id >= w.firstEventId and ev.phase == "done" then completed = completed + 1 end
	end
	local ok = completed >= WITNESS_MIN_COMPLETED and w.errors == 0
	local summary = launched .. " crise(s) lancée(s), " .. completed .. " terminée(s) de la rumeur à la reprise, " ..
		w.errors .. " erreur(s)"
	say("TEST Partie témoin accélérée (10 ans)" .. (ok and " OK " or " ÉCHEC ") .. summary)
	notify({ kind = ok and "done" or "announce", title = "Partie témoin terminée", text = summary })
	s.debug.witness = nil
	s.debug.fastQuarter = false
end

-- ---------------------------------------------------------------- débogage

local function handleDebug(s, name, param)
	param = param or {}
	if name == "forceEvent" then
		local world = readWorld(s)
		local ev, why = engine.forceEvent(s, world, { industryId = param.industryId })
		if ev ~= nil then
			say("crise forcée : " .. journal.headline(ev))
		else
			say("crise refusée : " .. tostring(why))
		end
		refreshJournal(s, world)
	elseif name == "nextPhase" then
		local world = readWorld(s)
		applyResult(s, world, engine.nextPhase(s, world))
	elseif name == "fastQuarter" then
		s.debug.fastQuarter = param.on == true
		say("trimestre accéléré : " .. (s.debug.fastQuarter and "oui" or "non"))
	elseif name == "dumpState" then
		local text, hash = dump(s)
		say("ÉTAT " .. hash .. " " .. text)
	elseif name == "resetAll" then
		local world = readWorld(s)
		local targets = engine.resetAll(s)
		local sent = effects.apply(targets)
		refreshJournal(s, world)
		say("tout rétabli (" .. sent .. " commande(s))")
	-- test « Sauvegarder en pleine crise », en deux temps autour d'une sauvegarde et d'un rechargement
	elseif name == "prepareSaveTest" then
		local world = readWorld(s)
		if next(engine.targets(s)) == nil then
			local ev, why = engine.forceEvent(s, world, {})
			if ev == nil then
				say("test de sauvegarde impossible : " .. tostring(why))
				return
			end
			applyResult(s, world, engine.nextPhase(s, world)) -- jusqu'à l'annonce, pour avoir des effets
		end
		s.debug.saveCheck = { hash = saveHash(s), targets = {} }
		for id, target in pairs(engine.targets(s)) do
			s.debug.saveCheck.targets[tostring(id)] = target
		end
		say("test de sauvegarde préparé, empreinte " .. s.debug.saveCheck.hash ..
			" : mettre en pause, sauvegarder, recharger, puis « Vérifier la sauvegarde »")
	elseif name == "checkSaveTest" then
		local check = s.debug.saveCheck
		if check == nil then
			say("TEST Sauvegarder en pleine crise SAUTÉ (cliquer d'abord « Préparer le test de sauvegarde »)")
			return
		end
		local hash = saveHash(s)
		local problems = {}
		if hash ~= check.hash then
			problems[#problems + 1] = "empreinte " .. hash .. " au lieu de " .. check.hash
		end
		-- une commande appliquée deux fois donnerait base × multiplicateur²
		for key, target in pairs(check.targets) do
			local actual = world_reader.getProductivity(tonumber(key))
			if not near(actual, target) then
				problems[#problems + 1] = "industrie " .. key .. " à " .. tostring(actual) .. " au lieu de " .. tostring(target)
			end
		end
		local ok = #problems == 0
		say("TEST Sauvegarder en pleine crise" .. (ok and " OK" or (" ÉCHEC " .. table.concat(problems, " ; "))))
		notify({ kind = ok and "done" or "announce", title = "Test de sauvegarde",
			text = ok and "OK : même état après rechargement" or "ÉCHEC (détail dans stdout.txt)" })
		s.debug.saveCheck = nil
	elseif name == "runWitness" then
		if s.debug.witness ~= nil then
			say("partie témoin déjà en cours : " .. s.debug.witness.remaining .. " trimestre(s) restant(s)")
			return
		end
		s.debug.witness = { remaining = WITNESS_QUARTERS, firstEventId = s.nextEventId, errors = 0 }
		s.debug.fastQuarter = true
		say("TÉMOIN début : " .. WITNESS_QUARTERS .. " trimestres accélérés, un toutes les " ..
			WITNESS_QUARTER_SECONDS .. " s de jeu (la date du mod avance de 10 ans sur celle du jeu)")
	elseif name == "runSelfTest" then
		selftest = { step = "start", wait = 0, results = {} }
		say("AUTOTEST début")
	end
end

-- ---------------------------------------------------------------- script de jeu

-- Une ressource .lua doit définir data() (sinon « function data() not defined ») ;
-- seuls les modules chargés par ug_require finissent par return.
local script = {
	update = function(_userParams, state, dt)
		loadModules()

		local s = state:get()
		local fresh = s == nil or s.version == nil
		s = ensureState(s)
		local changed = fresh

		if not state:hasEventSubscriptions() or (s.subscriptions or 1) < SUBSCRIPTIONS_VERSION then
			-- on repart de zéro : un nom abonné deux fois pourrait livrer chaque événement deux fois
			state:subscribeToNoEvents()
			for __, name in ipairs(EVENT_NAMES) do
				state:subscribeToEvent(name)
			end
			s.subscriptions = SUBSCRIPTIONS_VERSION
			changed = true
		end

		if selftest ~= nil then
			changed = stepSelfTest(s) or changed
		end

		if dt ~= nil and dt > 0 then
			if s.debug.fastQuarter then
				clock.fast = clock.fast + dt
				local interval = s.debug.witness ~= nil and WITNESS_QUARTER_SECONDS or FAST_QUARTER_SECONDS
				if clock.fast >= interval then
					clock.fast = 0.0
					s.debug.quarterOffset = s.debug.quarterOffset + 1
					changed = true
				end
			end

			local year, month = world_reader.readDate()
			local quarter = engine.quarterIndex(year, month) + s.debug.quarterOffset
			if s.lastQuarter == nil or quarter ~= s.lastQuarter then
				local world = readWorld(s)
				local ok, result = pcall(engine.tick, s, world, {})
				if ok then
					applyResult(s, world, result)
					if result.processed > 0 then
						say("trimestre " .. world.year .. "-T" .. (math.floor((world.month - 1) / 3) + 1) ..
							" : " .. #s.events .. " événement(s), " .. #result.notifications .. " notification(s)")
						stepWitness(s, result.processed)
					end
				else
					-- trimestre marqué traité pour ne pas reboucler sur la même erreur à chaque pas
					log.error("[chronicles] erreur pendant le trimestre", tostring(result))
					s.lastQuarter = quarter
					if s.debug.witness ~= nil then
						s.debug.witness.errors = s.debug.witness.errors + 1
					end
				end
				changed = true
			end

			clock.reassert = clock.reassert + dt
			if clock.reassert >= REASSERT_SECONDS then
				clock.reassert = 0.0
				effects.apply(engine.targets(s))
			end
		end

		if changed then
			state:set(s)
		end
	end,

	handleEvent = function(_userParams, state, _src, id, name, param)
		if id ~= EVENT_ID then
			return
		end
		loadModules()
		local s = ensureState(state:get())
		handleDebug(s, name, param)
		state:set(s)
	end,
}

function data()
	return script
end
