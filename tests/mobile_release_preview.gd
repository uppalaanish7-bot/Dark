extends SceneTree
## Actual mobile HUD and arena renders with an isolated profile.
var game: Node3D
var save_path: String
var output := "res://art/asset_review/mobile_release"
var allow_resume := true

func _initialize() -> void:
	call_deferred("run")

func settle(frames: int = 20) -> void:
	for n in frames:
		if allow_resume and game.state == "paused":
			game.resume()
		await process_frame

func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/" + label + ".png")
	print("MOBILE_RENDER ", label, " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 800)
	game = load("res://ground.tscn").instantiate()
	save_path = "user://mobile_release_review_%d.cfg" % Time.get_ticks_usec()
	game.settings_path = save_path
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	game.start_run()
	game.player.invulnerable = 9999
	game.player.yaw = 0
	game.player.pitch = -0.10
	game.player.update_camera(1)
	game.hud.banner_timer = 0
	# Windows can deliver a late initial window resize while the scene loads.
	# Apply the audit dimensions after startup so captures have a known aspect.
	await settle(5)
	root.size = Vector2i(1280, 800)
	await capture("female_controls")
	game.player.fire_slash()
	game.player.shoot()
	await capture("female_sword")
	game.player.mana = 9
	await capture("mana_recovery")
	root.size = Vector2i(1600, 800)
	await capture("wide_phone")
	game.player.visual.set_skin(1)
	game.selected_skin = 1
	game.player.mana = game.player.max_mana
	await capture("omega_controls")
	allow_resume = false
	game.pause_game()
	game.hud.show_controls()
	await capture("icon_guide")
	game.hud.show_settings()
	await capture("settings")
	game.resume()
	game.clear_run()
	game.queue_free()
	await process_frame
	await process_frame
	for base in [save_path, save_path.get_basename() + "_progress.cfg"]:
		for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(base + suffix)
	print("MOBILE_RELEASE_PREVIEW_COMPLETE")
	quit()
