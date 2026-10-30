-- Type de notification du mod : le titre et le texte arrivent tout faits dans les paramètres
-- (modèle : landmarks_notification_nonpersistent du jeu de base)

local data = {}

data.useDataState = function(params)
	local icon = "::/game_mechanics/notifications/gui/icons/building_industry_x.tga"
	if params.kind == "recovery" or params.kind == "done" then
		icon = "::/game_mechanics/notifications/gui/icons/building_industry_plus.tga"
	end
	return {
		title = params.title or "Chroniques économiques",
		description = params.description or "",
		icon = icon,
	}
end

return data
