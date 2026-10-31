# API TF3 : desserte, argent, villes, calendrier, météo (recherche du 2026-10-31)

Recherche en lecture seule (sous-agent Sonnet `Explore`) pour la v10. Sources : définitions Teal et zips
de `base/content` (`game_mechanics.zip`, `gui.zip`, `mission.zip`). « NON CONFIRMÉ » = à vérifier en jeu.

## Une industrie est-elle desservie ?

- **Méthode retenue** : compteurs du `LOG_BOOK` du stockList de l'industrie, comme le fait
  `game_mechanics/industries/industries.script.tl` :
  ```lua
  local logBook = api.engine.getComponent(industry.stockList, api.type.ComponentType.LOG_BOOK)
  local log = logBook.name2log_native:find("itemsLoaded")       -- nil si jamais rien chargé
  local n = log.values_native:size(); local last = log.values_native:at(n)   -- indices à partir de 1
  ```
  - `itemsLoaded` : cargo **enlevé** par un véhicule ; `itemsUnloaded` : cargo **livré** à l'industrie.
  - Valeurs cumulées (NON CONFIRMÉ : cadence d'échantillonnage) : le mod garde un instantané par industrie
    à chaque trimestre et fait la différence. Indépendant de la vitesse du calendrier.
  - Aussi : `itemsProduced`, `itemsConsumed`, `itemsDestroyed`.
- Statistiques natives sur un an glissant (`api.engine.util.stock`) : `getCargoShippedPerYear`,
  `getCargoDeliveredPerYear`, `getCargoOutputPerYear`, `getProductionRating`… Test du jeu lui-même :
  `rating = getProductionRating(sl) * min(1, shipped / output)`.
- Événement par cargo livré : `("SimCargoSystem", "OnToArriveAtDestination")` (modèle
  `game_mechanics/arrival_tracker/arrivaltracker.script.tl`).
- Lignes qui desservent une industrie : `lineSystem.getLinesForPlayer(player)` → arrêts → `STATION_GROUP.stations`
  → `catchmentAreaSystem.getStationCatchables(station, true)` contient le stockList de l'industrie.

## Verser une prime

```lua
local entry = api.type.JournalEntry.new()
entry.amount = montant            -- unités monétaires entières ; négatif = débit
entry.time = -1                   -- maintenant
entry.category.type = api.type.JournalEntry.Type.SUBSIDY   -- ligne « Subventions » du tableau des finances
api.cmd.sendCommand(api.cmd.makeJournalBookAssetCmd(api.engine.util.getPlayer(), entry, api.type.Vec3f.new(0, 0, 0)))
```
Modèles : récompense de mission (`mission/mission_sim.script.tl`), subventions (`subvention_util.tl`).
Ne jamais appeler `makeJournalClearAllCmd()` (efface tout le journal et les compteurs).

## Faire grandir une ville

- **Par le mécanisme du jeu** (le plus simple) : expérience de la ville, avec montée de niveau,
  notification et nouveaux besoins automatiques :
  ```lua
  api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd("", "Towns", "addExperiencePercentage",
    { townEntity = ville, amount = 0.25, source = "subvention" }))   -- 25 % de l'écart jusqu'au niveau suivant
  ```
  Ignoré si la croissance de la ville est désactivée (`developmentActive == false`).
- Leviers directs : `makeTownUpdateSizeCmd(ville, sizeFactors, false)`, `makeTownDevelopAtCmd(pos, rues, bâtiments)`,
  `makeTownUpdateCargoNeedsCmd`, `makeTownSetDevelopmentActiveCmd`.

## Vitesse du calendrier

- Composant `GAME_SPEED` du monde : `speedup` (0 = simulation en pause) et `millisPerDay` (**0 = calendrier figé**).
- Curseur « Vitesse du calendrier » : facteurs **0 ; 0,25 ; 0,5 ; 1 ; 2 ; 4**, avec
  `facteur = getDefaultDayDuration() / millisPerDay` (jour par défaut ≈ 2000 ms de jeu, NON CONFIRMÉ : appeler l'API).
- Durées en ms de jeu : `api.util.getYearDuration(millisPerDay)`, `getMonthDuration(…)`,
  `getDefault{Day,Month,Year}Duration()`. Un trimestre = année / 4.
- **Piège** : `getCalendarDate(gameTime)` calcule la date « à la vitesse actuelle » : changer la vitesse décale
  rétroactivement toutes les dates, la date courante peut sauter (en avant ou en arrière). Le jeu ne s'en
  sert que pour afficher. **Ne pas cadencer le mod sur `getCalendarDate`** : accumuler soi-même le temps de
  jeu (`dt`) rapporté à la durée d'un trimestre à la vitesse courante.
- Réglage par script : `makeGameSetCalendarSpeedCmd(millisPerDay)`, `makeGameSetDateCmd(date)`.

## Météo (pour les saisons, plus tard)

- État du script de jeu `::/game_mechanics/game_time/game_time.gs` : `weatherMode` (« Constant » | « Dynamic »),
  `currentWeatherState` (1 ensoleillé, 2 nuageux, 3 pluvieux), `timeOfDayMode`…
- Couverture nuageuse réelle : `WORLD.cloudCoverage` (0 à 1) ; réglage : `makeGameSetCloudCoverageCmd`,
  événements `("CloudCoverage", "SetMode" | "SkipPhase" | "OnManualCloudCoverageChanged")`.
  Effet visuel depuis un script de jeu : NON CONFIRMÉ.
