extends SceneTree
## Rendered endgame combat audit. Launch without --headless to exercise the real arena,
## HUD, player, final-boss rig, multiple flyers, combat VFX and frame timing.
const GAME_SCENE := preload("res://ground.tscn")
var game: Node3D
var failures: Array[String] = []
var fps_sum: float = 0.0
var fps_min: float = INF
var fps_samples: int = 0
var max_frame_ms: float = 0.0
const FINAL_FLOOR_Y: float = 180.0

class FocusIndependentGame extends "res://scripts/game.gd":
	func _notification(what: int) -> void:
		if what not in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
			super._notification(what)

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("FINAL BOSS RENDERED TEST: " + message)

func settle(seconds: float, measure: bool = false) -> void:
	if DisplayServer.get_name() == "headless":
		seconds = minf(seconds, 0.08)
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	var previous: int = Time.get_ticks_usec()
	while Time.get_ticks_msec() < until:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var frame_ms: float = float(now - previous) / 1000.0
		previous = now
		if measure and frame_ms > 0:
			max_frame_ms = maxf(max_frame_ms, frame_ms)
			fps_sum += 1000.0 / frame_ms
			fps_min = minf(fps_min, 1000.0 / frame_ms)
			fps_samples += 1

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER_CAPTURE_SKIPPED headless: ", label)
		return
	await RenderingServer.frame_post_draw
	var folder: String = "res://art/asset_review/final_boss_master"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var error: Error = get_root().get_texture().get_image().save_png(folder + "/" + label + ".png")
	check(error == OK, "Rendered frame saved: " + label)
	print("RENDER_CAPTURE ", label, " fps=", Engine.get_frames_per_second(), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

func set_pattern(boss: CharacterBody3D, index: int) -> void:
	boss.attack_windup = 0.0
	boss.attack_cooldown = 100.0
	boss.attack_number = 0
	boss.pattern_sequence.clear()
	boss.pattern_sequence.append(index)
	boss.begin_attack()

func run() -> void:
	Engine.max_fps = 60
	game = GAME_SCENE.instantiate()
	game.set_script(FocusIndependentGame)
	game.capture_mouse = true
	game.camera_shake = true
	game.settings_path = "user://final_boss_rendered_%d.cfg" % Time.get_ticks_usec()
	get_root().add_child(game)
	await process_frame
	check(game.progress.create_world("Final boss rendered audit"), "Private test profile created")
	game.start_run()
	for frame in 3: await physics_frame
	game.clear_run()
	await process_frame
	game.state = "playing"
	game.encounter_index = 10
	game.completed_encounters = 10
	game.encounter_active = true
	game.level_complete = false
	game.stage_boss_defeated = false
	game.player.health = game.player.max_health
	game.player.invulnerable = 60.0
	game.player.position = Vector3(12.0, FINAL_FLOOR_Y + 0.12, 0.0)
	game.player.safe_position = game.player.position
	game.player.yaw = PI
	game.player.pitch = -0.05
	game.player.velocity = Vector3.ZERO
	game.player.update_camera(1.0)
	game.player.camera.make_current()
	game.arena.set_stage(10)
	game.spawn_battle_stage(10)
	var flyer: CharacterBody3D = game.spawn_actor(false, Vector3(12.0, FINAL_FLOOR_Y + 0.12, -9.0), 8)
	flyer.home_position = Vector3(12.0, FINAL_FLOOR_Y + 0.12, -9.0)
	# The boss was spawned along yaw=PI's forward vector; turn the camera and hero back toward him.
	game.player.yaw = 0.0
	game.player.pitch = 0.08
	game.player.update_camera(0.2)
	game.hud.show_game()
	game.hud.banner_timer = 0.0
	await settle(1.5)
	var boss: CharacterBody3D
	for enemy in game.combatants.get_children():
		if enemy is CharacterBody3D and enemy.is_boss:
			boss = enemy
			break
	check(is_instance_valid(boss), "Final boss spawned in the live arena")
	if not is_instance_valid(boss):
		quit(1)
		return
	var flyers: Array[CharacterBody3D] = []
	var soldiers: int = 0
	for enemy in game.combatants.get_children():
		if enemy is CharacterBody3D and not enemy.is_boss:
			soldiers += 1
			if enemy.is_flyer(): flyers.append(enemy)
	check(soldiers >= 7 and flyers.size() == 1 and flyers[0].asset_id == "soldier_9", "The final retinue stays grounded while one actual winged test target flies")
	check(boss.visual.skeleton != null and boss.visual._sculpt_motion, "Actual imported final-boss scene uses its articulated fitted skeleton")
	check(boss.visual.find_children("*", "AnimationTree", true, false).is_empty(), "Confirmed no AnimationTree is present; runtime motions are procedural")
	print("FINAL_BOSS_RIG bones=", boss.visual.skeleton.get_bone_count(), " animation_clips=", boss.visual.animator.get_animation_list().size(), " animation_tree=false soldiers=", soldiers, " flyers=", flyers.size())
	await capture("idle_with_flyers")
	# Warm up the rendered scene, then take a short 60 FPS capped sample to avoid
	# leaving an uncapped stress run on low-spec test machines.
	if DisplayServer.get_name() != "headless":
		await settle(1.0)
		fps_sum = 0.0
		fps_min = INF
		fps_samples = 0
		max_frame_ms = 0.0
		await settle(2.0, true)
		check(fps_samples > 60, "Rendered frame-time samples collected with the final retinue")
		var performance_report: String = "samples=%d\naverage_fps=%.2f\nminimum_instant_fps=%.2f\nmax_frame_ms=%.2f\nrender_fps_cap=%d\n" % [fps_samples, fps_sum / maxf(float(fps_samples), 1.0), fps_min, max_frame_ms, Engine.max_fps]
		var report_file := FileAccess.open("res://art/asset_review/final_boss_master/rendered_metrics.txt", FileAccess.WRITE)
		if report_file != null: report_file.store_string(performance_report)
		print("RENDERED_PERFORMANCE ", performance_report.replace("\n", " | "))
	else:
		print("RENDERED_PERFORMANCE_SKIPPED: headless frame rate is not rendered performance")
	# Run core player inputs while the live AI and retinue remain active.
	Input.action_press("forward")
	await settle(0.55)
	Input.action_release("forward")
	game.player.jump_buffer = 0.15
	game.player.dodge()
	game.player.sword_attack()
	await settle(0.5)
	game.player.fire_timer = 0.0
	game.player.attack_pending = 0.0
	game.player.attack_kind = ""
	game.player.magic_cooldown = 0.0
	game.player.mana = game.player.max_mana
	game.player.cast_firebolt()
	await settle(0.45)
	# Put a real flying soldier on the camera ray and use the actual Q aerial counter.
	flyer = flyers[0]
	flyer.set_physics_process(false)
	flyer.position = Vector3(12.0, FINAL_FLOOR_Y + 5.4, -2.8)
	for index in range(1, flyers.size()):
		flyers[index].set_physics_process(false)
		flyers[index].position = Vector3(25.0 + index * 1.0, FINAL_FLOOR_Y + flyers[index].flight_altitude, 8.0)
		flyers[index].set_physics_process(true)
	game.player.position = Vector3(12.0, FINAL_FLOOR_Y + 0.12, 0.0)
	game.player.velocity = Vector3.ZERO
	game.player.yaw = PI
	game.player.pitch = 0.17
	game.player.update_camera(0.2)
	game.player.jump_buffer = 0.15
	await physics_frame
	check(game.player.velocity.y > 0.0, "Player performs a live jump before attacking the airborne target")
	game.player.combo_index = 2
	game.player.attack_yaw = PI
	game.player.attack_kind = "sword"
	game.player.attack_pending = 0.0
	var jump_melee_health: float = flyer.health
	game.player.resolve_attack()
	check(flyer.health < jump_melee_health, "A jumping sword attack reaches and damages a winged enemy")
	flyer.position = Vector3(12.0, FINAL_FLOOR_Y + flyer.flight_altitude, -9.0)
	game.player.position = Vector3(12.0, FINAL_FLOOR_Y + 0.12, 0.0)
	game.player.velocity = Vector3.ZERO
	game.player.update_camera(0.2)
	await physics_frame
	game.player.camera.look_at(flyer.global_position + Vector3.UP * 0.8)
	game.player.camera.force_update_transform()
	await physics_frame
	game.player.slash_cooldown = 0.0
	game.player.attack_pending = 0.0
	game.player.attack_kind = ""
	game.player.mana = game.player.max_mana
	var q_aim: Dictionary = game.player.aim_hit()
	var q_collider: Object = q_aim.get("hit", {}).get("collider")
	print("Q_DIAGNOSTIC flyer=", flyer.name, " asset=", flyer.asset_id, " pos=", flyer.global_position, " camera=", game.player.camera.global_position, " hit=", q_collider, " hit_pos=", q_aim.get("hit", {}).get("position", Vector3.INF))
	var q_result: bool = game.player.cast_aerial_q()
	check(q_result, "Player Q acquires and counters a flying soldier in the rendered arena")
	var q_health: float = flyer.health
	await settle(0.45)
	check(flyer.health < q_health, "The Q projectile reaches and damages its airborne target")
	flyer.set_physics_process(true)
	await settle(0.65)
	# Simulate the actual health thresholds to see the two Nox phase changes in the live scene.
	game.player.position = Vector3(12.0, FINAL_FLOOR_Y + 0.12, 0.0)
	game.player.velocity = Vector3.ZERO
	game.player.yaw = 0.0
	game.player.pitch = 0.08
	game.player.update_camera(0.2)
	boss.health = boss.max_health
	boss.phase = 1
	print("PHASE_DIAGNOSTIC before hp=", boss.health, " max=", boss.max_health, " phase=", boss.phase, " outside=", boss.outside_court(), " state=", game.state)
	boss.take_damage(boss.max_health * 0.46)
	print("PHASE_DIAGNOSTIC after_46 hp=", boss.health, " phase=", boss.phase, " dead=", boss.dead)
	check(boss.phase == 2, "Rendered guardian advances to phase two")
	boss.take_damage(boss.max_health * 0.26)
	print("PHASE_DIAGNOSTIC after_26 hp=", boss.health, " phase=", boss.phase, " dead=", boss.dead)
	check(boss.phase == 3, "Rendered guardian advances to phase three")
	set_pattern(boss, 3)
	await settle(0.55)
	await capture("phase_three_black_beam_windup")
	await settle(1.2)
	set_pattern(boss, 4)
	await settle(0.60)
	await capture("phase_three_dark_sphere_windup")
	for move in [{"index": 5, "cue": "Storm_Lance"}, {"index": 6, "cue": "Ember_Burst"}, {"index": 7, "cue": "Frost_Lattice"}, {"index": 8, "cue": "Gale_Shear"}]:
		set_pattern(boss, int(move.index))
		check(boss.visual.current_clip == move.cue, "Rendered Nox attack plays " + move.cue)
		await settle(1.5)
		check(boss.visual.model.transform.is_finite(), move.cue + " keeps the boss rig transform finite")
	await capture("phase_three_elemental_crossover")
	flyer.die(false)
	var health_at_summit: float = game.player.health
	boss.take_damage(boss.health + 1.0)
	check(boss.dead, "Final guardian death follows the actual combat damage path")
	for foe in game.combatants.get_children():
		if foe is CharacterBody3D and foe.is_in_group("enemies") and foe.encounter_index == 10 and not foe.dead:
			foe.die(false)
			foe.queue_free()
	game.advance_battle_stage()
	check(game.state == "victory", "Clearing Nox and the final retinue ends the run")
	check(game.player.health == health_at_summit, "Final victory does not restore health outside a floor transition")
	await settle(1.4)
	await capture("final_boss_defeat")
	for failure in failures: print("FINAL_BOSS_RENDERED_FAILED ", failure)
	print("FINAL_BOSS_RENDERED_CHECKS failures=", failures.size(), " fps_samples=", fps_samples)
	var result_file := FileAccess.open("res://art/asset_review/final_boss_master/rendered_checks.txt", FileAccess.WRITE)
	if result_file != null:
		var details: String = "failures=%d\nchecks=rendered scene, grounded final retinue, winged target, movement, jump melee, dodge, sword, ranged magic, aerial Q impact, phases 2 and 3, final boss signatures and death\n" % failures.size()
		for failure in failures: details += "FAILED: " + failure + "\n"
		result_file.store_string(details)
	if game.progress.active_world > 0:
		game.progress.delete_world(game.progress.active_world)
	quit(0 if failures.is_empty() else 1)
