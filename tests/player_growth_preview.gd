extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i.ZERO
	var game: Node3D = load("res://ground.tscn").instantiate()
	var save: String = "user://growth_preview_%d.cfg" % Time.get_ticks_usec()
	game.settings_path = save
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	game.start_run()
	game.player.award_xp(735)
	game.player.health = 112
	game.player.mana = 36
	game.pause_game()
	game.hud.show_growth()
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/asset_review/player_growth_panel.png")
	game.player.purchase_growth("overall")
	game.hud.refresh_growth()
	for i in 2: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/asset_review/player_growth_purchased.png")
	game.free()
	for prefix in [save, save.get_basename()+"_progress.cfg"]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(prefix+suffix): DirAccess.remove_absolute(prefix+suffix)
	print("PLAYER_GROWTH_PREVIEW_READY")
	quit()
