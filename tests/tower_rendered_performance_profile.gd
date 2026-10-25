extends SceneTree
## Short, 60 FPS capped samples on the normal and final floors with a real renderer.
const GAME_SCENE := preload("res://ground.tscn")
const DATA := preload("res://scripts/encounter_data.gd")
const LAYOUT := preload("res://scripts/tower_layout.gd")
const METRICS_PATH := "res://art/asset_review/final_boss_master/tower_rendered_profile.txt"
var game: Node3D
var report := ""
var failures: int = 0

class FocusIndependentGame extends "res://scripts/game.gd":
	func _notification(what: int) -> void:
		if what not in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
			super._notification(what)

func _initialize() -> void:
	call_deferred("run")

func sample(label: String, seconds: float) -> void:
	var soldiers_at_start: int = game.active_floor_soldier_count(game.encounter_index)
	var fps_sum: float = 0.0
	var fps_min: float = INF
	var max_frame_ms: float = 0.0
	var draws_sum: float = 0.0
	var samples: int = 0
	var until_msec: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	var previous_usec: int = Time.get_ticks_usec()
	while Time.get_ticks_msec() < until_msec:
		await process_frame
		var now_usec: int = Time.get_ticks_usec()
		var frame_ms: float = float(now_usec - previous_usec) / 1000.0
		previous_usec = now_usec
		if frame_ms <= 0.0:
			continue
		fps_sum += 1000.0 / frame_ms
		fps_min = minf(fps_min, 1000.0 / frame_ms)
		max_frame_ms = maxf(max_frame_ms, frame_ms)
		draws_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		samples += 1
	var average_fps: float = fps_sum / maxf(float(samples), 1.0)
	var average_draw_calls: float = draws_sum / maxf(float(samples), 1.0)
	var remaining_soldiers: int = game.active_floor_soldier_count(game.encounter_index)
	var result: String = "%s soldiers_start=%d soldiers_end=%d samples=%d average_fps=%.2f minimum_instant_fps=%.2f max_frame_ms=%.2f average_draw_calls=%.1f\n" % [label, soldiers_at_start, remaining_soldiers, samples, average_fps, fps_min, max_frame_ms, average_draw_calls]
	report += result
	print("TOWER_RENDER_PROFILE ", result.strip_edges())
	if soldiers_at_start != DATA.SOLDIERS_PER_FLOOR:
		failures += 1
		push_error("%s started with %d soldiers instead of %d" % [label, soldiers_at_start, DATA.SOLDIERS_PER_FLOOR])

func wait_for_full_retinue() -> void:
	var until_msec: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < until_msec and game.active_floor_soldier_count(game.encounter_index) < DATA.SOLDIERS_PER_FLOOR:
		await process_frame
	if game.active_floor_soldier_count(game.encounter_index) != DATA.SOLDIERS_PER_FLOOR:
		failures += 1
		push_error("Floor %d did not finish spawning %d soldiers" % [game.encounter_index + 1, DATA.SOLDIERS_PER_FLOOR])

func settle(seconds: float) -> void:
	var until_msec: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until_msec:
		await process_frame

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This profile needs a rendered display; headless FPS is not accepted.")
		quit(1)
		return
	Engine.max_fps = 60
	var settings_path: String = "user://tower_rendered_profile_%d.cfg" % Time.get_ticks_usec()
	game = GAME_SCENE.instantiate()
	game.set_script(FocusIndependentGame)
	game.settings_path = settings_path
	game.capture_mouse = false
	root.add_child(game)
	await process_frame
	game.start_run()
	if is_instance_valid(game.ally_bot):
		game.ally_bot.queue_free()
		game.ally_bot = null
		await process_frame
	game.player.invulnerable = 60.0
	await settle(1.8)
	await wait_for_full_retinue()
	await sample("floor_01", 1.5)

	game.clear_run()
	game.state = "playing"
	game.encounter_index = 10
	game.completed_encounters = 10
	game.encounter_active = true
	game.stage_boss_defeated = false
	game.level_complete = false
	game.player.health = game.player.max_health
	game.player.invulnerable = 60.0
	game.player.position = Vector3(12.0, 10.0 * LAYOUT.FLOOR_HEIGHT + 0.12, 0.0)
	game.player.safe_position = game.player.position
	game.player.yaw = PI
	game.player.pitch = -0.05
	game.player.velocity = Vector3.ZERO
	game.player.update_camera(1.0)
	game.player.camera.make_current()
	game.arena.set_stage(10)
	game.spawn_battle_stage(10)
	var boss: CharacterBody3D
	for actor in game.combatants.get_children():
		if actor is CharacterBody3D and actor.is_in_group("bosses"):
			boss = actor
			break
	if is_instance_valid(boss):
		boss.pattern_sequence.clear()
		boss.pattern_sequence.append(9)
		boss.attack_number = 0
		boss.attack_cooldown = 0.0
		boss.begin_attack()
	game.hud.show_game()
	game.hud.banner_timer = 0.0
	await settle(1.8)
	await wait_for_full_retinue()
	await sample("floor_11_final_boss", 1.5)
	if is_instance_valid(boss):
		await settle(0.8)
		boss.pattern_sequence.clear()
		boss.pattern_sequence.append(10)
		boss.attack_number = 0
		boss.attack_cooldown = 0.0
		boss.attack_windup = 0.0
		boss.movement_lock = 0.0
		boss.charge_time = 0.0
		boss.events.clear()
		boss.begin_attack()
		await settle(2.7)
		await sample("floor_11_spirit_bomb", 1.0)
	var metrics := FileAccess.open(METRICS_PATH, FileAccess.WRITE)
	if metrics != null:
		metrics.store_string("fps_cap=60\nrender_scale=0.85\n" + report)
	for path in [settings_path, settings_path.get_basename() + "_progress.cfg"]:
		for suffix in ["", ".bak", ".tmp"]:
			var candidate: String = path + suffix
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	quit(1 if failures > 0 else 0)
