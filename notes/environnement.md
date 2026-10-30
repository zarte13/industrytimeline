# Environnement de développement

Relevé le 2026-10-30.

## Chemins du jeu (Transport Fever 3, Steam app 3493540, compte Steam 195775244)

| Quoi | Chemin |
|---|---|
| Installation | `C:\Program Files (x86)\Steam\steamapps\common\Transport Fever 3` |
| Définitions Teal de l'API | `<installation>\api\tealdef`, `<installation>\base\tealdef` |
| Contenu de base (zips + quelques scripts) | `<installation>\base\content` |
| Journal du jeu | `C:\Program Files (x86)\Steam\userdata\195775244\3493540\local\crash_dump\stdout.txt` |
| Zone de staging des mods | `C:\Program Files (x86)\Steam\userdata\195775244\3493540\local\staging_area\phil_chronicles` |
| Sauvegardes | `C:\Program Files (x86)\Steam\userdata\195775244\3493540\local\save` (partie de test : `Testgame.sav`) |

Au 2026-10-30, `stdout.txt` ne contient aucune ligne `[chronicles]` : le prototype v8 a été déposé
après la dernière session de jeu, il n'a pas encore tourné depuis le staging.

## Outils

- Lua 5.5 installé par scoop (`lua`) : sert aux tests hors jeu (`lua tests/run.lua`).
  Le jeu tourne en Lua 5.4 : le cœur évite toute syntaxe propre à 5.5.
- Teal (`tl`) **absent** : son téléchargement depuis GitHub a été refusé par le mode auto.
  Les fichiers `.tl` ne sont donc vérifiés que par le jeu. Pour l'activer : autoriser le
  téléchargement de `tl.lua` v0.24.8 (teal-language/tl) dans `.build/tools/`.
- Déploiement : `tools/deploy.sh` (tests N1, copie vers le staging, vérification sha256).

## Faits de l'API utiles

- `ug_require` renvoie `any` ; il charge aussi des modules `.lua` (le jeu le fait pour `react.lua`).
- Script de jeu = `x.gs.lua` qui pointe vers `x.script@update` et `x.script@handleEvent`
  (modèle : `base/content/industries/industry_workers.*`).
- `industry_workers.script` du jeu remet la productivité à 1.0 ou au bonus des travailleurs
  quand leur nombre change : notre crise doit être réappliquée périodiquement.
- Voir `notes/tf3-api.md` pour le détail.
