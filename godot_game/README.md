# Godot 4 — IA GAME

Ouvrir ce dossier dans Godot 4. La scène principale construit une petite zone d'usine avec une presse, un joueur contrôlé au clavier et un HUD.

Le joueur peut se déplacer avec ZQSD/WASD. Approcher la machine au centre et appuyer sur E déclenche une requête vers le serveur FastAPI local.

Le modèle doit d'abord être entraîné via les scripts Python décrits dans le README racine. Le jeu ne simule pas une prédiction si l'API est indisponible : il affiche une erreur explicite.

Vérifiez le lancement dans Godot 4 avant la démonstration ; la compatibilité du fichier de projet et des scripts n'a pas encore été confirmée par une exécution du moteur dans cette session.
