# IA GAME — Simulation industrielle et Machine Learning

IA GAME est un prototype technique qui relie une simulation 3D Godot à un moteur ML Python. Les fonctions doivent être exécutées et vérifiées dans l'environnement cible avant toute présentation comme produit final.

## Composants

- **Godot 4** : scène 3D industrielle jouable, déplacement clavier et interaction avec une machine.
- **FastAPI** : API locale pour importer les données, entraîner et servir les prédictions.
- **Pandas / scikit-learn** : nettoyage CSV, pipeline de prétraitement, Random Forest classification/régression et évaluation sur jeu de test séparé.
- **GitHub Actions** : tests Python et contrôle Ruff.

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
2. Démarrer le serveur Python et entraîner le modèle.
3. Lancer le projet Godot.
4. Se déplacer avec ZQSD/WASD.
5. Approcher la presse industrielle et appuyer sur E pour demander une prédiction au modèle Python.

La scène et le dataset fournis sont des éléments de prototype. Le dataset de 500 lignes est **synthétique** et sert uniquement à vérifier le flux technique ; il ne constitue pas une preuve de performance industrielle réelle.

## API

- `GET /health` : état du service.
- `POST /datasets/preview` : diagnostic et aperçu CSV.
- `POST /models/train?target=failure` : entraînement sur le CSV envoyé en multipart/form-data.
- `POST /models/predict` : prédiction du modèle entraîné.

## DataRobot

Aucun compte DataRobot n'étant disponible à ce stade, le pipeline local scikit-learn est le moteur réellement utilisable. DataRobot n'est pas présenté comme connecté. Une intégration réelle nécessitera un compte, un endpoint et un jeton API configurés en secrets d'environnement, puis des tests d'authentification et d'entraînement.

## Limites avant compétition

- Tester l'ouverture et l'exécution du projet avec la version exacte de Godot 4 installée.
- Tester les appels HTTP depuis le poste de démonstration.
- Remplacer les données synthétiques par un dataset industriel documenté.
- Vérifier le choix de la cible, les fuites de données, les métriques et la reproductibilité.
- Ne jamais communiquer de clé API ou de donnée industrielle confidentielle dans Git.
