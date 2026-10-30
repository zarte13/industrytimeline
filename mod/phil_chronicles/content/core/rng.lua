-- Générateur pseudo-aléatoire déterministe. L'état est un simple entier dans [1, 2^31 - 2],
-- stocké tel quel dans state.rng : aucune table, aucune fonction dans la sauvegarde.
-- Le jeu tourne en Lua 5.2 : pas d'opérateurs binaires et des nombres flottants. D'où le
-- générateur de Park et Miller, dont les produits (< 2^46) restent exacts en double.
local M = {}

local MODULUS = 2147483647 -- 2^31 - 1
local MULTIPLIER = 48271

-- Ramène n'importe quelle graine dans [1, MODULUS - 1] (0 bloquerait le générateur).
local function normalise(state)
	local s = math.floor(state) % MODULUS
	if s == 0 then s = 1 end
	return s
end

-- Flottant dans [0,1) et nouvel état.
function M.next(state)
	local s = (normalise(state) * MULTIPLIER) % MODULUS
	return (s - 1) / (MODULUS - 1), s
end

-- Entier dans [a,b] (bornes incluses) et nouvel état.
function M.int(state, a, b)
	if b < a then a, b = b, a end
	local f, s = M.next(state)
	return a + math.floor(f * (b - a + 1)), s
end

-- Élément au hasard d'une liste (nil si vide, l'état ne bouge pas).
function M.pick(state, list)
	if #list == 0 then return nil, state end
	local i, s = M.int(state, 1, #list)
	return list[i], s
end

return M
