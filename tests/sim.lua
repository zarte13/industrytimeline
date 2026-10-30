-- Simulation de longue durée : joue le moteur trimestre par trimestre et relève des faits.
-- Usage : local sim = dofile("tests/sim.lua")(ctx) ; sim.run{ seed = 1, quarters = 400 }
return function(ctx)
	local engine, fake, regions = ctx.engine, ctx.fake, ctx.regions
	local S = {}

	-- opts : seed, quarters, frequency, cooldown, force (événements forcés pour stresser les garde-fous)
	function S.run(opts)
		local world = fake.build()
		local state = engine.newState(opts.seed or 1)
		local params = { frequency = opts.frequency or 0.25, cooldown = opts.cooldown or 4 }
		local info = regions.build(world)
		local playerRegion = info.of[fake.playerId]
		local playerType = fake.findIndustry(world, fake.playerId).type
		local townIds = info.order
		local out = { hist = {}, violations = {}, notifications = {}, forcedPlayer = 0, state = state, world = world }

		local function observe(q)
			local actives, perRegion, perIndustry = 0, {}, {}
			for _, ev in ipairs(state.events) do
				local h = out.hist[ev.id]
				if not h then
					h = { phases = {}, start = ev.startQuarter, sector = ev.sector, region = ev.regionId,
						industries = {}, quarters = {} }
					for _, id in ipairs(ev.industries) do h.industries[#h.industries + 1] = id end
					out.hist[ev.id] = h
				end
				if h.last ~= q then
					h.phases[#h.phases + 1] = ev.phase
					h.quarters[#h.quarters + 1] = q
					h.last = q
				end
				if ev.phase == "done" then h.finish = ev.endQuarter
				else
					actives = actives + 1
					perRegion[ev.regionId] = (perRegion[ev.regionId] or 0) + 1
					if perRegion[ev.regionId] > 2 then
						out.violations[#out.violations + 1] = "trois crises actives dans la région " .. ev.regionId
					end
					for _, id in ipairs(ev.industries) do
						perIndustry[id] = (perIndustry[id] or 0) + 1
						if perIndustry[id] > 1 then
							out.violations[#out.violations + 1] = "industrie " .. id .. " dans deux événements"
						end
						if id == fake.playerId then
							out.violations[#out.violations + 1] = "industrie du joueur ciblée"
						end
					end
				end
			end
		end

		engine.tick(state, world, params) -- premier appel : enregistre seulement
		local total = opts.quarters or 400
		local startQ = state.lastQuarter
		out.startQuarter = startQ
		for i = 1, total + (opts.drain and 12 or 0) do
			local p = params
			if i > total then p = { frequency = 0, cooldown = params.cooldown } end
			fake.advanceQuarter(world)
			if opts.force and i <= total then
				if i % 5 == 0 then
					engine.forceEvent(state, world, { regionId = playerRegion, sector = playerType })
				end
				if i % 7 == 0 then
					local ev = engine.forceEvent(state, world, { industryId = fake.playerId })
					if ev then out.violations[#out.violations + 1] = "forceEvent a accepté l'industrie du joueur" end
					out.forcedPlayer = out.forcedPlayer + 1
				end
				if i % 3 == 0 then
					engine.forceEvent(state, world, { regionId = townIds[(i // 3) % #townIds + 1] })
				end
			end
			observe(state.lastQuarter) -- événements forcés, encore en rumeur
			local r = engine.tick(state, world, p)
			for _, n in ipairs(r.notifications) do
				n.quarter = state.lastQuarter
				out.notifications[#out.notifications + 1] = n
			end
			for id, t in pairs(r.targets) do
				if id == fake.playerId then out.violations[#out.violations + 1] = "cible sur l'industrie du joueur" end
				local ind = fake.findIndustry(world, id)
				if ind then ind.productivity = t end
			end
			observe(state.lastQuarter)
		end
		return out
	end

	-- Liste canonique des événements, pour comparer deux parties.
	function S.signature(out)
		local ids = {}
		for id in pairs(out.hist) do ids[#ids + 1] = id end
		table.sort(ids)
		local parts = {}
		for _, id in ipairs(ids) do
			local h = out.hist[id]
			parts[#parts + 1] = id .. ":" .. h.sector .. ":" .. h.region .. ":" .. h.start .. ":" ..
				tostring(h.finish) .. ":" .. table.concat(h.industries, "+")
		end
		return table.concat(parts, "|")
	end

	return S
end
