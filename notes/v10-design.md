# v10 « ressentie » — conception (phase 1 étendue)

Planifiée avec Philippe le 2026-10-31, après sa partie témoin de 19 ans en v9 : la mécanique tourne
(9 crises complètes, aucune erreur), mais **on ne ressent rien**.

## Pourquoi rien ne se ressentait (v9)

1. Une seule industrie par crise (région = ville la plus proche, rarement deux industries du même type).
2. Le conteur ignore le réseau du joueur : la plupart des crises touchent des industries non desservies.
3. −40 % appliqué sur la productivité bonifiée par les travailleurs (« 1,96 → 1,17 » : toujours au-dessus
   de la normale) ; et une ligne goulot ne voit pas la baisse.
4. Aucune conséquence au-delà de la production : ni argent, ni villes, ni chaîne, ni décision.

## Décisions de Philippe

| Sujet | Décision |
|---|---|
| Place dans le plan | **Phase 1 étendue** : le MVP n'est fini que quand il se ressent |
| Crises | touchent **plusieurs industries à la fois** (toute une famille sur une zone) |
| Grèves | une famille (« toutes les mines ») sur **une grande zone** de plusieurs villes |
| Booms : cible | **près du réseau** du joueur : dans une zone que ses lignes touchent déjà, sur des industries qu'il **ne dessert pas encore** (il faut prolonger une ligne pour en profiter). Corrigé le 2026-10-31 : « sur des lignes existantes » n'avait pas de sens, un boom sur une industrie déjà desservie ne pousse à rien construire |
| Booms : durée | **selon l'intensité** : court et violent ou long et modéré, tiré au hasard |
| Booms : nouvelles industries | **la chaîne** (boom pétrolier : puits, puis raffinerie qui en a besoin) ; apparaissent **vite** |
| Booms : incitations | **villes qui grandissent**, **contrat de boom** (prime + prolongation), **prime en argent** |
| « Desservie » | **cargo transporté** (production enlevée ou intrants livrés) dans les 4 derniers trimestres |
| Nouvelles industries non desservies | **2 ans de grâce, puis ultimatum** visible d'1 an, puis fermeture |
| Rythme | **un grand événement à la fois** : au plus un boom et une crise ou grève en même temps |
| Vitesse du jeu | tout doit marcher **quelle que soit la vitesse** (simulation et calendrier) |

## Familles d'industries

| Famille | Types TF3 |
|---|---|
| Mines et carrières | coal_mine, iron_ore_mine, quarry, clay_pit, sand_pit, sand_excavator |
| Agriculture et pêche | farm, livestock_farm, cotton_farm, rubber_farm, fishing_grounds |
| Bois et papier | forest, saw_mill, paper_mill, furniture_factory, printing_press |
| Pétrole et chimie | oil_well, oil_platform, oil_refinery, chemical_plant, dredging_platform |
| Métallurgie et mécanique | steel_mill, tool_factory, machine_factory, vehicle_factory |
| Matériaux | bricks_works, cement_plant, glass_works |
| Biens de consommation | food_factory, brewery, textile_factory, weaving_mill, tire_factory |

À valider contre les vraies chaînes de cargo du jeu (entrées et sorties de chaque `.con`).

## Événements

| Événement | Cible | Effet | Durée |
|---|---|---|---|
| **Grève** | une famille, une grande zone | 10 à 20 % de la productivité **de base** | 1 à 2 trimestres, rumeur 1 trimestre avant |
| **Crise** | une famille, une grande zone | −50 à −70 % de la base, reprise progressive | 1 à 3 ans |
| **Boom court** | une industrie non desservie près du réseau + sa chaîne autour | +100 %, nouvelles industries rapides | 2 à 3 ans |
| **Boom long** | idem | +40 %, nouvelles industries plus lentes | 6 à 10 ans |

- **Zones** : la carte découpée en 4 à 6 grandes zones (groupes de villes voisines), au lieu de la ville la plus proche.
- **Base** : l'effet se calcule sur la productivité normale (1,0), pas sur le bonus des travailleurs ;
  à préciser : on neutralise le bonus pendant l'événement, ou on multiplie seulement la part de base.
- **Garde-fous** gardés : industries du joueur jamais touchées par les crises ou grèves ; reprise garantie ;
  un seul grand événement de chaque sorte à la fois.

## Cycle d'un boom

1. Le conteur choisit une industrie **près du réseau** (zone touchée par les lignes du joueur) qu'il **ne dessert
   pas encore** (aucun cargo transporté sur les 4 derniers trimestres) ; boom court ou long au hasard.
   « Près du réseau » (tranché le 2026-10-31) : **la même grande zone** (plusieurs villes) qu'au moins une gare
   desservie par une ligne du joueur ; parfois une vraie nouvelle ligne à construire.
   **Rumeur 2 trimestres avant** (« On parle d'un gisement près d'Harbin ») pour laisser préparer la ligne,
   puis notification au début : « Boom du pétrole près d'Harbin : la plateforme cherche un transporteur ».
2. **Nouvelles industries de la chaîne** autour : dès les premiers trimestres pour un boom court, plus étalées
   pour un boom long (cargos disponibles à l'époque seulement).
3. **Contrat de boom** : livrer X % de la production de l'industrie en boom pendant N trimestres → prime,
   et le boom se prolonge.
4. **Prime en argent** chaque trimestre dès que (et tant que) le joueur dessert l'industrie en boom.
   Pas desservie (tranché le 2026-10-31) : le boom dure **sa durée pleine** quand même ; ne pas le desservir fait
   seulement perdre la prime, le contrat et les nouvelles industries (qui finissent par fermer).
5. **Villes proches** : croissance et besoins en hausse pendant le boom.
6. Chaque nouvelle industrie : 2 ans de grâce ; non desservie à la fin du délai → ultimatum de fermeture
   d'1 an (compte à rebours du jeu) ; desservie entre-temps → ultimatum levé.
7. Fin du boom : retour progressif à la base ; les nouvelles industries desservies restent.

## Vitesse du jeu

- **Vitesse de simulation** (×1 à ×4, pause) : sans effet, tout est compté en trimestres du calendrier.
- **Vitesse du calendrier** : curseur « Vitesse du calendrier » de la fenêtre Météo et heure, multiplicateur
  (capture de Philippe : 2,00x ; bornes et valeur « figée » à relever). Un trimestre dure plus ou moins de temps de jeu, donc
  produit et transporte plus ou moins de cargo. Règles :
  - les objectifs de contrat sont des **pourcentages de la production** sur la période, jamais des tonnes fixes ;
  - les primes sont **par trimestre**, à l'échelle du revenu (ou proportionnelles au cargo transporté) ;
  - « desservie » = cargo transporté **> 0** sur les 4 derniers trimestres, indépendant de la durée ;
  - les durées (grâce, ultimatum, boom) sont en trimestres du calendrier ; l'ultimatum du jeu
    (`makeIndustrySetDespawnTimeCmd`, en temps de jeu) se calcule avec la durée réelle d'un trimestre.
- **Calendrier figé** (risque déjà listé dans le plan) : trimestres comptés en temps de jeu écoulé
  (durée d'un trimestre à la vitesse par défaut), ou événements désactivés.
- Tests N1 : mêmes scénarios avec des trimestres de durées différentes.

## Réponses de l'API (recherche du 2026-10-31)

Détail dans `notes/tf3-api-industries.md` et `notes/tf3-api-economie.md`.

| Besoin | Solution retenue |
|---|---|
| Créer une industrie de la chaîne | `makeIndustrySpawnProposal(type, villeOuNil)` puis `makeWorldBuildProposalCmd` ; le moteur place (terre ou eau) ; `nil` = échec, réessayer |
| Types possibles | ceux du **climat** de la carte (pas d'époque pour les industries) ; respecter `requiredIndustryTags` |
| Ultimatum puis fermeture | `makeIndustrySetManualDevelopmentCmd(ind, true)` sur nos industries (sinon le jeu annule l'ultimatum pendant 5 ans), puis `makeIndustrySetDespawnTimeCmd(ind, maintenant + 1 an)` ; suppression par le mod si le jeu ne la fait pas (à vérifier) ; notification `industry_close` du jeu envoyée par le mod |
| Desservie | différence par trimestre des compteurs `itemsLoaded` (enlevé) et `itemsUnloaded` (livré) du `LOG_BOOK` |
| Lignes du joueur près d'une industrie | arrêts des lignes → gares → `getStationCatchables` |
| Prime | `makeJournalBookAssetCmd` type `SUBSIDY` (ligne « Subventions » des finances) |
| Villes qui grandissent | événement du jeu `("Towns", "addExperiencePercentage", { townEntity, amount, source = "subvention" })` |
| Durée d'un trimestre | `api.util.getYearDuration(millisPerDay) / 4` ; curseur : 0 ; 0,25 ; 0,5 ; 1 ; 2 ; 4 |

### Changement important : le cadencement

`getCalendarDate` recalcule toutes les dates **à la vitesse actuelle** : changer la vitesse du calendrier
fait sauter la date courante, en avant ou en arrière. La v9 cadence ses trimestres dessus, ce qui pose trois problèmes :
- un saut en avant fait rattraper des trimestres d'un coup ;
- un saut en arrière bloque le mod jusqu'à ce que la date repasse, avec en prime une lecture de la carte
  à chaque pas, coûteuse ;
- à 0x (calendrier figé), plus rien n'avance.

v10 : le mod **compte ses propres trimestres** en accumulant le temps de jeu (`dt`) rapporté à la durée
d'un trimestre à la vitesse courante (`getYearDuration(millisPerDay) / 4`). La date affichée (année, T1-T4)
reste celle du calendrier, mais seulement pour les textes.

Calendrier figé (0x) : choix ouvert (voir la fin du document).

## Inconnues techniques (levées le 2026-10-31, voir ci-dessus ; liste d'origine)

1. Créer une industrie par script : proposition de construction (`SimpleProposal`, `.con` du type) ;
   placement valide (collisions, terrain, eau pour les plateformes). Voir comment `industries.script.tl` du
   jeu fait apparaître ses industries.
2. Fermer : `makeIndustrySetDespawnTimeCmd(entity, temps)` ; la notification de fermeture du jeu s'affiche-t-elle ?
3. Savoir si une industrie est desservie : cargo enlevé ou livré par les lignes du joueur (LOG_BOOK,
   stocks, gares à portée).
4. Chaînes : entrées et sorties de chaque type d'industrie (règles du `STOCK_LIST`, `.con`).
5. Argent : commande pour verser une prime au joueur.
6. Villes : `makeTownSetDevelopmentActiveCmd`, `makeTownUpdateCargoNeedsCmd` (déjà au plan, phase 3).
7. Durée réelle d'un trimestre : `millisPerDay` selon le curseur « Vitesse du calendrier » (bornes, valeur
   minimale, calendrier figé ?), et lecture de ce réglage par script.
8. Pour plus tard (saisons, phase 3) : la fenêtre « Météo et heure » a un cycle météo « Dynamique » ;
   voir si un script peut lire ou régler la météo.

## Restent à vérifier en jeu (étape 0 de la v10)

1. `makeIndustrySpawnProposal` : l'industrie apparaît, entité renvoyée (industrie ou construction), collisions.
2. Une industrie `manualDevelopment` avec horodatage dépassé est-elle supprimée par le jeu, ou faut-il la supprimer ?
3. Cadence des compteurs `itemsLoaded` / `itemsUnloaded` (s'incrémentent-ils à chaque chargement ?).
4. La notification `industry_close` envoyée par le mod affiche-t-elle le compte à rebours ?
5. `addExperiencePercentage` fait-il visiblement grandir la ville ?

## Choix ouverts

- ~~Calendrier figé (0x)~~ **Tranché le 2026-10-31 par Philippe : les événements s'arrêtent.** À 0x
  (`millisPerDay == 0`), le mod n'accumule plus de temps : aucun trimestre ne passe, aucune phase n'avance,
  aucune industrie n'apparaît ni ne ferme. Les productivités en cours restent appliquées (réaffirmation
  maintenue). La ligne du conteur affiche « Calendrier figé : événements en pause ». Tout reprend là où
  c'était quand le calendrier repart.

## Feedback (gardé de la v9)

Chaque nouvelle mécanique écrit dans « Activité du moteur » : zone et industries touchées par une grève,
industries créées, état « desservie », ultimatums, primes versées, avancement du contrat.
