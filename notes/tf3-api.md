# API de Transport Fever 3 utile au mod

Relevé le 2026-10-30 dans `api/tealdef`, `base/tealdef` et les zips de `base/content`
(lus avec `unzip -p`). « NON CONFIRMÉ » = déduit, à vérifier en jeu.

## Script de jeu

- Deux fichiers : `x.gs.lua` (`data()` renvoie `updateScript`, `handleEventScript`, option
  `postUpdateScript`, chacun `{ fileName = "x.script@update" }`, chemin relatif au `.gs.lua`)
  et `x.script.tl` (ou `.script.lua`) qui renvoie une table `GameScript<T>`.
- Le dossier ne compte pas : le moteur découvre les `.gs.lua` (NON CONFIRMÉ pour un mod).
- `update(userParams, state, dt)` à chaque pas ; `dt == 0` en pause ; `dt` en secondes.
- `handleEvent(userParams, state, src, id, name, param)`. Événements de cycle de vie (id `""`) :
  `initNewGame`, `initNewGameFromMap`, `initMission`, `handleLegacy` (script ajouté à une partie existante).
- `state:get()`, modifier, `state:set(t)`. Pas de hook save/load : l'état est sauvegardé tel quel.
  Données simples seulement ; les entités (entiers) peuvent servir de clés.
- Abonnement par NOM d'événement : `if not state:hasEventSubscriptions() then state:subscribeToEvent("X") end`
  dans `update`.
- Adresse d'un script : `"::/industries/industry_workers.gs"` ; pour un mod, `"<modId>::/chemin/x.gs"` (NON CONFIRMÉ).

## Lire l'état d'un script depuis l'interface

```teal
local e = api.engine.system.gameScriptSystem.getEntityForGameScript("phil_chronicles::/game_mechanics/chronicles/chronicles.gs") -- -1 si absent
local gs = api.engine.getComponent(e, api.type.ComponentType.GAME_SCRIPT) as Engine.Component.GameScript<T>
gs.state          -- copie Lua ; gs.state_native : NativeLuaTable (findPath, asTable)
```

## Envoyer un événement à un script

`api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd(src, id, name, param))` est diffusé à tous les
scripts ; le script doit s'abonner à `name`. `param` = table simple.

## Date

```teal
local gt = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME) as Engine.Component.GameTime
local d = api.engine.util.getCalendarDate(gt.gameTime)   -- d.year, d.month (1-12), d.day
```
`GAME_SPEED.millisPerDay == 0` en pause. `api.util.getDefaultYearDuration()` = durée d'une année en ms de jeu.

## Industries

- `api.engine.getEntitiesWithComponent(api.type.ComponentType.INDUSTRY)` ;
  composant `INDUSTRY` : `stockList`, `construction`, `level`, `closureTimeStamp`.
- Type : `CONSTRUCTION` de `industry.construction`, `con.fileName` ex. `industries/coal_mine/coal_mine.con`
  (préfixe `::/` possible : comparer par suffixe).
- Position : centre de `BOUNDING_VOLUME.bbox` (`(bbox.min + bbox.max) * 0.5`).
- Nom : `api.engine.util.getEntityName(e)`.
- Propriétaire : composant `PLAYER_OWNED { player }` sur l'industrie ou sur sa construction
  (`streetConnectorSystem.getConstructionEntityForSubconstruction`) ; vérifier les deux.
- `StockList.Modifiers` n'a qu'un champ : `productivity` (neutre 1.0).
  `api.cmd.makeStockListSetModifiersCmd(entity, modifiers)`.
- **Conflit** : `industry_workers.script` du jeu considère `productivity > 1.0` comme « bonus des
  travailleurs » et réécrit la valeur (bonus ou 1.0) quand son avis change.

## Villes

`api.engine.getEntitiesWithComponent(api.type.ComponentType.TOWN)` ; nom par `getEntityName` ;
position par `BOUNDING_VOLUME`.

## Notifications

Pas d'API directe : on envoie l'événement `("", "Notifications", "add", notification)` avec
```teal
{ type = "<chemin du .script sans extension>", params = {...}, autoDismissDuration = ms }
```
Le type est une paire `x.res.lua` (`type = "notification"`, `data = { guiType = "Info"|"Caution"|"Problem"|"Opportunity"|"Achievement", label, initiallyIgnoredType = false }`)
et `x.script.tl` (`NotificationType<T>` avec `useDataState(params) : NotificationGuiData { title, description, icon, ... }`).
Le jeu trouve le `.res` en remplaçant `.script` par `.res`. Icônes : `::/game_mechanics/notifications/gui/icons/*.tga`
(ex. `building_industry_plus.tga`, `building_industry_x.tga`). Modèle : `base/content/landmarks/landmarks_notification_nonpersistent.*`.
Délai par défaut : `notification_util.defaultAutoDismissDurationMs` (`::/game_mechanics/notifications/notification_util.tl`).

## Paramètres du mod

`mod.json` → `params` : `{ key, name, tooltip, uiType = "Slider"|"ComboBox"|"CheckBox", values, numbers, defaultIndex }`.
Valeur stockée = index. Lecture à l'exécution : `api.engine.config.getModParams()["<modId>"]` (NON CONFIRMÉ pour la clé).

## Journal

`log.message`, `log.warning`, `log.error(msg, détail)`, `debugPrint(...)`. Fichier :
`...\userdata\195775244\3493540\local\crash_dump\stdout.txt` (voir `environnement.md`).
