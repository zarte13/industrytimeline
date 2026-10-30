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

**Prochaine étape** : déposer la v2, lancer « Lancer l'autotest » sur `Testgame.sav`, lire `stdout.txt`.
