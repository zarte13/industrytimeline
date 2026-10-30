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

## 2026-10-30 — essai v3, correctif v4

**Constaté** : la syntaxe passe, mais « function data() not defined » au chargement de
`chronicles.script@update` (pile : `base/content/base.zip/base/init.lua`).

**Règle du jeu** : un fichier `.lua` chargé comme **ressource** (script de jeu `.script.lua`, type de
notification, `.gs.lua`, `.res.lua`) doit définir une fonction globale `data()` qui renvoie la table.
Un module chargé par `ug_require`/`require` (`core/`, `adapters/`) peut finir par `return`, comme `react.lua`.

**Correctif v4** : `chronicles.script.lua` et `chronicles_notification.script.lua` définissent `data()`.
Le simulateur (`tests/game_api_mock.lua`, `loadResource`) charge les ressources comme le jeu et échoue
sans `data()`, vérifié : l'ancienne forme fait 10 échecs. 27 tests verts.

## 2026-10-30 — essai v4 : le script de jeu tourne

**Confirmé en jeu** (partie chargée à 19:57) :

- Le script de jeu se charge et crée son état (« état initial créé, graine 102401 »). Points 1 et 3 confirmés.
- Les modules `ug_require "phil_chronicles::/core/…lua"` se chargent depuis le script de jeu (point 2) :
  le conteur a forcé une crise et le journal a écrit sa manchette.
- Les événements envoyés par l'interface arrivent dans `handleEvent` (point 4) : « AUTOTEST début ».
- L'autotest a choisi « Nogent-sur-Seine Camp de bûcherons » (productivité 1), forcé la crise et
  l'a passée à l'annonce (« Crise de la forêt · Nogent-sur-Seine · l'annonce »).
- `Testgame.sav` n'a aucune industrie du joueur : le cas « Industries du joueur intactes » est SAUTÉ.

**Pas encore vu** : la partie a été quittée 1 s après l'annonce, avant les relectures de productivité.
Restent : productivité appliquée, cycle complet, retour exact, notification affichée (point 5),
ligne « AUTOTEST fin ».

## 2026-10-30 — essai v4 bis, correctif v5 (autotest plus rapide)

**Confirmé en jeu** :

- **TEST Productivité appliquée OK** : la commande `makeStockListSetModifiersCmd` du mod modifie bien
  la productivité réelle (60 % relu sur le camp de bûcherons).
- La crise passe par le creux et la reprise jusqu'à « terminée » (phases avancées par l'autotest).
- Aucune erreur du mod dans `stdout.txt`.

**Pas encore vu** : la partie a été quittée 5 s après la fin de la crise, avant la relecture du
« Retour exact à la normale » et la ligne « AUTOTEST fin ».

**Mesure** : en jeu, le script de jeu reçoit un pas toutes les 2 à 4 s environ (13 s pour 4 pas entre
l'annonce et la première relecture). Les attentes fixes en nombre de pas rendaient l'autotest long.

**Correctif v5** :

- L'autotest relit la productivité à chaque pas et passe à la suite dès qu'elle est bonne
  (au plus 20 pas). Toutes les phases restantes sont avancées dans le même pas.
- Une notification « Autotest terminé : N OK, M ÉCHEC » s'affiche à la fin : elle dit quand quitter
  et vérifie au passage l'affichage du type de notification du mod (point 5).
- Tests N1 : notification de fin, et « autotest rapide » (au plus 10 pas). 28 tests verts.

## 2026-10-30 — essai v5 : autotest vert en jeu

`stdout.txt` (partie chargée à 20:01, `Testgame.sav`), en 5 s, sans aucune erreur du mod :

```
TEST Industries du joueur intactes SAUTÉ (aucune industrie du joueur)
autotest sur Nogent-sur-Seine Camp de bûcherons, productivité 1
TEST Productivité appliquée OK
TEST Cycle complet d'une crise OK
TEST Retour exact à la normale OK
TEST empreinte de l'état 41be51c1
AUTOTEST fin : 3 OK, 0 ÉCHEC
```

**Cas N2 de la phase 1 : où on en est**

| Cas N2 | Statut |
|---|---|
| Cycle complet d'une crise | OK en jeu (v5) |
| Productivité appliquée | OK en jeu (v5) |
| Retour exact à la normale | OK en jeu (v5) |
| Industries du joueur intactes | sauté : `Testgame.sav` n'a pas d'industrie du joueur ; OK hors jeu |
| Autres modificateurs gardés | `Modifiers` n'a que `productivity` en TF3 : sans objet, la réaffirmation couvre le script des travailleurs |
| Sauvegarder en pleine crise | à faire : forcer une crise, sauvegarder, recharger, « Écrire l'état » |
| Retirer le mod proprement | à faire : « Tout rétablir », sauvegarder, désactiver le mod |
| Industrie disparue en cours de crise | à faire en jeu (OK hors jeu) |
| Fermeture décidée par le jeu | à faire |
| Coût d'un trimestre | à faire (pas de mesure du temps dans le script pour l'instant) |
| Notification affichée | à confirmer par Philippe (la fin de l'autotest en envoie une) |

**Critère de fin de la phase 1** (plan) : les 17 cas passent et une partie témoin de 10 ans montre au moins
deux crises de la rumeur à la reprise, sans erreur dans `stdout.txt`.

**Prochaine étape** : les cas N2 manuels ci-dessus, puis la partie témoin de 10 ans.
