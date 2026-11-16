# Profils graphiques et télémétrie IA GAME

## Adaptation automatique au GPU

Au lancement, IA GAME détecte le nom et le fabricant du GPU via Godot, ainsi que le moteur de rendu, le système d'exploitation, le nombre de processeurs logiques et la résolution de l'écran.

Le jeu choisit un profil initial prudent :
- **Économique** pour les rendus logiciels et quelques GPU anciens connus, dont Intel HD Graphics 2000/3000/4000 : éclairages ponctuels désactivés.
- **Équilibré** par défaut pour les GPU intégrés, les modèles non classés et les cartes dont le nom ne permet pas d'estimer raisonnablement la puissance : un éclairage ponctuel sur deux est activé.
- **Élevé** uniquement pour certaines familles dédiées récentes explicitement reconnues : tous les éclairages ponctuels sont activés au départ.

Le nom du fabricant seul ne suffit donc pas à classer une carte NVIDIA ou AMD en profil élevé. Les FPS restent le signal d'adaptation principal.

L'adaptation observe les FPS une fois par seconde : sous 24 FPS, les éclairages ponctuels adaptatifs sont désactivés. Au-dessus de 48 FPS pendant dix échantillons consécutifs, le jeu restaure exactement les éclairages du profil initial. Il ne réactive pas aveuglément toutes les lumières. Le profil économique reste volontairement économique.

Le catalogue de règles initiales est dans `data/gpu_compatibility_profiles.csv`.

### Limites importantes

- Il n'existe pas d'API Godot portable permettant de connaître de manière fiable la VRAM disponible sur toutes les cartes et tous les pilotes. Le jeu ne prétend donc pas mesurer la VRAM.
- Le nom du GPU ne suffit pas à garantir ses performances : le pilote, la température, l'alimentation et les autres applications ont aussi un effet.
- La résolution du jeu reste réglée à 1280x720 ; ce système adapte ici surtout l'éclairage, pas la résolution ni tous les effets graphiques.
- Les catégories initiales sont des heuristiques, pas un classement certifié de toutes les cartes graphiques.
- Le système doit être testé avec des GPU Intel, AMD et NVIDIA réels. Les tests automatisés vérifient la logique des profils, pas les FPS physiques d'une carte.

## CSV généré automatiquement

À chaque lancement du jeu, le gestionnaire crée ou remplace le fichier :

`user://ia_game_hardware_benchmark.csv`

Le fichier contient :
- une ligne `hardware` avec le GPU, le fabricant, le moteur de rendu, le système, le nombre de processeurs logiques et la résolution ;
- une ligne `sample` par seconde avec les FPS, la mémoire statique suivie par Godot, le profil graphique, la raison du profil et l'état des éclairages.

Aucune touche F6 n'est nécessaire pour ce journal automatique. Le fichier est écrit dans le dossier de données utilisateur de Godot. Depuis Godot, utilisez **Projet > Ouvrir le dossier des données utilisateur** pour le retrouver.

La mémoire affichée est celle suivie par Godot, pas la RAM totale du processus. Les FPS et autres valeurs ne sont réels que lorsque le jeu tourne sur l'ordinateur concerné. Le catalogue CSV décrit des règles de compatibilité et ne contient pas de mesures de performances inventées.

## Validation

- Lancer la scène sur chaque ordinateur cible.
- Vérifier que le profil et le GPU affichés dans le HUD correspondent à la machine.
- Jouer au moins cinq minutes et conserver le CSV produit.
- Répéter le test en déplacement, près des quatre équipements et pendant une panne simulée.
- Comparer les FPS moyens/minimaux et la mémoire suivie par Godot.
- Ne jamais présenter le catalogue de profils comme un benchmark de FPS mesurés.
- Les tests headless de CI vérifient le chargement et la logique, pas le rendu ni les performances graphiques.
