import numpy as np
import pandas as pd
import pytest

from ml_engine.pipeline import clean_dataframe, load_model, predict_rows, train_model


def sample_data():
    rng = np.random.default_rng(7)
    n = 80
    temperature = rng.normal(70, 8, n)
    vibration = rng.normal(2, 0.5, n)
    failure = ((temperature > 73) & (vibration > 2)).astype(int)
    return pd.DataFrame({"temperature": temperature, "vibration": vibration, "failure": failure})


def test_clean_removes_duplicates_and_empty_columns():
    frame = pd.DataFrame({"x": [1, 1, 2], "empty": [None, None, None]})
    cleaned, report = clean_dataframe(frame)
    assert len(cleaned) == 2
    assert "empty" not in cleaned
    assert report["duplicate_rows_removed"] == 1


def test_train_and_predict(tmp_path):
    path = tmp_path / "model.joblib"
    result = train_model(sample_data(), "failure", path, random_state=12)
    assert path.exists()
    assert result["task"] == "classification"
    assert 0 <= result["metrics"]["accuracy"] <= 1
    model, metadata = load_model(path)
    predictions = predict_rows(model, [{"temperature": 90, "vibration": 3.2}])
    assert len(predictions) == 1
    assert metadata["target"] == "failure"


def test_missing_target_rejected(tmp_path):
    with pytest.raises(ValueError, match="cible absente"):
        train_model(sample_data(), "unknown", tmp_path / "model.joblib")
