extends "res://tests/cathedral_preview.gd"
## Targeted touch/portrait/Omega audit. Run with -- --touch-controls.
func run() -> void:
	game = load("res://ground.tscn").instantiate()
	game.settings_path = "user://cathedral_touch_audit_%d.cfg" % Time.get_ticks_usec()
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	game.camera_shake = false
	game.select_skin(1)
	game.hud.menu_root.open_page("characters")
	await capture("touch_characters", 1.0)
	game.progress.create_world("Touch review")
	game.enter_world()
	game.accept_quest()
	game.start_run()
	desired_state = "playing"
	game.player.invulnerable = 9999
	game.hud.banner_timer = 0
	await capture("touch_omega_idle", 1.0)
	var boss: CharacterBody3D = await stage(0)
	boss.begin_attack()
	await capture("touch_battle", 0.55)
	# Independent fingers: an actual left-thumb movement and a right-thumb
	# magic action remain held together while the camera/UX is drawn.
	game.touch_controls.begin_touch(801, Vector2(142, 456))
	game.touch_controls.stick_tip = Vector2(182, 445)
	game.touch_controls.movement = Vector2(0.5, -0.14)
	game.touch_controls.begin_touch(802, game.touch_controls.buttons["aim"].get_center())
	await capture("touch_spell", 0.14)
	game.touch_controls.end_touch(801)
	game.touch_controls.end_touch(802)
	game.pause_game()
	desired_state = "paused"
	game.hud.show_controls()
	await capture("touch_controls", 0.25)
	print("CATHEDRAL_TOUCH_VISUAL_AUDIT_COMPLETE | errors=", failures)
	quit(failures)
