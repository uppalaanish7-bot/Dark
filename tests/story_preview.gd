extends SceneTree
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + ("touch_" if game.mobile_controls else "") + filename + ".png")

func run() -> void:
	game = load("res://ground.tscn").instantiate()
	game.settings_path = "user://story_preview_%d.cfg" % Time.get_ticks_usec()
	root.add_child(game)
	current_scene = game
	await capture("hero_menu")
	game.enter_world()
	await capture("hero_orin")
	game.accept_quest()
	await create_timer(0.2).timeout
	await capture("hero_world")
	game.menu_camera.position = Vector3(24, 14, 34)
	game.menu_camera.look_at(Vector3(0, 15, -9))
	game.menu_camera.fov = 65
	game.menu_camera.make_current()
	await capture("hero_tower")
	game.player.position = Vector3(1, 0.1, -3)
	game.player.pitch = 0.1
	game.player.update_camera(1)
	game.player.camera.make_current()
	await capture("hero_door")
	game.show_menu()
	game.hud.menu_root.open_page("worlds")
	await capture("hero_worlds")
	game.hud.confirm_delete_world(game.progress.active_world)
	await capture("hero_delete")
	game.hud.modal_root.hide()
	game.start_run()
	game.wave_timer = 999
	game.finish(false)
	await capture("hero_lost")
	game.progress.complete_level(1)
	game.progress.complete_level(2)
	game.progress.select_level(3)
	game.start_run()
	game.finish(true)
	await capture("hero_won")
	game.enter_world()
	game.player.position = game.story_world.ELDER_POS + Vector3(0, 0.1, 2.4)
	game.talk_to_elder()
	game.deliver_elixir()
	await capture("hero_healed")
	game.close_story_dialogue()
	root.size = Vector2i(960, 600)
	await capture("hero_small")
	print("STORY_RENDER_OK")
	quit()
