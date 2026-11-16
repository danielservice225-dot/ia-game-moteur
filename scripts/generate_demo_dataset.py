from pathlib import Path

import numpy as np
import pandas as pd

rng = np.random.default_rng(2026)
n = 500
temperature = rng.normal(70, 9, n)
vibration = rng.normal(2.0, 0.7, n)
pressure = rng.normal(5.0, 0.4, n)
failure = (
    ((temperature > 78) & (vibration > 2.3)) | (pressure < 4.4)
).astype(int)
df = pd.DataFrame(
    {
        "temperature_c": temperature.round(2),
        "vibration_mm_s": vibration.round(3),
        "pressure_bar": pressure.round(3),
        "failure": failure,
    }
)
Path("data").mkdir(exist_ok=True)
df.to_csv("data/demo_industrial.csv", index=False)
print("Dataset synthétique créé : data/demo_industrial.csv (500 lignes)")
