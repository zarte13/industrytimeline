# Quel agent utiliser ?

Guide pour Claude (et pour toi) : à qui confier chaque tâche de ce projet.
L'agent principal (Opus) garde la conception, les contrats entre couches et la vérification ;
il délègue le reste aux sous-agents ci-dessous.

## En bref

| Tâche | Agent | Modèle | Pourquoi |
|---|---|---|---|
| Concevoir une phase, fixer les formats d'état et les contrats | principal | Opus 5.5 | Décisions qui engagent toute la suite |
| Code qui touche l'API du jeu (`adapters/`, script de jeu, `gui/`) | principal | Opus 5.5 | API peu documentée, erreurs visibles seulement en jeu |
| Relire un diff avant commit | principal (ou `/code-review`) | Opus 5.5 | Dernier filet avant la version |
| Écrire du code pur à partir d'une spec claire (`core/*.lua`) + ses tests N1 | `general-purpose` | Sonnet 5.5 | Bien cadré, vérifiable seul avec `lua tests/run.lua` |
| Fouiller l'API du jeu (`api/tealdef`, `base/content`, mods de campagne) | `Explore` | Sonnet 5.5 | Lecture large, demande du jugement pour résumer |
| Gabarits d'articles, catalogue d'événements (phases 2-3) | `general-purpose` | Sonnet 5.5 | Rédaction + structure de données |
| Trouver un fichier, un chemin, lire `stdout.txt` et extraire les lignes `[chronicles]` | `Explore` | Haiku 5.5 | Mécanique, rapide, peu coûteux |
| Scripts utilitaires simples (déploiement, empreintes, archives) | `general-purpose` | Haiku 5.5 | Tâche courte et vérifiable |
| Relancer les tests et résumer les échecs | `general-purpose` | Haiku 5.5 | Exécution + résumé |

## Règles

1. **Une spec avant de déléguer.** Le sous-agent reçoit un fichier de spec (ex. `notes/mvp-design.md`)
   et la liste exacte des fichiers qu'il a le droit d'écrire. Deux agents n'écrivent jamais les mêmes fichiers.
2. **Le sous-agent ne fait pas de commit.** Le principal vérifie (tests N1, relecture) puis commit.
3. **Haiku pour ce qui se vérifie d'un coup d'œil** ; Sonnet dès qu'il faut comprendre ou concevoir un peu ;
   Opus quand une erreur coûterait une session de jeu.
4. **Lecture seule = `Explore`.** Pour chercher sans rien modifier, prendre `Explore` (Haiku pour un chemin,
   Sonnet pour comprendre une API).
5. **Ce qui ne se teste qu'en jeu reste au principal** : il connaît les inconnues listées dans `notes/`.

## Exemples de demandes

- « Ajoute le boom pétrolier au catalogue » → Sonnet `general-purpose`, spec + `tests/run.lua` à faire passer.
- « Où le jeu écrit-il ses sauvegardes ? » → Haiku `Explore`.
- « Lis le résultat de l'autotest » → Haiku `Explore` sur `stdout.txt` (chemin dans `notes/environnement.md`).
- « Branche l'onglet Économie sur l'état » → principal (API d'interface du jeu).
