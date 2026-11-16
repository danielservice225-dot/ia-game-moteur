# IA GAME

Prototype technique d'un jeu de simulation industrielle connecté à un véritable moteur de Machine Learning.

## Architecture

- `backend/`: API HTTP FastAPI.
- `ml_engine/`: préparation CSV, entraînement scikit-learn et prédiction.
- `godot_game/`: client Godot 4 d'exemple pour appeler l'API.
- `tests/`: tests automatisés.
- `.github/workflows/`: vérification continue.

## Démarrage local

Python 3.10 à 3.12 recommandé.

```bash
python -m venv .venv
# Linux/macOS
source .venv/bin/activate
# Windows PowerShell : .venv\Scripts\Activate.ps1
pip install -e ".[dev]"
uvicorn backend.main:app --reload
```

Ouvrir http://127.0.0.1:8000/docs.

## Démonstration ML reproductible

```bash
python scripts/generate_demo_dataset.py
python scripts/demo_train.py
pytest
```

Le dataset de démonstration est synthétique et sert uniquement à vérifier le pipeline logiciel. Il ne constitue pas une preuve de performance industrielle réelle. Pour une évaluation scientifique, fournir un CSV industriel documenté et choisir une colonne cible pertinente.

## API

- `GET /health`: état du service.
- `POST /datasets/preview`: aperçu et diagnostic d'un CSV.
- `POST /models/train`: entraînement et évaluation sur un jeu de test séparé.
- `POST /models/predict`: prédictions avec le dernier modèle entraîné.

Les modèles sont sauvegardés dans `artifacts/`. Ne jamais versionner de données sensibles, secrets ou modèles propriétaires.

## DataRobot

L'intégration DataRobot n'est pas activée par défaut. Elle nécessite un compte, une URL d'instance et une clé API. Le moteur local scikit-learn permet de développer et tester le parcours hors ligne ; il ne doit pas être présenté comme un entraînement DataRobot.

## Limites actuelles

Ce dépôt fournit le socle backend ML et un exemple de communication Godot. Il ne contient pas encore un jeu 3D complet, ni une intégration DataRobot certifiée, ni des données industrielles validées. Ces éléments doivent être ajoutés et testés avant une présentation comme produit final.
