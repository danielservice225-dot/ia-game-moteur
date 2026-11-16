import numpy as np
import pandas as pd
from fastapi.testclient import TestClient

import backend.main as main
from backend.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_preview_csv():
    response = client.post(
        "/datasets/preview",
        files={"file": ("data.csv", b"x,y\n1,2\n1,2\n3,4\n", "text/csv")},
    )
    assert response.status_code == 200
    assert response.json()["rows_before"] == 3
    assert response.json()["rows_after"] == 2


def test_train_then_predict_through_api(tmp_path, monkeypatch):
    monkeypatch.setattr(main, "MODEL_PATH", tmp_path / "model.joblib")
    rng = np.random.default_rng(11)
    temperature = rng.normal(70, 8, 100)
    vibration = rng.normal(2, 0.6, 100)
    failure = ((temperature > 72) & (vibration > 2)).astype(int)
    csv_data = pd.DataFrame(
        {
            "temperature_c": temperature,
            "vibration_mm_s": vibration,
            "failure": failure,
        }
    ).to_csv(index=False).encode()

    trained = client.post(
        "/models/train?target=failure",
        files={"file": ("industrial.csv", csv_data, "text/csv")},
    )
    assert trained.status_code == 200, trained.text
    assert trained.json()["test_rows"] > 0
    assert main.MODEL_PATH.exists()

    prediction = client.post(
        "/models/predict",
        json={"rows": [{"temperature_c": 90, "vibration_mm_s": 3.0}]},
    )
    assert prediction.status_code == 200, prediction.text
    assert len(prediction.json()["predictions"]) == 1
