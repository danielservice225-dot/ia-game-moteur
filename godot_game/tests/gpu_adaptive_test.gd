extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var manager_script: Script = load("res://scripts/gpu_adaptive_manager.gd")
    var manager: Node = manager_script.new()
    root.add_child(manager)

    manager.gpu_name = "Intel HD Graphics 4000"
    manager.gpu_vendor = "Intel"
    manager._choose_initial_profile()
    if not _expect(manager.profile_name == "Économique", "L'Intel HD 4000 doit recevoir le profil économique."):
        return

    manager.gpu_name = "Intel UHD Graphics 620"
    manager.gpu_vendor = "Intel"
    manager._choose_initial_profile()
    if not _expect(manager.profile_name == "Équilibré", "Un GPU intégré non classé doit rester sur le profil équilibré."):
        return

    var first_light := OmniLight3D.new()
    var second_light := OmniLight3D.new()
    manager.add_child(first_light)
    manager.add_child(second_light)
    manager.configure([first_light, second_light])
    if not _expect(FileAccess.file_exists("user://ia_game_hardware_benchmark.csv"), "Le CSV matériel doit être créé automatiquement au démarrage."):
        return
    if not _expect(first_light.visible and not second_light.visible, "Le profil équilibré doit conserver un éclairage sur deux."):
        return

    manager._adapt_to_performance(20.0)
    if not _expect(not first_light.visible and not second_light.visible, "Une chute sous 24 FPS doit réduire les éclairages."):
        return

    for sample in range(10):
        manager._adapt_to_performance(50.0)
    if not _expect(first_light.visible and not second_light.visible, "La récupération doit restaurer le profil initial, pas activer toutes les lumières."):
        return

    var test_session_id := str(manager.session_id)
    manager._write_sample(60.0)
    manager.free()
    var telemetry_file := FileAccess.open("user://ia_game_hardware_benchmark.csv", FileAccess.READ)
    if not _expect(telemetry_file != null, "Le CSV de télémétrie doit pouvoir être relu après fermeture."):
        return
    var telemetry_text := telemetry_file.get_as_text()
    telemetry_file.close()
    if not _expect(
        telemetry_text.contains("session_id,record_type")
        and telemetry_text.contains(test_session_id + ",hardware,")
        and telemetry_text.contains(test_session_id + ",sample,"),
        "Le CSV doit contenir les métadonnées et au moins un échantillon horodaté par session."
    ):
        return

    print("PASS: profils GPU, adaptation et génération CSV validés.")
    quit(0)

func _expect(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error("FAIL: " + message)
    quit(1)
    return false
