# API TF3 : créer, fermer, chaînes (recherche du 2026-10-31)

Recherche en lecture seule (sous-agent Sonnet `Explore`) pour la v10. GM = `base/content/game_mechanics.zip`,
ECO = `base/content/economy.zip`. « NON CONFIRMÉ » = à vérifier en jeu.

## Créer une industrie

```lua
-- modèle : GM game_mechanics/company/company.script.tl (prospection), mission/tutorial/tasks/tutorial_init.tl
local proposal = api.engine.util.proposal.makeIndustrySpawnProposal(typeTag, townEntityOuNil)
if proposal ~= nil then
  api.cmd.sendCommand(api.cmd.makeWorldBuildProposalCmd(proposal, nil, false, false),
    function(data, success, resultEntities) --[[ resultEntities[1][1] = nouvelle entité ]] end)
end
```

- `typeTag` = `placementTag` du `.con` (« oil_well », « forest »…). `townEntity` = cellule de Voronoï de cette
  ville ; `nil` = n'importe où. Renvoie `nil` en cas d'échec : réessayer ou changer de type.
- Placement choisi par le moteur selon les `placementParams` de l'économie active (biome, distances, eau
  pour `oil_platform`, `sand_excavator`, `fishing_grounds`). Collisions : NON CONFIRMÉ.
- Appelable depuis `update` ou `handleEvent` d'un script de jeu.
- `resultEntities[1][1]` : entité industrie ou construction ? NON CONFIRMÉ
  (`streetConnectorSystem.getConstructionEntityForSubconstruction` au besoin).
- Nom donné par le moteur ; renommer : `api.cmd.makeEntitySetNameCmd(entity, name)`.
- Notification : type `::/game_mechanics/notifications/types/industry_spawn.script`,
  `params = { entity = EntityAndRevision, resName = … }` ; le mod l'envoie lui-même.
- Le jeu fait aussi apparaître des industries tout seul (`baseConfig.economy.industryDevelopment.spawnIndustries`).
- `dredging_platform` n'a pas de `.con.lua` : non créable.

## Fermer une industrie

- `api.cmd.makeIndustrySetDespawnTimeCmd(industry, horodatage)` : horodatage **absolu** en ms de jeu
  (`GAME_TIME.gameTime + durée`), `0` = annule. Champ `INDUSTRY.closureTimeStamp`.
- La suppression effective est faite par le script `Industries` du jeu (`industries.script.tl`, puis
  `gui/main/industry_util.tl` `removeIndustries`) quand l'horodatage est dépassé.
- **Piège** : toutes les 100 étapes, le script du jeu remet à 0 l'horodatage d'une industrie qui n'est pas
  candidate à la fermeture (utilisée depuis moins de 5 ans, ou construite depuis moins de 5 ans).
  Une industrie neuve créée par le mod verrait donc son ultimatum annulé pendant 5 ans.
- Parades :
  - `api.cmd.makeIndustrySetManualDevelopmentCmd(industry, true)` : le script du jeu l'ignore (ni fermeture,
    ni niveaux) ; le mod gère alors lui-même l'ultimatum **et la suppression** (même séquence que
    `removeIndustries` : `findSegmentsToDelete`, `createProposalRemove`, `makeSegmentsRemoveProposal`) ;
    NON CONFIRMÉ : si le script du jeu supprime encore une industrie `manualDevelopment` arrivée à échéance ;
  - `closureProbability = 0` dans `preRunFn` (comme les missions de campagne) : coupe les fermetures du jeu ;
  - événement `("", "Industries", "setPauseIndustryClosure", true)` : met à 0 tous les horodatages en cours.
- Règle du jeu : candidate si `max(dernier itemsConsumed, dernier itemsLoaded) + 5 ans < maintenant`
  (LOG_BOOK du stockList, sinon `construction.timeBuilt`) ; ignorée si `manualDevelopment`, `PLAYER_OWNED`,
  sans sortie, ou avec dépôts. Compte à rebours de 2 ans (`industries_config.res.lua`).
- Notification : type `::/game_mechanics/notifications/types/industry_close.script` (barre de progression du
  compte à rebours, « fermeture évitée » si annulée). Le mod l'envoie lui-même. Liste des industries en
  fermeture : `api.engine.util.industry.getClosingIndustries()`.

## Chaînes

- À l'exécution : `api.engine.util.stock.getInputsOutputsFromRules(industry.stockList)` → `{ entrées, sorties }`
  (identifiants de cargo ; nom : `api.res.cargoTypeRep.getName(id)`).
- Statistiques par cargo : `getCargoTypeShippedPerYear`, `getCargoTypeDeliveredPerYear`, `getCargoOutputPerYear`,
  `getCargoMaxProductionPerYear` (`api.engine.util.stock`).

| Type | Entrées | Sorties |
|---|---|---|
| farm | (bonus : engrais) | légumes, céréales |
| livestock_farm | céréales | viande, laine |
| cotton_farm | (bonus : engrais) | laine |
| rubber_farm | (bonus : engrais) | caoutchouc |
| forest | (bonus : machines) | bois |
| saw_mill | bois | planches, sciure |
| paper_mill | sciure | papier |
| printing_press | papier + teintures | livres |
| weaving_mill | laine | tissu |
| textile_factory | tissu + teintures | vêtements |
| furniture_factory | planches + verre | meubles |
| fishing_grounds (eau) | (bonus : outils) | poisson |
| food_factory | (poisson ou viande) + tôle | conserves |
| brewery | céréales + verre | boissons |
| coal_mine | (bonus : outils) | charbon |
| iron_ore_mine | (bonus : machines) | minerai de fer |
| steel_mill | minerai de fer + charbon | acier, tôle |
| machine_factory | acier + plastique | machines |
| tool_factory | planches + plastique | outils |
| vehicle_factory | pneus + tôle + machines | véhicules |
| tire_factory | caoutchouc | pneus |
| oil_well | (bonus : machines) | pétrole brut |
| oil_platform (eau) | (bonus : machines) | pétrole brut |
| oil_refinery | pétrole brut | carburant, produits chimiques, engrais |
| chemical_plant | produits chimiques | teintures, plastique |
| quarry | (bonus : outils) | pierre |
| cement_plant | pierre | ciment |
| clay_pit | (bonus : outils) | argile |
| bricks_works | argile | briques |
| sand_pit | (bonus : outils) | sable |
| sand_excavator (eau) | (bonus : machines) | sable |
| glass_works | sable | verre |

## Époque et climat

- **Aucune limite d'années pour les industries** : `availability = {}` dans tous les `.con.lua`.
- Ce qui compte est le **climat** de la carte (économie active : tempéré, sec, tropical, subarctique).
  Exemple : la carte tempérée retire cimenterie, papeterie, imprimerie, caoutchouc et pneus.
- Avant de créer un type : vérifier qu'il existe dans les `placementParams` de l'économie active
  (`api.res.economyRep`) ; comment lire l'économie active de la partie : NON CONFIRMÉ.
- `placementParams[type].requiredIndustryTags` : prérequis (ex. raffinerie après plateforme pétrolière).
- `industryPlacementFallbacks` : `oil_platform` → `oil_well`, `sand_excavator` → `sand_pit` sur terre.
