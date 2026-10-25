extends "res://tests/cathedral_preview.gd"
## Rendered review of the expanded floor. Optional -- --manual leaves a private
## playable session at the first chamber door; no normal player save is loaded.
const LAYOUT = preload("res://scripts/tower_layout.gd")
var review_save: String

func place(at: Vector3, facing: float = 0.0, tilt: float = -0.04) -> void:
	game.player.position = at
	game.player.safe_position = at
	game.player.velocity = Vector3.ZERO
	game.player.yaw = facing
	game.player.pitch = tilt
	game.player.visual.rotation.y = facing
	game.player.update_camera(1)
	game.arena.update_floor_visibility(at)

func run() -> void:
	root.title = "Hero — Expanded Floor Review"
	root.size = Vector2i(1440, 900)
	review_save = "res://tests/.expanded_review_%d.cfg" % Time.get_ticks_usec()
	game = load("res://ground.tscn").instantiate()
	game.settings_path = review_save
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	if not game.progress.create_world("Expanded Floor Review"):
		push_error("Could not create isolated visual review profile")
		quit(2)
		return
	game.enter_world()
	desired_state = "dialogue"
	await capture("expanded_quest", 0.3)
	root.size = Vector2i(960, 600)
	await capture("expanded_quest_960", 0.3)
	root.size = Vector2i(1440, 900)
	game.accept_quest()
	game.start_run()
	game.camera_shake = false
	game.player.invulnerable = 99999
	game.player.set_physics_process(false)
	desired_state = "playing"
	place(LAYOUT.floor_spawn(0))
	await capture("expanded_hall", 0.8)
	place(Vector3(-102, 0.12, -192), PI * 0.5)
	await capture("expanded_room_door", 0.5)
	place(LAYOUT.key_position(0) + Vector3(0, 0, 8))
	game.update_exploration(0)
	await capture("expanded_key_room", 0.5)
	place(LAYOUT.key_position(0))
	game.update_exploration(0)
	await capture("expanded_key_collected", 0.3)
	place(LAYOUT.stair_entry(0) + Vector3(0, 0, 3))
	await capture("expanded_stair_locked", 0.4)
	game.completed_encounters = 1
	game.encounter_index = 1
	game.arena.mark_encounter_complete(0)
	await capture("expanded_stair_open", 0.5)
	game.player.award_xp(735)
	game.player.health = 112
	game.player.mana = 36
	game.pause_game()
	game.hud.show_growth()
	desired_state = "paused"
	await capture("expanded_growth", 0.3)
	game.player.purchase_growth("overall")
	game.hud.refresh_growth()
	await capture("expanded_growth_bought", 0.3)
	root.size = Vector2i(960, 600)
	await capture("expanded_growth_960", 0.3)
	root.size = Vector2i(1440, 900)
	game.resume()
	desired_state = "playing"
	place(Vector3(-102, 0.12, -192), PI * 0.5)
	game.player.set_physics_process(true)
	game.hud.banner_timer = 0
	print("EXPANDED_FLOOR_REVIEW_COMPLETE | failures=", failures)
	if "--manual" in OS.get_cmdline_user_args():
		game.capture_mouse = true
		game.capture_controls()
		print("PRIVATE_MANUAL_REVIEW_READY | U opens upgrades | normal save untouched")
		return
	cleanup()
	quit(failures)

func cleanup() -> void:
	game.free()
	for prefix in [review_save, review_save.get_basename() + "_progress.cfg"]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(prefix + suffix):
				DirAccess.remove_absolute(prefix + suffix)
