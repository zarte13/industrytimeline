local mod = {}

mod.preRunFn = function(_captureParams : any, _configDict : {{string, string}}, _allModParams : {string : {string : integer}}, _baseConfig : BaseConfig)
	log.message("[chronicles] preRunFn : mod chargé")
end

return mod
