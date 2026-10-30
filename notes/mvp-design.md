# MVP (phase 1) — conception

Source : doc « Chroniques économiques : plan d'implémentation en 4 phases » (phase 1) et
« Moteur d'événements : architecture et tests ». Ce fichier fixe les contrats entre les couches.

## Objectif

Une crise sectorielle se déroule seule dans une vraie partie, de la rumeur à la reprise,
et survit à la sauvegarde. Notifications à l'annonce et à la reprise. Onglet Journal branché
sur l'état réel. Pas de fermetures : la crise ne touche que la productivité.
On garde toute l'interface du prototype v8 (bouton, 3 onglets, bloc d'industrie) et on ajoute
l'onglet Débogage.

## Choix technique : cœur en Lua pur

Le compilateur Teal n'est pas installé sur la machine (téléchargement refusé). Le jeu charge
des modules `.lua` avec `ug_require` (comme `::/gui/main/react.lua`) et `ug_require` renvoie
`any`. Donc :

- `content/core/*.lua` : Lua 5.2 pur (version du jeu : pas de `//` ni d'opérateurs binaires), aucun appel à `api`, `log`, `math.random`, `os`, `io`.
  Chaque module fait `return M`. Dépendances entre modules : un paramètre `deps` n'est pas
  nécessaire, chaque module est autonome sauf `engine.lua`, qui reçoit ses modules par
  `engine.new(modules)` (le jeu les charge avec `ug_require`, les tests avec `dofile`).
- `content/game_mechanics/chronicles/*.script.tl` et `gui/` : Teal, comme le prototype.
  Les modules du cœur y sont typés par des `local record` déclarés dans le fichier Teal.
- Tests hors jeu (N1) : `tests/run.lua`, lancés avec `lua tests/run.lua` depuis la racine.

## Photo de la partie (world), produite par adapters/world_reader

```lua
world = {
  year = 1931, month = 4, day = 12,          -- date du calendrier du jeu
  industries = {                             -- tableau
    { id = 1234, type = "steel_mill", name = "Aciérie de Valmont",
      x = 1200.0, y = -340.0, playerOwned = false, productivity = 1.0 },
  },
  towns = { { id = 77, name = "Valmont", x = 1000.0, y = -300.0 } },
}
```

`type` = nom de fichier de la construction sans chemin ni extension (ex. `steel_mill`).

## État sauvegardé (state) — données simples seulement

```lua
state = {
  version = 1,
  seed = 12345,           -- graine initiale
  rng = 12345,            -- état courant du générateur (entier)
  lastQuarter = nil,      -- index du dernier trimestre traité (year*4 + q, q = 0..3)
  nextEventId = 1,
  events = { ... },       -- tableau d'événements (voir plus bas), en cours et finis (les 20 derniers finis gardés)
  baseProductivity = { ["1234"] = 1.0 },  -- clé = tostring(entity), valeur d'avant le mod
  debug = { fastQuarter = false, verbose = false },
}
```

Événement :

```lua
{ id = 1, kind = "sector_crisis", sector = "steel_mill",
  regionId = 77, regionName = "Valmont",        -- région = ville la plus proche
  industries = { 1234, 1240 },                   -- touchées (jamais celles du joueur)
  phase = "rumor",          -- rumor | announce | trough | recovery | done
  quartersInPhase = 0,      -- trimestres déjà passés dans la phase
  troughLength = 3,         -- tiré au lancement (2 à 4)
  multiplier = 1.0,         -- multiplicateur courant de productivité
  startQuarter = 7724, endQuarter = nil }
```

## Déroulement d'une crise (catalogue : `sector_crisis` seul)

| Phase | Durée | Multiplicateur |
|---|---|---|
| rumor | 1 trimestre | 1.0 (aucun effet) |
| announce | 1 trimestre | 0.6 |
| trough | `troughLength` (2 à 4) | 0.6 |
| recovery | jusqu'au retour à 1.0 : +0.1 par trimestre (0.7, 0.8, 0.9, 1.0) | |
| done | — | 1.0, productivité rétablie à la valeur de base exacte |

Durée maximale = 1 + 1 + 4 + 4 = 10 trimestres (`catalog.maxDuration`).
La productivité visée = `baseProductivity[id] * multiplier` ; en `done`, exactement `baseProductivity[id]`,
puis l'entrée de `baseProductivity` est retirée si plus aucun événement ne touche l'industrie.

## Conteur (storyteller, version simple)

- Un tirage par trimestre : probabilité `params.frequency` (défaut 0.25) de lancer une crise,
  seulement si aucune crise n'a été lancée depuis `params.cooldown` trimestres (défaut 4).
- Choix : une région (ville) au hasard parmi celles qui ont au moins une industrie non-joueur
  sans événement en cours ; puis un secteur (type) présent dans cette région ; touche toutes les
  industries de ce type de cette région qui ne sont ni au joueur ni déjà touchées, au plus 3.
- Région d'une industrie = ville la plus proche (distance euclidienne x,y).

## Garde-fous

- Jamais d'industrie du joueur (`playerOwned = true`).
- Au plus 2 crises actives (phase ≠ done) par région.
- Une industrie n'est jamais dans deux événements actifs.
- Reprise garantie : toute crise finit en au plus `maxDuration` trimestres.

## Trimestres

`quarterIndex(year, month) = year * 4 + (month - 1) // 3`.
`engine.tick` traite chaque trimestre une seule fois ; si plusieurs trimestres ont passé
(saut de date), il les traite un par un, au plus 8 ; le premier appel (lastQuarter = nil)
enregistre le trimestre courant sans rien lancer.

## API du cœur

```lua
local engine = Engine.new({ rng=..., catalog=..., lifecycle=..., guardrails=..., storyteller=..., regions=..., journal=... })
state = engine.newState(seed)                       -- état initial
result = engine.tick(state, world, params)           -- params : { frequency, cooldown, forceEvent? }
-- result = { state = state (modifié en place), targets = { [id] = productivité visée },
--            notifications = { { kind="announce"|"recovery"|"done", eventId=1, text="..." } },
--            log = { "ligne", ... } }
engine.forceEvent(state, world, opts)   -- opts : { industryId? , sector?, regionId? } ; lance une crise
                                       --   immédiatement en phase rumor (guardrails appliqués), renvoie l'événement ou nil, raison
engine.nextPhase(state, world)         -- fait avancer tous les événements actifs d'une phase ; renvoie result comme tick
engine.resetAll(state)                 -- renvoie targets = baseProductivity de toutes les industries touchées, vide events et baseProductivity
engine.targets(state)                  -- productivités visées de toutes les industries touchées
journal.describe(state, world)         -- tableau de lignes de texte FR pour l'onglet Journal
journal.headline(event)                -- « Crise de l'acier · Valmont · le creux · trimestre 2 sur 3 »
```

Les industries disparues de `world` sont retirées de l'événement au trimestre suivant
(sans erreur) ; un événement sans industrie continue son cycle (le texte reste).
Une nouvelle industrie est prise en compte par le conteur au trimestre suivant.

## Adaptateurs (dans le jeu)

- `adapters/world_reader` : construit `world` depuis l'API.
- `adapters/effects` : pour chaque cible, relit la productivité réelle ; si l'écart dépasse 0.005,
  envoie `makeStockListSetModifiersCmd` avec les autres modificateurs recopiés. Réappliqué
  périodiquement, car `industry_workers.script` du jeu remet la productivité à 1.0 ou au bonus
  des travailleurs quand leur nombre change.
