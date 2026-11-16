import numpy as np
import pandas as pd
import pytest

from ml_engine.pipeline import clean_dataframe, load_model, predict_rows, train_model


def sample_data():
    rng = np.random.default_rng(7)
    n = 160
    temperature = rng.normal(70, 8, n)
    vibration = rng.normal(2, 0.5, n)
    failure = ((temperature > 73) & (vibration > 2)).astype(int)
    failure[:8] = 1
    frame = pd.DataFrame({
        "temperature": temperature,
        "vibration": vibration,
        "failure": failure,
    })
    frame.loc[2, "temperature"] = np.nan
    frame.loc[3, "vibration"] = np.inf
    frame.loc[4, "temperature"] = np.nan
    return frame


def test_clean_removes_duplicates_empty_columns_and_non_finite_values():
    frame = pd.DataFrame({
        "x": [1.0, 1.0, np.inf, 2.0],
        "empty": [None, None, None, None],
    })
    cleaned, report = clean_dataframe(frame)
    assert len(cleaned) == 3
    assert "empty" not in cleaned
    assert report["duplicate_rows_removed"] == 1
    assert report["non_finite_values_replaced"] == 1
    assert cleaned["x"].isna().sum() == 1


def test_clean_detects_numeric_text_and_missing_values():
    frame = pd.DataFrame({"temperature": ["21.5", "22.0", None], "kind": ["A", "B", "A"]})
    cleaned, report = clean_dataframe(frame)
    assert pd.api.types.is_numeric_dtype(cleaned["temperature"])
    assert "temperature" in report["numeric_columns_coerced"]
    assert report["missing_values_total"] == 1


def test_duplicate_column_names_are_rejected():
    frame = pd.DataFrame([[1, 2]], columns=["sensor", "sensor"])
    with pytest.raises(ValueError, match="dupliqués"):
        clean_dataframe(frame)


def test_train_and_predict_reports_imbalance_and_resources(tmp_path):
    path = tmp_path / "model.joblib"
    result = train_model(sample_data(), "failure", path, random_state=12)
    assert path.exists()
    assert result["task"] == "classification"
    assert 0 <= result["metrics"]["accuracy"] <= 1
    assert 0 <= result["metrics"]["balanced_accuracy"] <= 1
    assert 0 <= result["metrics"]["f1_macro"] <= 1
    assert "confusion_matrix" in result["metrics"]
    assert "per_class" in result["metrics"]
    assert "rss_after_mb" in result["resources"]
    assert result["prediction_latency_ms_per_row"] >= 0
    assert result["cleaning"]["missing_values_total"] >= 1
    model, metadata = load_model(path)
    predictions = predict_rows(model, [{"temperature": 90, "vibration": 3.2}])
    assert len(predictions) == 1
    assert metadata["target"] == "failure"


def test_missing_target_rejected(tmp_path):
    with pytest.raises(ValueError, match="cible absente"):
        train_model(sample_data(), "unknown", tmp_path / "model.joblib")


def test_single_class_target_rejected(tmp_path):
    frame = pd.DataFrame({"sensor": range(20), "failure": [0] * 20})
    with pytest.raises(ValueError, match="deux valeurs distinctes"):
        train_model(frame, "failure", tmp_path / "model.joblib")


def test_clean_rejects_headers_that_duplicate_after_trimming():
    frame = pd.DataFrame([[1, 2]], columns=["sensor", " sensor "])
    with pytest.raises(ValueError, match="après normalisation"):
        clean_dataframe(frame)


def test_clean_converts_string_infinity_to_missing():
    frame = pd.DataFrame({"measurement": ["1.2", "inf", "2.5"]})
    cleaned, report = clean_dataframe(frame)
    assert cleaned["measurement"].isna().sum() == 1
    assert report["non_finite_values_replaced"] == 1



def test_predict_uses_training_feature_schema_and_rejects_missing_sensors(tmp_path):
    path = tmp_path / "model.joblib"
    train_model(sample_data(), "failure", path, random_state=12)
    model, _ = load_model(path)

    # A game may send extra sensor fields; they must not break a model trained
    # on a smaller, explicitly defined feature set.
    prediction = predict_rows(
        model,
        [{"temperature": 90, "vibration": 3.2, "pressure": 5.1, "rpm": 1400}],
    )
    assert len(prediction) == 1

    with pytest.raises(ValueError, match="Variables capteurs absentes"):
        predict_rows(model, [{"temperature": 90}])



def test_clean_converts_whitespace_to_missing_and_reports_iqr_outliers():
    frame = pd.DataFrame({
        "temperature": [20.0, 21.0, 20.5, 22.0, 100.0],
        "category": ["A", "B", " ", "A", "B"],
    })
    cleaned, report = clean_dataframe(frame)
    assert cleaned["category"].isna().sum() == 1
    assert report["blank_strings_converted_to_missing"] == 1
    assert report["numeric_outliers_iqr_detected"]["temperature"] == 1
    # Statistical outliers are reported, not silently deleted: domain validation is required.
    assert len(cleaned) == 5
