# Protocole de démonstration reproductible — IA GAME

## Portée

Ce protocole décrit une séquence manuelle reproductible pour le jury. Il ne constitue pas encore un système automatique d'archivage des sessions. Les mesures de capteurs et les pannes sont synthétiques.

## Préparation

1. Préparer le modèle local avec `scripts/prepare_offline.ps1` (Windows) ou les commandes Python du README.
2. Lancer IA GAME avec `scripts/run_offline.ps1` ou démarrer l'API et Godot séparément.
3. Vérifier que le HUD affiche le GPU attendu et un nombre de FPS.
4. Laisser la scène tourner 60 secondes avant la première mesure.
5. Conserver `user://ia_game_hardware_benchmark.csv`. Activer F6 si l'on souhaite également conserver les mesures machine par machine, y compris les variables AI4I.

## Scénario standard

Repartir d'un lancement neuf du jeu pour chaque répétition.

1. **État initial** : approcher la presse P-01 et noter son état, ses trois capteurs génériques et les six variables AI4I.
2. **Diagnostic nominal** : appuyer sur E et conserver le message retourné par le modèle.
3. **Arrêt/redémarrage** : appuyer sur F deux fois et vérifier le retour à l'état RUNNING.
4. **Injection de panne** : appuyer sur G et vérifier l'état FAULT et la dégradation des capteurs.
5. **Diagnostic en panne** : appuyer sur E et noter la prédiction reçue. Ne pas supposer que le modèle doit détecter correctement une panne tant qu'il n'a pas été évalué sur des données industrielles représentatives.
6. **Maintenance** : appuyer sur M et vérifier le retour à l'état RUNNING.
7. **Production** : observer le compteur de pièces du convoyeur pendant au moins 60 secondes.
8. **Rapport ML** : ouvrir l'historique des entraînements dans le panneau CSV et exporter le rapport JSON de la dernière session.
9. **Fin de session** : quitter le jeu proprement pour fermer les fichiers CSV.

## Fiche de résultats à compléter pour chaque répétition

- Date et heure :
- Commit Git / version du projet :
- Ordinateur, CPU, GPU et pilote :
- Version de Godot et renderer :
- Résolution :
- Profil graphique sélectionné :
- FPS moyen et minimum observés :
- Taille du CSV matériel :
- État et capteurs avant/après panne :
- Réponse du modèle nominal / en panne :
- Temps de réponse ML :
- Résultat maintenance :
- Incidents ou messages d'erreur :

## Critères de réussite

- La scène démarre sans erreur.
- Le CSV matériel est créé et contient des lignes d'échantillons.
- Le backend local répond à `/health` et annonce un modèle disponible.
- Une requête depuis Godot reçoit une prédiction HTTP.
- Les transitions RUNNING → STOPPED → RUNNING → FAULT → RUNNING sont vérifiées.
- Le rapport JSON de l'entraînement est accessible depuis l'interface et l'historique de l'API.
- Les résultats sont conservés avec la version du code et les caractéristiques du PC.

## Limites connues

Le protocole ne génère pas encore de rapport PDF/JSON consolidé ni d'historique automatique des sessions. Les tests automatisés couvrent les transitions logiques et l'appel Godot vers l'API, mais le rendu, les FPS réels et le comportement sur le HP EliteBook 8570p nécessitent un essai physique.
