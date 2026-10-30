# Feedback pour la partie témoin réelle (v9) — conception

Demande de Philippe (2026-10-30) : pour jouer une vraie partie de 10 ans, voir ce qui se passe en
arrière-plan, une chronologie des crises dans le Journal, et une notification à chaque phase.

## Cœur (`core/`, Lua 5.2 pur)

### Historique des phases (lifecycle)

- `ev.history` : tableau `{ { phase = "rumor", quarter = 7724 }, ... }`, une entrée à la création
  (rumor) puis une à chaque entrée de phase (`entre`), y compris `skip` et `finish`.
- `ev.minMultiplier` : plus petit multiplicateur atteint (1.0 à la création).
- Les anciens événements sans `history` (sauvegardes v8) restent valides : tout lecteur tolère `nil`.

### Décisions du conteur dans `result.log`

À chaque trimestre traité, `engine.tick` ajoute dans `result.log` une ligne qui dit ce qu'a décidé le conteur :

- `Conteur : attente, prochain tirage dans N trimestre(s)` (recharge pas finie) ;
- `Conteur : tirage 0,42 pour un seuil de 0,25, pas de crise` (deux décimales, virgule française) ;
- `Conteur : tirage 0,12 pour un seuil de 0,25, crise lancée : <manchette>` ;
- `Conteur : tirage 0,12 réussi mais aucune crise possible (<raison>)` (raison de `storyteller.select`).

Pour cela `storyteller.roll` renvoie aussi un 3e résultat `info` : `{ wait = n }` (attente) ou
`{ value = f, threshold = p }` (tirage fait). Signature : `go, rngState, info = roll(...)`.

### Notifications à chaque phase

`result.notifications` reçoit une entrée pour **chaque** phase : `rumor` (au lancement par le conteur),
`announce`, `trough`, `recovery`, `done`. Le script de jeu filtre selon le réglage du joueur.
`journal.notification` a un modèle pour chacune (ajouter `trough` : « Creux de la crise {of} {ou} :
production à {pct} % »).

### Statut du conteur

`engine.storytellerStatus(state, quarter, params)` → `{ wait = n, chance = p }` : trimestres avant le
prochain tirage possible (0 = tirage au prochain trimestre) et probabilité du tirage.

### Chronologie (journal)

`journal.chronicle(state, world)` → lignes, la plus récente d'abord :

1. une ligne de compte : `N crise(s) depuis le début de la partie, dont M en cours` (N = `state.nextEventId - 1`) ;
2. par événement (actifs puis finis, plus récent d'abord), deux lignes :
   - `1931 T2 → 1933 T3 · Crise de l'acier · Valmont · 9 trimestres · 2 industries · plancher 60 %`
     (`→ en cours` si actif ; durée = fin − début, ou actuelle si actif) ;
   - `   rumeur 1931 T2 · annonce 1931 T3 · creux 1931 T4 · reprise 1932 T3 · fin 1933 T3`
     (depuis `ev.history` ; si absent, seulement la première ligne).
- Format d'un trimestre `q` : `math.floor(q / 4) .. " T" .. (q % 4 + 1)`.
- `catalog.keepFinished` passe de 20 à 40 (assez pour 10 ans de chronologie).

## Script de jeu (Opus)

- `s.activity` : les 40 dernières lignes d'activité, datées (`1931 T2 · ...`) : `result.log` de chaque
  trimestre, commandes de débogage, et **réaffirmations** (« le jeu a remis Aciérie X à 1,82 : remise à 0,60 »),
  qui montrent le conflit avec le bonus des travailleurs.
- `s.debug.allNotifications` (vrai par défaut) : notification à chaque phase ; faux = annonce et reprise seulement.
- `s.storyteller` : texte « Prochain tirage dans N trimestre(s) · chance 25 % » pour l'onglet Débogage.
- `s.chronicle` : lignes de `journal.chronicle`, rafraîchies avec le Journal.

## Interface (Opus)

- Journal : section « Chronologie » sous le journal courant.
- Débogage : ligne du conteur, interrupteur des notifications, « Activité du moteur » (plus récent en haut).
