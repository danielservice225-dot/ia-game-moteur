extends CanvasLayer

signal machine_selected(index: int)
signal diagnose_requested
signal toggle_requested
signal maintenance_requested
signal fault_requested

var machine_buttons: Array[Button] = []
var selected_title: Label
var selected_state: Label
var sensor_summary: Label
var diagnosis_summary: Label
var production_summary: Label
var performance_label: Label
var toggle_button: Button
var diagnose_button: Button
var maintenance_button: Button
var fault_button: Button
var definitions: Array[Dictionary] = []
var selected_index := -1


func _ready() -> void:
    layer = 30
    _build_ui()


func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.055, 0.075, 0.10, 0.94)
    style.border_color = Color(0.18, 0.28, 0.38, 0.95)
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    return style


func _build_ui() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var header := PanelContainer.new()
    header.position = Vector2(16, 14)
    header.custom_minimum_size = Vector2(520, 52)
    header.add_theme_stylebox_override("panel", _panel_style())
    root.add_child(header)

    var header_row := HBoxContainer.new()
    header_row.add_theme_constant_override("separation", 12)
    header.add_child(header_row)

    var brand := Label.new()
    brand.text = "IA GAME"
    brand.add_theme_font_size_override("font_size", 22)
    header_row.add_child(brand)

    var subtitle := Label.new()
    subtitle.text = "SUPERVISION INDUSTRIELLE"
    subtitle.add_theme_color_override("font_color", Color(0.55, 0.78, 0.92))
    subtitle.add_theme_font_size_override("font_size", 13)
    header_row.add_child(subtitle)

    var left := PanelContainer.new()
    left.position = Vector2(16, 78)
    left.custom_minimum_size = Vector2(280, 430)
    left.add_theme_stylebox_override("panel", _panel_style())
    root.add_child(left)

    var left_column := VBoxContainer.new()
    left_column.add_theme_constant_override("separation", 8)
    left.add_child(left_column)

    var list_title := Label.new()
    list_title.text = "ÉQUIPEMENTS"
    list_title.add_theme_font_size_override("font_size", 16)
    left_column.add_child(list_title)

    var list_hint := Label.new()
    list_hint.text = "Sélectionnez une machine par clic."
    list_hint.add_theme_color_override("font_color", Color(0.65, 0.72, 0.78))
    left_column.add_child(list_hint)

    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(250, 320)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left_column.add_child(scroll)

    var machine_list := VBoxContainer.new()
    machine_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    machine_list.add_theme_constant_override("separation", 7)
    scroll.add_child(machine_list)

    var icons := ["⚙", "◉", "▣", "⇄"]
    for i in range(4):
        var button := Button.new()
        button.custom_minimum_size = Vector2(245, 54)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.toggle_mode = true
        button.text = "%s  Équipement %d" % [icons[i], i + 1]
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        var index := i
        button.pressed.connect(func() -> void:
            machine_selected.emit(index)
        )
        machine_list.add_child(button)
        machine_buttons.append(button)

    var right := PanelContainer.new()
    right.anchor_left = 1.0
    right.anchor_right = 1.0
    right.offset_left = -350
    right.offset_right = -16
    right.offset_top = 78
    right.offset_bottom = 590
    right.add_theme_stylebox_override("panel", _panel_style())
    root.add_child(right)

    var details := VBoxContainer.new()
    details.add_theme_constant_override("separation", 10)
    right.add_child(details)

    var details_heading := Label.new()
    details_heading.text = "FICHE ÉQUIPEMENT"
    details_heading.add_theme_font_size_override("font_size", 16)
    details.add_child(details_heading)

    selected_title = Label.new()
    selected_title.text = "Aucune machine sélectionnée"
    selected_title.add_theme_font_size_override("font_size", 19)
    selected_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    details.add_child(selected_title)

    selected_state = Label.new()
    selected_state.text = "ÉTAT : —"
    selected_state.add_theme_color_override("font_color", Color(0.55, 0.85, 0.68))
    details.add_child(selected_state)

    var separator := HSeparator.new()
    details.add_child(separator)

    var sensor_heading := Label.new()
    sensor_heading.text = "CAPTEURS"
    sensor_heading.add_theme_font_size_override("font_size", 14)
    details.add_child(sensor_heading)

    sensor_summary = Label.new()
    sensor_summary.text = "Sélectionnez un équipement pour afficher ses mesures."
    sensor_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    details.add_child(sensor_summary)

    var ai_heading := Label.new()
    ai_heading.text = "DIAGNOSTIC IA"
    ai_heading.add_theme_font_size_override("font_size", 14)
    details.add_child(ai_heading)

    diagnosis_summary = Label.new()
    diagnosis_summary.text = "IA DataRobot : déploiement non configuré."
    diagnosis_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    diagnosis_summary.custom_minimum_size.y = 70
    details.add_child(diagnosis_summary)

    diagnose_button = Button.new()
    diagnose_button.text = "Lancer le diagnostic IA"
    diagnose_button.disabled = true
    diagnose_button.pressed.connect(func() -> void:
        diagnose_requested.emit()
    )
    details.add_child(diagnose_button)

    toggle_button = Button.new()
    toggle_button.text = "Arrêter la machine"
    toggle_button.disabled = true
    toggle_button.pressed.connect(func() -> void:
        toggle_requested.emit()
    )
    details.add_child(toggle_button)

    fault_button = Button.new()
    fault_button.text = "Simuler une panne"
    fault_button.disabled = true
    fault_button.pressed.connect(func() -> void:
        fault_requested.emit()
    )
    details.add_child(fault_button)

    maintenance_button = Button.new()
    maintenance_button.text = "Effectuer la maintenance"
    maintenance_button.disabled = true
    maintenance_button.pressed.connect(func() -> void:
        maintenance_requested.emit()
    )
    details.add_child(maintenance_button)

    var footer := PanelContainer.new()
    footer.anchor_top = 1.0
    footer.anchor_bottom = 1.0
    footer.offset_left = 16
    footer.offset_right = -16
    footer.offset_top = -76
    footer.offset_bottom = -14
    footer.add_theme_stylebox_override("panel", _panel_style())
    root.add_child(footer)

    var footer_row := HBoxContainer.new()
    footer_row.add_theme_constant_override("separation", 24)
    footer.add_child(footer_row)

    production_summary = Label.new()
    production_summary.text = "PRODUCTION : 0 pièce"
    footer_row.add_child(production_summary)

    performance_label = Label.new()
    performance_label.text = "PERFORMANCES : mesures en cours"
    performance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    performance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    footer_row.add_child(performance_label)


func refresh(
    machine_data: Array[Dictionary],
    active_index: int,
    ai_message: String,
    production_units: int,
    performance_text: String
) -> void:
    definitions = machine_data
    selected_index = active_index
    for i in range(machine_buttons.size()):
        if i >= definitions.size():
            machine_buttons[i].visible = false
            continue
        machine_buttons[i].visible = true
        var machine: Dictionary = definitions[i]
        var state := str(machine.get("state", "RUNNING"))
        var icon := "●" if state == "RUNNING" else "■" if state == "FAULT" else "Ⅱ"
        machine_buttons[i].text = "%s  %s  |  %s  |  %s" % [
            icon,
            str(machine.get("code", "M-00")),
            str(machine.get("name", "Équipement")),
            state
        ]
        machine_buttons[i].button_pressed = i == selected_index

    production_summary.text = "PRODUCTION : %d pièces" % production_units
    performance_label.text = performance_text

    var valid_selection := selected_index >= 0 and selected_index < definitions.size()
    diagnose_button.disabled = not valid_selection
    toggle_button.disabled = not valid_selection
    fault_button.disabled = not valid_selection
    maintenance_button.disabled = not valid_selection

    if not valid_selection:
        selected_title.text = "Aucune machine sélectionnée"
        selected_state.text = "ÉTAT : —"
        sensor_summary.text = "Cliquez sur une machine dans l'usine ou dans la liste."
        diagnosis_summary.text = ai_message
        return

    var machine: Dictionary = definitions[selected_index]
    selected_title.text = "%s  (%s)" % [
        str(machine.get("name", "Équipement")),
        str(machine.get("code", "M-00"))
    ]
    var state := str(machine.get("state", "RUNNING"))
    selected_state.text = "ÉTAT : " + state
    selected_state.add_theme_color_override(
        "font_color",
        Color(1.0, 0.32, 0.25) if state == "FAULT" else Color(0.55, 0.85, 0.68)
    )
    sensor_summary.text = (
        "Température : %.1f °C\nVibration : %.2f mm/s\nPression : %.2f bar\n"
        + "Vitesse : %.0f tr/min\nCouple : %.1f Nm\nUsure outil : %.1f min"
    ) % [
        float(machine.get("temperature", 0.0)),
        float(machine.get("vibration", 0.0)),
        float(machine.get("pressure", 0.0)),
        float(machine.get("rpm", 0.0)),
        float(machine.get("torque_nm", 0.0)),
        float(machine.get("tool_wear_min", 0.0))
    ]
    diagnosis_summary.text = ai_message
    toggle_button.text = "Arrêter la machine" if bool(machine.get("running", true)) else "Redémarrer la machine"
