extends CanvasLayer

signal machine_selected(index: int)
signal diagnose_requested
signal toggle_requested
signal maintenance_requested
signal fault_requested

var machine_buttons: Array[Button] = []
var selected_title: Label
var selected_state: Label
var diagnosis_summary: Label
var production_summary: Label
var performance_label: Label
var toggle_button: Button
var diagnose_button: Button
var maintenance_button: Button
var fault_button: Button
var machine_status_label: Label
var alert_title: Label
var alert_body: Label
var console_log: RichTextLabel
var sensor_summary: Label
var factory_map: FactoryMap
var definitions: Array[Dictionary] = []
var selected_index := -1
var status_message := "Simulation prête — sélectionnez un équipement."

const NAVY := Color("#07172b")
const PANEL := Color(0.025, 0.065, 0.12, 0.94)
const PANEL_LIGHT := Color(0.045, 0.105, 0.18, 0.96)
const BLUE := Color("#087df5")
const CYAN := Color("#25c9ff")
const GREEN := Color("#00df83")
const AMBER := Color("#ffbd32")
const RED := Color("#ff4545")
const WHITE := Color("#edf6ff")
const MUTED := Color("#a9c0d8")

func _ready() -> void:
    layer = 30
    _build_ui()

func _panel_style(fill: Color = PANEL, border: Color = Color(0.10, 0.40, 0.72, 0.95), radius: int = 12) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 9
    style.content_margin_bottom = 9
    return style

func _label(value: String, size: int = 15, color: Color = WHITE, bold: bool = false) -> Label:
    var item := Label.new()
    item.text = value
    item.add_theme_font_size_override("font_size", size)
    item.add_theme_color_override("font_color", color)
    if bold:
        item.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
        item.add_theme_constant_override("shadow_offset_x", 1)
        item.add_theme_constant_override("shadow_offset_y", 1)
    return item

func _button_style(fill: Color, hover: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 9
    style.content_margin_bottom = 9
    return style

func _make_button(text_value: String, callback: Callable, active: bool = false) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0, 42)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.add_theme_font_size_override("font_size", 15)
    button.add_theme_color_override("font_color", WHITE)
    button.add_theme_stylebox_override("normal", _button_style(Color(0.02, 0.10, 0.20, 0.8) if not active else Color(0.02, 0.30, 0.78, 0.96), Color(0.02, 0.28, 0.55, 0.95), Color(0.08, 0.48, 0.95, 0.8)))
    button.add_theme_stylebox_override("hover", _button_style(Color(0.03, 0.22, 0.42, 0.98), Color(0.03, 0.22, 0.42, 0.98), CYAN))
    button.add_theme_stylebox_override("pressed", _button_style(Color(0.02, 0.34, 0.76, 1.0), Color(0.02, 0.34, 0.76, 1.0), CYAN))
    button.pressed.connect(callback)
    return button

func _add_panel(parent: Control, rect: Rect2, title: String = "") -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.position = rect.position
    panel.size = rect.size
    panel.add_theme_stylebox_override("panel", _panel_style())
    parent.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 7)
    panel.add_child(column)
    if not title.is_empty():
        column.add_child(_label(title, 17, WHITE, true))
        var separator := HSeparator.new()
        separator.add_theme_color_override("separator", Color(0.15, 0.38, 0.62, 0.8))
        column.add_child(separator)
    return column

func _place_panel(column: VBoxContainer, preset: int, panel_position: Vector2) -> void:
    var panel := column.get_parent() as PanelContainer
    panel.set_anchors_preset(preset)
    panel.position = panel_position

func _build_ui() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(root)

    # Barre supérieure — pleine largeur, comme sur la référence.
    var top := PanelContainer.new()
    top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top.offset_left = 10
    top.offset_top = 10
    top.offset_right = -10
    top.offset_bottom = 78
    top.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.045, 0.09, 0.97), Color(0.08, 0.36, 0.72, 0.95), 14))
    root.add_child(top)
    var top_row := HBoxContainer.new()
    top_row.add_theme_constant_override("separation", 20)
    top.add_child(top_row)
    var brand := VBoxContainer.new()
    brand.custom_minimum_size.x = 250
    brand.add_child(_label("✿  IA GAME", 24, WHITE, true))
    brand.add_child(_label("Simulation 3D industrielle", 12, CYAN))
    top_row.add_child(brand)
    top_row.add_child(_label("▣  Usine en service", 17, GREEN, true))
    top_row.add_child(_label("▦  Jour : 1", 16, WHITE, true))
    top_row.add_child(_label("◷  " + Time.get_time_string_from_system(), 16, WHITE, true))
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(spacer)
    performance_label = _label("▮  PERFORMANCE : mesure…", 16, GREEN, true)
    performance_label.custom_minimum_size.x = 300
    top_row.add_child(performance_label)

    # Menu vertical fixe à gauche.
    var nav := _add_panel(root, Rect2(12, 92, 158, 390), "")
    nav.add_child(_label("MENU", 12, MUTED, true))
    nav.add_child(_make_button("⌂  Accueil", func(): _set_status("Vue générale de l'usine."), true))
    nav.add_child(_make_button("▣  Machines", _focus_first_machine))
    nav.add_child(_make_button("⚠  Pannes", _show_faults))
    nav.add_child(_make_button("▥  Prédictions ML", func(): diagnose_requested.emit()))
    nav.add_child(_make_button("▤  Rapports", func(): _set_status("Les mesures de performance sont exportées avec F6.")))
    nav.add_child(_make_button("⚙  Paramètres", func(): _set_status("Configuration graphique et simulation.")))
    nav.add_child(_make_button("⏻  Quitter", func(): get_tree().quit()))

    # Panneau d'état des machines en haut à droite.
    var machine_panel := _add_panel(root, Rect2(0, 0, 270, 158), "État des machines")
    _place_panel(machine_panel, Control.PRESET_TOP_RIGHT, Vector2(-286, 91))
    machine_status_label = _label("●  En ligne : —   ▲  En alerte : —   ✖  En panne : —", 13, WHITE)
    machine_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    machine_panel.add_child(machine_status_label)
    var health := ProgressBar.new()
    health.custom_minimum_size.y = 13
    health.max_value = 100
    health.value = 100
    health.show_percentage = false
    machine_panel.add_child(health)

    # Carte d'alerte sous l'état des machines.
    var alert := _add_panel(root, Rect2(0, 0, 270, 220), "Alerte équipement")
    _place_panel(alert, Control.PRESET_TOP_RIGHT, Vector2(-286, 260))
    alert_title = _label("Aucune panne détectée", 16, GREEN, true)
    alert.add_child(alert_title)
    alert_body = _label("Surveillance des équipements active.", 13, WHITE)
    alert_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    alert.add_child(alert_body)
    sensor_summary = _label("Sélectionnez une machine pour afficher ses capteurs.", 12, MUTED)
    sensor_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    alert.add_child(sensor_summary)
    var alert_actions := HBoxContainer.new()
    alert.add_child(alert_actions)
    diagnose_button = Button.new()
    diagnose_button.text = "Diagnostic IA"
    diagnose_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    diagnose_button.pressed.connect(func(): diagnose_requested.emit())
    alert_actions.add_child(diagnose_button)
    fault_button = Button.new()
    fault_button.text = "Simuler panne"
    fault_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fault_button.pressed.connect(func(): fault_requested.emit())
    alert_actions.add_child(fault_button)
    var action_row := HBoxContainer.new()
    alert.add_child(action_row)
    toggle_button = Button.new()
    toggle_button.text = "Marche / arrêt"
    toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    toggle_button.pressed.connect(func(): toggle_requested.emit())
    action_row.add_child(toggle_button)
    maintenance_button = Button.new()
    maintenance_button.text = "Maintenance"
    maintenance_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    maintenance_button.pressed.connect(func(): maintenance_requested.emit())
    action_row.add_child(maintenance_button)

    # Console système en bas à gauche.
    var console := _add_panel(root, Rect2(12, 0, 410, 150), "Console système")
    _place_panel(console, Control.PRESET_BOTTOM_LEFT, Vector2(12, -164))
    console_log = RichTextLabel.new()
    console_log.bbcode_enabled = true
    console_log.fit_content = true
    console_log.scroll_active = false
    console_log.custom_minimum_size.y = 84
    console_log.add_theme_font_size_override("normal_font_size", 12)
    console.add_child(console_log)
    _log("Simulation 3D initialisée", GREEN)
    _log("Surveillance des machines active", GREEN)

    # Bannière de marque centrée en bas.
    var banner := PanelContainer.new()
    banner.anchor_left = 0.5
    banner.anchor_right = 0.5
    banner.anchor_top = 1.0
    banner.anchor_bottom = 1.0
    banner.offset_left = -260
    banner.offset_right = 260
    banner.offset_top = -145
    banner.offset_bottom = -14
    banner.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.055, 0.12, 0.96), Color(0.02, 0.48, 0.95, 0.98), 16))
    root.add_child(banner)
    var banner_col := VBoxContainer.new()
    banner_col.alignment = BoxContainer.ALIGNMENT_CENTER
    banner_col.add_child(_label("✿  IA GAME", 30, CYAN, true))
    banner_col.add_child(_label("Simulation industrielle intelligente", 16, WHITE, true))
    banner_col.add_child(_label("Prévenir les pannes  •  Optimiser la production  •  Réduire les coûts", 11, MUTED))
    banner.add_child(banner_col)

    # Mini-carte ancrée en bas à droite.
    var map := PanelContainer.new()
    map.anchor_left = 1.0
    map.anchor_right = 1.0
    map.anchor_top = 1.0
    map.anchor_bottom = 1.0
    map.offset_left = -300
    map.offset_right = -12
    map.offset_top = -164
    map.offset_bottom = -12
    map.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.05, 0.10, 0.97), Color(0.10, 0.40, 0.72, 0.95)))
    root.add_child(map)
    var map_col := VBoxContainer.new()
    map_col.add_child(_label("Vue d'ensemble", 14, WHITE, true))
    factory_map = FactoryMap.new()
    factory_map.custom_minimum_size = Vector2(260, 105)
    map_col.add_child(factory_map)
    map.add_child(map_col)


func _log(message: String, color: Color = WHITE) -> void:
    if console_log:
        console_log.append_text("[color=#%s]●[/color]  %s\n" % [color.to_html(false), message])

func _set_status(message: String) -> void:
    status_message = message
    _log(message, CYAN)

func _focus_first_machine() -> void:
    if definitions.size() > 0:
        machine_selected.emit(0)
    else:
        _set_status("Aucun équipement disponible.")

func _show_faults() -> void:
    var found := false
    for i in range(definitions.size()):
        if str(definitions[i].get("state", "")) == "FAULT":
            machine_selected.emit(i)
            found = true
            break
    _set_status("Panne sélectionnée." if found else "Aucune panne active.")

func refresh(machine_data: Array[Dictionary], active_index: int, ai_message: String, production_units: int, performance_text: String) -> void:
    definitions = machine_data
    selected_index = active_index
    var online := 0
    var faults := 0
    var alerts := 0
    for i in range(definitions.size()):
        var state := str(definitions[i].get("state", "RUNNING"))
        if state == "FAULT":
            faults += 1
        elif state == "ALERT":
            alerts += 1
        else:
            online += 1
    if machine_status_label:
        machine_status_label.text = "●  En ligne : %d\n▲  En alerte : %d\n✖  En panne : %d" % [online, alerts, faults]
    if performance_label:
        performance_label.text = performance_text.replace("PERFORMANCES :", "▮  PERFORMANCE :")
    if factory_map:
        var states: Array[String] = []
        for machine in definitions:
            states.append(str(machine.get("state", "RUNNING")))
        factory_map.set_machine_states(states)
    if faults > 0:
        for machine in definitions:
            if str(machine.get("state", "")) == "FAULT":
                alert_title.text = "Panne : " + str(machine.get("code", "Machine"))
                alert_title.add_theme_color_override("font_color", RED)
                alert_body.text = str(machine.get("name", "Équipement")) + " — arrêt détecté. Sélectionnez la machine pour consulter les capteurs."
                break
    elif active_index >= 0 and active_index < definitions.size():
        var selected: Dictionary = definitions[active_index]
        alert_title.text = str(selected.get("code", "Machine")) + " sélectionnée"
        alert_title.add_theme_color_override("font_color", CYAN)
        alert_body.text = ai_message
        sensor_summary.text = "TEMP. %.1f °C   |   VIB. %.2f mm/s\nPRESSION %.2f bar   |   RPM %.0f\nCOUPLE %.1f Nm   |   USURE %.0f min" % [float(selected.get("temperature", 0.0)), float(selected.get("vibration", 0.0)), float(selected.get("pressure", 0.0)), float(selected.get("rpm", 0.0)), float(selected.get("torque_nm", 0.0)), float(selected.get("tool_wear_min", 0.0))]
    else:
        alert_title.text = "Aucune panne détectée"
        alert_title.add_theme_color_override("font_color", GREEN)
        alert_body.text = "Surveillance des équipements active."
        sensor_summary.text = "Sélectionnez une machine pour afficher ses capteurs."
    var valid := active_index >= 0 and active_index < definitions.size()
    diagnose_button.disabled = not valid
    fault_button.disabled = not valid
    toggle_button.disabled = not valid
    maintenance_button.disabled = not valid


class FactoryMap extends Control:
    var machine_states: Array[String] = ["RUNNING", "RUNNING", "RUNNING", "RUNNING"]

    func set_machine_states(states: Array[String]) -> void:
        machine_states = states.duplicate()
        queue_redraw()

    func _draw() -> void:
        var area := Rect2(Vector2(2, 2), size - Vector2(4, 4))
        draw_rect(area, Color("#102a40"), true)
        draw_rect(area, Color("#2b6385"), false, 1.5)
        for x in range(1, 7):
            draw_line(Vector2(size.x * x / 7.0, 5), Vector2(size.x * x / 7.0, size.y - 5), Color(0.18, 0.38, 0.52, 0.55), 1.0)
        for y in range(1, 4):
            draw_line(Vector2(5, size.y * y / 4.0), Vector2(size.x - 5, size.y * y / 4.0), Color(0.18, 0.38, 0.52, 0.55), 1.0)
        var machine_points := [Vector2(0.25, 0.35), Vector2(0.43, 0.32), Vector2(0.64, 0.35), Vector2(0.48, 0.72)]
        for i in range(machine_points.size()):
            var p: Vector2 = machine_points[i] * size
            var state := machine_states[i] if i < machine_states.size() else "RUNNING"
            var marker_color := Color("#ff4545") if state == "FAULT" else Color("#ffbd32") if state == "ALERT" else Color("#00df83")
            draw_rect(Rect2(p - Vector2(6, 5), Vector2(12, 10)), marker_color, true)
        draw_line(Vector2(size.x * 0.1, size.y * 0.84), Vector2(size.x * 0.9, size.y * 0.84), Color("#f5b82e"), 3.0)
