extends "res://tests/cathedral_preview.gd"
## Captures the final menus and real combat presentation using a private save.
func run() -> void:
	game = load("res://ground.tscn").instantiate()
	game.settings_path = "user://cathedral_quality_review_%d.cfg" % Time.get_ticks_usec()
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	game.camera_shake = false
	game.hud.menu_root.selected_guardian = 10
	game.hud.menu_root.open_page("bestiary")
	await capture("bestiary",0.8)
	root.size = Vector2i(960,600)
	game.hud.menu_root.selected_guardian = 3
	game.hud.menu_root.open_page("bestiary")
	await capture("small_bestiary",0.4)
	root.size = Vector2i(1440,900)
	game.select_skin(0)
	game.progress.create_world("Quality review")
	game.enter_world()
	game.accept_quest()
	game.start_run()
	desired_state = "playing"
	game.player.invulnerable = 9999
	game.hud.banner_timer = 0
	await capture("quality_entry",0.8)
	var sentinel: CharacterBody3D = await stage(0)
	game.player.position = sentinel.position + Vector3(0,0.1,5.2)
	game.player.safe_position = game.player.position
	game.player.update_camera(1)
	for actor in game.combatants.get_children():
		if actor is CharacterBody3D and actor != sentinel:
			actor.position.x += 12
	game.player.fire_slash()
	await capture("quality_fire",0.35)
	await settle(0.8)
	game.player.cast_firebolt()
	await capture("quality_cast",0.12)
	var grand: CharacterBody3D = await stage(9)
	grand.begin_attack()
	await capture("quality_lava",0.45)
	var final_boss: CharacterBody3D = await stage(10)
	final_boss.begin_attack()
	await capture("quality_void",0.45)
	game.clear_run()
	await settle(1.0)
	print("QUALITY_VISUAL_REVIEW_COMPLETE | errors=",failures)
	quit(failures)
