# Journal de bord

## 2026-10-30 — MVP (phase 1), version 2

**Fait**

- Cœur Lua pur (`core/`) : générateur à graine, catalogue (crise sectorielle seule), cycle de vie,
  garde-fous, conteur simple (fréquence 0.25, recharge 4 trimestres, région = ville la plus proche),
  journal en français, moteur. Écrit par un sous-agent Sonnet d'après `notes/mvp-design.md`.
- Tests N1 (`tests/run.lua`) : 13 cas dont la simulation de 400 trimestres (environ 57 crises par siècle).
- Script de jeu `game_mechanics/chronicles/chronicles.script.lua` : trimestre, cœur, effets, notifications,
  état sauvegardé, commandes de débogage, autotest N2 dans `stdout.txt`.
- Adaptateurs `adapters/world_reader.lua` et `adapters/effects.lua`.
- Type de notification `chronicles_notification` (annonce et reprise).
- Interface : Journal branché sur l'état, pastille du bouton = événements actifs, onglet Débogage,
  bloc d'industrie avec « Forcer une crise ici ». Onglets Économie et Bilan du prototype gardés.
- `tools/deploy.sh` (sous-agent Haiku), `GUIDE_AGENTS.md`.

**Décisions**

- Cœur, adaptateurs et script de jeu en Lua, pas en Teal : le compilateur `tl` n'est pas
  disponible ici, et le jeu accepte `.lua` et `.script.lua`. L'interface reste en Teal.
  (Erreur de cette session : j'avais supposé Lua 5.4 ; le jeu est en 5.2, corrigé en v3.)
- Région = ville la plus proche (texte du journal naturel : « Crise de l'acier à Valmont »).
- La productivité visée est réaffirmée toutes les 10 s de jeu, car `industry_workers.script`
  du jeu la réécrit quand le bonus des travailleurs change.
- Onglet Débogage toujours visible dans le MVP (le paramètre « Mode débogage » viendra quand la
  lecture des paramètres du mod sera confirmée en jeu).
- Notification seulement à l'annonce et à la reprise (pas à la fin), comme le plan.

**Interprétation de la demande** : « garde le AI » compris comme « garde l'interface » (UI du
prototype conservée) ; le conteur, qui joue le rôle de directeur d'IA, est en place en version simple.
À confirmer avec Philippe.

**À vérifier en jeu (étape 0 du plan + nouveautés)**

1. Le jeu découvre-t-il `chronicles.gs.lua` d'un mod et charge-t-il `chronicles.script.lua` ?
   Chercher `[chronicles] état initial créé` dans `stdout.txt`.
2. `ug_require "phil_chronicles::/core/engine.lua"` fonctionne-t-il depuis le script de jeu ?
3. L'adresse `phil_chronicles::/game_mechanics/chronicles/chronicles.gs` est-elle la bonne pour
   `getEntityForGameScript` (sinon le Journal reste sur « paraîtra au prochain trimestre ») ?
4. Les événements de l'interface (`makeScriptingSendEventCmd`, id `PhilChronicles`) arrivent-ils ?
5. La notification s'affiche-t-elle avec le type du mod ?
6. Les 5 inconnues de l'étape 0 (rechargement du script avec la sauvegarde, raccourcis du mode
   Débogage, productivité après sauvegarde, vitesse pour l'autotest).
7. Fichier `.tl` de l'interface : il n'a pas été vérifié par un compilateur Teal.

## 2026-10-30 — premier essai en jeu (v2), correctif v3

**Constaté dans `stdout.txt`** (partie chargée à 19:46)

- Le mod est installé depuis le staging (rev. 2), `preRunFn` tourne.
- Le jeu **découvre** `chronicles.gs.lua` d'un mod : « Creating entity for newly added GameScript
  phil_chronicles::/game_mechanics/chronicles/chronicles.gs ». Points 1 et 3 confirmés pour la découverte.
- L'interface Teal se compile et fonctionne : les clics envoient bien les événements
  (`[chronicles] interface -> nextPhase`, `fastQuarter`, `runSelfTest`). Point 7 confirmé.
- **Échec** : le script de jeu ne se charge pas, « unexpected symbol near '/' » ligne 92 (`q // 4`),
  puis « Expected table at path » à chaque pas. **Le jeu embarque Lua 5.2.2**, pas 5.4 :
  pas de `//`, pas d'opérateurs binaires (`& | ~ << >>`), nombres en double.

**Correctif v3**

- `//` remplacé par `math.floor(a / b)` (moteur et script de jeu).
- `core/rng.lua` réécrit en Park et Miller (multiplicateur 48271, module 2^31 - 1) : produits < 2^46,
  exacts en double. Les tirages changent, les tests de rythme restent dans leurs bandes.
- Nouveaux tests N1 : « Compatibilité Lua 5.2 du jeu » (cherche ces opérateurs dans tout `mod/`)
  et « Générateur exact en flottants ». 27 tests verts.

**Encore à vérifier** : chargement de `chronicles.script.lua` et des modules `ug_require` (points 1-2),
arrivée des événements dans `handleEvent` (point 4), notification (point 5), autotest complet.

**Prochaine étape** : recharger `Testgame.sav` avec la v3 (relancer le jeu si le script n'est pas rechargé),
« Lancer l'autotest », lire `stdout.txt`.
