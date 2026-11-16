from __future__ import annotations

import time
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.impute import SimpleImputer
from sklearn.metrics import (
    accuracy_score, f1_score, mean_absolute_error, mean_squared_error, r2_score,
    precision_score, recall_score,
)
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.utils.multiclass import type_of_target


def clean_dataframe(frame: pd.DataFrame) -> tuple[pd.DataFrame, dict]:
    if frame.empty:
        raise ValueError("Le jeu de données est vide.")
    result = frame.copy()
    before = len(result)
    result = result.drop_duplicates().reset_index(drop=True)
    dropped = before - len(result)
    # Les colonnes entièrement vides ne portent aucune information exploitable.
    empty_columns = [str(c) for c in result.columns[result.isna().all()]]
    result = result.drop(columns=empty_columns)
    return result, {"duplicate_rows_removed": int(dropped), "empty_columns_removed": empty_columns}


def train_model(
    frame: pd.DataFrame,
    target: str,
    model_path: Path,
    test_size: float = 0.2,
    random_state: int = 42,
) -> dict:
    started = time.perf_counter()
    data, cleaning = clean_dataframe(frame)
    if target not in data.columns:
        raise ValueError(f"Colonne cible absente : {target}")
    data = data.dropna(subset=[target])
    if len(data) < 10:
        raise ValueError("Au moins 10 lignes avec une cible connue sont nécessaires.")
    X = data.drop(columns=[target])
    y = data[target]
    if X.shape[1] == 0:
        raise ValueError("Aucune colonne explicative disponible.")
    if y.nunique() < 2:
        raise ValueError("La cible doit contenir au moins deux valeurs distinctes.")

    kind = type_of_target(y)
    classification = kind in {"binary", "multiclass"}
    stratify = y if classification and y.value_counts().min() >= 2 else None
    if stratify is not None and y.value_counts().min() < 2:
        stratify = None
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=test_size, random_state=random_state, stratify=stratify
    )

    numeric = X.select_dtypes(include=["number", "bool"]).columns.tolist()
    categorical = [c for c in X.columns if c not in numeric]
    transformers = []
    if numeric:
        transformers.append(("numeric", Pipeline([
            ("imputer", SimpleImputer(strategy="median")),
            ("scaler", StandardScaler()),
        ]), numeric))
    if categorical:
        transformers.append(("categorical", Pipeline([
            ("imputer", SimpleImputer(strategy="most_frequent")),
            ("encoder", OneHotEncoder(handle_unknown="ignore")),
        ]), categorical))
    preprocessing = ColumnTransformer(transformers=transformers)
    estimator = (
        RandomForestClassifier(n_estimators=150, random_state=random_state, n_jobs=-1,
                               class_weight="balanced")
        if classification else
        RandomForestRegressor(n_estimators=150, random_state=random_state, n_jobs=-1)
    )
    pipeline = Pipeline([("preprocessing", preprocessing), ("model", estimator)])
    pipeline.fit(X_train, y_train)
    predictions = pipeline.predict(X_test)

    if classification:
        metrics = {
            "accuracy": float(accuracy_score(y_test, predictions)),
            "precision_weighted": float(precision_score(y_test, predictions, average="weighted", zero_division=0)),
            "recall_weighted": float(recall_score(y_test, predictions, average="weighted", zero_division=0)),
            "f1_weighted": float(f1_score(y_test, predictions, average="weighted", zero_division=0)),
        }
        task = "classification"
    else:
        mse = mean_squared_error(y_test, predictions)
        metrics = {
            "mae": float(mean_absolute_error(y_test, predictions)),
            "rmse": float(np.sqrt(mse)),
            "r2": float(r2_score(y_test, predictions)),
        }
        task = "regression"

    model_path.parent.mkdir(parents=True, exist_ok=True)
    metadata = {
        "task": task, "target": target, "features": list(X.columns),
        "metrics": metrics, "train_rows": int(len(X_train)), "test_rows": int(len(X_test)),
        "random_state": random_state, "test_size": test_size,
        "cleaning": cleaning,
    }
    joblib.dump({"pipeline": pipeline, "metadata": metadata}, model_path)
    metadata["training_seconds"] = round(time.perf_counter() - started, 6)
    return metadata


def load_model(model_path: Path):
    payload = joblib.load(model_path)
    return payload["pipeline"], payload["metadata"]


def predict_rows(model, rows: list[dict]) -> list:
    if not rows:
        raise ValueError("La liste rows ne doit pas être vide.")
    frame = pd.DataFrame(rows)
    predictions = model.predict(frame)
    return [v.item() if hasattr(v, "item") else v for v in predictions]
