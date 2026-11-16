extends Node
# Simulation déterministe de capteurs et d'états d'équipements.
# Les mesures sont des signaux de démonstration, pas des données certifiées d'usine réelle.

signal machine_state_changed(index: int, state: String)
signal production_count_changed(total: int)

const STATE_RUNNING := "RUNNING"
const STATE_STOPPED := "STOPPED"
const STATE_FAULT := "FAULT"
const STATE_MAINTENANCE := "MAINTENANCE"

var machines: Array[Dictionary] = []
var elapsed := 0.0
var production_units := 0
var _production_clock := 0.0

func configure(definitions: Array[Dictionary]) -> void:
    machines.clear()
    for definition in definitions:
        machines.append({
            "name": str(definition.get("name", "Équipement")),
            "code": str(definition.get("code", "M-00")),
            "state": STATE_RUNNING if bool(definition.get("running", true)) else STATE_STOPPED,
            "running": bool(definition.get("running", true)),
            "base_temperature": float(definition.get("temperature", 60.0)),
            "base_vibration": float(definition.get("vibration", 1.5)),
            "base_pressure": float(definition.get("pressure", 5.0)),
            "temperature_c": float(definition.get("temperature", 60.0)),
            "vibration_mm_s": float(definition.get("vibration", 1.5)),
            "pressure_bar": float(definition.get("pressure", 5.0)),
            "load_pct": 0.0,
            "rpm": 0.0,
            "fault_latched": false
        })

func advance(delta: float) -> void:
    elapsed += delta
    for index in range(machines.size()):
        var machine: Dictionary = machines[index]
        if bool(machine["running"]):
            var phase := elapsed * 0.7 + float(index) * 1.37
            var load := clampf(0.62 + sin(phase) * 0.12, 0.25, 0.92)
            machine["load_pct"] = load * 100.0
            machine["rpm"] = 1450.0 * load
            var target_temperature := float(machine["base_temperature"]) + load * 8.0 + sin(phase * 0.4) * 1.2
            machine["temperature_c"] = move_toward(float(machine["temperature_c"]), target_temperature, delta * 0.9)
            machine["vibration_mm_s"] = float(machine["base_vibration"]) + load * 0.55 + abs(sin(phase * 1.8)) * 0.18
            machine["pressure_bar"] = maxf(0.0, float(machine["base_pressure"]) + sin(phase * 0.6) * 0.12)
        else:
            machine["load_pct"] = 0.0
            machine["rpm"] = 0.0
            machine["temperature_c"] = move_toward(float(machine["temperature_c"]), 27.0, delta * 0.22)
            machine["vibration_mm_s"] = move_toward(float(machine["vibration_mm_s"]), 0.0, delta * 0.8)
            if str(machine["state"]) != STATE_FAULT:
                machine["pressure_bar"] = move_toward(float(machine["pressure_bar"]), 0.0, delta * 0.5)
        if bool(machine["running"]) and (
            float(machine["temperature_c"]) >= 108.0
            or float(machine["vibration_mm_s"]) >= 7.5
            or float(machine["pressure_bar"]) <= 1.0
        ):
            _set_state(index, STATE_FAULT)
            machine["fault_latched"] = true
        machines[index] = machine
    if machines.size() > 3 and bool(machines[3]["running"]):
        _production_clock += delta
        while _production_clock >= 1.0:
            _production_clock -= 1.0
            production_units += 1
            production_count_changed.emit(production_units)

func toggle_machine(index: int) -> bool:
    if not _valid_index(index):
        return false
    var machine: Dictionary = machines[index]
    if bool(machine["fault_latched"]):
        return false
    _set_state(index, STATE_STOPPED if bool(machine["running"]) else STATE_RUNNING)
    return bool(machines[index]["running"])

func inject_fault(index: int) -> void:
    if not _valid_index(index):
        return
    var machine: Dictionary = machines[index]
    machine["temperature_c"] = maxf(float(machine["temperature_c"]), 112.0)
    machine["vibration_mm_s"] = maxf(float(machine["vibration_mm_s"]), 8.2)
    machine["pressure_bar"] = minf(float(machine["pressure_bar"]), 0.6)
    machine["fault_latched"] = true
    machines[index] = machine
    _set_state(index, STATE_FAULT)

func perform_maintenance(index: int) -> bool:
    if not _valid_index(index):
        return false
    var machine: Dictionary = machines[index]
    if not bool(machine["fault_latched"]) and bool(machine["running"]):
        return false
    _set_state(index, STATE_MAINTENANCE)
    machine = machines[index]
    machine["fault_latched"] = false
    machine["temperature_c"] = float(machine["base_temperature"])
    machine["vibration_mm_s"] = float(machine["base_vibration"])
    machine["pressure_bar"] = float(machine["base_pressure"])
    machines[index] = machine
    _set_state(index, STATE_RUNNING)
    return true

func get_snapshot(index: int) -> Dictionary:
    if not _valid_index(index):
        return {}
    return machines[index].duplicate(true)

func get_sensor_payload(index: int) -> Dictionary:
    if not _valid_index(index):
        return {}
    var machine: Dictionary = machines[index]
    return {
        "temperature_c": snappedf(float(machine["temperature_c"]), 0.01),
        "vibration_mm_s": snappedf(float(machine["vibration_mm_s"]), 0.001),
        "pressure_bar": snappedf(float(machine["pressure_bar"]), 0.001)
    }

func _set_state(index: int, state: String) -> void:
    if not _valid_index(index):
        return
    var machine: Dictionary = machines[index]
    machine["state"] = state
    machine["running"] = state == STATE_RUNNING
    machines[index] = machine
    machine_state_changed.emit(index, state)

func _valid_index(index: int) -> bool:
    return index >= 0 and index < machines.size()
