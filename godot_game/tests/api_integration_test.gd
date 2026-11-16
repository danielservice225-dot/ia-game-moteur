extends SceneTree

const API_URL := "http://127.0.0.1:8000"

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var panel: Node = root.get_node_or_null("DatasetImportPanel")
    if panel == null:
        panel = load("res://scripts/dataset_import_panel.gd").new()
        root.add_child(panel)
        await process_frame

    var csv_text := "Type,Air temperature [K],Process temperature [K],Rotational speed [rpm],Torque [Nm],Tool wear [min],Machine failure\n"
    for index in range(120):
        var failure := 1 if index % 6 == 0 else 0
        var air_temperature := 296.0 + float(index % 13) * 0.4
        var process_temperature := air_temperature + 10.0 + float(index % 4) * 0.2
        var rpm := 1400 + (index % 11) * 25
        var torque := 62.0 + float(index % 5) if failure == 1 else 34.0 + float(index % 7)
        var tool_wear := float(index % 240)
        var torque_cell := "" if index % 31 == 0 else "%.2f" % torque
        csv_text += "M,%.2f,%.2f,%d,%s,%.1f,%d\n" % [
            air_temperature, process_temperature, rpm, torque_cell, tool_wear, failure
        ]

    var csv_file := FileAccess.open("user://ia-game-e2e.csv", FileAccess.WRITE)
    if not _expect(csv_file != null, "Impossible de créer le CSV de test dans Godot."):
        return
    csv_file.store_string(csv_text)
    csv_file.close()
    var csv_path := ProjectSettings.globalize_path("user://ia-game-e2e.csv")

    panel.call("_on_file_selected", csv_path)
    var http: HTTPRequest = panel.get("http")
    var preview_response: Array = await http.request_completed
    if not _expect(
        int(preview_response[0]) == HTTPRequest.RESULT_SUCCESS and int(preview_response[1]) == 200,
        "Le panneau Godot n'a pas importé le CSV : " + (preview_response[3] as PackedByteArray).get_string_from_utf8()
    ):
        return
    var preview: Dictionary = panel.get("preview_data")
    var preview_report: Dictionary = preview.get("report", {})
    if not _expect(
        preview.get("rows_after", 0) == 120 and preview_report.get("missing_values_total", 0) > 0,
        "L'aperçu CSV n'a pas reconnu les lignes et les valeurs manquantes."
    ):
        return
    print("PASS: panneau Godot -> import CSV -> aperçu et contrôle qualité.")

    var target_select: OptionButton = panel.get("target_select")
    var target_index := -1
    for index in range(target_select.item_count):
        if target_select.get_item_text(index) == "Machine failure":
            target_index = index
            break
    if not _expect(target_index >= 0, "La colonne Machine failure est absente du sélecteur de cible."):
        return
    target_select.select(target_index)
    panel.call("_train_model")
    var training_response: Array = await http.request_completed
    if not _expect(
        int(training_response[0]) == HTTPRequest.RESULT_SUCCESS and int(training_response[1]) == 200,
        "L'entraînement demandé depuis Godot a échoué : " + (training_response[3] as PackedByteArray).get_string_from_utf8()
    ):
        return
    var report_id := str(panel.get("last_report_id"))
    var training_data = JSON.parse_string((training_response[3] as PackedByteArray).get_string_from_utf8())
    if not _expect(
        not report_id.is_empty()
        and typeof(training_data) == TYPE_DICTIONARY
        and training_data.get("train_rows", 0) > 0
        and training_data.get("test_rows", 0) > 0
        and training_data.get("metrics", {}).has("balanced_accuracy"),
        "Le rapport d'entraînement ne contient pas les tailles train/test ou les métriques attendues."
    ):
        return
    print("PASS: entraînement ML lancé depuis le panneau Godot et rapport reçu.")

    panel.call("_load_history")
    var history_response: Array = await http.request_completed
    if not _expect(
        int(history_response[0]) == HTTPRequest.RESULT_SUCCESS and int(history_response[1]) == 200,
        "La lecture de l'historique depuis Godot a échoué."
    ):
        return
    var history = JSON.parse_string((history_response[3] as PackedByteArray).get_string_from_utf8())
    var found_report := false
    if typeof(history) == TYPE_DICTIONARY:
        for item in history.get("items", []):
            if str(item.get("report_id", "")) == report_id:
                found_report = true
                break
    if not _expect(found_report, "Le nouvel entraînement est absent de l'historique."):
        return
    print("PASS: historique des entraînements visible depuis Godot.")

    panel.call("_export_last_report")
    var export_response: Array = await http.request_completed
    if not _expect(
        int(export_response[0]) == HTTPRequest.RESULT_SUCCESS
        and int(export_response[1]) == 200
        and (export_response[3] as PackedByteArray).size() > 0,
        "L'export du rapport JSON depuis Godot a échoué."
    ):
        return
    panel.call("_save_export", ProjectSettings.globalize_path("user://ia-game-e2e-report.json"))
    if not _expect(
        FileAccess.file_exists("user://ia-game-e2e-report.json"),
        "Le panneau Godot n'a pas enregistré le rapport exporté."
    ):
        return
    var saved_report = JSON.parse_string(FileAccess.get_file_as_string("user://ia-game-e2e-report.json"))
    if not _expect(
        typeof(saved_report) == TYPE_DICTIONARY and str(saved_report.get("report_id", "")) == report_id,
        "Le fichier exporté n'est pas le rapport de cet entraînement."
    ):
        return
    print("PASS: export JSON et sauvegarde du rapport depuis Godot.")

    var simulation = load("res://scripts/industrial_simulation.gd").new()
    simulation.configure([{
        "name": "Presse hydraulique",
        "code": "P-01",
        "running": true,
        "temperature": 74.0,
        "vibration": 1.8,
        "pressure": 5.0,
        "machine_type": "M",
        "tool_wear_min": 38.0
    }])
    simulation.advance(1.0)
    var machine_payload: Dictionary = simulation.get_sensor_payload(0)
    if not _expect(machine_payload.size() == 9, "La simulation n'a pas fourni les neuf mesures de la machine."):
        return

    var prediction_request := HTTPRequest.new()
    root.add_child(prediction_request)
    var headers := PackedStringArray(["Content-Type: application/json"])
    var payload := JSON.stringify({"rows": [machine_payload]})
    var request_error := prediction_request.request(
        API_URL + "/models/predict", headers, HTTPClient.METHOD_POST, payload
    )
    if not _expect(request_error == OK, "Impossible d'envoyer le diagnostic de la machine simulée."):
        return
    var prediction_response: Array = await prediction_request.request_completed
    if not _expect(
        int(prediction_response[0]) == HTTPRequest.RESULT_SUCCESS and int(prediction_response[1]) == 200,
        "Le diagnostic de la machine a échoué : " + (prediction_response[3] as PackedByteArray).get_string_from_utf8()
    ):
        return
    var prediction = JSON.parse_string((prediction_response[3] as PackedByteArray).get_string_from_utf8())
    if not _expect(
        typeof(prediction) == TYPE_DICTIONARY
        and prediction.get("predictions", []).size() == 1
        and prediction.get("performance", {}).has("latency_ms"),
        "Le diagnostic ne contient pas de prédiction et de mesure de latence."
    ):
        return

    print("PASS: diagnostic ML d'une machine simulée avec le schéma réel des neuf capteurs.")
    print("PASS: parcours Godot complet CSV -> entraînement -> historique -> export -> diagnostic.")
    prediction_request.queue_free()
    simulation.free()
    quit(0)


func _expect(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error("FAIL: " + message)
    quit(1)
    return false
