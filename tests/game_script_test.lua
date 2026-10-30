-- Tests hors jeu (N2) du script de jeu avec l'API simulée. Appelé par tests/run.lua.
local Mock = dofile("tests/game_api_mock.lua")

return function(test, check, eq)
	local VALMONT_ACIERIE, JOUEUR, CHARBON, FER = 101, Mock.playerIndustry, 104, 106
	local function near(a, b, tol, msg)
		if a == nil or math.abs(a - b) > (tol or 0.01) then
			error((msg or "valeur") .. " : attendu " .. tostring(b) .. ", obtenu " .. tostring(a), 2)
		end
	end
	-- carte neuve, script rechargé, premier update passé
	local function boot()
		local m = Mock.new()
		m.update(0.5)
		return m
	end
	local function minHistory(m, id)
		local lo
		for _, v in ipairs(m.history[id] or {}) do lo = lo and math.min(lo, v) or v end
		return lo
	end

	test("Script : abonnements et état initial", function()
		local m = Mock.new()
		m.update(0.5)
		local expected = { "forceEvent", "nextPhase", "fastQuarter", "dumpState", "resetAll", "runSelfTest" }
		eq(#m.state.subs, #expected, "nombre d'abonnements")
		for i, name in ipairs(expected) do eq(m.state.subs[i], name, "abonnement " .. i) end
		local s = m.state:get()
		eq(s.version, 1, "version")
		eq(s.lastQuarter, m.quarterIndex(), "trimestre initial")
		check(m.hasLog("[chronicles] état initial créé"), "log de l'état initial absent")
		m.update(0.5)
		eq(#m.state.subs, #expected, "pas de nouvel abonnement")
		eq(#m.errorLogs(), 0, "erreurs journalisées")
	end)

	test("Script : trimestre traité", function()
		local m = boot()
		local previous = m.state:get().lastQuarter
		for q = 1, 40 do
			m.advanceQuarter()
			m.update(1)
			m.update(1)
			local last = m.state:get().lastQuarter
			eq(last, previous + 1, "trimestre " .. q)
			previous = last
		end
		eq(m.state:get().lastQuarter, m.quarterIndex(), "dernier trimestre")
		eq(#m.errorLogs(), 0, "erreurs journalisées")
		check(#m.notifications >= 1, "aucune notification envoyée")
		for _, n in ipairs(m.notifications) do
			check(type(n.params.title) == "string" and #n.params.title > 0, "titre vide")
			check(type(n.params.description) == "string" and #n.params.description > 0, "description vide")
			check(n.type:find("chronicles_notification", 1, true), "type de notification")
		end
		local reached
		for _, id in ipairs(Mock.industryIds) do
			local lo = minHistory(m, id)
			if lo and math.abs(lo - 0.6) <= 0.01 then reached = true end
		end
		eq(m.productivity(JOUEUR), 1.0, "industrie du joueur")
		check(reached, "productivité de 0,6 jamais atteinte")
		check(m.hasLog("trimestre 19"), "journal de trimestre absent")
	end)

	test("Script : crise forcée par l'interface", function()
		local m = boot()
		m.handle("forceEvent", { industryId = VALMONT_ACIERIE })
		local s = m.state:get()
		eq(#s.events, 1, "événement créé")
		eq(s.events[1].industries[1], VALMONT_ACIERIE, "industrie visée")
		eq(s.events[1].phase, "rumor")
		m.handle("forceEvent", { industryId = CHARBON }, "AutreMod")
		eq(#m.state:get().events, 1, "événement d'un autre identifiant ignoré")
		m.handle("nextPhase")
		eq(m.state:get().events[1].phase, "announce")
		m.update(0.1)
		near(m.productivity(VALMONT_ACIERIE), 0.6, 0.01, "productivité de l'aciérie")
		eq(m.productivity(CHARBON), 1.0, "autre industrie intacte")
		check(m.modifiers(VALMONT_ACIERIE).capacity == 1.0, "autres modificateurs recopiés")
		check(#m.notifications == 1 and m.notifications[1].params.kind == "announce", "notification d'annonce")
	end)

	test("Script : industrie du joueur", function()
		local m = boot()
		m.handle("forceEvent", { industryId = JOUEUR })
		check(m.hasLog("crise refusée"), "refus non journalisé")
		eq(#m.state:get().events, 0, "aucun événement")
		m.handle("nextPhase")
		m.update(0.1)
		eq(m.productivity(JOUEUR), 1.0)
		eq(m.commands, 0, "aucune commande envoyée")
	end)

	test("Script : tout rétablir", function()
		local m = Mock.new()
		m.setProductivity(CHARBON, 1.3)
		m.update(0.5)
		m.handle("forceEvent", { industryId = CHARBON })
		m.handle("forceEvent", { industryId = FER })
		m.handle("nextPhase")
		m.update(0.1)
		near(m.productivity(CHARBON), 0.78, 0.01, "creux sur base 1,3")
		m.handle("resetAll")
		m.update(0.1)
		check(m.productivity(CHARBON) == 1.3, "base exacte, obtenu " .. tostring(m.productivity(CHARBON)))
		check(m.productivity(FER) == 1.0, "base exacte de l'industrie 2")
		local s = m.state:get()
		eq(#s.events, 0, "événements vidés")
		check(next(s.baseProductivity) == nil, "base vidée")
		check(m.hasLog("tout rétabli"), "log de rétablissement")
	end)

	test("Script : réaffirmation", function()
		local m = boot()
		m.handle("forceEvent", { industryId = VALMONT_ACIERIE })
		m.handle("nextPhase")
		m.update(0.1)
		near(m.productivity(VALMONT_ACIERIE), 0.6, 0.01, "cible appliquée")
		local sent = m.commands
		m.setProductivity(VALMONT_ACIERIE, 1.0) -- le jeu de base réécrit la productivité
		for _ = 1, 5 do m.update(1) end
		eq(m.productivity(VALMONT_ACIERIE), 1.0, "pas de réaffirmation avant 10 s")
		eq(m.commands, sent, "aucune commande avant 10 s")
		for _ = 1, 6 do m.update(1) end -- plus de 10 secondes cumulées
		check(m.commands > sent, "cible jamais renvoyée")
		m.update(0.1)
		near(m.productivity(VALMONT_ACIERIE), 0.6, 0.01, "cible rétablie")
	end)

	test("Script : autotest", function()
		local m = boot()
		m.handle("runSelfTest")
		for _ = 1, 40 do m.update(0.2) end
		m.flush()
		local _, fin = m.hasLog("AUTOTEST fin : ")
		check(fin, "fin de l'autotest absente")
		local ok, ko = fin:match("AUTOTEST fin : (%d+) OK, (%d+) ÉCHEC")
		check(ok and tonumber(ok) >= 3, "moins de 3 OK : " .. tostring(fin))
		eq(tonumber(ko), 0, "échecs de l'autotest : " .. tostring(fin))
		for _, name in ipairs({ "Productivité appliquée", "Cycle complet d'une crise",
			"Retour exact à la normale", "Industries du joueur intactes" }) do
			check(m.hasLog("TEST " .. name .. " OK"), "ligne manquante ou en échec : " .. name)
		end
		eq(m.productivity(JOUEUR), 1.0)
		eq(#m.errorLogs(), 0, "erreurs journalisées")
	end)

	local function lastHash(m)
		local h
		for _, l in ipairs(m.logs) do h = l.text:match("ÉTAT (%x%x%x%x%x%x%x%x) ") or h end
		return h
	end
	test("Script : empreinte stable", function()
		local m = boot()
		m.handle("forceEvent", { industryId = VALMONT_ACIERIE })
		m.handle("nextPhase")
		m.handle("dumpState")
		local h1 = lastHash(m)
		check(h1, "empreinte absente")
		m.handle("dumpState")
		eq(lastHash(m), h1, "deuxième empreinte")
		-- sauvegarde puis rechargement : nouvelle instance du script, état recopié
		local m2 = Mock.new()
		m2.state:set(Mock.deepcopy(m.state:get()))
		m2.handle("dumpState")
		eq(lastHash(m2), h1, "empreinte après rechargement")
	end)

	test("Script : trimestre accéléré", function()
		local m = boot()
		local before = m.state:get().lastQuarter
		m.handle("fastQuarter", { on = true })
		eq(m.state:get().debug.fastQuarter, true)
		for _ = 1, 4 do m.update(1) end
		eq(m.state:get().lastQuarter, before, "pas encore")
		for _ = 1, 2 do m.update(1) end
		eq(m.state:get().lastQuarter, before + 1, "un trimestre de plus")
		eq(m.state:get().debug.quarterOffset, 1, "décalage")
		m.handle("fastQuarter", { on = false })
		for _ = 1, 10 do m.update(1) end
		eq(m.state:get().lastQuarter, before + 1, "arrêt de l'accélération")
	end)

	test("Notification : données du type", function()
		local data = Mock.loadResource(Mock.NOTIFICATION_SCRIPT)
		local a = data.useDataState({ kind = "announce", title = "Crise annoncée", description = "Texte" })
		eq(a.title, "Crise annoncée")
		eq(a.description, "Texte")
		check(a.icon:find("building_industry_x", 1, true), "icône d'annonce : " .. tostring(a.icon))
		local r = data.useDataState({ kind = "recovery", title = "Reprise", description = "Retour" })
		eq(r.title, "Reprise")
		check(r.icon:find("building_industry_plus", 1, true), "icône de reprise : " .. tostring(r.icon))
		local d = data.useDataState({})
		check(#d.title > 0 and d.description == "", "valeurs par défaut")
	end)

	test("Syntaxe Lua du mod (luac -p)", function()
		local windows = package.config:sub(1, 1) == "\\"
		local lister = io.popen(windows and "dir /s /b mod\\*.lua" or "find mod -name '*.lua'")
		local files = {}
		for raw in lister:lines() do
			local line = raw:gsub("%s+$", "")
			if #line > 0 then files[#files + 1] = line end
		end
		lister:close()
		check(#files >= 10, "fichiers Lua introuvables : " .. #files)
		local erreurs = {}
		for _, f in ipairs(files) do
			local p = io.popen('luac -p "' .. f .. '" 2>&1')
			local out = p:read("a")
			local okc = p:close()
			if not okc or #out > 0 then erreurs[#erreurs + 1] = f .. " : " .. out end
		end
		eq(#erreurs, 0, table.concat(erreurs, "; "))
	end)

	-- Le jeu embarque Lua 5.2.2 (« unexpected symbol near '/' » sur un « // » en jeu, v2) :
	-- ni division entière, ni opérateurs binaires, ni attributs <const>, et des nombres flottants.
	test("Compatibilité Lua 5.2 du jeu", function()
		local windows = package.config:sub(1, 1) == "\\"
		local lister = io.popen(windows and "dir /s /b mod\\*.lua" or "find mod -name '*.lua'")
		local erreurs, n = {}, 0
		for raw in lister:lines() do
			local f = raw:gsub("%s+$", "")
			if #f > 0 then
				n = n + 1
				local h = assert(io.open(f, "rb"))
				local src = h:read("a")
				h:close()
				-- retire commentaires et chaînes avant de chercher les opérateurs
				src = src:gsub("%-%-%[(=*)%[.-%]%1%]", " ")
				src = src:gsub("%[(=*)%[.-%]%1%]", '""')
				src = src:gsub("%-%-[^\n]*", " ")
				src = src:gsub('"[^"\\\n]*(\\.[^"\\\n]*)*"', '""')
				src = src:gsub('"(\\.|[^"\\\n])*"', '""')
				src = src:gsub("'[^'\\\n]*'", "''")
				src = src:gsub('"[^"\n]*"', '""')
				for _, motif in ipairs({ "//", "&", "|", "~[^=]", "<<", ">>", "%f[%w]goto%f[%W]", "<const>", "<close>" }) do
					local pos = src:find(motif)
					if pos then
						erreurs[#erreurs + 1] = f .. " : « " .. src:sub(pos, pos + 12):gsub("\n", " ") .. " »"
					end
				end
			end
		end
		lister:close()
		check(n >= 10, "fichiers Lua introuvables : " .. n)
		eq(#erreurs, 0, table.concat(erreurs, "; "))
	end)

	test("Générateur exact en flottants", function()
		local rng = dofile("mod/phil_chronicles/content/core/rng.lua")
		local s = 0
		for _ = 1, 100000 do
			local f
			f, s = rng.next(s)
			check(f >= 0 and f < 1, "tirage hors de [0,1) : " .. tostring(f))
			check(s == math.floor(s) and s >= 1 and s < 2147483647, "état invalide : " .. tostring(s))
			check(s * 48271 < 2 ^ 53, "produit inexact en double")
		end
	end)
end
