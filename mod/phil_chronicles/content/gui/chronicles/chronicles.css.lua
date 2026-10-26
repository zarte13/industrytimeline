local ssu = require "::/gui/main/stylesheetutil.lua"

function data()
	local result = {}
	local a = ssu.makeAdder(result)

	a("Window#phil_chronicles.window", {
		size = { 900, 560 },
	})
	a("Window#phil_chronicles.window Window::Content", {
		padding = { 12, 12, 12, 12 },
	})
	a("BoxLayout!chronicles-tab", {
		gravity = { -1, 0 }, -- contenu collé en haut de l'onglet (sinon centré verticalement)
		innerSpacing = { 8, 8 },
		padding = { 12, 12, 12, 12 },
	})
	a("BoxLayout!chronicles-industry", {
		innerSpacing = { 6, 6 },
		padding = { 8, 8, 8, 8 },
	})
	a("BoxLayout!chronicles-fill, ScrollArea!chronicles-scroll", {
		gravity = { -1, -1 }, -- remplit l'onglet pour que le défilement ait une hauteur
	})
	a("BoxLayout!chronicles-row", {
		innerSpacing = { 8, 0 },
	})
	a("Button!chronicles-button BoxLayout", {
		innerSpacing = { 6, 0 },
		padding = { 4, 8, 4, 8 },
	})

	-- diagnostic : si le « 2 » du bouton devient rouge, ce fichier est bien chargé par le jeu
	a("TextView!chronicles-badge", {
		color = { 0.94, 0.54, 0.52, 1.0 },
	})

	return result
end
