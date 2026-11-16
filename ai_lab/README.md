# IA GAME AI Lab

Application Streamlit indépendante consacrée à l'entraînement et à la sélection de modèles dans DataRobot.

## Rôle

- Importer un CSV industriel.
- Afficher un aperçu et les valeurs manquantes.
- Réutiliser un Use Case DataRobot ou en créer un.
- Créer un dataset et un projet DataRobot.
- Lancer AutoML Quick et attendre la fin de l'entraînement.
- Récupérer le modèle recommandé et sa métrique de validation.
- Exporter un manifeste versionné destiné à préparer l'intégration au jeu.

Cette application ne fabrique pas de modèle local de substitution. Le manifeste n'est pas un modèle exécutable et ne prouve pas qu'un déploiement existe. Le jeu ne doit utiliser un modèle qu'après déploiement DataRobot et validation du contrat de prédiction.

## Installation dans WSL

Depuis la racine du dépôt, dans un environnement virtuel Python :

```bash
source .venv/bin/activate
python3 -m pip install -r ai_lab/requirements.txt
```

## Configuration

Récupérez un jeton personnel depuis les paramètres développeur de votre instance DataRobot. Configurez les variables uniquement dans le terminal ou dans un gestionnaire de secrets :

```bash
export DATAROBOT_ENDPOINT="https://VOTRE-INSTANCE-DATAROBOT"
export DATAROBOT_API_TOKEN="VOTRE_JETON_PERSONNEL"
```

Ne mettez jamais ces valeurs dans le dépôt, dans un fichier commité ou dans le manifeste exporté.

## Démarrage

```bash
streamlit run ai_lab/app.py
```

Ouvrez l'adresse locale indiquée par Streamlit, généralement http://localhost:8501.

## Workflow de compétition

1. Vérifier la provenance, les unités et la qualité du dataset.
2. Choisir une cible pertinente et exclure les variables qui divulguent directement la cible.
3. Entraîner avec DataRobot AutoML.
4. Comparer les modèles et vérifier la métrique de validation adaptée.
5. Examiner l'importance des variables et les risques de fuite de données.
6. Déployer le modèle retenu dans DataRobot.
7. Exporter le manifeste avec le Deployment ID.
8. Intégrer le service de prédiction dans IA GAME après validation du schéma exact des capteurs et des réponses.

## Limites actuelles

- L'application nécessite un compte DataRobot, un endpoint et un jeton valides.
- Le déploiement DataRobot n'est pas créé automatiquement.
- Le manifeste n'est pas encore consommé par le jeu.
- L'intégration de prédiction, la validation du schéma capteurs et les tests de bout en bout restent à réaliser.
