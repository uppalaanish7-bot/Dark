extends SceneTree
## Bounded desktop combat review. Uses a temporary save and real AI/physics.
## -- --seconds=90 runs 90 simulation seconds per hero (default).
class ReviewGame extends "res://scripts/game.gd":
	func _notification(what: int) -> void:
		if what not in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
			super._notification(what)
	func capture_controls() -> void:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

var game: Node3D
var profile: String
var duration := 90.0
var render_scale := 1.0
var selected_skin := -1
var profile_only := false
var failures: Array[String] = []
var peak_nodes := 0
var impact_ids: Dictionary = {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			duration = clampf(arg.trim_prefix("--seconds=").to_float(), 30.0, 600.0)
		elif arg.begins_with("--scale="):
			render_scale = clampf(arg.trim_prefix("--scale=").to_float(), 0.65, 1.0)
		elif arg.begins_with("--skin="):
			selected_skin = clampi(arg.trim_prefix("--skin=").to_int(), 0, 1)
		elif arg == "--profile-only":
			profile_only = true
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	if not ok:
		failures.append(detail)
		push_error("PC SOAK: " + detail)

func run() -> void:
	root.title = "Hero - PC combat stability review"
	game = load("res://ground.tscn").instantiate()
	game.set_script(ReviewGame)
	profile = "user://pc_combat_soak_%d.cfg" % Time.get_ticks_usec()
	game.settings_path = profile
	root.add_child(game)
	game.set_render_scale(render_scale)
	current_scene = game
	var first_skin: int = selected_skin if selected_skin >= 0 else 0
	var last_skin: int = selected_skin if selected_skin >= 0 else 1
	for skin in range(first_skin, last_skin + 1):
		game.show_menu()
		game.select_skin(skin)
		game.start_run()
		game.player.invulnerable = 9999
		game.player.position = Vector3(-4, 0.12, 65)
		game.player.yaw = 0
		game.player.update_camera(1)
		# Keep the original eleven AI opponents alive long enough to exercise
		# repeated casts and summoning; this is confined to the review profile.
		for boss in get_nodes_in_group("bosses"):
			boss.max_health *= 100.0
			boss.health = boss.max_health
			if profile_only:
				boss.summon_timer = 9999.0
		if profile_only:
			game.roaming_timer = 9999.0
		var next_report := 15.0
		var next_cast := 4.0
		var start_impacts := impact_ids.size()
		print("PC_SOAK_START skin=%d seconds=%.1f desktop=%s scale=%.2f" % [skin, duration, not game.mobile_controls, render_scale])
		while game.elapsed < duration:
			if game.state == "paused" and profile_only:
				# Focus changes pause normal gameplay. Keep the rendered profiling
				# fixture running when the desktop switches away from its window.
				game.resume()
			elif game.state != "playing":
				break
			await physics_frame
			for spell in get_nodes_in_group("player_sky_spells"):
				if spell.impacted and spell.caster == game.ally_bot:
					impact_ids[spell.get_instance_id()] = true
			peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
			if game.elapsed >= next_cast:
				next_cast += 12.0
				game.player.mana = game.player.max_mana
				game.player.ultimate()
			if game.elapsed >= next_report:
				print("PC_SOAK_HEARTBEAT skin=%d elapsed=%.1f fps=%d enemies=%d ally_impacts=%d nodes=%d memory_mb=%.1f process_ms=%.2f physics_ms=%.2f draws=%d render_objects=%d" % [skin, game.elapsed, Engine.get_frames_per_second(), get_nodes_in_group("enemies").size(), impact_ids.size() - start_impacts, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), OS.get_static_memory_usage() / 1048576.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
				next_report += 15.0
		check(game.elapsed >= duration or game.state == "victory", "Combat reaches its review duration or victory")
		print("PC_SOAK_END skin=%d elapsed=%.1f state=%s" % [skin, game.elapsed, game.state])
		if not profile_only:
			check(impact_ids.size() > start_impacts, "Natural ally AI completes a sky-spell impact for skin %d" % skin)
		check(game.player.global_position.is_finite(), "Player position remains finite")
		game.pause_game()
		if not profile_only:
			check(game.state == "paused" or game.state == "victory", "Pause still responds after sustained combat")
			game.resume()
			game.show_menu()
			await process_frame
			await process_frame
			check(get_nodes_in_group("player_sky_spells").is_empty(), "Returning to menu clears active sky spells")
	game.free()
	await process_frame
	await process_frame
	for path in [profile, profile.get_basename() + "_progress.cfg"]:
		for suffix in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(path + suffix)
	print("PC_SOAK_DONE failures=%d ally_impacts=%d peak_nodes=%d" % [failures.size(), impact_ids.size(), peak_nodes])
	quit(0 if failures.is_empty() else 1)
