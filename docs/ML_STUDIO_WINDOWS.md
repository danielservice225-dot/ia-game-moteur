# IA GAME ML Studio — application Windows

IA GAME ML Studio est une interface de bureau PySide6 qui démarre FastAPI et le moteur scikit-learn localement. Aucun service cloud n'est nécessaire pour importer un CSV, entraîner un modèle ou effectuer une prédiction.

## Première version

- Tableau de bord de l'API et de la présence du modèle.
- Sélection de CSV depuis le système de fichiers.
- Aperçu et rapport de nettoyage via POST /datasets/preview.
- Entraînement via POST /models/train avec choix de la cible, test_size et random_state.
- Historique via GET /models/history.
- Prédictions via POST /models/predict.
- Artefacts enregistrés dans %LOCALAPPDATA%\IA GAME ML Studio\artifacts sous Windows.
- API locale liée uniquement à 127.0.0.1:8765 ; le port 8000 de la simulation existante reste inchangé.

## Développement local Windows

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -e ".[dev]"
python -m pip install -r requirements-ml-studio.txt
python -m ml_studio.app
```

## Génération de l'exécutable

Le workflow .github/workflows/build-ml-studio-windows.yml exécute les tests, construit l'EXE PyInstaller et génère un installateur Inno Setup. Les deux fichiers sont publiés comme artefacts du workflow.

## Intégration Godot à finaliser

Le modèle est stocké dans le dossier d'artefacts propre à ML Studio. Pour que la simulation empaquetée utilise le même modèle, elle devra partager ce dossier ou recevoir le chemin via IA_GAME_ARTIFACT_DIR. Cette liaison doit être implémentée et testée sur Windows avant de déclarer l'intégration terminée.

## Limites actuelles

Le pipeline existant entraîne un Random Forest de classification ou de régression ; il ne compare pas encore plusieurs familles d'algorithmes. Les métriques dépendent du dataset et de la machine. Les datasets synthétiques ne prouvent pas la qualité industrielle.
