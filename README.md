# IA GAME — Simulation industrielle et Machine Learning

IA GAME est un prototype technique qui relie une simulation 3D Godot à un moteur ML Python. Les fonctions doivent être exécutées et vérifiées dans l'environnement cible avant toute présentation comme produit final.

## Composants

- **Godot 4** : scène 3D industrielle jouable, déplacement clavier et interaction avec une machine.
- **FastAPI** : API locale pour importer les données, entraîner et servir les prédictions.
- **Pandas / scikit-learn** : nettoyage CSV, pipeline de prétraitement, Random Forest classification/régression et évaluation sur jeu de test séparé.
- **GitHub Actions** : tests Python/Ruff et validation headless du projet Godot 4.

## Démarrer le moteur Python

Python 3.10+ recommandé.

```bash
python -m venv .venv
# Linux/macOS
source .venv/bin/activate
# Windows PowerShell : .venv\Scripts\Activate.ps1
pip install -e ".[dev]"
python scripts/generate_demo_dataset.py
python scripts/demo_train.py
uvicorn backend.main:app --reload
```

API : http://127.0.0.1:8000/docs

## Lancer le jeu

1. Ouvrir le dossier `godot_game/` avec Godot 4.
2. Démarrer le serveur Python et entraîner le modèle avec les commandes ci-dessus.
3. Lancer le projet Godot.
4. Se déplacer avec ZQSD/WASD.
5. Approcher la presse industrielle et appuyer sur E pour demander une prédiction au modèle Python.

Le script de démonstration et l'API utilisent le même fichier `artifacts/model.joblib`. Le jeu ne simule pas une prédiction si l'API est indisponible : il affiche une erreur explicite.

## Simulation industrielle Godot

La branche de travail ajoute un premier modèle d'états et de capteurs pour quatre équipements :
- presse hydraulique (P-01) ;
- pompe centrifuge (M-02) ;
- compresseur (C-03) ;
- convoyeur (CV-04).

Commandes en jeu :
- **F** : démarrer ou arrêter l'équipement sélectionné ;
- **E** : envoyer ses trois mesures (température, vibration, pression) au modèle Python ;
- **G** : injecter une panne de démonstration sur l'équipement sélectionné ;
- **M** : effectuer la maintenance et réinitialiser ses capteurs.

La simulation fait évoluer les mesures et le compteur de production du convoyeur. Les mesures générées sont synthétiques et servent à valider le flux logiciel ; elles ne remplacent pas des données de capteurs industriels réels ni un modèle physique certifié. La maintenance est une mécanique de démonstration.

Le rendu utilise le renderer Forward+ et des effets d'occlusion ambiante. Les équipements et opérateurs restent actuellement des modèles procéduraux simplifiés. Pour atteindre un rendu photoréaliste, il faudra importer des modèles 3D PBR de qualité, des personnages riggés et des animations licenciés correctement.

## API

- `GET /health` : état du service.
- `POST /datasets/preview` : diagnostic et aperçu CSV.
- `POST /models/train?target=failure` : entraînement sur le CSV envoyé en multipart/form-data.
- `POST /models/predict` : prédiction du modèle entraîné.

## Données de démonstration

Le dataset généré contient 500 lignes **synthétiques**. Il sert uniquement à vérifier le flux logiciel ; il ne constitue pas une preuve de performance industrielle réelle. Pour la compétition, utiliser un dataset industriel documenté, justifier la variable cible et vérifier les fuites de données.

## DataRobot

Aucun compte DataRobot n'étant disponible à ce stade, le pipeline local scikit-learn est le moteur réellement utilisable. DataRobot n'est pas présenté comme connecté. Une intégration réelle nécessitera un compte, un endpoint et un jeton API configurés en secrets d'environnement, puis des tests d'authentification et d'entraînement.

## Limites avant compétition

- Tester l'ouverture et l'exécution du projet avec la version exacte de Godot 4 installée.
- Tester les appels HTTP depuis le poste de démonstration.
- Remplacer les données synthétiques par un dataset industriel documenté.
- Vérifier les métriques, les performances, la reproductibilité et la séparation entraînement/test.
- Ne jamais communiquer de clé API ou de donnée industrielle confidentielle dans Git.
