from __future__ import annotations

import io
import os
from pathlib import Path
from typing import Annotated

import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from pydantic import BaseModel

from ml_engine.pipeline import clean_dataframe, load_model, predict_rows, train_model

ARTIFACT_DIR = Path(os.getenv("IA_GAME_ARTIFACT_DIR", "artifacts"))
MODEL_PATH = ARTIFACT_DIR / "model.joblib"

app = FastAPI(
    title="IA GAME ML API",
    version="0.2.0",
    description="API de Machine Learning pour la simulation industrielle IA GAME",
)


class PredictRequest(BaseModel):
    rows: list[dict]


def read_csv_upload(content: bytes) -> pd.DataFrame:
    try:
        frame = pd.read_csv(io.BytesIO(content))
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"CSV illisible : {exc}") from exc
    if frame.empty:
        raise HTTPException(status_code=400, detail="Le fichier CSV est vide.")
    return frame


@app.get("/health")
def health() -> dict:
    return {
        "status": "ok",
        "service": "ia-game-ml",
        "model_available": MODEL_PATH.is_file(),
    }


@app.post("/datasets/preview")
async def preview_dataset(file: Annotated[UploadFile, File()]) -> dict:
    if not file.filename or not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Veuillez fournir un fichier .csv")
    frame = read_csv_upload(await file.read())
    cleaned, report = clean_dataframe(frame)
    preview = cleaned.head(10)
    return {
        "filename": file.filename,
        "rows_before": len(frame),
        "rows_after": len(cleaned),
        "columns": list(cleaned.columns),
        "missing_values": {str(k): int(v) for k, v in cleaned.isna().sum().items()},
        "report": report,
        "preview": preview.astype(object).where(pd.notna(preview), None).to_dict("records"),
    }


@app.post("/models/train")
async def train_endpoint(
    target: str,
    test_size: float = 0.2,
    random_state: int = 42,
    file: Annotated[UploadFile, File()] = ...,
) -> dict:
    if not file.filename or not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Veuillez fournir un fichier .csv")
    frame = read_csv_upload(await file.read())
    try:
        return train_model(frame, target, MODEL_PATH, test_size, random_state)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.post("/models/predict")
def predict_endpoint(request: PredictRequest) -> dict:
    if not MODEL_PATH.is_file():
        raise HTTPException(status_code=409, detail="Aucun modèle entraîné. Lancez /models/train.")
    try:
        model, metadata = load_model(MODEL_PATH)
        predictions = predict_rows(model, request.rows)
    except (ValueError, KeyError) as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return {"predictions": predictions, "model": metadata}
