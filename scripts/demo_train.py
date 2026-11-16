from pathlib import Path

import pandas as pd

from ml_engine.pipeline import train_model

result = train_model(
    pd.read_csv("data/demo_industrial.csv"),
    target="failure",
    model_path=Path("artifacts/demo_model.joblib"),
    random_state=42,
)
print(result)
