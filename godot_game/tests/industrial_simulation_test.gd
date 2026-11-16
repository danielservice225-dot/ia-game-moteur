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

    print("PASS: 8 contrôles de simulation industrielle Godot.")
    quit(0)

func _definitions() -> Array[Dictionary]:
    return [
        {"name": "Presse hydraulique", "code": "P-01", "running": true, "temperature": 86.0, "vibration": 3.1, "pressure": 4.1},
        {"name": "Pompe centrifuge", "code": "M-02", "running": true, "temperature": 68.0, "vibration": 2.4, "pressure": 5.2},
        {"name": "Compresseur industriel", "code": "C-03", "running": true, "temperature": 74.0, "vibration": 2.8, "pressure": 7.0},
        {"name": "Convoyeur motorisé", "code": "CV-04", "running": true, "temperature": 52.0, "vibration": 1.8, "pressure": 2.2}
    ]

func _expect(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error("FAIL: " + message)
    quit(1)
    return false
