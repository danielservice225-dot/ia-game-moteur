from pathlib import Path

import numpy as np
import pandas as pd

rng = np.random.default_rng(2026)
n = 500

machine_type = rng.choice(["L", "M", "H"], size=n, p=[0.5, 0.3, 0.2])
air_temperature = rng.normal(300.0, 2.0, n)
process_temperature = air_temperature + rng.normal(10.0, 1.5, n)
rotational_speed = rng.normal(1538.0, 180.0, n).clip(900.0, 2800.0)
torque = rng.normal(40.0, 10.0, n).clip(3.0, 75.0)
tool_wear = rng.integers(0, 253, n)

machine_failure = (
    ((tool_wear > 185) & (torque > 45.0))
    | ((process_temperature - air_temperature > 12.5) & (torque > 48.0))
    | ((rotational_speed < 1150.0) & (torque > 55.0))
).astype(int)

df = pd.DataFrame(
    {
        "Type": machine_type,
        "Air temperature [K]": air_temperature.round(2),
        "Process temperature [K]": process_temperature.round(2),
        "Rotational speed [rpm]": rotational_speed.round(1),
        "Torque [Nm]": torque.round(2),
        "Tool wear [min]": tool_wear,
        "Machine failure": machine_failure,
    }
)

Path("data").mkdir(exist_ok=True)
df.to_csv("data/demo_industrial.csv", index=False)
print("Dataset de démonstration synthétique compatible AI4I créé : data/demo_industrial.csv (500 lignes)")
