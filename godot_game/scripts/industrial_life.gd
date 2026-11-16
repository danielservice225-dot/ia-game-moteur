extends Node
# Personnages animés et mécanismes de production pilotés par l'état marche/arrêt.
var factory: Node3D
var workers: Array[Dictionary] = []
var machines: Array[Dictionary] = []
var crates: Array[MeshInstance3D] = []
var elapsed := 0.0

func setup(root: Node3D) -> void:
    factory = root
    _build_workers()
    _build_mechanisms()
    _build_crates()

func _material(c: Color, metal := 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.metallic = metal
    m.roughness = 0.55
    return m

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    n.mesh = mesh
    n.position = pos
    n.material_override = mat
    parent.add_child(n)
    return n

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
    var m := BoxMesh.new()
    m.size = size
    return _mesh(parent, m, pos, mat)

func _capsule(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
    var m := CapsuleMesh.new()
    m.radius = radius
    m.height = height
    return _mesh(parent, m, pos, mat)

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
    var m := CylinderMesh.new()
    m.top_radius = radius
    m.bottom_radius = radius
    m.height = height
    m.radial_segments = 32
    var n := _mesh(parent, m, pos, mat)
    n.rotation = rot
    return n

func _build_workers() -> void:
    _worker("AMADOU | Opérateur", Vector3(-10, 0, 5.5), Color(0.95, 0.32, 0.06), -1.0)
    _worker("MARIAM | Technicienne", Vector3(9.5, 0, 5.5), Color(0.08, 0.36, 0.78), 1.0)
    _worker("KOFFI | Maintenance", Vector3(-9, 0, -7), Color(0.12, 0.48, 0.27), -1.0)

func _worker(label: String, origin: Vector3, jacket_color: Color, direction: float) -> void:
    var root := Node3D.new()
    root.position = origin
    factory.add_child(root)
    var jacket := _material(jacket_color)
    var trousers := _material(Color(0.10, 0.14, 0.19))
    var skin := _material(Color(0.48, 0.29, 0.18))
    var yellow := _material(Color(1.0, 0.72, 0.04), 0.1)
    _capsule(root, Vector3(0, 1.22, 0), 0.29, 0.86, jacket)
    _box(root, Vector3(0, 1.25, -0.27), Vector3(0.35, 0.55, 0.035), yellow)
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.22
    head_mesh.height = 0.44
    _mesh(root, head_mesh, Vector3(0, 1.95, 0), skin)
    _capsule(root, Vector3(0, 2.18, 0), 0.235, 0.13, yellow)
    var arms: Array[Node3D] = []
    var legs: Array[Node3D] = []
    for side in [-1.0, 1.0]:
        var arm := Node3D.new()
        arm.position = Vector3(side * 0.34, 1.48, 0)
        root.add_child(arm)
        _capsule(arm, Vector3(0, -0.25, 0), 0.105, 0.58, jacket)
        arms.append(arm)
        var leg := Node3D.new()
        leg.position = Vector3(side * 0.14, 0.78, 0)
        root.add_child(leg)
        _capsule(leg, Vector3(0, -0.28, 0), 0.13, 0.66, trousers)
        legs.append(leg)
    var tag := Label3D.new()
    tag.text = label
    tag.position = Vector3(0, 2.55, 0)
    tag.font_size = 24
    tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    root.add_child(tag)
    workers.append({"root": root, "arms": arms, "legs": legs, "origin": origin, "phase": randf() * TAU})

func _lamp(parent: Node3D, pos: Vector3) -> MeshInstance3D:
    var m := SphereMesh.new()
    m.radius = 0.13
    m.height = 0.26
    return _mesh(parent, m, pos, _material(Color(0.08, 0.9, 0.28)))

func _build_mechanisms() -> void:
    var yellow := _material(Color(1.0, 0.66, 0.04), 0.25)
    var steel := _material(Color(0.42, 0.49, 0.53), 0.82)
    var press := Node3D.new()
    press.position = Vector3(0, 0, -4)
    factory.add_child(press)
    var ram := _box(press, Vector3(0, 2.0, 0.82), Vector3(1.15, 0.24, 0.55), yellow)
    var lamp0 := _lamp(press, Vector3(1.2, 3.45, 0.7))
    machines.append({"part": ram, "lamp": lamp0, "kind": "press", "running": true})
    var pump := Node3D.new()
    pump.position = Vector3(-7, 0, -3)
    factory.add_child(pump)
    var rotor := _cylinder(pump, Vector3(1, 1, 0.48), 0.24, 0.12, yellow)
    machines.append({"part": rotor, "lamp": _lamp(pump, Vector3(1.25, 2.1, 0)), "kind": "pump", "running": true})
    var comp := Node3D.new()
    comp.position = Vector3(7, 0, -3)
    factory.add_child(comp)
    var fan := _cylinder(comp, Vector3(0, 1.45, 1.16), 0.42, 0.12, steel)
    machines.append({"part": fan, "lamp": _lamp(comp, Vector3(1.25, 2.6, 0)), "kind": "compressor", "running": true})
    var conv := Node3D.new()
    conv.position = Vector3(0, 0, 4)
    factory.add_child(conv)
    var roller := _cylinder(conv, Vector3(-4.35, 0.78, 0), 0.18, 1.8, yellow, Vector3(0, 0, PI / 2))
    machines.append({"part": roller, "lamp": _lamp(conv, Vector3(4.4, 1.7, 0)), "kind": "conveyor", "running": true})

func _build_crates() -> void:
    var colors := [Color(0.78, 0.28, 0.12), Color(0.12, 0.42, 0.72), Color(0.82, 0.68, 0.24)]
    for i in range(3):
        crates.append(_box(factory, Vector3(-3.6 + float(i) * 3, 1.16, 4), Vector3(0.72, 0.68, 0.72), _material(colors[i])))

func set_machine_running(index: int, running: bool) -> void:
    if index < 0 or index >= machines.size():
        return
    machines[index]["running"] = running
    var lamp := machines[index]["lamp"] as MeshInstance3D
    var mat := _material(Color(0.08, 0.9, 0.28) if running else Color(0.92, 0.06, 0.04))
    mat.emission_enabled = true
    mat.emission = mat.albedo_color
    lamp.material_override = mat

func _process(delta: float) -> void:
    elapsed += delta
    for worker in workers:
        var phase := elapsed * 2.2 + float(worker["phase"])
        var root := worker["root"] as Node3D
        var origin: Vector3 = worker["origin"]
        root.position.x = origin.x + sin(elapsed * 0.28 + float(worker["phase"])) * 1.15
        root.position.z = origin.z + cos(elapsed * 0.22 + float(worker["phase"])) * 0.65
        root.rotation.y = sin(phase * 0.2) * 0.45
        var arms: Array = worker["arms"]
        var legs: Array = worker["legs"]
        arms[0].rotation.x = sin(phase) * 0.35
        arms[1].rotation.x = -sin(phase) * 0.35
        legs[0].rotation.x = -sin(phase) * 0.22
        legs[1].rotation.x = sin(phase) * 0.22
    for data in machines:
        if not bool(data["running"]):
            continue
        var part := data["part"] as Node3D
        match data["kind"]:
            "press":
                part.position.y = 2.0 + 0.36 * abs(sin(elapsed * 1.8))
            "pump":
                part.rotate_y(delta * 5.0)
            "compressor":
                part.rotate_z(delta * 7.0)
            "conveyor":
                part.rotate_x(delta * 5.0)
    if bool(machines[3]["running"]):
        for crate in crates:
            crate.position.x += delta * 1.6
            if crate.position.x > 4.0:
                crate.position.x = -4.0
