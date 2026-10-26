-- Chroniques économiques : prototype d'interface (test 1)
-- Vérifie : bouton dans la zone des mods, fenêtre à 3 onglets, lecture de l'état du jeu,
-- bloc ajouté à la fenêtre native d'une industrie, commande de productivité.

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

local record ChroniclesWindowParams
	initialTab : string
	onClose : function()
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

local function setProductivity(entity : Engine.Entity, value : number)
	local modifiers = api.type.StockList.Modifiers.new()
	modifiers.productivity = value
	log.message("[chronicles] industrie " .. tostring(entity) .. ", stocklist " .. tostring(getStockListEntity(entity)))
	api.cmd.sendCommand(api.cmd.makeStockListSetModifiersCmd(entity, modifiers), function(_data : any, success : boolean)
		log.message("[chronicles] productivité " .. tostring(value) .. " -> " .. tostring(success))
	end)
end

local function getName(entity : Engine.Entity) : string
	-- même fonction que les statistiques du jeu
	return api.engine.util.getEntityName(entity) or ("#" .. tostring(entity))
end

-- ---------------------------------------------------------------- onglets

local function journalTab() : TreeNodeId
	return vbox({
		text("Le Courrier économique · édition du 4e trimestre 1931", "font-scale-annotation"),
		text("CRISE · LE CREUX · TRIMESTRE 4 SUR 8", "font-scale-annotation"),
		text("Les Forges du Nord fermeront dans deux ans sans nouveaux débouchés", "font-scale-headline"),
		text("Les aciéries de la vallée tournent toujours à 60 % de leur capacité. Sans acheteurs pour leur acier, les Forges du Nord fermeront à l'été 1933."),
		text("En bref : Port-Bellard dépasse les 6 000 habitants."),
	}, "chronicles-tab")
end

local EconomyTab = react.RegisterRecipe("ChroniclesEconomyTab", function() : TreeNodeId
	-- lecture de l'état du moteur, rafraîchie par minuterie
	local countState = engine_react_util.useStepStateTimer(function() : integer
		-- STOCK_LIST ne peut pas être parcouru : on compte les entités INDUSTRY (comme statistic_industries.tl)
		return #api.engine.getEntitiesWithComponent(api.type.ComponentType.INDUSTRY)
	end)
	return vbox({
		text("Événements en cours", "font-scale-headline"),
		text("Crise de l'acier · Valmont · le creux (exemple statique)"),
		text("Donnée réelle de la partie : " .. tostring(countState:old()) .. " industries sur la carte."),
	}, "chronicles-tab")
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
					tab("journal", "Journal", journalTab()),
					tab("economie", "Économie", EconomyTab{}),
					tab("bilan", "Bilan 1931", ReportTab{}),
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
	-- la racine d'une recette doit être une mise en page (BoxLayout), pas un Button
	return hbox({
		builtin.Button{
			-- sans classe, un Button du jeu a un fond invisible ; "primary" = fond d'accent (default.css.lua)
			meta = { class = "primary, chronicles-button", tooltip = "Chroniques économiques · 2 non lus" },
			onClick = function()
				log.message("[chronicles] clic sur le bouton du mod")
				openWindow("journal")
			end,
			content = hbox({
				text("Chroniques", "font-scale-body"),
				text("2", "font-scale-body, chronicles-badge"),
			}),
		},
	})
end)

local ChroniclesIndustryPlugin = react.RegisterPluginRecipe(industry_eow.IndustryEowExtensionPoint, "ChroniclesIndustryPlugin", function(params : IndustryEow.IndustryWidgetPluginParams) : TreeNodeId
	local entity = params.entityId
	local prodState = engine_react_util.useStepStateTimer(function() : number
		return getProductivity(entity)
	end)
	local prod = prodState:old()
	local prodText = prod < 0 and "inconnue" or (tostring(math.floor(prod * 100 + 0.5)) .. " %")

	return vbox({
		text("Chroniques économiques", "font-scale-headline"),
		text(getName(entity) .. " · productivité : " .. prodText),
		hbox({
			builtin.Button{
				meta = { class = "secondary", tooltip = "Test : applique une crise (−40 %)" },
				onClick = function() setProductivity(entity, 0.6) end,
				content = text("Test crise −40 %"),
			},
			builtin.Button{
				meta = { class = "secondary", tooltip = "Test : rétablit la productivité" },
				onClick = function() setProductivity(entity, 1.0) end,
				content = text("Rétablir 100 %"),
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
