extends "res://tests/cathedral_preview.gd"
## Real gameplay-camera captures of the tower floor, stairs and open terrace.
func run() -> void:
	game = load("res://ground.tscn").instantiate()
	game.settings_path = "user://tower_visual_review_%d.cfg" % Time.get_ticks_usec()
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	root.size = Vector2i(1440, 900)
	game.camera_shake = false
	game.progress.create_world("Tower visual review")
	game.start_run()
	desired_state = "playing"
	await stage(0)
	game.player.position = Vector3(0, 0.12, 19)
	game.player.pitch = -0.08
	game.player.update_camera(1)
	await capture("tower_floor_01", 0.8)
	await stage(9)
	game.player.position = Vector3(0, 162.12, 20)
	game.player.pitch = -0.08
	game.player.update_camera(1)
	await capture("tower_guard_floor", 0.65)
	game.clear_run()
	game.encounter_active = false
	game.encounter_index = 1
	game.completed_encounters = 1
	game.arena.reset_progress()
	game.arena.mark_encounter_complete(0)
	game.arena.set_encounter(0)
	game.player.position = Vector3(32, 0.12, 21)
	game.player.safe_position = game.player.position
	game.player.velocity = Vector3.ZERO
	game.player.pitch = 0.14
	game.player.yaw = 0
	game.player.update_camera(1)
	await capture("tower_stairs", 0.8)
	game.player.position = Vector3(32, 5.12, 5.3)
	game.player.safe_position = game.player.position
	game.player.velocity = Vector3.ZERO
	game.player.pitch = 0.1
	game.player.update_camera(1)
	await capture("tower_stairs_midflight", 0.65)
	game.clear_run()
	game.encounter_active = false
	game.level_complete = true
	game.completed_encounters = 11
	game.encounter_index = 11
	for index in range(11):
		game.arena.mark_encounter_complete(index)
	game.arena.reveal_portal()
	game.player.position = Vector3(0, 198.12, 10)
	game.player.safe_position = game.player.position
	game.player.velocity = Vector3.ZERO
	game.player.pitch = -0.02
	game.player.yaw = 0
	game.player.update_camera(1)
	game.hud.banner_timer = 0
	await capture("tower_terrace", 1.0)
	game.player.position = Vector3(0, 198.12, -2)
	game.player.safe_position = game.player.position
	game.player.update_camera(1)
	await capture("tower_potion", 0.6)
	print("TOWER_VISUAL_REVIEW_COMPLETE | errors=", failures)
	quit(failures)
