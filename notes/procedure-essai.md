# Procédure d'essai en jeu (phase 1)

À faire avec la version déposée dans le staging. Après chaque essai, dire « lis-le » :
Claude lit `stdout.txt` et met à jour le doc « Moteur d'événements » et le carnet.

## 1. Autotest (1 minute)

1. Charger `Testgame.sav`.
2. Chroniques → onglet Débogage → « Lancer l'autotest ».
3. Attendre la notification « Autotest terminé ».

Couvre : productivité appliquée, cycle complet, retour exact, Tout rétablir, industrie disparue
(simulée), coût d'un trimestre.

## 2. Test de sauvegarde (2 minutes)

1. « Préparer le test de sauvegarde ».
2. Mettre en pause, sauvegarder, recharger cette sauvegarde.
3. « Vérifier la sauvegarde » → notification « Test de sauvegarde ».

## 3. Partie témoin accélérée (2 minutes)

1. « Partie témoin accélérée (10 ans) », jeu non en pause.
2. Attendre la notification « Partie témoin terminée » (40 trimestres, un toutes les 2 s de jeu).

La date interne du mod garde ensuite 10 ans d'avance sur celle du jeu : faire cet essai sur une
sauvegarde de test, pas sur une vraie partie.

## 4. Retirer le mod proprement (3 minutes)

1. Dans une partie avec une crise en cours (« Forcer un événement » puis « Phase suivante »),
   noter l'industrie touchée et sa productivité réduite (fenêtre de l'industrie).
2. « Tout rétablir », vérifier la productivité revenue à 100 %, sauvegarder.
3. Quitter, désactiver le mod, recharger la sauvegarde : aucune erreur, productivité à 100 %.

## 5. À l'œil

- Les notifications « Crise annoncée » et « Reprise » s'affichent-elles (titre, texte, icône) ?
- Le Journal et le bloc de la fenêtre d'industrie sont-ils lisibles ?

## 6. Partie témoin réelle (10 ans de jeu)

Jouer normalement, mod actif, sur une partie neuve ou de test. Ce qu'on voit pendant la partie :

- une notification à chaque phase de chaque crise (bouton « Notifications » de Débogage pour revenir à
  annonce et reprise seulement) ;
- Débogage : « Prochain tirage dans N trimestre(s) · chance 25 % », puis « Activité du moteur » :
  chaque trimestre, la décision du conteur (« tirage 0,42 pour un seuil de 0,25, pas de crise »), les phases,
  les productivités changées, et les **réaffirmations** quand le jeu a modifié une productivité ;
- Journal : crises en cours, puis « Chronologie » de toute la partie (dates de chaque phase, durée,
  industries, plancher).

À la fin : dire « lis-le ». Claude compte les crises et les erreurs dans `stdout.txt`, et on juge ensemble
le rythme (trop de crises, pas assez, trop longues).

## 7. Étape 0 de la v10 (15 minutes, partie de test avec quelques lignes)

Onglet Débogage, section « Essais v10 (étape 0) ». Tout s'écrit dans « Activité du moteur » (lignes `ESSAI …`).

1. **Lire le calendrier** : note la vitesse et la durée d'un trimestre. Change le curseur « Vitesse du
   calendrier » (ex. 2x puis 0,5x), clique à nouveau : la durée doit changer.
2. **Créer une industrie** : une industrie apparaît près de la ville qui a le plus de gares. Une notification
   « industrie fondée » s'affiche ; clique dessus pour la voir. Capture si elle est mal placée.
3. **Ultimatum 1 trimestre** : sur l'industrie créée. Une notification « fermeture » avec compte à rebours
   doit s'afficher (capture). Laisse passer un peu plus d'un trimestre : l'activité dira si le jeu l'a
   supprimée, ou si elle est toujours là.
4. Ouvre la fenêtre d'une industrie **que tu dessers**, clique « Essai : suivre les compteurs ».
   Laisse passer deux trimestres : les compteurs `itemsLoaded` doivent augmenter.
5. **Faire grandir une ville** : relevé avant, puis après au trimestre suivant. Regarde aussi la ville en jeu.

Puis « lis-le ».

## Hors de portée d'un essai rapide

- Industrie du joueur en jeu : il faut une partie où l'on possède une industrie (le cas passe hors jeu).
- Fermeture décidée par le jeu : rare, elle suit le même chemin que l'industrie disparue.
- Partie témoin réelle (jouer 10 ans normalement) : recommandée avant la phase 2, pour juger le rythme.
