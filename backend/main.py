from __future__ import annotations

import io
import json
import os
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Annotated

import pandas as pd
import psutil
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import Response
from pydantic import BaseModel

from ml_engine.pipeline import clean_dataframe, load_model, predict_rows, train_model

ARTIFACT_DIR = Path(os.getenv("IA_GAME_ARTIFACT_DIR", "artifacts"))
MODEL_PATH = ARTIFACT_DIR / "model.joblib"
REPORT_DIR = ARTIFACT_DIR / "reports"
HISTORY_PATH = REPORT_DIR / "history.json"

app = FastAPI(
    title="IA GAME ML API",
    version="0.3.0",
    description="API locale de Machine Learning, rapports et télémétrie pour IA GAME",
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


def _read_history() -> list[dict]:
    if not HISTORY_PATH.is_file():
        return []
    try:
        value = json.loads(HISTORY_PATH.read_text(encoding="utf-8"))
        return value if isinstance(value, list) else []
    except (OSError, json.JSONDecodeError):
        return []


def _write_report(metadata: dict) -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    report_id = str(metadata["report_id"])
    report_path = REPORT_DIR / f"{report_id}.json"
    report_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    history = _read_history()
    history.insert(0, {
        "report_id": report_id,
        "created_at": metadata["created_at"],
        "source_filename": metadata["source_filename"],
        "target": metadata["target"],
        "task": metadata["task"],
        "metrics": metadata["metrics"],
        "training_seconds": metadata["training_seconds"],
        "report_url": f"/models/reports/{report_id}",
        "export_url": f"/models/reports/{report_id}/export",
    })
    HISTORY_PATH.write_text(
        json.dumps(history[:100], ensure_ascii=False, indent=2), encoding="utf-8"
    )


@app.get("/health")
def health() -> dict:
    return {
        "status": "ok",
        "service": "ia-game-ml",
        "model_available": MODEL_PATH.is_file(),
        "history_available": HISTORY_PATH.is_file(),
    }


@app.post("/datasets/preview")
async def preview_dataset(file: Annotated[UploadFile, File()]) -> dict:
    if not file.filename or not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Veuillez fournir un fichier .csv")
    frame = read_csv_upload(await file.read())
    try:
        cleaned, report = clean_dataframe(frame)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
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
        metadata = train_model(frame, target, MODEL_PATH, test_size, random_state)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    metadata.update({
        "report_id": uuid.uuid4().hex,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "source_filename": file.filename,
        "report_url": "",
        "export_url": "",
    })
    metadata["report_url"] = f"/models/reports/{metadata['report_id']}"
    metadata["export_url"] = f"/models/reports/{metadata['report_id']}/export"
    _write_report(metadata)
    return metadata


@app.get("/models/history")
def model_history() -> dict:
    return {"count": len(_read_history()), "items": _read_history()}


@app.get("/models/reports/{report_id}")
def get_training_report(report_id: str) -> dict:
    if not report_id.isalnum():
        raise HTTPException(status_code=400, detail="Identifiant de rapport invalide.")
    path = REPORT_DIR / f"{report_id}.json"
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Rapport introuvable.")
    return json.loads(path.read_text(encoding="utf-8"))


@app.get("/models/reports/{report_id}/export")
def export_training_report(report_id: str) -> Response:
    report = get_training_report(report_id)
    payload = json.dumps(report, ensure_ascii=False, indent=2)
    return Response(
        content=payload,
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="ia-game-report-{report_id}.json"'},
    )


@app.post("/models/predict")
def predict_endpoint(request: PredictRequest) -> dict:
    if not MODEL_PATH.is_file():
        raise HTTPException(status_code=409, detail="Aucun modèle entraîné. Lancez /models/train.")
    try:
        model, metadata = load_model(MODEL_PATH)
        process = psutil.Process()
        memory_before_mb = process.memory_info().rss / (1024 * 1024)
        cpu_before = process.cpu_times()
        started = time.perf_counter()
        predictions = predict_rows(model, request.rows)
        latency_seconds = time.perf_counter() - started
        memory_after_mb = process.memory_info().rss / (1024 * 1024)
        cpu_after = process.cpu_times()
    except (ValueError, KeyError) as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return {
        "predictions": predictions,
        "model": metadata,
        "performance": {
            "latency_ms": round(latency_seconds * 1000, 6),
            "latency_ms_per_row": round(latency_seconds * 1000 / max(len(request.rows), 1), 6),
            "process_rss_before_mb": round(memory_before_mb, 3),
            "process_rss_after_mb": round(memory_after_mb, 3),
            "cpu_seconds": round(
                (cpu_after.user + cpu_after.system) - (cpu_before.user + cpu_before.system), 6
            ),
        },
    }
