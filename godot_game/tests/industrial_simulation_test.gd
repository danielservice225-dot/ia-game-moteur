extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var simulation_script: Script = load("res://scripts/industrial_simulation.gd")
    var simulation: Node = simulation_script.new()
    root.add_child(simulation)
    simulation.call("configure", _definitions())

    var snapshot: Dictionary = simulation.call("get_snapshot", 0)
    if not _expect(snapshot.get("state") == "RUNNING", "Une machine démarre en RUNNING."):
        return
    var healthy_payload: Dictionary = simulation.call("get_sensor_payload", 0)
    if not _expect(
        float(healthy_payload["temperature_c"]) < 78.0
        and float(healthy_payload["vibration_mm_s"]) < 2.3
        and float(healthy_payload["pressure_bar"]) > 4.4,
        "Les mesures initiales correspondent à un état nominal du dataset de démonstration."
    ):
        return

    var stopped: bool = simulation.call("toggle_machine", 0)
    if not _expect(not stopped, "La touche F logique arrête la machine."):
        return
    snapshot = simulation.call("get_snapshot", 0)
    if not _expect(snapshot.get("state") == "STOPPED", "L'état STOPPED est enregistré."):
        return

    var restarted: bool = simulation.call("toggle_machine", 0)
    if not _expect(restarted, "Une machine arrêtée peut redémarrer."):
        return

    simulation.call("inject_fault", 0)
    snapshot = simulation.call("get_snapshot", 0)
    if not _expect(snapshot.get("state") == "FAULT", "Une panne simulée verrouille la machine."):
        return
    if not _expect(float(snapshot.get("temperature_c", 0.0)) >= 112.0, "La panne dégrade la température."):
        return
    var blocked_restart: bool = simulation.call("toggle_machine", 0)
    if not _expect(not blocked_restart, "Une machine en panne ne redémarre pas sans maintenance."):
        return

    var repaired: bool = simulation.call("perform_maintenance", 0)
    if not _expect(repaired, "La maintenance répare la machine en panne."):
        return
    snapshot = simulation.call("get_snapshot", 0)
    if not _expect(snapshot.get("state") == "RUNNING", "Après maintenance, la machine revient en RUNNING."):
        return

    simulation.call("advance", 2.2)
    if not _expect(int(simulation.get("production_units")) >= 2, "Le convoyeur incrémente le compteur de production."):
        return
    var payload: Dictionary = simulation.call("get_sensor_payload", 0)
    if not _expect(
        payload.has("temperature_c") and payload.has("vibration_mm_s") and payload.has("pressure_bar"),
        "Le jeu expose les trois capteurs attendus par le modèle ML."
    ):
        return

    print("PASS: contrôles de simulation industrielle terminés.")
    quit(0)

func _definitions() -> Array[Dictionary]:
    return [
        {"name": "Presse hydraulique", "code": "P-01", "running": true, "temperature": 74.0, "vibration": 1.8, "pressure": 5.0},
        {"name": "Pompe centrifuge", "code": "M-02", "running": true, "temperature": 66.0, "vibration": 1.6, "pressure": 5.5},
        {"name": "Compresseur industriel", "code": "C-03", "running": true, "temperature": 70.0, "vibration": 1.9, "pressure": 6.8},
        {"name": "Convoyeur motorisé", "code": "CV-04", "running": true, "temperature": 48.0, "vibration": 1.2, "pressure": 5.0}
    ]

func _expect(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error("FAIL: " + message)
    quit(1)
    return false
