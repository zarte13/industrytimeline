-- Fonctions exécutées dans l'état « parallèle » du jeu (appelées par useStepStateParallelSimple)

local record ChroniclesParallel
	record DeliveryTotals
		late : integer
		total : integer
	end
	getDeliveryTotals : function(_param : integer) : DeliveryTotals
end

local chronicles_parallel : ChroniclesParallel = {}

chronicles_parallel.getDeliveryTotals = function(_param : integer) : ChroniclesParallel.DeliveryTotals
	local result : ChroniclesParallel.DeliveryTotals = { late = 0, total = 0 }
	local interval = api.util.getDefaultYearDuration()
	for __, town in ipairs(api.engine.getEntitiesWithComponent(api.type.ComponentType.TOWN)) do
		local stats = api.engine.util.town.getTownDeliveriesStats(town, interval, true, true)
		for __, perCargo in pairs(stats) do
			for __, lateTotal in pairs(perCargo) do
				result.late = result.late + lateTotal[1]
				result.total = result.total + lateTotal[2]
			end
		end
	end
	return result
end

return {
	chronicles_parallel = chronicles_parallel
}
