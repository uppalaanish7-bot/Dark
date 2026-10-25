extends SceneTree
## Exercise the shipped eleven-floor flow, lift, vital rules, wing roster, and death state.
const GAME_SCENE := preload("res://ground.tscn")
const ENEMY := preload("res://scripts/enemy.gd")
const DATA := preload("res://scripts/encounter_data.gd")
const LAYOUT := preload("res://scripts/tower_layout.gd")
var game: Node3D
var checks: int = 0
var failures: Array[String] = []
var settings_path: String
var progress_path: String

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("TOWER PROGRESSION: " + detail)

func active_boss(stage: int) -> CharacterBody3D:
	for actor in game.combatants.get_children():
		if actor is CharacterBody3D and actor.is_in_group("bosses") and actor.encounter_index == stage and not actor.dead:
			return actor
	return null

func active_stage_enemies(stage: int) -> Array[CharacterBody3D]:
	var result: Array[CharacterBody3D] = []
	for actor in game.combatants.get_children():
		if actor is CharacterBody3D and actor.is_in_group("enemies") and actor.encounter_index == stage and not actor.dead:
			result.append(actor)
	return result

func run() -> void:
	settings_path = "user://tower_progression_%d.cfg" % Time.get_ticks_usec()
	progress_path = settings_path.get_basename() + "_progress.cfg"
	game = GAME_SCENE.instantiate()
	game.settings_path = settings_path
	game.capture_mouse = false
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.start_run()
	game.arena.elevator_ride_seconds = 0.025

	check(game.arena._floor_visual_roots.size() == 11 and game.arena._floor_bodies.size() == 11, "The arena builds eleven matching visual floors and collision floors")
	check(game.arena.elevator_car != null and game.arena.central_pillar != null, "The central shaft retains its pillar and a real lift platform")
	check(game.encounter_index == 0 and active_boss(0) != null, "A new run spawns the floor-one guardian first")
	check(game.active_encounter_foes() == 5, "Floor one has one guardian and its four soldiers")

	var winged_ids := ["soldier_9", "subboss_9", "grand_boss"]
	var all_ids: Array[String] = []
	for index in range(1, 10):
		all_ids.append("soldier_%d" % index)
		all_ids.append("subboss_%d" % index)
	all_ids.append_array(["grand_soldier", "grand_boss", "main_boss"])
	for asset_id in all_ids:
		var probe = ENEMY.new()
		probe.asset_id = asset_id
		check(probe.is_flyer() == (asset_id in winged_ids), "%s flight assignment matches the winged model roster" % asset_id)
		probe.free()

	for stage in range(11):
		var boss: CharacterBody3D = active_boss(stage)
		check(game.encounter_index == stage and is_instance_valid(boss), "Floor %02d starts only after the previous lift ride" % (stage + 1))
		var record: Dictionary = DATA.record(stage)
		check(boss != null and boss.asset_id == record.boss_id, "Floor %02d uses %s" % [stage + 1, record.name])
		for actor in active_stage_enemies(stage):
			check(absf(actor.global_position.y - float(stage) * LAYOUT.FLOOR_HEIGHT) < 8.0, "Floor %02d keeps its live fighters on that storey" % (stage + 1))
		if not is_instance_valid(boss):
			break
		game.player.health = 31.0
		game.player.mana = 7.0
		game.player.mana_regen_delay = 5.0
		game._process(12.0)
		check(is_equal_approx(game.player.health, 31.0), "Health does not regenerate during floor %02d" % (stage + 1))
		var before_growth: Dictionary = game.player.growth_snapshot()
		boss.die(false)
		check(is_equal_approx(game.player.health, 31.0) and is_equal_approx(game.player.mana, 7.0), "Guardian death does not refill health or mana on floor %02d" % (stage + 1))
		if stage == 0:
			check(game.player.max_health == 220.0 and game.player.health == 31.0, "A capacity upgrade leaves current health unchanged")
			check(game.player.growth_purchase_reason("heal") != "", "The healing purchase is blocked during a run")
			var saved_growth: Dictionary = game.player.growth_snapshot()
			var saved_health: float = game.player.health
			game.on_boss_killed(boss)
			check(game.player.growth_snapshot() == saved_growth and game.player.health == saved_health, "A duplicate guardian callback cannot duplicate a reward or restore health")
		check(game.player.growth_snapshot().level >= before_growth.level, "Guardian reward growth is retained")
		boss.queue_free()

		var foes: Array[CharacterBody3D] = active_stage_enemies(stage)
		for foe in foes:
			if foe != boss and not foe.dead:
				foe.die(false)
				foe.queue_free()
		check(game.active_encounter_foes() == 0, "Floor %02d is clear only after its retinue falls" % (stage + 1))
		var health_before_lift: float = game.player.health
		if stage == 10:
			game.advance_battle_stage()
			check(game.state == "victory" and game.completed_encounters == 11, "The final guardian and retinue end the tower run in victory")
			check(is_equal_approx(game.player.health, health_before_lift) and game.health_restore_count == 10, "The summit victory does not add an extra health restoration")
			break

		game.advance_battle_stage()
		check(game.encounter_index == stage and game.lift_activated and not game.lift_transition_active, "Floor %02d clear activates the lift without starting the next fight" % (stage + 1))
		check(is_equal_approx(game.player.health, health_before_lift), "Clearing floor %02d does not heal before ascent" % (stage + 1))
		game.player.position = game.arena.elevator_car.global_position + Vector3(0.0, 0.12, 0.0)
		check(game.arena.player_is_on_elevator(game.player), "The player can board the active lift from the current floor")
		game.start_lift_transition()
		check(game.state == "lift" and game.lift_transition_active, "Boarding starts a single lift transition")
		game.process_mode = Node.PROCESS_MODE_ALWAYS
		for frame in range(20):
			await process_frame
			if game.state == "playing" and game.encounter_index == stage + 1:
				break
		game.process_mode = Node.PROCESS_MODE_DISABLED
		check(game.state == "playing" and game.encounter_index == stage + 1, "The moving lift delivers the party to the next floor")
		var expected_y: float = float(stage + 1) * LAYOUT.FLOOR_HEIGHT + 0.12
		var arrival_error: float = absf(game.player.global_position.y - expected_y)
		if arrival_error >= 0.05:
			print("LIFT_ARRIVAL_DIAGNOSTIC floor=", stage + 2, " local=", game.player.position, " global=", game.player.global_position, " expected_y=", expected_y, " parent=", game.player.get_parent().name)
		check(arrival_error < 0.25, "The player arrives at the next floor without falling or teleporting to the wrong height")
		check(game.health_restore_count == stage + 1 and game.player.health == game.player.max_health and game.player.mana == game.player.max_mana, "Lift arrival restores both vital bars exactly once")
		var restored_health: float = game.player.health
		game.on_lift_arrived(stage + 1)
		check(game.health_restore_count == stage + 1 and game.player.health == restored_health, "Duplicate lift-arrival events cannot restore health twice")

	check(game.health_restore_count == 10, "The ten floor-to-floor rides produce ten health restorations")
	game.begin_arena()
	game.player.invulnerable = 0.0
	game.player.health = 1.0
	game.player.receive_damage(2.0)
	check(game.state == "dead" and game.player.health == 0.0, "Player death ends the run immediately at zero health")
	var saved: Dictionary = game.progress.session_for_world().checkpoint
	check(saved.get("status", "") == "dead" and saved.player.health == 0.0 and saved.enemies.is_empty(), "The saved death checkpoint cannot retain a live encounter")
	game.enter_world()
	check(game.state == "dead" and game.player.health == 0.0, "Reopening a failed run shows game over without reviving or skipping it")
	game.retry_run()
	check(game.state == "playing" and game.encounter_index == 0 and active_boss(0) != null and game.player.health == game.player.max_health, "Restart creates a new floor-one run")

	for failure in failures:
		print("TOWER_PROGRESSION_FAILED ", failure)
	print("TOWER_PROGRESSION_CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	var exit_code: int = 0 if failures.is_empty() else 1
	for path in [settings_path, progress_path]:
		for suffix in ["", ".bak", ".tmp"]:
			var candidate: String = path + suffix
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	quit(exit_code)
