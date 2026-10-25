extends "res://tests/cathedral_preview.gd"
func run() -> void:
	root.title="Hero — Elemental Powers Review"
	root.size=Vector2i(1440,900)
	game=load("res://ground.tscn").instantiate()
	game.settings_path="user://elemental_preview_%d.cfg"%Time.get_ticks_usec()
	game.capture_mouse=false
	root.add_child(game)
	current_scene=game
	game.camera_shake=false
	game.progress.create_world("Elemental review")
	game.enter_world()
	game.accept_quest()
	game.start_run()
	desired_state="playing"
	for skin in 2:
		game.show_menu()
		game.select_skin(skin)
		game.start_run()
		var boss: CharacterBody3D = await stage(1)
		game.player.reset()
		game.player.invulnerable=9999
		game.player.pitch=-0.03
		game.player.update_camera(1)
		game.player.fire_slash()
		await capture("fire_blade" if skin==0 else "lightning_blade",0.25)
		game.player.camera.look_at(boss.global_position+Vector3.UP*1.4)
		game.player.ultimate()
		await settle(0.62)
		var spell: Node = get_first_node_in_group("player_sky_spells")
		if spell!=null and skin==0: spell.position=boss.global_position
		await capture("meteor_fall" if skin==0 else "storm_charge",0.45)
		await capture("meteor_impact" if skin==0 else "lightning_storm",0.36)
		await settle(0.8)
		game.player.mana=100
		game.player.cast_firebolt()
		await capture("fireball" if skin==0 else "arc_bolt",0.04)
	game.hud.menu_root.open_page("characters")
	game.show_menu()
	game.hud.menu_root.open_page("characters")
	desired_state="menu"
	await capture("elemental_characters",0.3)
	game.clear_run()
	print("ELEMENTAL_GAMEPLAY_REVIEW_COMPLETE")
	game.free()
	await process_frame
	quit(failures)
