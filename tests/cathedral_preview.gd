extends SceneTree
## Reproducible visual audit. Uses a unique save and exercises real lobby/world/
## cathedral APIs. No existing player save is read or modified.
var game: Node3D
var desired_state: String = "menu"
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func settle(seconds: float = 0.4) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		# A hidden review window may receive a focus-out notification. This
		# isolated capture intentionally resumes only its own review instance.
		if game.state == "paused" and desired_state in ["playing", "world"]:
			paused = false
			game.state = desired_state
			if desired_state == "playing":
				game.hud.show_game()
			else:
				game.hud.show_world()
		await process_frame

func capture(label: String, wait_seconds: float = 0.35) -> void:
	await settle(wait_seconds)
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://tests/cathedral_" + label + ".png")
	if result != OK:
		failures += 1
	print("CAPTURE ", label, " | state=", game.state, " | size=", root.size, " | draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " | primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " | fps=", Engine.get_frames_per_second())

func stage(index: int) -> CharacterBody3D:
	game.clear_run()
	await process_frame
	game.encounter_index = index
	game.completed_encounters = index
	game.encounter_active = false
	game.level_complete = false
	game.arena.reset_progress()
	for i in range(index):
		game.arena.mark_encounter_complete(i)
	game.arena.set_encounter(index)
	var center: Vector3 = game.ENCOUNTERS.CENTERS[index]
	game.player.position = center + Vector3(0, 0.08, 12.5 if index < 9 else 15.0)
	game.player.safe_position = game.player.position
	game.player.velocity = Vector3.ZERO
	game.player.yaw = 0.0
	game.player.pitch = -0.04
	game.player.invulnerable = 9999
	game.player.health = game.player.MAX_HEALTH
	game.player.mana = game.player.MAX_MANA
	game.player.update_camera(1.0)
	game.player.camera.make_current()
	game.begin_encounter()
	await settle(0.5)
	for actor in game.combatants.get_children():
		if actor is CharacterBody3D:
			actor.set_physics_process(false)
			actor.visual.rotation.y = PI
			actor.spawn_time = 0
	game.hud.banner_timer = 0.0
	var boss: CharacterBody3D = get_first_node_in_group("bosses")
	return boss

func run() -> void:
	game = load("res://ground.tscn").instantiate()
	game.settings_path = "user://cathedral_visual_audit_%d.cfg" % Time.get_ticks_usec()
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	game.camera_shake = false
	await capture("lobby", 1.0)
	if not game.progress.create_world("Cinder Cathedral · Visual Review"):
		push_error("Unable to create isolated review world")
		quit(2)
		return
	game.enter_world()
	desired_state = "dialogue"
	await capture("quest", 0.3)
	game.accept_quest()
	desired_state = "world"
	await capture("courtyard", 0.7)
	game.start_run()
	desired_state = "playing"
	game.player.invulnerable = 9999
	await capture("entry", 1.4)
	game.hud.banner_timer = 0
	await capture("entry_clear", 0.2)
	var sentinel: CharacterBody3D = await stage(0)
	sentinel.begin_attack()
	await capture("first_battle", 0.65)
	game.player.fire_slash()
	await capture("fire_slash", 0.18)
	var azrael: CharacterBody3D = await stage(9)
	azrael.begin_attack()
	await capture("grand_boss", 0.65)
	var nox: CharacterBody3D = await stage(10)
	nox.health = nox.max_health * 0.3
	nox.phase = 3
	nox.attack_number = 2
	nox.begin_attack()
	await capture("main_boss", 0.65)
	root.size = Vector2i(960, 600)
	await capture("small_hud", 0.45)
	root.size = Vector2i(1440, 900)
	game.clear_run()
	game.encounter_active = false
	game.player.position = game.arena.exit_position + Vector3(0, 0.08, 14)
	game.player.safe_position = game.player.position
	game.player.yaw = 0
	game.player.pitch = 0.03
	game.player.update_camera(1.0)
	game.finish(true)
	await capture("portal_arrival", 2.2)
	game.hud.banner_timer = 0
	await capture("portal", 0.1)
	game.player.position = game.arena.exit_position + Vector3(0, 0.08, 1)
	game.portal_cooldown = 0
	await settle(0.2)
	desired_state = "construction"
	await capture("next_level", 0.15)
	root.size = Vector2i(960, 600)
	await capture("small_next_level", 0.3)
	print("CATHEDRAL_VISUAL_AUDIT_COMPLETE | errors=", failures)
	quit(failures)
