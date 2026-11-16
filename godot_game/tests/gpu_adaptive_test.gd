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
    if not _expect(first_light.visible and not second_light.visible, "Le profil équilibré doit conserver un éclairage sur deux."):
        return

    manager._adapt_to_performance(20.0)
    if not _expect(not first_light.visible and not second_light.visible, "Une chute sous 24 FPS doit réduire les éclairages."):
        return

    for sample in range(10):
        manager._adapt_to_performance(50.0)
    if not _expect(first_light.visible and not second_light.visible, "La récupération doit restaurer le profil initial, pas activer toutes les lumières."):
        return

    manager.free()
    print("PASS: profils GPU et adaptation des éclairages validés.")
    quit(0)

func _expect(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error("FAIL: " + message)
    quit(1)
    return false
