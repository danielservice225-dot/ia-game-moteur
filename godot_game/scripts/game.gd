extends Node3D

const ApiClient = preload("res://scripts/ia_game_api.gd")
var player: CharacterBody3D
var camera: Camera3D
var api: Node
var status_label: Label
var result_label: Label
var machine_area: Area3D
var machine_temperature := 86.0
var machine_vibration := 3.1
var machine_pressure := 4.1
var prediction_text := "IA non interrogée"

func _ready() -> void:
    _build_factory()
    _build_player()
    _build_hud()
    api = ApiClient.new()
    add_child(api)
    api.prediction_received.connect(_on_prediction_received)
    api.request_failed.connect(_on_api_failed)
    _update_hud()

func _build_factory() -> void:
    _make_box(Vector3(0, -0.35, 0), Vector3(24, 0.4, 24), Color(0.12, 0.16, 0.19))
    _make_box(Vector3(0, 0.15, -5), Vector3(18, 0.3, 0.35), Color(0.95, 0.55, 0.12))
    _make_box(Vector3(-8, 2, -5), Vector3(0.25, 4, 0.25), Color(0.9, 0.45, 0.08))
    _make_box(Vector3(8, 2, -5), Vector3(0.25, 4, 0.25), Color(0.9, 0.45, 0.08))
    _make_box(Vector3(0, 4, -5), Vector3(16, 0.2, 0.2), Color(0.9, 0.45, 0.08))
    _make_machine(Vector3(0, 1, -3), "PRESSE INDUSTRIELLE", Color(0.16, 0.42, 0.72))
    _make_box(Vector3(-5, 0.55, 1), Vector3(2.2, 1.1, 1.2), Color(0.22, 0.28, 0.32))
    _make_box(Vector3(5, 0.55, 1), Vector3(2.2, 1.1, 1.2), Color(0.22, 0.28, 0.32))
    for x in range(-8, 9, 2):
        _make_box(Vector3(x, 0.08, -9), Vector3(0.12, 0.12, 0.5), Color(0.95, 0.7, 0.15))

func _make_box(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.25
    material.roughness = 0.55
    mesh_instance.material_override = material
    add_child(mesh_instance)
    return mesh_instance

func _make_machine(pos: Vector3, machine_name: String, color: Color) -> void:
    var body := _make_box(pos, Vector3(2.5, 2, 1.8), color)
    body.name = "IndustrialMachine"
    _make_box(pos + Vector3(0, 1.15, 0), Vector3(1.1, 0.3, 1.1), Color(0.12, 0.16, 0.2))
    _make_box(pos + Vector3(0, 0.15, 0.96), Vector3(0.8, 0.55, 0.08), Color(0.08, 0.12, 0.15))
    var label := Label3D.new()
    label.text = machine_name
    label.position = pos + Vector3(0, 1.5, 0)
    label.font_size = 34
    label.modulate = Color(0.85, 0.94, 1)
    add_child(label)
    machine_area = Area3D.new()
    machine_area.position = pos
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 3.2
    shape.shape = sphere
    machine_area.add_child(shape)
    add_child(machine_area)

func _build_player() -> void:
    player = get_node("Player") as CharacterBody3D
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    var collision := player.get_node("CollisionShape3D") as CollisionShape3D
    collision.shape = capsule
    collision.position.y = 0.9
    camera = Camera3D.new()
    camera.position = Vector3(0, 0.65, 0)
    camera.current = true
    player.add_child(camera)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(18, 18)
    panel.custom_minimum_size = Vector2(390, 168)
    layer.add_child(panel)
    var column := VBoxContainer.new()
    panel.add_child(column)
    var title := Label.new()
    title.text = "IA GAME  /  LABORATOIRE INDUSTRIEL"
    title.add_theme_font_size_override("font_size", 18)
    column.add_child(title)
    status_label = Label.new()
    column.add_child(status_label)
    result_label = Label.new()
    result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(result_label)
    var hint := Label.new()
    hint.text = "ZQSD / WASD : déplacer   |   E : analyser la machine"
    column.add_child(hint)

func _physics_process(delta: float) -> void:
    var direction := Vector3.ZERO
    direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    direction.z = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
    direction = direction.normalized()
    player.velocity.x = direction.x * 4.5
    player.velocity.z = direction.z * 4.5
    if not player.is_on_floor():
        player.velocity.y -= 20.0 * delta
    else:
        player.velocity.y = 0
    player.move_and_slide()
    if Input.is_action_just_pressed("interact") and player.global_position.distance_to(Vector3(0, 1, -3)) < 4.5:
        _analyse_machine()

func _analyse_machine() -> void:
    prediction_text = "Analyse en cours..."
    _update_hud()
    api.request_prediction({
        "temperature_c": machine_temperature,
        "vibration_mm_s": machine_vibration,
        "pressure_bar": machine_pressure
    })

func _on_prediction_received(result: Dictionary) -> void:
    var predictions: Array = result.get("predictions", [])
    if predictions.is_empty():
        prediction_text = "Réponse reçue sans prédiction."
    else:
        var failure := int(predictions[0]) == 1
        prediction_text = "ALERTE : risque de panne détecté." if failure else "Machine déclarée normale par le modèle."
    _update_hud()

func _on_api_failed(message: String) -> void:
    prediction_text = "API indisponible : " + message + " | Démarrez le serveur Python."
    _update_hud()

func _update_hud() -> void:
    if status_label:
        status_label.text = "Machine P-01 | Température: %.1f °C | Vibration: %.1f mm/s | Pression: %.1f bar" % [machine_temperature, machine_vibration, machine_pressure]
    if result_label:
        result_label.text = "Diagnostic ML : " + prediction_text
