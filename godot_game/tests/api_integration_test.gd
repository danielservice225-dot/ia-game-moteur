extends SceneTree

const API_URL := "http://127.0.0.1:8000"
const BOUNDARY := "----IAGameE2EBoundary7MA4YWxkTrZu0gW"

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var panel: Node = root.get_node_or_null("DatasetImportPanel")
    if panel == null:
        panel = load("res://scripts/dataset_import_panel.gd").new()
        root.add_child(panel)
        await process_frame
    if not _expect(
        panel.get("target_select") != null
        and panel.get("history_button") != null
        and panel.get("export_button") != null,
        "Le panneau d'import CSV, d'historique et d'export n'est pas initialisé."
    ):
        return

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

    var multipart := PackedByteArray()
    multipart.append_array(("--" + BOUNDARY + "\r\n").to_utf8_buffer())
    multipart.append_array("Content-Disposition: form-data; name=\"file\"; filename=\"godot-e2e.csv\"\r\n".to_utf8_buffer())
    multipart.append_array("Content-Type: text/csv\r\n\r\n".to_utf8_buffer())
    multipart.append_array(csv_text.to_utf8_buffer())
    multipart.append_array(("\r\n--" + BOUNDARY + "--\r\n").to_utf8_buffer())
    var multipart_headers := PackedStringArray([
        "Content-Type: multipart/form-data; boundary=" + BOUNDARY
    ])

    var preview_response: Array = await _send_request(
        API_URL + "/datasets/preview", HTTPClient.METHOD_POST, multipart_headers, multipart
    )
    if not _expect(_http_ok(preview_response), "L'import et l'aperçu CSV depuis Godot ont échoué."):
        return
    var preview = JSON.parse_string((preview_response[3] as PackedByteArray).get_string_from_utf8())
    if not _expect(
        typeof(preview) == TYPE_DICTIONARY
        and preview.get("rows_after", 0) == 120
        and preview.get("report", {}).get("missing_values_total", 0) > 0,
        "L'aperçu CSV n'a pas reconnu les lignes et les valeurs manquantes."
    ):
        return
    print("PASS: Godot -> API : import CSV et contrôle qualité.")

    var training_response: Array = await _send_request(
        API_URL + "/models/train?target=Machine%20failure",
        HTTPClient.METHOD_POST,
        multipart_headers,
        multipart
    )
    if not _expect(_http_ok(training_response), "L'entraînement ML depuis Godot a échoué."):
        return
    var training = JSON.parse_string((training_response[3] as PackedByteArray).get_string_from_utf8())
    if not _expect(
        typeof(training) == TYPE_DICTIONARY
        and not str(training.get("report_id", "")).is_empty()
        and training.get("train_rows", 0) > 0
        and training.get("test_rows", 0) > 0
        and training.get("metrics", {}).has("balanced_accuracy"),
        "Le rapport d'entraînement ne contient pas les tailles train/test et les métriques attendues."
    ):
        return
    var report_id := str(training.get("report_id"))
    print("PASS: entraînement ML, séparation train/test et métriques.")

    var history_response: Array = await _send_request(
        API_URL + "/models/history", HTTPClient.METHOD_GET
    )
    if not _expect(_http_ok(history_response), "La lecture de l'historique a échoué."):
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
    print("PASS: historique des entraînements.")

    var export_response: Array = await _send_request(
        API_URL + "/models/reports/" + report_id + "/export", HTTPClient.METHOD_GET
    )
    if not _expect(
        _http_ok(export_response)
        and (export_response[3] as PackedByteArray).size() > 0
        and str(export_response[2]).to_lower().contains("content-disposition"),
        "L'export du rapport JSON a échoué."
    ):
        return
    var export_path := "user://ia-game-e2e-report.json"
    var export_file := FileAccess.open(export_path, FileAccess.WRITE)
    if not _expect(export_file != null, "Impossible d'enregistrer le rapport JSON dans Godot."):
        return
    export_file.store_buffer(export_response[3])
    export_file.close()
    var saved_report = JSON.parse_string(FileAccess.get_file_as_string(export_path))
    if not _expect(
        typeof(saved_report) == TYPE_DICTIONARY
        and str(saved_report.get("report_id", "")) == report_id,
        "Le rapport JSON sauvegardé ne correspond pas à l'entraînement."
    ):
        return
    print("PASS: export et sauvegarde du rapport JSON.")

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

    var prediction_response: Array = await _send_request(
        API_URL + "/models/predict",
        HTTPClient.METHOD_POST,
        PackedStringArray(["Content-Type: application/json"]),
        JSON.stringify({"rows": [machine_payload]}).to_utf8_buffer()
    )
    if not _expect(_http_ok(prediction_response), "Le diagnostic de la machine simulée a échoué."):
        return
    var prediction = JSON.parse_string((prediction_response[3] as PackedByteArray).get_string_from_utf8())
    if not _expect(
        typeof(prediction) == TYPE_DICTIONARY
        and prediction.get("predictions", []).size() == 1
        and prediction.get("performance", {}).has("latency_ms"),
        "Le diagnostic ne contient pas de prédiction et de mesure de latence."
    ):
        return

    print("PASS: diagnostic ML de la machine simulée avec les neuf capteurs.")
    print("PASS: parcours complet Godot CSV -> entraînement -> historique -> export -> diagnostic.")
    simulation.free()
    quit(0)


func _send_request(
    url: String,
    method: int,
    headers: PackedStringArray = PackedStringArray(),
    body: PackedByteArray = PackedByteArray()
) -> Array:
    var request := HTTPRequest.new()
    request.timeout = 30.0
    root.add_child(request)
    var error := OK
    if body.is_empty():
        error = request.request(url, headers, method)
    else:
        error = request.request_raw(url, headers, method, body)
    if error != OK:
        request.queue_free()
        return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
    var response: Array = await request.request_completed
    request.queue_free()
    return response


func _http_ok(response: Array) -> bool:
    return response.size() >= 4 and int(response[0]) == HTTPRequest.RESULT_SUCCESS and int(response[1]) >= 200 and int(response[1]) < 300


func _expect(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error("FAIL: " + message)
    quit(1)
    return false
