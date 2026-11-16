extends SceneTree

func _initialize() -> void:
	call_deferred("_capture_interface")

func _capture_interface() -> void:
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	if packed_scene == null:
		push_error("Impossible de charger la scène principale.")
		quit(1)
		return

	var game_scene: Node = packed_scene.instantiate()
	root.add_child(game_scene)

	for frame in range(8):
		await process_frame
	await create_timer(4.0).timeout
	await process_frame

	var output_dir := ProjectSettings.globalize_path("res://../artifacts")
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		push_error("Impossible de créer le dossier de captures : %s" % mkdir_error)
		quit(1)
		return

	var screenshot := root.get_texture().get_image()
	if screenshot.is_empty():
		push_error("La capture de l'interface est vide.")
		quit(1)
		return

	var output_path := output_dir.path_join("ia-game-interface.png")
	var save_error := screenshot.save_png(output_path)
	if save_error != OK:
		push_error("Échec de sauvegarde de la capture : %s" % save_error)
		quit(1)
		return

	print("CAPTURE_INTERFACE_OK: ", output_path, " (", screenshot.get_width(), "x", screenshot.get_height(), ")")
	quit(0)
