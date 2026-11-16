extends CanvasLayer

const API_BASE_URL := "http://127.0.0.1:8000"
const BOUNDARY := "----IAGameCsvBoundary7MA4YWxkTrZu0gW"

var file_dialog: FileDialog
var http: HTTPRequest
var selected_csv_path := ""
var selected_csv_name := ""
var preview_data: Dictionary = {}
var status_label: Label
var file_label: Label
var target_select: OptionButton
var train_button: Button
var panel: PanelContainer
var busy := false

func _ready() -> void:
    layer = 20
    _build_interface()

func _build_interface() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var open_button := Button.new()
    open_button.text = "IMPORTER CSV / ENTRAÎNER L'IA"
    open_button.position = Vector2(18, 220)
    open_button.custom_minimum_size = Vector2(260, 42)
    open_button.pressed.connect(_toggle_panel)
    root.add_child(open_button)

    panel = PanelContainer.new()
    panel.position = Vector2(18, 270)
    panel.custom_minimum_size = Vector2(390, 330)
    panel.visible = false
    root.add_child(panel)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 10)
    panel.add_child(content)

    var title := Label.new()
    title.text = "DONNÉES INDUSTRIELLES — CSV"
    title.add_theme_font_size_override("font_size", 17)
    content.add_child(title)

    var description := Label.new()
    description.text = "Importez un CSV, vérifiez ses colonnes, choisissez la variable à prédire puis lancez l'entraînement."
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(description)

    var choose_button := Button.new()
    choose_button.text = "Choisir un fichier CSV"
    choose_button.pressed.connect(_open_file_dialog)
    content.add_child(choose_button)

    file_label = Label.new()
    file_label.text = "Aucun fichier sélectionné"
    file_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(file_label)

    var target_label := Label.new()
    target_label.text = "Colonne cible à prédire"
    content.add_child(target_label)

    target_select = OptionButton.new()
    target_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    target_select.disabled = true
    content.add_child(target_select)

    train_button = Button.new()
    train_button.text = "Lancer l'entraînement ML"
    train_button.disabled = true
    train_button.pressed.connect(_train_model)
    content.add_child(train_button)

    status_label = Label.new()
    status_label.text = "En attente d'un fichier CSV."
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(status_label)

    file_dialog = FileDialog.new()
    file_dialog.file_mode = FileDialog.FILE_MODE_OPEN
    file_dialog.access = FileDialog.ACCESS_FILESYSTEM
    file_dialog.add_filter("*.csv", "Fichiers CSV")
    file_dialog.file_selected.connect(_on_file_selected)
    add_child(file_dialog)

    http = HTTPRequest.new()
    http.timeout = 120.0
    http.request_completed.connect(_on_http_completed)
    add_child(http)

func _toggle_panel() -> void:
    panel.visible = not panel.visible

func _open_file_dialog() -> void:
    file_dialog.popup_centered_ratio(0.72)

func _on_file_selected(path: String) -> void:
    selected_csv_path = path
    selected_csv_name = path.get_file()
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        _set_status("Impossible de lire ce fichier.")
        return
    var bytes := file.get_buffer(file.get_length())
    file.close()
    if bytes.is_empty():
        _set_status("Le fichier CSV est vide.")
        return
    file_label.text = selected_csv_name
    target_select.clear()
    target_select.disabled = true
    train_button.disabled = true
    preview_data.clear()
    _set_status("Vérification du CSV en cours...")
    _send_multipart("/datasets/preview", bytes, "preview")

func _train_model() -> void:
    if selected_csv_path.is_empty() or target_select.get_item_count() == 0:
        return
    var file := FileAccess.open(selected_csv_path, FileAccess.READ)
    if file == null:
        _set_status("Impossible de relire le CSV.")
        return
    var bytes := file.get_buffer(file.get_length())
    file.close()
    var target := target_select.get_item_text(target_select.selected)
    _set_status("Entraînement du modèle sur les données importées...")
    train_button.disabled = true
    _send_multipart("/models/train?target=" + target.uri_encode(), bytes, "train")

func _send_multipart(endpoint: String, file_bytes: PackedByteArray, action: String) -> void:
    if busy:
        _set_status("Une opération est déjà en cours.")
        return
    busy = true
    http.set_meta("action", action)
    var safe_name := selected_csv_name.replace("\\", "_").replace("\"", "_").replace("\n", "_").replace("\r", "_")
    var body := PackedByteArray()
    body.append_array(("--" + BOUNDARY + "\r\n").to_utf8_buffer())
    body.append_array(("Content-Disposition: form-data; name=\"file\"; filename=\"" + safe_name + "\"\r\n").to_utf8_buffer())
    body.append_array("Content-Type: text/csv\r\n\r\n".to_utf8_buffer())
    body.append_array(file_bytes)
    body.append_array(("\r\n--" + BOUNDARY + "--\r\n").to_utf8_buffer())
    var headers := PackedStringArray(["Content-Type: multipart/form-data; boundary=" + BOUNDARY])
    var error := http.request_raw(API_BASE_URL + endpoint, headers, HTTPClient.METHOD_POST, body)
    if error != OK:
        busy = false
        _set_status("Erreur d'envoi HTTP : " + error_string(error))

func _on_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    busy = false
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if result != HTTPRequest.RESULT_SUCCESS:
        _set_status("Erreur réseau. Vérifiez que l'API Python fonctionne sur le port 8000.")
        return
    if response_code < 200 or response_code >= 300:
        var detail := str(parsed.get("detail", parsed)) if typeof(parsed) == TYPE_DICTIONARY else str(parsed)
        _set_status("Erreur API (%d) : %s" % [response_code, detail])
        if http.get_meta("action", "") == "train":
            train_button.disabled = false
        return

    var action := str(http.get_meta("action", ""))
    if action == "preview":
        if typeof(parsed) != TYPE_DICTIONARY:
            _set_status("Réponse d'aperçu invalide.")
            return
        preview_data = parsed
        var columns: Array = parsed.get("columns", [])
        target_select.clear()
        for column in columns:
            target_select.add_item(str(column))
        target_select.disabled = columns.is_empty()
        train_button.disabled = columns.is_empty()
        var report: Dictionary = parsed.get("report", {})
        _set_status("CSV prêt : %s lignes, %d colonnes, %s doublons supprimés. Choisissez la cible." % [
            str(parsed.get("rows_after", 0)),
            columns.size(),
            str(report.get("duplicate_rows_removed", 0))
        ])
    elif action == "train":
        var metrics: Dictionary = parsed.get("metrics", {})
        var lines := PackedStringArray()
        for key in metrics.keys():
            lines.append("%s : %.4f" % [str(key), float(metrics[key])])
        _set_status("ENTRAÎNEMENT TERMINÉ — %s\nTrain : %s | Test : %s\n%s" % [
            str(parsed.get("task", "ML")),
            str(parsed.get("train_rows", 0)),
            str(parsed.get("test_rows", 0)),
            "\n".join(lines)
        ])
        train_button.disabled = false

func _set_status(message: String) -> void:
    if status_label:
        status_label.text = message
