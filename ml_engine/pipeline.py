from __future__ import annotations

import time
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import psutil
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.impute import SimpleImputer
from sklearn.metrics import (
    accuracy_score,
    average_precision_score,
    balanced_accuracy_score,
    confusion_matrix,
    f1_score,
    mean_absolute_error,
    mean_squared_error,
    precision_recall_fscore_support,
    precision_score,
    r2_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.utils.multiclass import type_of_target


def clean_dataframe(frame: pd.DataFrame) -> tuple[pd.DataFrame, dict]:
    """Nettoyage conservateur : ne supprime pas les valeurs extrêmes sans règle métier."""
    if frame.empty:
        raise ValueError("Le jeu de données est vide.")
    if frame.columns.duplicated().any():
        duplicates = frame.columns[frame.columns.duplicated()].astype(str).tolist()
        raise ValueError(f"Noms de colonnes dupliqués : {duplicates}")

    result = frame.copy()
    result.columns = [str(column).strip() for column in result.columns]
    if result.columns.duplicated().any():
        duplicates = result.columns[result.columns.duplicated()].astype(str).tolist()
        raise ValueError(f"Noms de colonnes dupliqués après normalisation : {duplicates}")
    if any(not column for column in result.columns):
        raise ValueError("Le CSV contient un nom de colonne vide.")
    before_rows = len(result)
    before_columns = len(result.columns)
    missing_before = {str(k): int(v) for k, v in result.isna().sum().items()}
    result = result.replace([np.inf, -np.inf], np.nan)
    non_finite_replaced = int(
        frame.select_dtypes(include=[np.number]).isin([np.inf, -np.inf]).sum().sum()
    )

    coerced_columns: list[str] = []
    for column in result.select_dtypes(include=["object", "string"]).columns:
        non_null = result[column].dropna()
        if non_null.empty:
            continue
        converted = pd.to_numeric(non_null.astype(str).str.replace(",", ".", regex=False), errors="coerce")
        # Convert only when almost every populated value is numeric; preserve categorical codes otherwise.
        if float(converted.notna().mean()) >= 0.95:
            result[column] = pd.to_numeric(
                result[column].astype("string").str.replace(",", ".", regex=False),
                errors="coerce",
            )
            coerced_columns.append(str(column))

    coerced_non_finite = int(
        result.select_dtypes(include=[np.number]).isin([np.inf, -np.inf]).sum().sum()
    )
    non_finite_replaced += coerced_non_finite
    result = result.replace([np.inf, -np.inf], np.nan)

    missing_after_coercion = {str(k): int(v) for k, v in result.isna().sum().items()}
    result = result.drop_duplicates().reset_index(drop=True)
    duplicates_removed = before_rows - len(result)
    empty_columns = [str(c) for c in result.columns[result.isna().all()]]
    result = result.drop(columns=empty_columns)
    missing_final = {str(k): int(v) for k, v in result.isna().sum().items()}
    constant_columns = [
        str(column) for column in result.columns if result[column].nunique(dropna=True) <= 1
    ]
    return result, {
        "rows_before": int(before_rows),
        "rows_after": len(result),
        "columns_before": int(before_columns),
        "columns_after": len(result.columns),
        "duplicate_rows_removed": int(duplicates_removed),
        "empty_columns_removed": empty_columns,
        "constant_columns_detected": constant_columns,
        "numeric_columns_coerced": coerced_columns,
        "non_finite_values_replaced": non_finite_replaced,
        "missing_values_before": missing_before,
        "missing_values_after_coercion": missing_after_coercion,
        "missing_values_after_cleaning": missing_final,
        "missing_values_total": int(sum(missing_final.values())),
    }


def _resource_snapshot() -> dict:
    process = psutil.Process()
    memory = process.memory_info().rss / (1024 * 1024)
    cpu_times = process.cpu_times()
    return {"rss_mb": float(memory), "cpu_seconds": float(cpu_times.user + cpu_times.system)}


def train_model(
    frame: pd.DataFrame,
    target: str,
    model_path: Path,
    test_size: float = 0.2,
    random_state: int = 42,
) -> dict:
    if not 0.1 <= test_size <= 0.5:
        raise ValueError("test_size doit être compris entre 0.1 et 0.5.")
    started = time.perf_counter()
    resources_before = _resource_snapshot()
    data, cleaning = clean_dataframe(frame)
    if target not in data.columns:
        raise ValueError(f"Colonne cible absente : {target}")
    target_missing = int(data[target].isna().sum())
    data = data.dropna(subset=[target]).reset_index(drop=True)
    if len(data) < 10:
        raise ValueError("Au moins 10 lignes avec une cible connue sont nécessaires.")
    X = data.drop(columns=[target])
    y = data[target]
    if X.shape[1] == 0:
        raise ValueError("Aucune colonne explicative disponible.")
    if y.nunique() < 2:
        raise ValueError("La cible doit contenir au moins deux valeurs distinctes.")

    classification = type_of_target(y) in {"binary", "multiclass"}
    class_distribution = {str(k): int(v) for k, v in y.value_counts(dropna=False).items()} if classification else {}
    minimum_class_count = min(class_distribution.values()) if classification else 0
    stratify = y if classification and minimum_class_count >= 2 else None
    if stratify is not None and int(np.ceil(len(y) * test_size)) < y.nunique():
        raise ValueError("Le jeu de test est trop petit pour contenir toutes les classes. Augmentez test_size.")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=test_size, random_state=random_state, stratify=stratify
    )
    numeric = X.select_dtypes(include=["number", "bool"]).columns.tolist()
    categorical = [column for column in X.columns if column not in numeric]
    transformers = []
    if numeric:
        transformers.append(
            ("numeric", Pipeline([
                ("imputer", SimpleImputer(strategy="median")),
                ("scaler", StandardScaler()),
            ]), numeric)
        )
    if categorical:
        transformers.append(
            ("categorical", Pipeline([
                ("imputer", SimpleImputer(strategy="most_frequent")),
                ("encoder", OneHotEncoder(handle_unknown="ignore")),
            ]), categorical)
        )
    preprocessing = ColumnTransformer(transformers=transformers)
    estimator = (
        RandomForestClassifier(
            n_estimators=200, random_state=random_state, n_jobs=-1, class_weight="balanced"
        )
        if classification
        else RandomForestRegressor(n_estimators=200, random_state=random_state, n_jobs=-1)
    )
    pipeline = Pipeline([("preprocessing", preprocessing), ("model", estimator)])
    pipeline.fit(X_train, y_train)
    predictions = pipeline.predict(X_test)

    if classification:
        precision_macro = precision_score(y_test, predictions, average="macro", zero_division=0)
        recall_macro = recall_score(y_test, predictions, average="macro", zero_division=0)
        f1_macro = f1_score(y_test, predictions, average="macro", zero_division=0)
        precision_weighted = precision_score(y_test, predictions, average="weighted", zero_division=0)
        recall_weighted = recall_score(y_test, predictions, average="weighted", zero_division=0)
        f1_weighted = f1_score(y_test, predictions, average="weighted", zero_division=0)
        labels = list(pipeline.named_steps["model"].classes_)
        per_precision, per_recall, per_f1, per_support = precision_recall_fscore_support(
            y_test, predictions, labels=labels, zero_division=0
        )
        metrics = {
            "accuracy": float(accuracy_score(y_test, predictions)),
            "balanced_accuracy": float(balanced_accuracy_score(y_test, predictions)),
            "precision_macro": float(precision_macro),
            "recall_macro": float(recall_macro),
            "f1_macro": float(f1_macro),
            "precision_weighted": float(precision_weighted),
            "recall_weighted": float(recall_weighted),
            "f1_weighted": float(f1_weighted),
            "confusion_matrix": confusion_matrix(y_test, predictions, labels=labels).tolist(),
            "class_labels": [str(label) for label in labels],
            "per_class": {
                str(label): {
                    "precision": float(per_precision[index]),
                    "recall": float(per_recall[index]),
                    "f1": float(per_f1[index]),
                    "support": int(per_support[index]),
                }
                for index, label in enumerate(labels)
            },
        }
        if len(labels) == 2 and hasattr(pipeline, "predict_proba"):
            probabilities = pipeline.predict_proba(X_test)[:, 1]
            positive_label = labels[1]
            binary_truth = (y_test == positive_label).astype(int)
            if binary_truth.nunique() == 2:
                metrics["pr_auc"] = float(average_precision_score(binary_truth, probabilities))
                metrics["roc_auc"] = float(roc_auc_score(binary_truth, probabilities))
        task = "classification"
    else:
        mse = mean_squared_error(y_test, predictions)
        metrics = {
            "mae": float(mean_absolute_error(y_test, predictions)),
            "rmse": float(np.sqrt(mse)),
            "r2": float(r2_score(y_test, predictions)),
        }
        task = "regression"

    prediction_started = time.perf_counter()
    pipeline.predict(X_test)
    prediction_seconds = time.perf_counter() - prediction_started
    resources_after = _resource_snapshot()
    training_seconds = time.perf_counter() - started
    metadata = {
        "task": task,
        "target": target,
        "features": list(X.columns),
        "metrics": metrics,
        "train_rows": len(X_train),
        "test_rows": len(X_test),
        "random_state": int(random_state),
        "test_size": float(test_size),
        "training_seconds": round(training_seconds, 6),
        "prediction_seconds_total": round(prediction_seconds, 6),
        "prediction_latency_ms_per_row": round(prediction_seconds * 1000 / max(len(X_test), 1), 6),
        "resources": {
            "rss_before_mb": round(resources_before["rss_mb"], 3),
            "rss_after_mb": round(resources_after["rss_mb"], 3),
            "rss_delta_mb": round(resources_after["rss_mb"] - resources_before["rss_mb"], 3),
            "cpu_seconds_delta": round(resources_after["cpu_seconds"] - resources_before["cpu_seconds"], 6),
        },
        "cleaning": cleaning,
        "target_missing_rows_removed": target_missing,
        "class_distribution": class_distribution,
        "stratified_split": bool(stratify is not None),
        "imbalance_ratio": (
            round(max(class_distribution.values()) / min(class_distribution.values()), 3)
            if classification and minimum_class_count else None
        ),
    }
    model_path.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump({"pipeline": pipeline, "metadata": metadata}, model_path)
    return metadata


def load_model(model_path: Path):
    payload = joblib.load(model_path)
    return payload["pipeline"], payload["metadata"]


def predict_rows(model, rows: list[dict]) -> list:
    if not rows:
        raise ValueError("La liste rows ne doit pas être vide.")
    frame = pd.DataFrame(rows)
    expected_features = list(getattr(model, "feature_names_in_", []))
    if expected_features:
        missing_features = [name for name in expected_features if name not in frame.columns]
        if missing_features:
            raise ValueError(
                "Variables capteurs absentes pour ce modèle : "
                + ", ".join(str(name) for name in missing_features)
            )
        # The game can provide a superset of sensors. Select the exact training schema
        # and preserve its order; never fabricate missing sensor measurements.
        frame = frame.loc[:, expected_features]
    predictions = model.predict(frame)
    return [value.item() if hasattr(value, "item") else value for value in predictions]
