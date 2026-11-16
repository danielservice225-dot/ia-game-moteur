# IA GAME — Simulation industrielle et Machine Learning

IA GAME est un prototype technique qui relie une simulation industrielle 3D Godot à un moteur de Machine Learning Python. Les fonctions doivent être exécutées et vérifiées dans l'environnement cible avant toute présentation comme produit final.

## Composants

- **Godot 4** : usine 3D jouable, déplacement, inspection et commandes des équipements.
- **Renderer Compatibility (OpenGL)** : chemin graphique retenu pour favoriser la compatibilité avec les GPU anciens.
- **FastAPI** : API locale pour importer les données, entraîner et servir les prédictions.
- **Pandas / scikit-learn** : nettoyage CSV, prétraitement, Random Forest classification/régression et évaluation sur un jeu de test séparé.
- **GitHub Actions** : tests Python/Ruff, validation headless Godot, tests du profil GPU et appel HTTP réel de Godot vers l'API ML.

## Préparer le moteur Python

Python 3.10+ est requis.

```powershell
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -e ".[dev]"
python scripts/generate_demo_dataset.py
python scripts/demo_train.py
uvicorn backend.main:app --host 127.0.0.1 --port 8000
```

Documentation interactive de l'API : http://127.0.0.1:8000/docs

## Lancer le jeu manuellement

1. Démarrer l'API Python avec la commande ci-dessus.
2. Ouvrir le dossier `godot_game/` dans Godot 4.
3. Exécuter le projet.
4. Se déplacer avec ZQSD/WASD.
5. Approcher un équipement et appuyer sur E pour demander une prédiction au modèle Python.

Le jeu contacte `http://127.0.0.1:8000`. Si l'API est indisponible, il affiche une erreur au lieu d'inventer une prédiction.

## Préparer puis lancer une démonstration hors ligne (Windows)

La préparation nécessite une connexion Internet pour installer les dépendances Python une première fois. Après cette préparation, le lancement du jeu et de l'API se fait localement, sans service cloud.

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\prepare_offline.ps1
.\scripts\run_offline.ps1
```

Si Godot n'est pas dans le PATH :

```powershell
.\scripts\run_offline.ps1 -GodotExe "C:\Chemin\vers\Godot.exe"
```

Le script de préparation génère le dataset de démonstration et entraîne `artifacts/model.joblib`. Le script hors ligne démarre l'API sur la boucle locale, vérifie sa disponibilité, lance Godot puis arrête l'API à la fermeture du jeu. Il faut conserver le dossier `.venv/`, le modèle `artifacts/model.joblib` et le projet Godot sur le PC de démonstration.

## Simulation industrielle

Quatre équipements sont présents :
- presse hydraulique (P-01) ;
- pompe centrifuge (M-02) ;
- compresseur (C-03) ;
- convoyeur (CV-04).

Commandes :
- **F** : démarrer ou arrêter l'équipement sélectionné ;
- **E** : envoyer les mesures génériques et les six variables AI4I simulées au modèle ML ;
- **G** : injecter une panne de démonstration ;
- **M** : effectuer la maintenance ;
- **F6** : démarrer/arrêter un CSV complémentaire contenant les capteurs génériques et les variables AI4I.

Les mesures actuelles sont synthétiques. Elles servent à vérifier le circuit logiciel ; elles ne remplacent pas des données de capteurs industriels réels ni un modèle physique certifié. Les équipements et opérateurs restent des modèles procéduraux simplifiés : les modèles 3D PBR et les personnages humains riggés sont encore à intégrer.

## Adaptation graphique et mesures

Le projet utilise le renderer Compatibility, une résolution de base de 1280×720 et un profil graphique initial choisi selon le nom du GPU. Les FPS observés peuvent réduire temporairement les éclairages ponctuels ; le retour à la normale restaure le profil initial plutôt que d'activer toutes les lumières.

À chaque lancement, le jeu ajoute une session identifiée dans `user://ia_game_hardware_benchmark.csv`, sans écraser les sessions précédentes. Le fichier contient les informations GPU, moteur de rendu, résolution, FPS et mémoire statique suivie par Godot. Cette valeur n'est pas la RAM totale du processus. Les mesures de performance réelles ne sont disponibles qu'après exécution sur l'ordinateur cible.

Voir `docs/PERFORMANCE_BENCHMARK.md` et `docs/HARDWARE_PROFILE.md`.

## Importer un dataset et entraîner depuis le jeu

Le bouton **IMPORTER CSV / ENTRAÎNER L'IA** ouvre un panneau dans l'interface Godot. Il permet de sélectionner un CSV local, d'envoyer un aperçu à l'API, de choisir la colonne cible et de lancer l'entraînement. Les métriques, les variables utilisées, le nombre de lignes d'entraînement/test, le temps CPU consommé, la mémoire RSS du processus et la latence de test sont affichés dans le panneau. Le HUD affiche aussi la latence et les ressources mesurées pour les prédictions. Le panneau inclut des boutons pour consulter les cinq derniers entraînements et exporter le dernier rapport au format JSON.

Le fichier est traité localement par le backend Python ; il n'est pas envoyé à un service cloud. Le panneau vérifie que les variables explicatives correspondent aux capteurs réellement disponibles dans la simulation. Il prend en charge les trois mesures génériques (`temperature_c`, `vibration_mm_s`, `pressure_bar`) ainsi que les six variables AI4I (`Type`, `Air temperature [K]`, `Process temperature [K]`, `Rotational speed [rpm]`, `Torque [Nm]`, `Tool wear [min]`). Les colonnes non prises en charge sont signalées avant l'entraînement afin d'éviter de créer un modèle inutilisable par le jeu. Le modèle entraîné remplace le modèle local utilisé par les prochaines prédictions.

## API

- `GET /health` : état du service et présence du modèle.
- `POST /datasets/preview` : diagnostic et aperçu CSV.
- `POST /models/train?target=failure` : entraînement sur un CSV envoyé en multipart/form-data.
- `POST /models/predict` : prédiction avec le modèle enregistré et mesures de latence, CPU et RAM du processus.
- `GET /models/history` : historique des 100 derniers entraînements.
- `GET /models/reports/{report_id}` : rapport complet d'un entraînement.
- `GET /models/reports/{report_id}/export` : téléchargement du rapport JSON.

## Données et limites scientifiques

Le script de démonstration génère 500 lignes synthétiques au format de colonnes AI4I. Il sert uniquement à vérifier l'entraînement et l'intégration ; ce n'est pas le dataset AI4I industriel original et ses métriques ne prouvent pas la qualité du modèle. Ses métriques ne constituent pas une preuve de performance industrielle. Pour la compétition, utiliser un dataset industriel documenté, justifier la variable cible, vérifier les unités et les fuites de données, puis conserver les rapports d'entraînement et les preuves de test.

Aucune intégration DataRobot n'est déclarée comme active. Le moteur utilisable dans ce dépôt est le pipeline local scikit-learn.

## Validation avant compétition

- Exécuter les tests Python et Godot de GitHub Actions.
- Lancer le jeu sur le HP EliteBook 8570p et conserver son CSV de télémétrie réel.
- Vérifier les FPS dans les zones de l'usine et pendant les pannes.
- Vérifier l'appel Godot → FastAPI → modèle entraîné sur la machine de présentation.
- Remplacer les données synthétiques par un dataset industriel documenté.
- Importer des assets 3D et personnages riggés avec licences vérifiées.
- Répéter le protocole du jury et conserver les résultats.

Ne pas annoncer une fonction comme terminée sans test sur l'environnement concerné. Ne jamais inclure de jetons, mots de passe ou données industrielles confidentielles dans Git.
