-- Journal : textes français pour l'onglet Journal, les notifications et le log.
-- Le catalogue est relié par engine.new (pas de require entre modules du cœur).
local M = {}

local catalog = nil

function M.setCatalog(c)
	catalog = c
end

local function secteur(sectorType)
	if catalog then return catalog.sector(sectorType) end
	return { noun = sectorType, of = "de " .. sectorType, name = sectorType }
end

local PHASES = {
	rumor = "la rumeur", announce = "l'annonce", trough = "le creux",
	recovery = "la reprise", done = "terminée",
}

local MODELES = {
	rumor = "Rumeur : {noun} {de} inquiète",
	announce = "Crise {of} {ou} : production réduite à {pct} %",
	recovery = "Reprise {ou} : {noun} se redresse, la production remonte",
	done = "Fin de la crise {of} {ou}",
}

-- Remplace {clé} par vars[clé] ; une clé inconnue donne un texte vide.
local function remplit(modele, vars)
	return (modele:gsub("{(%w+)}", function(k) return vars[k] or "" end))
end

-- « de Valmont » / « d'Alba »
local function deVille(name)
	local c = name:sub(1, 1)
	if c:find("[AEIOUYHaeiouyh]") or name:sub(1, 2) == "É" then return "d'" .. name end
	return "de " .. name
end

local function variables(ev)
	local s = secteur(ev.sector)
	return {
		noun = s.noun, of = s.of, name = s.name,
		de = deVille(ev.regionName), ou = "à " .. ev.regionName, region = ev.regionName,
		pct = tostring(math.floor((ev.multiplier or 1) * 100 + 0.5)),
	}
end

local function dureePhase(ev)
	if ev.phase == "trough" then return ev.troughLength or 1 end
	if ev.phase == "recovery" then return catalog and catalog.recoveryQuarters or 3 end
	return 1
end

-- « Crise de l'acier · Valmont · le creux · trimestre 2 sur 3 »
function M.headline(ev)
	local v = variables(ev)
	local txt = "Crise " .. v.of .. " · " .. ev.regionName .. " · " .. PHASES[ev.phase]
	if ev.phase ~= "done" then
		txt = txt .. " · trimestre " .. ((ev.quartersInPhase or 0) + 1) .. " sur " .. dureePhase(ev)
	end
	return txt
end

-- Texte de notification ou de log pour une phase (rumor, announce, recovery, done).
function M.notification(kind, ev)
	return remplit(MODELES[kind] or MODELES.done, variables(ev))
end

local function nomsIndustries(ev, byId)
	local noms = {}
	for _, id in ipairs(ev.industries) do
		local ind = byId[id]
		noms[#noms + 1] = ind and ind.name or "industrie disparue"
	end
	return noms
end

local function detail(ev)
	local v = variables(ev)
	if ev.phase == "rumor" then
		return remplit("Des bruits courent : {noun} {de} inquiète. Aucun effet pour l'instant.", v)
	elseif ev.phase == "announce" then
		return remplit("La crise est annoncée {ou}. Production réduite à {pct} %.", v)
	elseif ev.phase == "trough" then
		local reste = (ev.troughLength or 1) - (ev.quartersInPhase or 0)
		return remplit("Le creux de la crise : production à {pct} %, reprise dans ", v) ..
			reste .. (reste > 1 and " trimestres." or " trimestre.")
	elseif ev.phase == "recovery" then
		return remplit("La reprise est en cours {ou} : production à {pct} %.", v)
	end
	return remplit("La crise {of} {ou} est terminée.", v)
end

-- Lignes de l'onglet Journal.
function M.describe(state, world)
	local byId = {}
	for _, ind in ipairs(world.industries or {}) do byId[ind.id] = ind end
	local lignes, actives, finies = {}, {}, {}
	for _, ev in ipairs(state.events) do
		if ev.phase == "done" then finies[#finies + 1] = ev else actives[#actives + 1] = ev end
	end
	if #actives == 0 then lignes[#lignes + 1] = "Aucune crise en cours." end
	for _, ev in ipairs(actives) do
		lignes[#lignes + 1] = M.headline(ev)
		lignes[#lignes + 1] = detail(ev)
		local noms = nomsIndustries(ev, byId)
		lignes[#lignes + 1] = #noms > 0 and ("Industries touchées : " .. table.concat(noms, ", ") .. ".")
			or "Aucune industrie touchée."
	end
	local debut = math.max(1, #finies - 2)
	for i = #finies, debut, -1 do
		lignes[#lignes + 1] = "Terminée : " .. M.headline(finies[i])
	end
	return lignes
end

return M
