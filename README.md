# IA GAME — Simulation industrielle et Machine Learning

IA GAME est un prototype technique qui relie une simulation industrielle 3D Godot à un moteur de Machine Learning Python. Les fonctions doivent être exécutées et vérifiées dans l'environnement cible avant toute présentation comme produit final.

## Composants

- **Godot 4** : simulation 3D et tableau de supervision ; sélection des machines par clic, sans déplacement obligatoire.
- **Interface de supervision** : liste d'équipements, fiche capteurs, état, diagnostic, arrêt/redémarrage, panne de scénario et maintenance.
- **IA GAME AI Lab** : application Streamlit indépendante consacrée à l'entraînement et à la sélection des modèles dans DataRobot.
- **DataRobot** : AutoML, comparaison, validation et sélection du modèle ; le jeu ne doit utiliser qu'un déploiement DataRobot déclaré et validé.
- **FastAPI / scikit-learn** : moteur local conservé pour les tests et expérimentations du pipeline ML ; il n'est plus appelé comme moteur IA du jeu.
- **GitHub Actions** : tests Python/Ruff et validation headless Godot ; le nouveau parcours de supervision et le connecteur DataRobot doivent encore être couverts par des tests dédiés.

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

1. Ouvrir le dossier `godot_game/` dans Godot 4.
2. Exécuter le projet.
3. Cliquer sur une machine dans la scène 3D ou sur sa carte dans la liste des équipements.
4. Utiliser les boutons de la fiche : diagnostic IA, arrêt/redémarrage, simulation de panne et maintenance.
5. Aucun déplacement clavier n'est nécessaire pour le parcours normal.

La caméra est une caméra de supervision fixe. Le diagnostic IA reste indisponible tant qu'un déploiement DataRobot n'a pas été configuré et validé ; le jeu ne doit pas remplacer silencieusement DataRobot par un modèle local.

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
- **Clic gauche** sur une machine 3D ou sur sa carte : sélectionner l'équipement ;
- **Diagnostic IA** : action désactivée tant que le déploiement DataRobot n'est pas configuré ;
- **Arrêter / Redémarrer** : modifier l'état de l'équipement sélectionné ;
- **Simuler une panne** : injecter un scénario de panne reproductible ;
- **Effectuer la maintenance** : réinitialiser l'équipement après un arrêt ou une panne ;
- **F6** : démarrer/arrêter un CSV complémentaire de télémétrie.

Les mesures actuelles sont synthétiques. Elles servent à vérifier le circuit logiciel ; elles ne remplacent pas des données de capteurs industriels réels ni un modèle physique certifié. Les équipements et opérateurs restent des modèles procéduraux simplifiés : les modèles 3D PBR et les personnages humains riggés sont encore à intégrer.

## Adaptation graphique et mesures

Le projet utilise le renderer Compatibility, une résolution de base de 1280×720 et un profil graphique initial choisi selon le nom du GPU. Les FPS observés peuvent réduire temporairement les éclairages ponctuels ; le retour à la normale restaure le profil initial plutôt que d'activer toutes les lumières.

À chaque lancement, le jeu ajoute une session identifiée dans `user://ia_game_hardware_benchmark.csv`, sans écraser les sessions précédentes. Le fichier contient les informations GPU, moteur de rendu, résolution, FPS et mémoire statique suivie par Godot. Cette valeur n'est pas la RAM totale du processus. Les mesures de performance réelles ne sont disponibles qu'après exécution sur l'ordinateur cible.

Voir `docs/PERFORMANCE_BENCHMARK.md` et `docs/HARDWARE_PROFILE.md`.

## Entraînement DataRobot dans l'application indépendante

L'entraînement ne se fait plus dans le jeu. L'application `ai_lab/` est séparée de Godot et utilise le SDK DataRobot pour créer/réutiliser un Use Case, importer un CSV, créer un projet, lancer AutoML et récupérer le modèle recommandé.

Installation et lancement :

```bash
source .venv/bin/activate
python3 -m pip install -r ai_lab/requirements.txt
export DATAROBOT_ENDPOINT="https://VOTRE-INSTANCE-DATAROBOT"
export DATAROBOT_API_TOKEN="VOTRE_JETON_PERSONNEL"
streamlit run ai_lab/app.py
```

Ne placez jamais le jeton dans Git ou dans le manifeste exporté. Après entraînement, déployez le modèle dans DataRobot puis indiquez son Deployment ID pour produire le manifeste d'intégration. À ce stade, l'application AI Lab est amorcée ; l'authentification, le déploiement et la connexion de prédiction au jeu restent à valider avec un compte DataRobot réel.

Voir [ai_lab/README.md](ai_lab/README.md) et [docs/ARCHITECTURE_V2.md](docs/ARCHITECTURE_V2.md).

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
