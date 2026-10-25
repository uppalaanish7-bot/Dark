extends "res://tests/cathedral_preview.gd"
## Final desktop delivery captures, without replaying the combat audit.
func run() -> void:
	game = load("res://ground.tscn").instantiate()
	game.settings_path = "user://cathedral_final_capture_%d.cfg" % Time.get_ticks_usec()
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	game.camera_shake = false
	game.select_skin(0)
	game.hud.menu_root.open_page("characters")
	await capture("characters", 0.5)
	game.progress.create_world("Cathedral of Cinders")
	game.enter_world()
	game.accept_quest()
	game.start_run()
	desired_state = "playing"
	game.player.invulnerable = 9999
	game.hud.banner_timer = 0
	await capture("entry_clear", 1.0)
	game.encounter_index = 10
	game.completed_encounters = 11
	game.encounter_active = false
	game.player.position = game.arena.exit_position + Vector3(0, 0.08, 14)
	game.player.safe_position = game.player.position
	game.player.yaw = 0
	game.player.pitch = 0.03
	game.player.update_camera(1.0)
	game.finish(true)
	game.hud.banner_timer = 0
	await capture("portal", 2.1)
	print("CATHEDRAL_DELIVERY_CAPTURE_COMPLETE | errors=", failures)
	quit(failures)
