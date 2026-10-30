-- Chroniques économiques : interface du mod
-- Bouton dans la zone des mods, fenêtre à onglets (Journal, Économie, Bilan, Débogage),
-- bloc ajouté à la fenêtre native d'une industrie. L'état vient du script de jeu
-- game_mechanics/chronicles ; les boutons de débogage lui envoient des événements.

local react = ug_require "::/gui/main/react.lua" as React
local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local engine_react_util = ug_require "::/gui/main/engine_react_util.tl" as EngineReactUtil
local game_react_globals = ug_require "::/gui/main/game_react_globals.tl" as GameReactGlobals
local main_mod_button_area = ug_require "::/gui/main/main_mod_button_area.tl" as MainModButtonArea
local industry_eow = ug_require "::/gui/entity_window/industry/industry_eow.script.tl" as IndustryEow
local styleutil = ug_require "::/gui/main/styleutil.tl" as StyleUtil
local util = ug_require "::/scripts/util.tl" as Util
local cargo_util = ug_require "::/gui/main/cargo_util.tl" as CargoUtil

local WINDOW_ID = "phil_chronicles.window"
local GAME_SCRIPT = "phil_chronicles::/game_mechanics/chronicles/chronicles.gs"
local EVENT_ID = "PhilChronicles"

local record ChroniclesWindowParams
	initialTab : string
	onClose : function()
end

-- ---------------------------------------------------------------- état du script de jeu

-- sous-ensemble de l'état sauvegardé (notes/mvp-design.md) lu par l'interface
local record ChroniclesEvent
	id : integer
	phase : string
	regionName : string
	industries : {integer}
	multiplier : number
end

local record ChroniclesDebug
	fastQuarter : boolean
	allNotifications : boolean
end

local record ChroniclesState
	journal : {string}
	headlines : {string}
	chronicle : {string}
	activity : {string}
	storyteller : string
	events : {ChroniclesEvent}
	debug : ChroniclesDebug
end

local function readGameState() : ChroniclesState
	local entity = api.engine.system.gameScriptSystem.getEntityForGameScript(GAME_SCRIPT)
	if entity == nil or entity < 0 then
		return nil
	end
	local gameScript = api.engine.getComponent(entity, api.type.ComponentType.GAME_SCRIPT) as Engine.Component.GameScript<ChroniclesState>
	if gameScript == nil then
		return nil
	end
	return gameScript.state
end

local function activeEvents(state : ChroniclesState) : {ChroniclesEvent}
	local list : {ChroniclesEvent} = {}
	if state == nil or state.events == nil then
		return list
	end
	for __, ev in ipairs(state.events) do
		if ev.phase ~= "done" then list[#list + 1] = ev end
	end
	return list
end

local function sendToScript(name : string, param : table)
	log.message("[chronicles] interface -> " .. name)
	api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd("", EVENT_ID, name, param))
end

-- ---------------------------------------------------------------- utilitaires

local function text(t : string, class? : string) : TreeNodeId
	return builtin.TextView{
		meta = { class = class or "font-scale-body" },
		text = t,
	}
end

local function vbox(children : {TreeNodeId}, class? : string) : TreeNodeId
	return builtin.BoxLayout{
		meta = { class = class },
		orientation = builtin.type.Orientation.Vertical,
		children = children,
	}
end

local function hbox(children : {TreeNodeId}, class? : string) : TreeNodeId
	return builtin.BoxLayout{
		meta = { class = class },
		orientation = builtin.type.Orientation.Horizontal,
		children = children,
	}
end

-- L'entité INDUSTRY pointe vers son entité STOCK_LIST (industry.stockList),
-- qui peut être la même entité (fenêtre d'industrie) ou une autre (statistiques).
local function getStockListEntity(entity : Engine.Entity) : Engine.Entity
	local industry = api.engine.getComponent(entity, api.type.ComponentType.INDUSTRY) as Engine.Component.Industry
	if industry ~= nil and industry.stockList ~= nil then
		return industry.stockList
	end
	return entity
end

local function getProductivity(entity : Engine.Entity) : number
	local stockList = api.engine.getComponent(getStockListEntity(entity), api.type.ComponentType.STOCK_LIST) as Engine.Component.StockList
	if stockList == nil or stockList.modifiers == nil then
		return -1
	end
	return stockList.modifiers.productivity
end

local function getName(entity : Engine.Entity) : string
	-- même fonction que les statistiques du jeu
	return api.engine.util.getEntityName(entity) or ("#" .. tostring(entity))
end

-- ---------------------------------------------------------------- onglets

-- texte écrit par le script de jeu à chaque trimestre (core/journal.lua)
local JournalTab = react.RegisterRecipe("ChroniclesJournalTab", function() : TreeNodeId
	local linesState = engine_react_util.useStepStateTimer(function() : {string}
		local state = readGameState()
		if state == nil or state.journal == nil then
			return { "Le journal paraîtra au prochain trimestre." }
		end
		return state.journal
	end)
	-- toutes les crises de la partie, datées (core/journal.lua, chronicle)
	local chronicleState = engine_react_util.useStepStateTimer(function() : {string}
		local state = readGameState()
		if state == nil or state.chronicle == nil then
			return {}
		end
		return state.chronicle
	end)
	local children : {TreeNodeId} = {
		text("Le Courrier économique", "font-scale-headline"),
	}
	for __, line in ipairs(linesState:old()) do
		children[#children + 1] = text(line)
	end
	local chronicle = chronicleState:old()
	if #chronicle > 0 then
		children[#children + 1] = text("Chronologie", "font-scale-headline")
		for __, line in ipairs(chronicle) do
			children[#children + 1] = text(line, "font-scale-annotation")
		end
	end
	return vbox(children, "chronicles-tab")
end)

local function debugButton(label : string, tooltip : string, onClick : function()) : TreeNodeId
	return builtin.Button{
		meta = { class = "secondary", tooltip = tooltip },
		onClick = onClick,
		content = text(label),
	}
end

-- pilote le script de jeu ; les résultats s'écrivent dans stdout.txt avec le préfixe [chronicles]
local DebugTab = react.RegisterRecipe("ChroniclesDebugTab", function() : TreeNodeId
	local fastState = engine_react_util.useStepStateTimer(function() : boolean
		local state = readGameState()
		return state ~= nil and state.debug ~= nil and state.debug.fastQuarter == true
	end)
	local countState = engine_react_util.useStepStateTimer(function() : integer
		return #activeEvents(readGameState())
	end)
	local allNotificationsState = engine_react_util.useStepStateTimer(function() : boolean
		local state = readGameState()
		return state == nil or state.debug == nil or state.debug.allNotifications ~= false
	end)
	local storytellerState = engine_react_util.useStepStateTimer(function() : string
		local state = readGameState()
		return state ~= nil and state.storyteller or "Conteur : en attente du premier trimestre"
	end)
	-- dernières décisions du moteur, la plus récente en haut (écrites par le script de jeu)
	local activityState = engine_react_util.useStepStateTimer(function() : {string}
		local state = readGameState()
		if state == nil or state.activity == nil then
			return {}
		end
		return state.activity
	end)
	local fast = fastState:old()
	local allNotifications = allNotificationsState:old()
	local activityRows : {TreeNodeId} = {}
	for __, line in ipairs(activityState:old()) do
		activityRows[#activityRows + 1] = text(line, "font-scale-annotation")
	end
	if #activityRows == 0 then
		activityRows[1] = text("Rien encore : l'activité s'affiche au prochain trimestre.", "font-scale-annotation")
	end
	return vbox({
		text("Débogage", "font-scale-headline"),
		text("Événements actifs : " .. tostring(countState:old()) .. " · trimestre accéléré : " .. (fast and "oui" or "non")),
		text(storytellerState:old()),
		hbox({
			debugButton(allNotifications and "Notifications : chaque phase" or "Notifications : annonce et reprise",
				"Cliquer pour basculer", function() sendToScript("toggleNotifications", {}) end),
		}, "chronicles-row"),
		hbox({
			debugButton("Lancer l'autotest", "Écrit TEST <nom> OK ou ÉCHEC dans stdout.txt", function() sendToScript("runSelfTest", {}) end),
			debugButton("Forcer un événement", "Crise sectorielle choisie par le conteur", function() sendToScript("forceEvent", {}) end),
			debugButton("Phase suivante", "Fait avancer tous les événements d'une phase", function() sendToScript("nextPhase", {}) end),
		}, "chronicles-row"),
		hbox({
			debugButton(fast and "Trimestre normal" or "Trimestre accéléré", "Un trimestre toutes les 5 secondes de jeu", function() sendToScript("fastQuarter", { on = not fast }) end),
			debugButton("Écrire l'état", "Copie l'état et son empreinte dans stdout.txt", function() sendToScript("dumpState", {}) end),
			debugButton("Tout rétablir", "Productivités d'avant le mod, événements effacés", function() sendToScript("resetAll", {}) end),
		}, "chronicles-row"),
		hbox({
			debugButton("Partie témoin accélérée (10 ans)", "40 trimestres accélérés, puis bilan : crises complètes et erreurs", function() sendToScript("runWitness", {}) end),
		}, "chronicles-row"),
		text("Test de sauvegarde : préparer, mettre en pause, sauvegarder, recharger, puis vérifier.", "font-scale-annotation"),
		hbox({
			debugButton("Préparer le test de sauvegarde", "Lance une crise si besoin et note l'empreinte de l'état", function() sendToScript("prepareSaveTest", {}) end),
			debugButton("Vérifier la sauvegarde", "Après rechargement : même empreinte, aucune commande appliquée deux fois", function() sendToScript("checkSaveTest", {}) end),
		}, "chronicles-row"),
		text("Activité du moteur", "font-scale-headline"),
		vbox(activityRows),
	}, "chronicles-tab")
end)

local EconomyTab = react.RegisterRecipe("ChroniclesEconomyTab", function() : TreeNodeId
	-- lecture de l'état du moteur, rafraîchie par minuterie
	local countState = engine_react_util.useStepStateTimer(function() : integer
		-- STOCK_LIST ne peut pas être parcouru : on compte les entités INDUSTRY (comme statistic_industries.tl)
		return #api.engine.getEntitiesWithComponent(api.type.ComponentType.INDUSTRY)
	end)
	-- manchettes écrites par le script de jeu (core/journal.lua)
	local headlinesState = engine_react_util.useStepStateTimer(function() : {string}
		local state = readGameState()
		if state == nil or state.headlines == nil then
			return {}
		end
		return state.headlines
	end)
	local children : {TreeNodeId} = { text("Événements en cours", "font-scale-headline") }
	local headlines = headlinesState:old()
	if #headlines == 0 then
		children[#children + 1] = text("Aucun événement en cours.")
	end
	for __, line in ipairs(headlines) do
		children[#children + 1] = text(line)
	end
	children[#children + 1] = text(tostring(countState:old()) .. " industries sur la carte.", "font-scale-annotation")
	return vbox(children, "chronicles-tab")
end)

-- Livraisons à temps sur un an, toutes villes : calculées dans l'état « parallèle »,
-- comme la fenêtre de ville du jeu (town_react_util -> town_util_parallel)
local record DeliveryTotals
	late : integer
	total : integer
end

-- Délais max par cargo produit : même source que l'onglet « Délai de livraison » de la compagnie
local record CargoDelay
	name : string
	seconds : integer
end

local function getCargoDelays() : {CargoDelay}
	local list : {CargoDelay} = {}
	local passenger = cargo_util.getPassengerCargoTypeId()
	for cargoTypeId, _name in pairs(api.res.cargoTypeRep.getAll()) do
		if cargoTypeId ~= passenger and api.engine.util.stock.isCargoTypeCurrentlyProduced(cargoTypeId) then
			local cargoType = api.res.cargoTypeRep.get(cargoTypeId)
			list[#list + 1] = { name = cargoType.name, seconds = api.engine.util.stock.getAdjustedDeliveryTime(cargoTypeId) }
		end
	end
	table.sort(list, function(x : CargoDelay, y : CargoDelay) : boolean
		if x.seconds == y.seconds then return x.name < y.name end
		return x.seconds < y.seconds
	end)
	return list
end

local function getMillisPerDay() : integer
	local gameSpeed = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_SPEED) as Engine.Component.GameSpeed
	return gameSpeed.millisPerDay
end

-- une barre horizontale dessinée avec un Component à taille fixe (technique du graphique des délais du jeu)
local function bar(width : integer) : TreeNodeId
	return builtin.Component{
		meta = {
			styleSheet = styleutil.makeStyle{
				backgroundColor = api.type.Vec4f.new(0.55, 0.71, 0.95, 1.0),
				size = { math.max(width, 2), 12 },
			},
		},
	}
end

local ReportTab = react.RegisterRecipe("ChroniclesReportTab", function() : TreeNodeId
	local balanceState = engine_react_util.useStepStateTimer(function() : integer
		return api.engine.util.finance.getPlayersBalance(api.engine.util.getPlayer())
	end)
	local earningsState = engine_react_util.useStepStateTimer(function() : integer
		return api.engine.util.finance.calculateEarnings(api.engine.util.getPlayer())
	end)
	local deliveriesState = engine_react_util.useStepStateParallelSimple("phil_chronicles::/gui/chronicles/chronicles_parallel.script@chronicles_parallel.getDeliveryTotals", 0) as ReactStateT<DeliveryTotals>
	local delaysState = engine_react_util.useStepStateTimer(getCargoDelays)
	local millisPerDayState = engine_react_util.useStepState(getMillisPerDay)

	local d = deliveriesState:old()
	local onTimeText = "calcul en cours…"
	if d ~= nil and d.total == 0 then
		onTimeText = "aucune livraison de cargo depuis un an"
	elseif d ~= nil then
		local pct = math.floor((d.total - d.late) * 100 / d.total + 0.5)
		onTimeText = tostring(pct) .. " % à temps (" .. tostring(d.total - d.late) .. " sur " .. tostring(d.total) .. ")"
	end

	local delays = delaysState:old()
	local maxSeconds = 1
	for __, c in ipairs(delays) do maxSeconds = math.max(maxSeconds, c.seconds) end
	local delayRows : {TreeNodeId} = {}
	for __, c in ipairs(delays) do
		delayRows[#delayRows + 1] = hbox({
			-- libellé à largeur fixe pour aligner le début des barres
			builtin.TextView{
				meta = { class = "font-scale-annotation", styleSheet = styleutil.makeStyle{ size = { 170, -1 } } },
				text = c.name,
			},
			bar(math.floor(c.seconds * 300 / maxSeconds)),
			text(util.formatDurationWithCurrentCalenderSpeed(c.seconds * 1000, millisPerDayState:old()), "font-scale-annotation"),
		}, "chronicles-row")
	end

	local children : {TreeNodeId} = {
		text("Bilan · la une (données réelles)", "font-scale-headline"),
		text("Compte : " .. api.util.formatMoney(balanceState:old()) .. " · revenus de l'année : " .. api.util.formatMoney(earningsState:old())),
		text("Cargo livré à temps, toutes villes, 12 derniers mois : " .. onTimeText),
		text("Délai max par cargo produit (à la vitesse actuelle du calendrier)", "font-scale-headline"),
	}
	for __, row in ipairs(delayRows) do children[#children + 1] = row end
	return vbox(children, "chronicles-tab")
end)

-- ---------------------------------------------------------------- fenêtre

local ChroniclesWindow = react.RegisterWrapperRecipe("ChroniclesWindow", builtin.Window, function(params : ChroniclesWindowParams) : TreeNodeId
	local tabState = react.useState(params.initialTab or "journal") as ReactStateT<string>
	local pinnedState = react.useState(false) as ReactStateT<boolean>

	local function tab(key : string, label : string, item : TreeNodeId) : TreeNodeId
		return builtin.TabWidgetChild{
			localKey = key,
			value = key,
			indicator = text(label, "font-scale-tab-widget-indicator"),
			-- l'item d'un onglet ne doit pas être une mise en page : on l'enveloppe dans un Component (comme le jeu)
			-- défilement vertical si le contenu dépasse (motif de advanced_settings.tl)
			item = builtin.Component{ layout = vbox({
				builtin.ScrollArea{
					meta = { class = "chronicles-scroll" },
					horizontalPolicy = builtin.type.ScrollBarPolicy.AlwaysOff,
					verticalPolicy = builtin.type.ScrollBarPolicy.AsNeeded,
					content = builtin.Component{ layout = vbox({ item }) },
				},
			}, "chronicles-fill") },
		}
	end

	return builtin.Window{
		id = WINDOW_ID,
		title = "Chroniques économiques",
		closable = true,
		pinnable = true,
		pinned = pinnedState:old(),
		onPinned = function(pin : boolean) pinnedState:set(pin) end,
		onClose = params.onClose,
		-- taille imposée en ligne (styleSheet), car la règle du fichier .css.lua n'a pas été appliquée
		content = builtin.Component{
			meta = { styleSheet = styleutil.makeStyle{ size = { 900, 560 } } },
			layout = builtin.BoxLayout{
			orientation = builtin.type.Orientation.Vertical,
			children = {
			builtin.TabWidget{
				orientation = builtin.type.TabOrientation.North,
				value = tabState:old(),
				onValueChange = function(v : integer|number|string)
					if v is string then tabState:set(v) end
				end,
				tabs = {
					tab("journal", "Journal", JournalTab{}),
					tab("economie", "Économie", EconomyTab{}),
					tab("bilan", "Bilan", ReportTab{}),
					tab("debogage", "Débogage", DebugTab{}),
				},
			},
			},
			},
		},
	}
end)

local function openWindow(initialTab : string)
	local wapi = game_react_globals.getDefaultWindowApi()
	wapi.addSingletonWindow(ChroniclesWindow, {
		initialTab = initialTab,
		onClose = function()
			game_react_globals.getDefaultWindowApi().removeAllWindows(ChroniclesWindow)
		end,
	})
	wapi.moveSingletonWindowToFront(ChroniclesWindow)
end

-- ---------------------------------------------------------------- plugins

local ChroniclesButtonPlugin = react.RegisterPluginRecipe(main_mod_button_area.MainModButtonAreaExtension, "ChroniclesButtonPlugin", function() : TreeNodeId
	local countState = engine_react_util.useStepStateTimer(function() : integer
		return #activeEvents(readGameState())
	end)
	local count = countState:old()
	local content : {TreeNodeId} = { text("Chroniques", "font-scale-body") }
	if count > 0 then
		content[#content + 1] = text(tostring(count), "font-scale-body, chronicles-badge")
	end
	-- la racine d'une recette doit être une mise en page (BoxLayout), pas un Button
	return hbox({
		builtin.Button{
			-- sans classe, un Button du jeu a un fond invisible ; "primary" = fond d'accent (default.css.lua)
			meta = { class = "primary, chronicles-button", tooltip = "Chroniques économiques · " .. tostring(count) .. " événement(s) en cours" },
			onClick = function()
				log.message("[chronicles] clic sur le bouton du mod")
				openWindow("journal")
			end,
			content = hbox(content),
		},
	})
end)

local ChroniclesIndustryPlugin = react.RegisterPluginRecipe(industry_eow.IndustryEowExtensionPoint, "ChroniclesIndustryPlugin", function(params : IndustryEow.IndustryWidgetPluginParams) : TreeNodeId
	local entity = params.entityId
	local prodState = engine_react_util.useStepStateTimer(function() : number
		return getProductivity(entity)
	end)
	-- phase de l'événement qui touche cette industrie, ou nil
	local phaseState = engine_react_util.useStepStateTimer(function() : string
		for __, ev in ipairs(activeEvents(readGameState())) do
			for __, id in ipairs(ev.industries or {}) do
				if id == entity then return ev.phase .. " · " .. ev.regionName end
			end
		end
		return nil
	end)
	local prod = prodState:old()
	local prodText = prod < 0 and "inconnue" or (tostring(math.floor(prod * 100 + 0.5)) .. " %")
	local phase = phaseState:old()

	return vbox({
		text("Chroniques économiques", "font-scale-headline"),
		text(getName(entity) .. " · productivité : " .. prodText),
		text(phase ~= nil and ("En crise : " .. phase) or "Aucun événement en cours ici."),
		hbox({
			builtin.Button{
				meta = { class = "secondary", tooltip = "Débogage : lance une crise sectorielle sur cette industrie" },
				onClick = function() sendToScript("forceEvent", { industryId = entity }) end,
				content = text("Forcer une crise ici"),
			},
			builtin.Button{
				meta = { class = "primary" },
				onClick = function() openWindow("economie") end,
				content = text("Fiche de l'événement"),
			},
		}),
	}, "chronicles-industry")
end)

return {
	ChroniclesButtonPlugin = ChroniclesButtonPlugin,
	ChroniclesIndustryPlugin = ChroniclesIndustryPlugin,
	ChroniclesWindow = ChroniclesWindow,
}
