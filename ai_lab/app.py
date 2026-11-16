from __future__ import annotations

import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path

import datarobot as dr
import pandas as pd
import streamlit as st


st.set_page_config(page_title="IA GAME AI Lab", page_icon="🧠", layout="wide")

st.title("IA GAME AI Lab")
st.caption("Application indépendante de préparation, entraînement et sélection des modèles DataRobot.")

st.info(
    "Cette application entraîne et sélectionne les modèles dans DataRobot. "
    "Elle ne crée pas de modèle scikit-learn local et ne remplace pas un modèle dans le jeu. "
    "Pour être consommé par la simulation, le modèle sélectionné doit ensuite être déployé "
    "dans DataRobot et son identifiant de déploiement doit être renseigné."
)


def get_client():
    token = os.getenv("DATAROBOT_API_TOKEN")
    endpoint = os.getenv("DATAROBOT_ENDPOINT")
    if not token or not endpoint:
        return None, "DATAROBOT_API_TOKEN et DATAROBOT_ENDPOINT doivent être configurés dans l'environnement."
    try:
        return dr.Client(token=token, endpoint=endpoint), None
    except Exception as exc:  # SDK errors vary by deployment/version.
        return None, f"Connexion DataRobot impossible : {exc}"


client, connection_error = get_client()
if connection_error:
    st.error(connection_error)
    st.markdown(
        "Configurez les variables dans votre terminal, sans inscrire le jeton dans Git :\n"
        "```bash\n"
        "export DATAROBOT_ENDPOINT='https://VOTRE-INSTANCE-DATAROBOT'\n"
        "export DATAROBOT_API_TOKEN='VOTRE_JETON_PERSONNEL'\n"
        "streamlit run ai_lab/app.py\n"
        "```"
    )
    st.stop()

st.success("Configuration DataRobot détectée. Les opérations seront exécutées dans votre instance.")

with st.sidebar:
    st.header("Projet DataRobot")
    project_name = st.text_input("Nom du projet", "IA GAME — Maintenance prédictive")
    use_case_id = st.text_input("Use Case ID existant (facultatif)", "")
    st.caption("Si l'ID est vide, un nouveau Use Case sera créé.")

uploaded = st.file_uploader("Dataset industriel (CSV)", type=["csv"])
if uploaded is None:
    st.warning("Importez un dataset CSV pour commencer.")
    st.stop()

try:
    frame = pd.read_csv(uploaded)
except Exception as exc:
    st.error(f"Lecture du CSV impossible : {exc}")
    st.stop()

if frame.empty or len(frame.columns) < 2:
    st.error("Le dataset doit contenir des lignes et au moins deux colonnes.")
    st.stop()

st.subheader("Contrôle initial du dataset")
m1, m2, m3 = st.columns(3)
m1.metric("Lignes", f"{len(frame):,}".replace(",", " "))
m2.metric("Colonnes", len(frame.columns))
m3.metric("Valeurs manquantes", int(frame.isna().sum().sum()))
st.caption(
    f"Doublons exacts : {int(frame.duplicated().sum())} · "
    f"Colonnes constantes : {sum(frame[column].nunique(dropna=False) <= 1 for column in frame.columns)}"
)
st.dataframe(frame.head(20), use_container_width=True)

target = st.selectbox("Variable cible à prédire", options=list(frame.columns), index=(
    list(frame.columns).index("Machine failure") if "Machine failure" in frame.columns else len(frame.columns) - 1
))
st.caption(
    "Pour AI4I 2020, « Machine failure » est une cible possible. "
    "Les colonnes de sous-types de panne (TWF, HDF, PWF, OSF, RNF) peuvent révéler directement "
    "la cible et doivent être exclues du jeu de caractéristiques pour une évaluation honnête."
)
leakage_candidates = ["UDI", "Product ID"]
if target == "Machine failure":
    leakage_candidates += ["TWF", "HDF", "PWF", "OSF", "RNF"]
available_exclusions = [column for column in leakage_candidates if column in frame.columns and column != target]
excluded_columns = st.multiselect(
    "Colonnes à exclure de l'entraînement (identifiants ou risque de fuite)",
    options=[column for column in frame.columns if column != target],
    default=available_exclusions,
)
training_frame = frame.drop(columns=excluded_columns)
valid_training_frame = target in training_frame.columns and len(training_frame.columns) >= 2
if not valid_training_frame:
    st.error("Après exclusion, il faut conserver la cible et au moins une variable explicative.")

automl_mode_label = st.selectbox("Mode DataRobot AutoML", ["Quick", "Comprehensive"])
automl_mode = dr.AUTOPILOT_MODE.QUICK if automl_mode_label == "Quick" else dr.AUTOPILOT_MODE.COMPREHENSIVE

if st.button(
    "Créer le projet et lancer DataRobot AutoML",
    type="primary",
    use_container_width=True,
    disabled=not valid_training_frame,
):
    try:
        with st.spinner("Création du Use Case et du dataset dans DataRobot..."):
            if use_case_id.strip():
                use_case = dr.UseCase.get(use_case_id.strip())
            else:
                use_case = dr.UseCase.create(
                    name=project_name,
                    description="Use Case IA GAME pour la maintenance prédictive industrielle.",
                )

            suffix = Path(uploaded.name).name
            with tempfile.NamedTemporaryFile(suffix=".csv", delete=False) as temp_file:
                temp_file.write(training_frame.to_csv(index=False).encode("utf-8"))
                temp_path = temp_file.name

            try:
                dataset = dr.Dataset.create_from_file(
                    file_path=temp_path,
                    name=suffix,
                    use_cases=[use_case],
                )
            finally:
                Path(temp_path).unlink(missing_ok=True)

            project = dr.Project.create_from_dataset(
                dataset_id=dataset.id,
                project_name=project_name,
                use_case=use_case,
            )

        with st.spinner(f"Démarrage de DataRobot AutoML en mode {automl_mode_label}..."):
            project.analyze_and_model(
                target=target,
                mode=automl_mode,
                worker_count=-1,
            )
            project.wait_for_autopilot()

        recommendation = dr.ModelRecommendation.get(project.id).get_model()
        metric_name = project.metric
        metrics = recommendation.metrics
        validation_score = metrics.get(metric_name, {}).get("validation")
        try:
            feature_impact = recommendation.get_feature_impact()
        except Exception:
            feature_impact = []
        comparison = []
        for candidate in dr.Model.list(project.id):
            candidate_metrics = candidate.metrics.get(metric_name, {})
            comparison.append({
                "model_id": str(candidate.id),
                "model_type": str(candidate.model_type),
                "validation_score": candidate_metrics.get("validation"),
                "cross_validation_score": candidate_metrics.get("crossValidation"),
                "recommended": str(candidate.id) == str(recommendation.id),
            })
        st.session_state["training_result"] = {
            "use_case_id": str(use_case.id),
            "dataset_id": str(dataset.id),
            "project_id": str(project.id),
            "model_id": str(recommendation.id),
            "model_type": str(recommendation.model_type),
            "target": target,
            "metric": str(metric_name),
            "validation_score": validation_score,
            "metrics": metrics,
            "features": [str(column) for column in training_frame.columns if column != target],
            "excluded_columns": [str(column) for column in excluded_columns],
            "model_comparison": comparison,
            "feature_impact": feature_impact,
            "source_filename": uploaded.name,
            "trained_at": datetime.now(timezone.utc).isoformat(),
        }
        st.success("AutoML terminé. Le modèle recommandé a été récupéré depuis DataRobot.")
    except Exception as exc:
        st.error(f"Échec du workflow DataRobot : {exc}")

result = st.session_state.get("training_result")
if result:
    st.divider()
    st.subheader("Résultat du modèle DataRobot")
    c1, c2, c3 = st.columns(3)
    c1.metric("Modèle", result["model_type"])
    c2.metric("Métrique", result["metric"])
    c3.metric(
        "Score validation",
        "Non fourni" if result["validation_score"] is None else f"{result['validation_score']:.5f}",
    )
    if result.get("model_comparison"):
        st.markdown("**Comparaison des modèles DataRobot**")
        st.dataframe(pd.DataFrame(result["model_comparison"]), use_container_width=True)
    st.caption("Colonnes exclues : " + (", ".join(result.get("excluded_columns", [])) or "aucune"))
    if result.get("feature_impact"):
        st.markdown("**Importance des variables — DataRobot**")
        st.dataframe(pd.DataFrame(result["feature_impact"]), use_container_width=True)
    st.code(
        f"Use Case : {result['use_case_id']}\n"
        f"Dataset : {result['dataset_id']}\n"
        f"Projet : {result['project_id']}\n"
        f"Modèle : {result['model_id']}\n"
        f"Cible : {result['target']}",
        language="text",
    )

    deployment_name = st.text_input(
        "Nom du déploiement",
        value=f"IA GAME - {result['target']} - v1",
    )
    if st.button("Créer le déploiement DataRobot", type="primary"):
        try:
            with st.spinner("Création du déploiement DataRobot..."):
                deployment = dr.Deployment.create_from_learning_model(
                    model_id=result["model_id"],
                    label=deployment_name,
                    description="Déploiement IA GAME pour diagnostic de maintenance prédictive.",
                )
            st.session_state["deployment_id"] = str(deployment.id)
            st.success(f"Déploiement créé dans DataRobot : {deployment.id}")
        except Exception as exc:
            st.error(f"Création du déploiement impossible : {exc}")

    deployment_id = st.text_input(
        "Deployment ID DataRobot",
        value=st.session_state.get("deployment_id", ""),
        help="L'identifiant est renseigné automatiquement après création. Vous pouvez aussi saisir un déploiement existant.",
    )
    manifest = {
        "contract_version": "1.0",
        "provider": "DataRobot",
        "status": "deployment_required" if not deployment_id.strip() else "deployment_id_created_or_supplied_not_prediction_verified",
        **result,
        "deployment_id": deployment_id.strip() or None,
        "prediction_path": (
            f"/api/v2/deployments/{deployment_id.strip()}/predictions"
            if deployment_id.strip()
            else None
        ),
        "api_token_included": False,
    }
    st.download_button(
        "Exporter le manifeste du modèle",
        data=json.dumps(manifest, ensure_ascii=False, indent=2, default=str),
        file_name="ia-game-datarobot-model-manifest.json",
        mime="application/json",
        use_container_width=True,
    )
    if not deployment_id.strip():
        st.warning(
            "Le manifeste décrit le modèle entraîné, mais le jeu ne peut pas encore l'utiliser. "
            "Un déploiement DataRobot est nécessaire. Aucun jeton n'est exporté."
        )
