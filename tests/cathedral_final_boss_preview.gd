extends "res://tests/cathedral_preview.gd"
func run() -> void:
	game = load("res://ground.tscn").instantiate()
	game.settings_path = "user://cathedral_facing_%d.cfg" % Time.get_ticks_usec()
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	game.camera_shake = false
	game.enter_world()
	game.accept_quest()
	game.start_run()
	desired_state = "playing"
	var boss: CharacterBody3D = await stage(10)
	boss.health = 870
	boss.phase = 3
	boss.begin_attack()
	await capture("main_boss", 1.1)
	print("FINAL_BOSS_FACING_REVIEW_COMPLETE")
	quit(failures)
