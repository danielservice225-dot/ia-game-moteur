# IA GAME Trainer — application Windows native

IA GAME Trainer est une application de bureau PySide6. Elle ouvre une fenêtre Windows native et n'utilise pas de navigateur.

## Fonctions

- Import d'un fichier CSV via l'explorateur Windows.
- Aperçu des données, dimensions, valeurs manquantes et doublons.
- Sélection de la variable cible et exclusion manuelle de colonnes.
- Exclusion suggérée des identifiants et des colonnes de fuite connues pour la cible AI4I « Machine failure ».
- Entraînement local réel du pipeline scikit-learn sur les données importées, avec séparation entraînement/test.
- Métriques de classification ou de régression, rapport JSON et historique.
- Export du modèle Joblib et du rapport.

Le modèle actuel est un Random Forest entraîné par le pipeline partagé ml_engine. L'application ne prétend pas comparer plusieurs algorithmes et ne dépend pas d'un compte DataRobot pour l'entraînement local. Les résultats dépendent du dataset choisi et doivent être évalués sur des données représentatives. Un CSV synthétique ne prouve pas une performance industrielle.

## Construire sous Windows

Depuis la racine du dépôt, dans PowerShell :

    Set-ExecutionPolicy -Scope Process Bypass
    .\scripts\build_windows.ps1

Le fichier généré est dist\IA_GAME_Trainer.exe.

La première compilation télécharge les dépendances Python. L'exécutable peut être volumineux car il embarque Python, Qt, pandas, NumPy et scikit-learn.

## Construire avec GitHub Actions

Le workflow Windows desktop executable compile l'application sur un runner Windows. Après un succès, télécharger l'archive IA-GAME-Trainer-Windows-x64 depuis les artefacts de l'exécution GitHub Actions.

## Stockage local

Les modèles, rapports et historiques sont enregistrés dans le dossier de données utilisateur fourni par Windows. Ils ne sont pas écrits à côté de l'exécutable.

## Limites

- Le binaire Windows doit être construit et testé sur Windows.
- La première version embarque un modèle Random Forest unique.
- L'intégration automatique du modèle exporté dans le jeu Godot reste une étape distincte.
- L'application ne configure pas et ne déploie pas de modèle DataRobot.
