-- Générateur pseudo-aléatoire déterministe. L'état est un simple entier (32 bits),
-- stocké tel quel dans state.rng : aucune table, aucune fonction dans la sauvegarde.
local M = {}

local MASK = 0xFFFFFFFF

-- Avance l'état (congruentiel linéaire 32 bits).
local function avance(state)
	return (math.floor(state) * 1664525 + 1013904223) & MASK
end

-- Mélange les bits de l'état pour la sortie (les bas bits d'un LCG sont faibles).
local function brasse(s)
	local h = s ~ (s >> 15)
	h = (h * 2246822519) & MASK
	h = h ~ (h >> 13)
	return h
end

-- Flottant dans [0,1) et nouvel état.
function M.next(state)
	local s = avance(state)
	return (brasse(s) >> 8) / 16777216, s
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
