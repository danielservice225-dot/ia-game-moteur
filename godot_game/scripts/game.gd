extends Node3D

const ApiClient = preload("res://scripts/ia_game_api.gd")
const IndustrialLife = preload("res://scripts/industrial_life.gd")
const IndustrialSimulation = preload("res://scripts/industrial_simulation.gd")
const GpuAdaptiveManager = preload("res://scripts/gpu_adaptive_manager.gd")
const DatasetImportPanel = preload("res://scripts/dataset_import_panel.gd")

const FLOOR_SIZE := Vector3(30.0, 0.5, 24.0)
const PLAYER_SPEED := 5.0
const MOUSE_SENSITIVITY := 0.0022

var player: CharacterBody3D
var camera: Camera3D
var camera_pitch := 0.0
var api: Node
var industrial_life: Node
var simulation: Variant
var status_label: Label
var result_label: Label
var objective_label: Label
var machines: Array[Dictionary] = []
var selected_machine := -1
var prediction_text := "Approchez-vous d'une machine et appuyez sur E."
var elapsed := 0.0
var performance_label: Label
var performance_accumulator := 0.0
var benchmark_active := false
var benchmark_elapsed := 0.0
var benchmark_file: FileAccess
var adaptive_graphics: Node
var dataset_import_panel: CanvasLayer

func _ready() -> void:
    _build_factory()
    adaptive_graphics = GpuAdaptiveManager.new()
    add_child(adaptive_graphics)
    adaptive_graphics.configure(get_tree().get_nodes_in_group("adaptive_lights"))
    simulation = IndustrialSimulation.new()
    add_child(simulation)
    simulation.configure(machines)
    industrial_life = IndustrialLife.new()
    add_child(industrial_life)
    industrial_life.setup(self)
    _build_player()
    _build_hud()
    api = ApiClient.new()
    add_child(api)
    api.prediction_received.connect(_on_prediction_received)
    api.request_failed.connect(_on_api_failed)
    dataset_import_panel = DatasetImportPanel.new()
    add_child(dataset_import_panel)
    _update_hud()

func _build_factory() -> void:
    _add_floor()
    _build_hall_structure()
    _build_lighting()
    _build_production_line()
    _build_storage_area()
    _build_safety_markings()
    _build_control_station()

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.65) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = roughness
    return material

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, collision: bool = false) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.material_override = material
    parent.add_child(mesh_instance)
    if collision:
        var body := StaticBody3D.new()
        body.position = pos
        var shape_node := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        shape_node.shape = shape
        body.add_child(shape_node)
        add_child(body)
    return mesh_instance

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 24
    instance.mesh = mesh
    instance.position = pos
    instance.rotation = rotation
    instance.material_override = material
    parent.add_child(instance)
    return instance

func _label_3d(parent: Node3D, text_value: String, pos: Vector3, color: Color = Color(0.9, 0.95, 1.0)) -> void:
    var label := Label3D.new()
    label.text = text_value
    label.position = pos
    label.font_size = 32
    label.modulate = color
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    parent.add_child(label)

func _add_floor() -> void:
    var floor_body := StaticBody3D.new()
    floor_body.name = "IndustrialConcreteFloor"
    add_child(floor_body)
    var floor_mesh := BoxMesh.new()
    floor_mesh.size = FLOOR_SIZE
    var floor_instance := MeshInstance3D.new()
    floor_instance.mesh = floor_mesh
    floor_instance.position.y = -0.25
    floor_instance.material_override = _material(Color(0.28, 0.31, 0.33), 0.08, 0.88)
    floor_body.add_child(floor_instance)
    var floor_shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = FLOOR_SIZE
    floor_shape.shape = box_shape
    floor_shape.position.y = -0.25
    floor_body.add_child(floor_shape)
    var line_material := _material(Color(0.78, 0.72, 0.48), 0.0, 0.8)
    for x in range(-14, 15, 2):
        _box(self, Vector3(float(x), 0.012, 0), Vector3(0.025, 0.02, 23.0), line_material)
    for z in range(-10, 11, 2):
        _box(self, Vector3(0, 0.013, float(z)), Vector3(29.0, 0.02, 0.025), line_material)

func _build_hall_structure() -> void:
    var concrete := _material(Color(0.48, 0.51, 0.52), 0.05, 0.9)
    var dark_steel := _material(Color(0.12, 0.16, 0.19), 0.72, 0.36)
    var roof := _material(Color(0.24, 0.28, 0.31), 0.55, 0.5)
    var glass := _material(Color(0.12, 0.36, 0.48, 0.72), 0.25, 0.18)
    _box(self, Vector3(0, 4.5, -12), Vector3(30, 9, 0.35), concrete, true)
    _box(self, Vector3(-15, 4.5, 0), Vector3(0.35, 9, 24), concrete, true)
    _box(self, Vector3(15, 4.5, 0), Vector3(0.35, 9, 24), concrete, true)
    _box(self, Vector3(0, 9, 0), Vector3(30, 0.35, 24), roof)
    for x in [-13.5, -9.0, -4.5, 0.0, 4.5, 9.0, 13.5]:
        _box(self, Vector3(x, 4.5, -11.65), Vector3(0.28, 9, 0.28), dark_steel)
        _box(self, Vector3(x, 4.5, 11.65), Vector3(0.28, 9, 0.28), dark_steel)
        _box(self, Vector3(x, 8.45, 0), Vector3(0.22, 0.22, 23.5), dark_steel)
    for z in [-9.0, -5.0, -1.0, 3.0, 7.0, 11.0]:
        _box(self, Vector3(0, 8.35, z), Vector3(29.5, 0.25, 0.22), dark_steel)
    for x in [-11.0, -7.0, 7.0, 11.0]:
        _box(self, Vector3(x, 5.9, -11.78), Vector3(2.6, 2.3, 0.06), glass)
        _box(self, Vector3(x, 5.9, -11.72), Vector3(0.08, 2.4, 0.08), dark_steel)
    _box(self, Vector3(0, 1.6, -11.72), Vector3(4.0, 3.2, 0.12), dark_steel)
    _label_3d(self, "IA GAME  |  USINE DE PRODUCTION", Vector3(0, 7.2, -11.35), Color(0.95, 0.72, 0.2))

func _build_lighting() -> void:
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-58, -25, 0)
    sun.light_energy = 1.15
    sun.shadow_enabled = false
    add_child(sun)
    for x in [-10.0, -3.5, 3.5, 10.0]:
        var light := OmniLight3D.new()
        light.position = Vector3(x, 8.1, 0)
        light.light_color = Color(0.78, 0.86, 1.0)
        light.light_energy = 1.5
        light.omni_range = 10.0
        light.add_to_group("adaptive_lights")
        add_child(light)
        var housing := _material(Color(0.1, 0.12, 0.14), 0.65, 0.4)
        _box(self, Vector3(x, 8.55, 0), Vector3(2.4, 0.18, 0.55), housing)
        _box(self, Vector3(x, 8.43, 0), Vector3(2.1, 0.06, 0.32), _material(Color(0.82, 0.9, 1.0), 0.0, 0.25))

func _register_machine(machine_name: String, code: String, position: Vector3, temperature: float, vibration: float, pressure: float, machine_type: String = "M", tool_wear_min: float = 0.0) -> void:
    machines.append({
        "name": machine_name,
        "code": code,
        "position": position,
        "temperature": temperature,
        "vibration": vibration,
        "pressure": pressure,
        "machine_type": machine_type,
        "tool_wear_min": tool_wear_min,
        "running": true
    })

func _build_production_line() -> void:
    var steel := _material(Color(0.36, 0.41, 0.44), 0.82, 0.28)
    var painted_blue := _material(Color(0.08, 0.24, 0.42), 0.58, 0.34)
    var safety_yellow := _material(Color(0.95, 0.58, 0.06), 0.25, 0.42)
    var rubber := _material(Color(0.045, 0.055, 0.06), 0.0, 0.92)
    _make_press(Vector3(0, 0, -4), painted_blue, steel, safety_yellow)
    _make_motor_pump(Vector3(-7, 0, -3), steel, painted_blue)
    _make_compressor(Vector3(7, 0, -3), steel, safety_yellow)
    _make_conveyor(Vector3(0, 0, 4), steel, rubber, safety_yellow)
    _register_machine("Presse hydraulique", "P-01", Vector3(0, 0, -4), 74.0, 1.8, 5.0, "M", 38.0)
    _register_machine("Pompe centrifuge", "M-02", Vector3(-7, 0, -3), 66.0, 1.6, 5.5, "L", 52.0)
    _register_machine("Compresseur industriel", "C-03", Vector3(7, 0, -3), 70.0, 1.9, 6.8, "H", 78.0)
    _register_machine("Convoyeur motorisé", "CV-04", Vector3(0, 0, 4), 48.0, 1.2, 5.0, "M", 18.0)
    _make_pipe_run(steel, safety_yellow)

func _make_press(origin: Vector3, blue: Material, steel: Material, yellow: Material) -> void:
    var root := Node3D.new()
    root.position = origin
    add_child(root)
    _box(root, Vector3(0, 0.35, 0), Vector3(3.4, 0.7, 2.6), steel)
    _box(root, Vector3(-1.25, 2.0, 0), Vector3(0.42, 3.3, 0.5), blue)
    _box(root, Vector3(1.25, 2.0, 0), Vector3(0.42, 3.3, 0.5), blue)
    _box(root, Vector3(0, 3.55, 0), Vector3(3.0, 0.5, 2.0), blue)
    _box(root, Vector3(0, 1.55, 0), Vector3(1.9, 0.22, 1.6), steel)
    _box(root, Vector3(0, 2.35, 0), Vector3(1.45, 1.0, 1.2), yellow)
    _cylinder(root, Vector3(0, 3.0, 0), 0.28, 0.9, steel)
    _box(root, Vector3(0, 0.9, 1.35), Vector3(0.85, 0.45, 0.08), _material(Color(0.05, 0.09, 0.11), 0.2, 0.35))
    _label_3d(root, "PRESSE P-01", Vector3(0, 4.0, 0), Color(1.0, 0.8, 0.25))
    for x in [-1.45, 1.45]:
        _cylinder(root, Vector3(x, 0.95, 0), 0.16, 0.5, steel)
    _make_guard_rail(root, Vector3(0, 0, 1.8), 2.8, yellow)

func _make_motor_pump(origin: Vector3, steel: Material, blue: Material) -> void:
    var root := Node3D.new()
    root.position = origin
    add_child(root)
    _box(root, Vector3(0, 0.25, 0), Vector3(3.0, 0.5, 2.0), steel)
    _cylinder(root, Vector3(-0.6, 1.1, 0), 0.72, 1.7, blue, Vector3(0, 0, PI / 2))
    _cylinder(root, Vector3(0.45, 1.1, 0), 0.62, 0.8, steel, Vector3(0, 0, PI / 2))
    _cylinder(root, Vector3(1.0, 1.0, 0), 0.85, 0.55, blue)
    _cylinder(root, Vector3(1.0, 1.0, 0.31), 0.3, 0.08, steel)
    for x in [-1.0, -0.2, 0.4]:
        _box(root, Vector3(x, 1.85, 0), Vector3(0.08, 0.22, 1.3), steel)
    _label_3d(root, "POMPE M-02", Vector3(0, 2.45, 0), Color(0.75, 0.88, 1.0))

func _make_compressor(origin: Vector3, steel: Material, yellow: Material) -> void:
    var root := Node3D.new()
    root.position = origin
    add_child(root)
    _box(root, Vector3(0, 0.3, 0), Vector3(3.0, 0.6, 2.1), steel)
    _cylinder(root, Vector3(0, 1.45, 0), 0.95, 2.2, yellow, Vector3(0, 0, PI / 2))
    _cylinder(root, Vector3(-1.2, 1.45, 0), 0.65, 0.18, steel, Vector3(0, 0, PI / 2))
    _cylinder(root, Vector3(1.2, 1.45, 0), 0.65, 0.18, steel, Vector3(0, 0, PI / 2))
    _cylinder(root, Vector3(0, 2.55, 0), 0.12, 0.7, steel)
    _label_3d(root, "COMPRESSEUR C-03", Vector3(0, 3.0, 0), Color(1.0, 0.82, 0.3))

func _make_conveyor(origin: Vector3, steel: Material, rubber: Material, yellow: Material) -> void:
    var root := Node3D.new()
    root.position = origin
    add_child(root)
    _box(root, Vector3(0, 0.8, 0), Vector3(9.0, 0.18, 1.65), rubber)
    for x in [-4.2, -3.0, -1.8, -0.6, 0.6, 1.8, 3.0, 4.2]:
        _cylinder(root, Vector3(x, 0.72, 0), 0.17, 1.85, steel, Vector3(0, 0, PI / 2))
        _box(root, Vector3(x, 0.35, 0), Vector3(0.12, 0.7, 0.12), steel)
    for z in [-0.88, 0.88]:
        _box(root, Vector3(0, 1.0, z), Vector3(9.2, 0.22, 0.12), yellow)
    _label_3d(root, "CONVOYEUR CV-04", Vector3(0, 1.8, 0), Color(1.0, 0.8, 0.25))

func _make_pipe_run(steel: Material, yellow: Material) -> void:
    for x in [-10.0, -8.0, 8.0, 10.0]:
        _cylinder(self, Vector3(x, 5.2, -5.0), 0.12, 10.0, steel, Vector3(0, 0, PI / 2))
        _cylinder(self, Vector3(x, 5.2, -5.0), 0.18, 0.12, yellow, Vector3(0, 0, PI / 2))
    _box(self, Vector3(0, 6.0, -8.5), Vector3(20, 0.16, 0.16), steel)
    _box(self, Vector3(0, 5.7, -8.5), Vector3(20, 0.12, 0.12), yellow)

func _make_guard_rail(parent: Node3D, origin: Vector3, width: float, material: Material) -> void:
    for x in [-width / 2.0, width / 2.0]:
        _cylinder(parent, origin + Vector3(x, 0.55, 0), 0.055, 1.1, material)
    _box(parent, origin + Vector3(0, 1.0, 0), Vector3(width, 0.08, 0.08), material)

func _build_storage_area() -> void:
    var rack := _material(Color(0.16, 0.22, 0.28), 0.7, 0.42)
    var shelf := _material(Color(0.68, 0.43, 0.18), 0.25, 0.58)
    for z in [-7.0, -3.0, 1.0]:
        for x in [10.5, 13.0]:
            _box(self, Vector3(x, 2.0, z), Vector3(0.12, 4.0, 0.12), rack)
            _box(self, Vector3(x, 2.0, z + 1.8), Vector3(0.12, 4.0, 0.12), rack)
            for y in [0.55, 1.8, 3.05]:
                _box(self, Vector3(x + 1.25, y, z + 0.9), Vector3(2.6, 0.12, 2.0), shelf)
            for i in range(3):
                _box(self, Vector3(x + 0.6 + float(i) * 0.65, 1.1, z + 0.9), Vector3(0.55, 0.95, 0.65), _material(Color(0.34, 0.39, 0.42), 0.3, 0.7))

func _build_safety_markings() -> void:
    var yellow := _material(Color(1.0, 0.68, 0.05), 0.0, 0.65)
    var black := _material(Color(0.035, 0.04, 0.045), 0.0, 0.82)
    for i in range(12):
        var z := -1.0 + float(i) * 0.24
        _box(self, Vector3(-2.1, 0.035, z), Vector3(0.18, 0.025, 0.16), yellow if i % 2 == 0 else black)
        _box(self, Vector3(2.1, 0.035, z), Vector3(0.18, 0.025, 0.16), yellow if i % 2 == 0 else black)
    for x in [-12.5, 12.5]:
        _box(self, Vector3(x, 0.04, 4.0), Vector3(0.12, 0.03, 12.0), yellow)

func _build_control_station() -> void:
    var cabinet := _material(Color(0.18, 0.23, 0.27), 0.65, 0.38)
    var screen := _material(Color(0.04, 0.24, 0.3), 0.25, 0.18)
    _box(self, Vector3(0, 1.25, -9.4), Vector3(2.8, 2.5, 0.9), cabinet)
    _box(self, Vector3(0, 1.65, -8.91), Vector3(1.8, 0.95, 0.05), screen)
    _label_3d(self, "SUPERVISION", Vector3(0, 2.75, -8.8), Color(0.35, 0.95, 0.85))
    for x in [-0.75, -0.25, 0.25, 0.75]:
        _cylinder(self, Vector3(x, 0.95, -8.86), 0.09, 0.12, _material(Color(0.15, 0.85, 0.35), 0.0, 0.25))

func _build_player() -> void:
    player = get_node("Player") as CharacterBody3D
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.36
    capsule.height = 1.8
    var collision := player.get_node("CollisionShape3D") as CollisionShape3D
    collision.shape = capsule
    collision.position = Vector3(0, 0.9, 0)
    camera = Camera3D.new()
    camera.position = Vector3(0, 1.58, 0)
    camera.current = true
    player.add_child(camera)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(18, 18)
    panel.custom_minimum_size = Vector2(480, 190)
    layer.add_child(panel)
    var column := VBoxContainer.new()
    panel.add_child(column)
    var title := Label.new()
    title.text = "IA GAME  /  SIMULATION INDUSTRIELLE"
    title.add_theme_font_size_override("font_size", 18)
    column.add_child(title)
    status_label = Label.new()
    column.add_child(status_label)
    result_label = Label.new()
    result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(result_label)
    objective_label = Label.new()
    objective_label.text = "OBJECTIF : inspecter les équipements et détecter les risques de panne."
    objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(objective_label)
    var hint := Label.new()
    hint.text = "ZQSD/WASD : marcher | E : diagnostic ML | F : marche/arrêt | M : maintenance | G : panne test | Échap : souris"
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(hint)
    performance_label = Label.new()
    performance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(performance_label)
    _update_performance_display()

func _process(delta: float) -> void:
    performance_accumulator += delta
    if performance_accumulator >= 1.0:
        performance_accumulator = 0.0
        _update_performance_display()
        if benchmark_active:
            benchmark_elapsed += 1.0
            _write_benchmark_sample()

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        player.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
        camera_pitch = clamp(camera_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.15, 1.15)
        camera.rotation.x = camera_pitch
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
        _toggle_benchmark()
    if event is InputEventKey and event.pressed and event.keycode == KEY_F:
        _toggle_selected_machine()
    if event is InputEventKey and event.pressed and event.keycode == KEY_M:
        _maintain_selected_machine()
    if event is InputEventKey and event.pressed and event.keycode == KEY_G:
        _inject_selected_fault()
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
    elapsed += delta
    simulation.advance(delta)
    for i in range(machines.size()):
        var previous_running := bool(machines[i]["running"])
        var snapshot: Dictionary = simulation.get_snapshot(i)
        machines[i]["temperature"] = snapshot["temperature_c"]
        machines[i]["vibration"] = snapshot["vibration_mm_s"]
        machines[i]["pressure"] = snapshot["pressure_bar"]
        machines[i]["running"] = snapshot["running"]
        machines[i]["state"] = snapshot["state"]
        if previous_running != bool(snapshot["running"]):
            industrial_life.set_machine_running(i, bool(snapshot["running"]))
    var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var move_direction := (player.transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
    player.velocity.x = move_direction.x * PLAYER_SPEED
    player.velocity.z = move_direction.z * PLAYER_SPEED
    if not player.is_on_floor():
        player.velocity.y -= 22.0 * delta
    else:
        player.velocity.y = 0.0
    player.move_and_slide()
    _refresh_machine_selection()
    _update_hud()
    if Input.is_action_just_pressed("interact"):
        _analyse_selected_machine()

func _refresh_machine_selection() -> void:
    selected_machine = -1
    var closest_distance := 3.8
    for i in range(machines.size()):
        var machine_position: Vector3 = machines[i]["position"]
        var distance := player.global_position.distance_to(machine_position + Vector3(0, 1.0, 0))
        if distance < closest_distance:
            closest_distance = distance
            selected_machine = i
    if objective_label:
        if selected_machine >= 0:
            objective_label.text = "ÉQUIPEMENT PROCHE : %s (%s) — appuyez sur E pour lancer le diagnostic." % [machines[selected_machine]["name"], machines[selected_machine]["code"]]
        else:
            objective_label.text = "OBJECTIF : approchez-vous d'une machine pour l'inspecter."

func _toggle_selected_machine() -> void:
    if selected_machine < 0:
        prediction_text = "Approchez-vous d'un équipement pour le démarrer ou l'arrêter."
        _update_hud()
        return
    var machine: Dictionary = machines[selected_machine]
    var running: bool = simulation.toggle_machine(selected_machine)
    machine["running"] = running
    machine["state"] = simulation.get_snapshot(selected_machine)["state"]
    industrial_life.set_machine_running(selected_machine, running)
    prediction_text = "%s : %s." % [machine["code"], "EN MARCHE" if running else str(machine["state"])]
    _update_hud()

func _maintain_selected_machine() -> void:
    if selected_machine < 0:
        prediction_text = "Approchez-vous d'une machine avant la maintenance."
        _update_hud()
        return
    var repaired: bool = simulation.perform_maintenance(selected_machine)
    if repaired:
        machines[selected_machine]["running"] = true
        machines[selected_machine]["state"] = "RUNNING"
        industrial_life.set_machine_running(selected_machine, true)
        prediction_text = "%s : maintenance terminée, capteurs réinitialisés." % machines[selected_machine]["code"]
    else:
        prediction_text = "Maintenance non nécessaire : arrêtez ou diagnostiquez l'équipement."
    _update_hud()

func _inject_selected_fault() -> void:
    if selected_machine < 0:
        prediction_text = "Approchez-vous d'une machine pour simuler une panne."
        _update_hud()
        return
    simulation.inject_fault(selected_machine)
    machines[selected_machine]["running"] = false
    machines[selected_machine]["state"] = "FAULT"
    industrial_life.set_machine_running(selected_machine, false)
    prediction_text = "%s : panne simulée, valeurs capteurs dégradées." % machines[selected_machine]["code"]
    _update_hud()

func _analyse_selected_machine() -> void:
    if selected_machine < 0:
        prediction_text = "Aucune machine à portée. Approchez-vous d'un équipement."
        _update_hud()
        return
    var machine: Dictionary = machines[selected_machine]
    prediction_text = "Analyse ML en cours sur %s..." % machine["code"]
    _update_hud()
    api.request_prediction(simulation.get_sensor_payload(selected_machine))

func _on_prediction_received(result: Dictionary) -> void:
    var predictions: Array = result.get("predictions", [])
    if predictions.is_empty():
        prediction_text = "Réponse reçue sans prédiction exploitable."
    else:
        var model_info: Dictionary = result.get("model", {})
        var task := str(model_info.get("task", "classification"))
        var target := str(model_info.get("target", ""))
        if task == "classification" and target.to_lower() in ["failure", "machine failure", "machine_failure"]:
            var failed := int(predictions[0]) == 1
            prediction_text = "ALERTE : risque de panne détecté." if failed else "Équipement déclaré normal par le modèle."
        elif task == "classification":
            prediction_text = "Classe prédite pour %s : %s" % [target, str(predictions[0])]
        else:
            prediction_text = "Valeur estimée pour %s : %s" % [target, str(predictions[0])]
    var performance: Dictionary = result.get("performance", {})
    if not performance.is_empty():
        prediction_text += "\\nPERFORMANCES ML : %.2f ms | RAM %.1f Mo | CPU %.4f s" % [
            float(performance.get("latency_ms", 0.0)),
            float(performance.get("process_rss_after_mb", 0.0)),
            float(performance.get("cpu_seconds", 0.0))
        ]
    _update_hud()

func _on_api_failed(message: String) -> void:
    prediction_text = "API indisponible : %s. Démarrez le serveur Python." % message
    _update_hud()

func _update_performance_display() -> void:
    if not performance_label:
        return
    var memory_mb := float(OS.get_static_memory_usage()) / (1024.0 * 1024.0)
    var fps := Engine.get_frames_per_second()
    var benchmark_state := "CSV matériel automatique | F6 : mesure complémentaire"
    var gpu_profile := adaptive_graphics.get_profile_label() if adaptive_graphics else "Profil GPU en détection"
    performance_label.text = "PERFORMANCES : %d FPS | mémoire Godot : %.1f Mo | %s | %s" % [fps, memory_mb, gpu_profile, benchmark_state]

func _toggle_benchmark() -> void:
    if benchmark_active:
        benchmark_active = false
        if benchmark_file:
            benchmark_file.close()
            benchmark_file = null
        prediction_text = "Mesure terminée : fichier user://ia_game_benchmark.csv enregistré."
        _update_hud()
        _update_performance_display()
        return
    benchmark_file = FileAccess.open("user://ia_game_benchmark.csv", FileAccess.WRITE)
    if benchmark_file == null:
        prediction_text = "Impossible de créer le fichier de mesure dans le dossier utilisateur."
        _update_hud()
        return
    benchmark_file.store_line("elapsed_s,fps,godot_static_memory_mb,machine_code,machine_state,temperature_c,vibration_mm_s,pressure_bar,Type,Air temperature [K],Process temperature [K],Rotational speed [rpm],Torque [Nm],Tool wear [min]")
    benchmark_elapsed = 0.0
    benchmark_active = true
    prediction_text = "Mesure démarrée : laissez tourner la scène et testez les équipements."
    _update_hud()
    _update_performance_display()

func _write_benchmark_sample() -> void:
    if not benchmark_file:
        return
    var memory_mb := float(OS.get_static_memory_usage()) / (1024.0 * 1024.0)
    var fps := Engine.get_frames_per_second()
    var code := "none"
    var state := "none"
    var temperature := 0.0
    var vibration := 0.0
    var pressure := 0.0
    var machine_type := ""
    var air_temperature_k := 0.0
    var process_temperature_k := 0.0
    var rotational_speed_rpm := 0.0
    var torque_nm := 0.0
    var tool_wear_min := 0.0
    if selected_machine >= 0 and selected_machine < machines.size():
        var machine: Dictionary = machines[selected_machine]
        code = str(machine.get("code", "none"))
        state = str(machine.get("state", "unknown"))
        temperature = float(machine.get("temperature", 0.0))
        vibration = float(machine.get("vibration", 0.0))
        pressure = float(machine.get("pressure", 0.0))
        var sensor_payload: Dictionary = simulation.get_sensor_payload(selected_machine)
        machine_type = str(sensor_payload.get("Type", ""))
        air_temperature_k = float(sensor_payload.get("Air temperature [K]", 0.0))
        process_temperature_k = float(sensor_payload.get("Process temperature [K]", 0.0))
        rotational_speed_rpm = float(sensor_payload.get("Rotational speed [rpm]", 0.0))
        torque_nm = float(sensor_payload.get("Torque [Nm]", 0.0))
        tool_wear_min = float(sensor_payload.get("Tool wear [min]", 0.0))
    benchmark_file.store_line("%.1f,%d,%.2f,%s,%s,%.2f,%.2f,%.2f,%s,%.2f,%.2f,%.1f,%.2f,%.2f" % [benchmark_elapsed, fps, memory_mb, code, state, temperature, vibration, pressure, machine_type, air_temperature_k, process_temperature_k, rotational_speed_rpm, torque_nm, tool_wear_min])
    benchmark_file.flush()

func _exit_tree() -> void:
    if benchmark_file:
        benchmark_file.close()
        benchmark_file = null

func _update_hud() -> void:
    if status_label:
        if selected_machine >= 0:
            var machine: Dictionary = machines[selected_machine]
            status_label.text = "%s | %s | %s | %.1f °C | %.1f mm/s | %.1f bar | %d pièces" % [machine["code"], machine["name"], machine.get("state", "RUNNING"), machine["temperature"], machine["vibration"], machine["pressure"], int(simulation.production_units)]
        else:
            status_label.text = "%d équipements dans l'usine | Aucun équipement sélectionné" % machines.size()
    if result_label:
        result_label.text = "DIAGNOSTIC IA : " + prediction_text
