import numpy as np
import pandas as pd
from fastapi.testclient import TestClient

from backend import main
from backend.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_preview_csv_reports_missing_and_duplicate_data():
    response = client.post(
        "/datasets/preview",
        files={"file": ("data.csv", b"x,y\n1,2\n1,2\n3,\n", "text/csv")},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["rows_before"] == 3
    assert payload["rows_after"] == 2
    assert payload["report"]["duplicate_rows_removed"] == 1
    assert payload["report"]["missing_values_total"] == 1


def test_train_then_predict_and_export_report_through_api(tmp_path, monkeypatch):
    monkeypatch.setattr(main, "MODEL_PATH", tmp_path / "model.joblib")
    monkeypatch.setattr(main, "REPORT_DIR", tmp_path / "reports")
    monkeypatch.setattr(main, "HISTORY_PATH", tmp_path / "reports" / "history.json")
    rng = np.random.default_rng(11)
    temperature = rng.normal(70, 8, 160)
    vibration = rng.normal(2, 0.6, 160)
    failure = ((temperature > 72) & (vibration > 2)).astype(int)
    failure[:8] = 1
    csv_data = pd.DataFrame({
        "temperature_c": temperature,
        "vibration_mm_s": vibration,
        "failure": failure,
    }).to_csv(index=False).encode()

    trained = client.post(
        "/models/train?target=failure",
        files={"file": ("industrial.csv", csv_data, "text/csv")},
    )
    assert trained.status_code == 200, trained.text
    report = trained.json()
    assert report["test_rows"] > 0
    assert report["report_id"]
    assert report["metrics"]["balanced_accuracy"] >= 0
    assert main.MODEL_PATH.exists()

    history = client.get("/models/history")
    assert history.status_code == 200
    assert history.json()["count"] == 1
    assert history.json()["items"][0]["report_id"] == report["report_id"]

    detailed = client.get(report["report_url"])
    assert detailed.status_code == 200
    assert detailed.json()["source_filename"] == "industrial.csv"

    exported = client.get(report["export_url"])
    assert exported.status_code == 200
    assert "attachment;" in exported.headers["content-disposition"]

    prediction = client.post(
        "/models/predict",
        json={"rows": [{"temperature_c": 90, "vibration_mm_s": 3.0}]},
    )
    assert prediction.status_code == 200, prediction.text
    assert len(prediction.json()["predictions"]) == 1
    assert prediction.json()["performance"]["latency_ms"] >= 0
