-- Tests hors jeu (N1) du cœur Lua. Lancer depuis la racine du dépôt : lua tests/run.lua
local CORE = "mod/phil_chronicles/content/core/"
local mods = {}
for _, nom in ipairs({ "rng", "catalog", "lifecycle", "guardrails", "storyteller", "regions", "journal" }) do
	mods[nom] = dofile(CORE .. nom .. ".lua")
end
local Engine = dofile(CORE .. "engine.lua")
local fake = dofile("tests/fake_map.lua")

local function newEngine() return Engine.new(mods) end

local ctx = { engine = newEngine(), fake = fake, regions = mods.regions }
local sim = dofile("tests/sim.lua")(ctx)

local function check(cond, msg)
	if not cond then error(msg or "assertion fausse", 2) end
end
local function eq(a, b, msg)
	if a ~= b then error((msg or "valeur") .. " : attendu " .. tostring(b) .. ", obtenu " .. tostring(a), 2) end
end
local function near(a, b, msg)
	if math.abs(a - b) > 1e-9 then error((msg or "valeur") .. " : attendu " .. tostring(b) .. ", obtenu " .. tostring(a), 2) end
end
local function noPlaceholder(text, what)
	check(not text:find("[{}]"), "marqueur restant dans " .. (what or "texte") .. " : " .. text)
end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

local NOFREQ = { frequency = 0, cooldown = 4 }
local tests = {}
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end

-- Prépare un moteur, un monde et un état déjà initialisé (premier appel passé).
local function setup(seed, params)
	local engine = newEngine()
	local world = fake.build()
	local state = engine.newState(seed or 1)
	engine.tick(state, world, params or NOFREQ)
	return engine, world, state
end

test("Changement de trimestre", function()
	local engine = newEngine()
	local world, state = fake.build(), nil
	state = engine.newState(1)
	local r = engine.tick(state, world, NOFREQ)
	eq(r.processed, 0, "premier appel")
	eq(state.lastQuarter, 1900 * 4, "trimestre enregistré")
	eq(engine.tick(state, world, NOFREQ).processed, 0, "même date (pause)")
	eq(engine.tick(state, world, NOFREQ).processed, 0, "même date encore")
	world.day = 20 -- même trimestre, autre jour
	eq(engine.tick(state, world, NOFREQ).processed, 0, "même trimestre")
	fake.advanceQuarter(world)
	eq(engine.tick(state, world, NOFREQ).processed, 1, "un trimestre")
	eq(engine.tick(state, world, NOFREQ).processed, 0, "répété")
	for _ = 1, 3 do fake.advanceQuarter(world) end
	eq(engine.tick(state, world, NOFREQ).processed, 3, "saut de 3")
	eq(state.lastQuarter, 1900 * 4 + 4, "dernier trimestre")
	for _ = 1, 12 do fake.advanceQuarter(world) end
	eq(engine.tick(state, world, NOFREQ).processed, 8, "saut plafonné à 8")
	-- passage d'année
	local e2 = newEngine()
	local w2 = fake.build()
	w2.month = 10
	local s2 = e2.newState(1)
	e2.tick(s2, w2, NOFREQ)
	eq(s2.lastQuarter, 1900 * 4 + 3, "T4 1900")
	fake.advanceQuarter(w2)
	eq(w2.year, 1901, "année")
	eq(e2.tick(s2, w2, NOFREQ).processed, 1, "passage d'année")
	eq(s2.lastQuarter, 1901 * 4, "T1 1901")
	-- un événement n'avance qu'une fois par trimestre
	local e3, w3, s3 = setup(1)
	e3.forceEvent(s3, w3, { industryId = 1 })
	e3.tick(s3, w3, NOFREQ)
	e3.tick(s3, w3, NOFREQ)
	eq(s3.events[1].phase, "rumor", "pause : la phase ne bouge pas")
	fake.advanceQuarter(w3)
	e3.tick(s3, w3, NOFREQ)
	eq(s3.events[1].phase, "announce", "un trimestre plus tard")
end)

local function cycleComplet(base)
	local engine, world, state = setup(3)
	fake.findIndustry(world, 1).productivity = base
	local ev = engine.forceEvent(state, world, { industryId = 1 })
	check(ev, "crise non lancée")
	eq(ev.phase, "rumor")
	local attendu = { { "rumor", 1.0 }, { "announce", 0.6 } }
	for _ = 1, ev.troughLength do attendu[#attendu + 1] = { "trough", 0.6 } end
	attendu[#attendu + 1] = { "recovery", 0.7 }
	attendu[#attendu + 1] = { "recovery", 0.8 }
	attendu[#attendu + 1] = { "recovery", 0.9 }
	attendu[#attendu + 1] = { "done", 1.0 }
	for i, att in ipairs(attendu) do
		if i > 1 then
			fake.advanceQuarter(world)
			engine.tick(state, world, NOFREQ)
		end
		eq(ev.phase, att[1], "phase " .. i)
		near(ev.multiplier, att[2], "multiplicateur " .. i)
		if att[1] ~= "done" then
			near(engine.targets(state)[1], base * att[2], "cible " .. i)
		end
	end
	-- retour exact à la base (comparaison stricte)
	fake.advanceQuarter(world)
	local donne = engine.tick(state, world, NOFREQ)
	check(next(state.baseProductivity) == nil, "base vidée")
	check(next(donne.targets) == nil, "plus de cible après la fin")
end

test("Cycle complet d'une crise (base 1.0)", function() cycleComplet(1.0) end)
test("Cycle complet d'une crise (base 1.3)", function()
	cycleComplet(1.3)
	-- la cible de la dernière étape est exactement la base
	local engine, world, state = setup(3)
	fake.findIndustry(world, 1).productivity = 1.3
	local ev = engine.forceEvent(state, world, { industryId = 1 })
	local last
	for _ = 1, 12 do
		fake.advanceQuarter(world)
		local r = engine.tick(state, world, NOFREQ)
		if ev.phase == "done" and not last then last = r.targets[1] end
	end
	check(last == 1.3, "cible finale exacte, obtenu " .. tostring(last))
end)

local SIM_A = sim.run({ seed = 11, quarters = 400, drain = true })
local SIM_STRESS = sim.run({ seed = 5, quarters = 400, frequency = 1.0, cooldown = 0, force = true, drain = true })
local SIM_FORCE = sim.run({ seed = 9, quarters = 400, force = true, drain = true })

test("La rumeur précède le choc", function()
	for _, out in ipairs({ SIM_A, SIM_STRESS, SIM_FORCE }) do
		check(count(out.hist) > 0, "aucune crise")
		for id, h in pairs(out.hist) do
			local rumeur
			for _, p in ipairs(h.phases) do
				if p == "rumor" then rumeur = true end
				if p == "announce" then check(rumeur, "crise " .. id .. " : annonce sans rumeur") break end
			end
			eq(h.phases[1], "rumor", "première phase de la crise " .. id)
		end
	end
end)

test("Industries du joueur intactes", function()
	for _, out in ipairs({ SIM_A, SIM_STRESS, SIM_FORCE }) do
		eq(#out.violations, 0, table.concat(out.violations, "; "))
	end
	check(SIM_FORCE.forcedPlayer > 0, "forçages sur le joueur non exercés")
	-- forçage ciblant directement le joueur, ou sa région et son secteur
	local engine, world, state = setup(2)
	local ev, why = engine.forceEvent(state, world, { industryId = fake.playerId })
	check(ev == nil and why, "forçage du joueur accepté")
	ev = engine.forceEvent(state, world, { sector = "steel_mill", regionId = 77 })
	check(ev, "crise de l'acier à Valmont refusée")
	eq(#ev.industries, 1, "une seule aciérie éligible")
	eq(ev.industries[1], 1)
	eq(state.baseProductivity[tostring(fake.playerId)], nil, "base du joueur")
end)

test("Deux crises au plus par région", function()
	for _, out in ipairs({ SIM_A, SIM_STRESS, SIM_FORCE }) do
		eq(#out.violations, 0, table.concat(out.violations, "; "))
	end
	-- la région Valmont accepte deux crises puis refuse la troisième
	local engine, world, state = setup(4)
	check(engine.forceEvent(state, world, { sector = "coal_mine", regionId = 77 }), "1re crise")
	check(engine.forceEvent(state, world, { sector = "iron_ore_mine", regionId = 77 }), "2e crise")
	local ev, why = engine.forceEvent(state, world, { regionId = 77 })
	check(ev == nil, "3e crise acceptée")
	eq(why, "région saturée")
	-- une industrie déjà touchée ne peut pas l'être deux fois
	ev, why = engine.forceEvent(state, world, { industryId = 4 })
	check(ev == nil and why, "industrie déjà touchée acceptée")
end)

test("Reprise garantie", function()
	for _, out in ipairs({ SIM_A, SIM_STRESS, SIM_FORCE }) do
		local n = 0
		for id, h in pairs(out.hist) do
			n = n + 1
			check(h.finish, "crise " .. id .. " jamais terminée")
			check(h.finish - h.start <= mods.catalog.maxDuration, "crise " .. id .. " trop longue")
		end
		check(n > 0, "aucune crise")
		for _, ev in ipairs(out.state.events) do eq(ev.phase, "done", "événement encore actif") end
		check(next(out.state.baseProductivity) == nil, "base non vidée")
		for _, ind in ipairs(out.world.industries) do
			check(ind.productivity == 1.0, "productivité non rétablie pour " .. ind.name)
		end
	end
	-- garde-fou de durée : un événement bloqué est terminé d'office
	local engine, world, state = setup(6)
	local ev = engine.forceEvent(state, world, { industryId = 1 })
	ev.troughLength = 1000
	for _ = 1, mods.catalog.maxDuration + 1 do
		fake.advanceQuarter(world)
		engine.tick(state, world, NOFREQ)
	end
	eq(ev.phase, "done", "garde-fou de durée")
end)

local function parDecennie(out)
	local par = {}
	for _, h in pairs(out.hist) do
		local d = (h.start - out.startQuarter) // 40 + 1
		par[d] = (par[d] or 0) + 1
	end
	return par
end

-- Bande : après un délai de 4 trimestres, chaque tirage réussit à 0,25 (attente moyenne 4),
-- soit un écart moyen de 7 trimestres et environ 57 crises en 400 trimestres. L'écart-type du
-- total est d'environ 4 : la bande 38..76 vaut +-5 écarts-types ; par décennie (40 trimestres,
-- moyenne 5,7) on exige 1..10 (10 = maximum permis par le délai de 4 trimestres).
test("Rythme", function()
	for _, seed in ipairs({ 11, 12, 13, 14, 15 }) do
		local out = (seed == 11) and SIM_A or sim.run({ seed = seed, quarters = 400 })
		local par = parDecennie(out)
		local total, cols = 0, {}
		for d = 1, 10 do
			local n = par[d] or 0
			total = total + n
			cols[#cols + 1] = tostring(n)
			check(n >= 1 and n <= 10, "décennie " .. d .. " hors bande : " .. n .. " (graine " .. seed .. ")")
		end
		print(string.format("  graine %d : %d crises ; par décennie : %s", seed, total, table.concat(cols, " ")))
		check(total >= 38 and total <= 76, "total hors bande : " .. total .. " (graine " .. seed .. ")")
	end
end)

test("Partie rejouable", function()
	local a = sim.signature(sim.run({ seed = 77, quarters = 400 }))
	local b = sim.signature(sim.run({ seed = 77, quarters = 400 }))
	eq(a, b, "même graine")
	check(#a > 0, "signature vide")
	check(a ~= sim.signature(sim.run({ seed = 78, quarters = 400 })), "graines différentes, mêmes événements")
	-- l'état du générateur reste un entier simple
	local out = sim.run({ seed = 77, quarters = 50 })
	eq(math.type(out.state.rng), "integer", "état rng")
end)

test("Industrie disparue en cours de crise", function()
	local engine, world, state = setup(8)
	fake.findIndustry(world, 5).x, fake.findIndustry(world, 5).y = 1100.0, -200.0 -- région de Valmont
	local ev = engine.forceEvent(state, world, { sector = "coal_mine", regionId = 77 })
	check(ev, "crise non lancée")
	eq(#ev.industries, 2, "deux mines touchées")
	local cible = ev.industries[1]
	for i, ind in ipairs(world.industries) do
		if ind.id == cible then table.remove(world.industries, i) break end
	end
	fake.advanceQuarter(world)
	local ok, r = pcall(engine.tick, state, world, NOFREQ)
	check(ok, "erreur : " .. tostring(r))
	eq(ev.phase, "announce", "la crise continue")
	eq(#ev.industries, 1, "industrie retirée de l'événement")
	check(r.targets[cible] == nil, "cible de l'industrie disparue")
	check(state.baseProductivity[tostring(cible)] == nil, "base de l'industrie disparue")
	-- toutes les industries disparues : le cycle continue jusqu'au bout
	world.industries = {}
	for _ = 1, 12 do
		fake.advanceQuarter(world)
		ok, r = pcall(engine.tick, state, world, NOFREQ)
		check(ok, "erreur : " .. tostring(r))
	end
	eq(ev.phase, "done", "cycle sans industrie")
	check(#mods.journal.describe(state, world) > 0, "journal sans industrie")
end)

test("Nouvelle industrie", function()
	local engine = newEngine()
	local world = { year = 1900, month = 1, day = 1, towns = { { id = 1, name = "Alba", x = 0, y = 0 } }, industries = {} }
	local state = engine.newState(3)
	local P = { frequency = 1.0, cooldown = 0 }
	engine.tick(state, world, P)
	fake.advanceQuarter(world)
	engine.tick(state, world, P)
	eq(#state.events, 0, "aucune industrie, aucune crise")
	world.industries[1] = { id = 50, type = "farm", name = "Ferme neuve", x = 10, y = 10, playerOwned = false, productivity = 1.0 }
	fake.advanceQuarter(world)
	engine.tick(state, world, P)
	eq(#state.events, 1, "crise au trimestre suivant")
	eq(state.events[1].industries[1], 50)
	-- idem dans la carte fictive : une nouvelle industrie est choisie par le conteur
	local e2, w2, s2 = setup(3, P)
	w2.industries = { { id = 90, type = "saw_mill", name = "Scierie neuve", x = 1000, y = -300, playerOwned = false, productivity = 1.0 } }
	fake.advanceQuarter(w2)
	e2.tick(s2, w2, P)
	eq(s2.events[#s2.events].industries[1], 90)
end)

test("Journal", function()
	local engine, world, state = setup(10)
	local ev = engine.forceEvent(state, world, { sector = "iron_ore_mine", regionId = 79 })
	check(ev, "crise non lancée")
	local nom = fake.findIndustry(world, ev.industries[1]).name
	local function verifie(phase)
		local h = mods.journal.headline(ev)
		noPlaceholder(h, "titre")
		check(h:find("Brenne", 1, true), "ville absente du titre : " .. h)
		check(h:find("minerai de fer", 1, true), "secteur absent du titre : " .. h)
		local lignes = mods.journal.describe(state, world)
		check(#lignes >= 2, "journal vide")
		local tout = table.concat(lignes, "\n")
		noPlaceholder(tout, "journal (" .. phase .. ")")
		check(tout:find("Brenne", 1, true), "ville absente du journal")
		if phase ~= "done" then check(tout:find(nom, 1, true), "nom d'industrie absent : " .. nom) end
		for _, k in ipairs({ "rumor", "announce", "recovery", "done" }) do
			noPlaceholder(mods.journal.notification(k, ev), "notification " .. k)
		end
	end
	local vues = {}
	for _ = 1, 20 do
		vues[ev.phase] = true
		verifie(ev.phase)
		if ev.phase == "done" then break end
		engine.nextPhase(state, world)
	end
	for _, p in ipairs({ "rumor", "announce", "trough", "recovery", "done" }) do check(vues[p], "phase non vue : " .. p) end
	check(mods.journal.notification("rumor", ev):find("Rumeur : l'acier") == nil, "secteur différent")
	-- exemple du plan et repli sur le type brut
	local modele = { sector = "steel_mill", regionName = "Valmont", multiplier = 1.0, phase = "rumor", quartersInPhase = 0, industries = {} }
	eq(mods.journal.notification("rumor", modele), "Rumeur : l'acier de Valmont inquiète")
	modele.phase, modele.troughLength, modele.quartersInPhase = "trough", 3, 1
	eq(mods.journal.headline(modele), "Crise de l'acier · Valmont · le creux · trimestre 2 sur 3")
	modele.sector = "sulfur_mine"
	check(mods.journal.headline(modele):find("sulfur_mine", 1, true), "repli sur le type brut")
	noPlaceholder(mods.journal.headline(modele))
	check(#mods.journal.describe(engine.newState(1), world) == 1, "journal vide d'état")
end)

test("resetAll rend les productivités de base", function()
	local engine, world, state = setup(12)
	fake.findIndustry(world, 1).productivity = 1.3
	engine.forceEvent(state, world, { industryId = 1 })
	engine.forceEvent(state, world, { industryId = 3 })
	for _ = 1, 3 do
		fake.advanceQuarter(world)
		engine.tick(state, world, NOFREQ)
	end
	check(engine.targets(state)[1] < 1.3, "crise sans effet")
	local t = engine.resetAll(state)
	check(t[1] == 1.3, "base exacte de l'industrie 1")
	check(t[3] == 1.0, "base exacte de l'industrie 3")
	eq(count(t), 2)
	eq(#state.events, 0, "événements vidés")
	check(next(state.baseProductivity) == nil, "base vidée")
	check(next(engine.targets(state)) == nil, "plus de cible")
end)

test("Notifications", function()
	-- une annonce et une reprise par crise, au bon trimestre, dans les simulations
	for _, out in ipairs({ SIM_A, SIM_STRESS, SIM_FORCE }) do
		local ann, rec, autres = {}, {}, 0
		for _, n in ipairs(out.notifications) do
			noPlaceholder(n.text, "notification")
			check(#n.text > 0, "texte vide")
			if n.kind == "announce" then ann[n.eventId] = (ann[n.eventId] or 0) + 1
			elseif n.kind == "recovery" then rec[n.eventId] = (rec[n.eventId] or 0) + 1
			else autres = autres + 1 end
		end
		eq(autres, 0, "types de notification inattendus")
		for id, h in pairs(out.hist) do
			eq(ann[id], 1, "annonces de la crise " .. id)
			eq(rec[id], 1, "reprises de la crise " .. id)
			for k, p in ipairs(h.phases) do
				for _, n in ipairs(out.notifications) do
					if n.eventId == id and n.kind == "announce" and p == "announce" then eq(n.quarter, h.quarters[k], "trimestre de l'annonce") end
					if n.eventId == id and n.kind == "recovery" and p == "recovery" and h.phases[k - 1] ~= "recovery" then
						eq(n.quarter, h.quarters[k], "trimestre de la reprise")
					end
				end
			end
		end
	end
	-- pas à pas avec nextPhase
	local engine, world, state = setup(14)
	engine.forceEvent(state, world, { industryId = 1 })
	local attendu = { "announce", nil, "recovery", nil }
	for i = 1, 4 do
		local r = engine.nextPhase(state, world)
		eq(#r.notifications, attendu[i] and 1 or 0, "notifications à l'étape " .. i)
		if attendu[i] then eq(r.notifications[1].kind, attendu[i]) end
	end
	eq(state.events[1].phase, "done")
end)

-- Script de jeu avec API simulée (N2)
dofile("tests/game_script_test.lua")(test, check, eq)

-- Exécution
local echecs = 0
for _, t in ipairs(tests) do
	local ok, err = pcall(t.fn)
	if ok then
		print("TEST " .. t.name .. " OK")
	else
		echecs = echecs + 1
		print("TEST " .. t.name .. " ÉCHEC " .. tostring(err))
	end
end
print(string.format("%d tests, %d échec(s)", #tests, echecs))
if echecs > 0 then os.exit(1) end
