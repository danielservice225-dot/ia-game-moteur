# Mesure des performances IA GAME

## Affichage en jeu

Le HUD affiche une fois par seconde :
- le nombre d'images par seconde (FPS) ;
- la mémoire statique suivie par Godot, en Mo ;
- le temps écoulé depuis le lancement ou depuis le début de l'enregistrement.

La mémoire affichée est la mémoire suivie par le moteur Godot. Ce n'est pas la mémoire totale du processus Windows et elle ne remplace pas une mesure système.

## Enregistrer un benchmark

1. Lancer le projet Godot et ouvrir la scène principale.
2. Appuyer sur **F6** pour commencer l'enregistrement.
3. Effectuer un parcours reproductible : rester immobile, marcher dans l'usine, inspecter successivement les quatre équipements, injecter une panne avec **G**, puis effectuer la maintenance avec **M**.
4. Appuyer de nouveau sur **F6** pour arrêter et fermer le fichier.
5. Récupérer le fichier `ia_game_benchmark.csv` dans le dossier utilisateur de Godot (`user://`, visible depuis Godot via Projet > Ouvrir le dossier des données utilisateur).

Le CSV contient une ligne par seconde : temps, FPS, mémoire statique Godot, code et état de la machine sélectionnée, température, vibration et pression. Les lignes sans machine sélectionnée utilisent le code et l'état `none`.

## Limites et protocole matériel

- Le script ne mesure pas le pourcentage CPU : Godot ne fournit pas ici une mesure CPU portable et fiable entre les systèmes.
- Pour obtenir la consommation RAM totale et CPU, compléter le CSV avec les mesures du Gestionnaire des tâches Windows ou du Moniteur système Linux.
- Faire les essais sur le HP EliteBook 8570p, Intel HD Graphics 4000, 16 Go RAM, avec la même résolution, le même pilote et le même scénario.
- Répéter chaque scénario au moins trois fois et conserver les fichiers bruts.
- Ne pas considérer 30 FPS comme atteint avant mesure réelle sur le PC cible.
- Les tests headless de CI vérifient le chargement et la logique, pas le rendu ni les performances graphiques.

## Critères de validation

Consigner la moyenne et le minimum FPS, la mémoire Godot, la RAM système et le CPU système. Comparer les mesures à l'arrêt, en déplacement et pendant les interactions avec les machines. Ne pas annoncer de résultat matériel sans joindre les fichiers de mesure.
