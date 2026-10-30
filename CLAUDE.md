# Chroniques économiques (mod Transport Fever 3)

Mod `phil_chronicles` : événements économiques (crises, reprises) racontés par un journal.
Plan en 4 phases : doc Claude « Chroniques économiques : plan d'implémentation en 4 phases »
(https://claude.ai/artifact/Cj89ckGcTkhseGg74z1kgB). Architecture et 23 cas de test :
https://claude.ai/artifact/63oDXrhzXPQpcaojUMXdo8.

## À lire avant de travailler

- `GUIDE_AGENTS.md` : quel sous-agent (Opus, Sonnet, Haiku) pour quelle tâche.
- `notes/mvp-design.md` : formats de l'état et de la photo, API du cœur.
- `notes/tf3-api.md` : API du jeu relevée dans les définitions Teal et les scripts de base.
- `notes/environnement.md` : chemins (stdout.txt, staging, sauvegardes) et outils.
- `notes/journal-de-bord.md` : décisions, état d'avancement, ce qui reste à vérifier en jeu.

## Structure

- `mod/phil_chronicles/content/core/` : Lua pur, sans `api` ; testé hors jeu.
- `content/adapters/` : seuls fichiers Lua qui lisent ou modifient le moteur.
- `content/game_mechanics/chronicles/` : script de jeu (Lua) et type de notification.
- `content/gui/chronicles/` : interface (Teal).
- `tests/` : tests hors jeu (N1), `lua tests/run.lua`.
- `tools/deploy.sh` : tests, copie vers le staging du jeu, vérification sha256.

## Règles

- Textes, commentaires et commits en français ; noms de fichiers et de modules en anglais.
- Rien ne part au staging tant que `lua tests/run.lua` n'est pas vert.
- Le cœur reste compatible Lua 5.4 (le jeu), même si les tests tournent en Lua 5.5.
