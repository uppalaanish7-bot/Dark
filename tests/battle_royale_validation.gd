extends SceneTree
## Check shared arena construction and encounter identity without a long combat run.
const GAME_SCENE := preload("res://ground.tscn")
const DATA := preload("res://scripts/encounter_data.gd")
const LAYOUT := preload("res://scripts/tower_layout.gd")
var game: Node3D
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("ARENA VALIDATION: " + detail)

func run() -> void:
	game = GAME_SCENE.instantiate()
	game.settings_path = "user://tower_arena_validation_%d.cfg" % Time.get_ticks_usec()
	game.capture_mouse = false
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.start_run()

	check(game.arena.get_play_bounds().size == Vector2(276.0, 276.0), "Arena footprint remains 276m square")
	check(game.arena._floor_visual_roots.size() == LAYOUT.FLOOR_COUNT, "All eleven floors reuse the same arena visual set")
	check(game.arena._floor_bodies.size() == LAYOUT.FLOOR_COUNT, "Every visual floor has its own collision floor")
	check(game.arena.elevator_car != null and game.arena.central_pillar != null, "The central pillar and lift remain in the shared arena")
	check(not game.arena.is_walkable(Vector3(0.0, 0.12, 6.0)) and game.arena.is_walkable(Vector3(9.0, 0.12, 0.0)), "Floor navigation keeps fighters away from the open shaft")
	check(absf(game.arena.stage_radius - 132.0) < 0.01, "The encounter boundary stays fixed and fair on floor one")
	check(game.encounter_index == 0 and game.active_encounter_foes() == 5, "A new run loads only one guardian and the first faction")

	var seen_elements: Array[String] = []
	var seen_boss_models: Array[String] = []
	for stage in range(11):
		var record: Dictionary = DATA.record(stage)
		check(record.boss_id not in seen_boss_models, "Floor %02d has its own supplied guardian model" % (stage + 1))
		seen_boss_models.append(record.boss_id)
		check(record.element not in seen_elements, "Floor %02d has a distinct elemental combat identity" % (stage + 1))
		seen_elements.append(record.element)
		check(int(record.soldiers) >= 4 and int(record.soldiers) <= 7, "Floor %02d has a bounded retinue" % (stage + 1))
		check(absf(float(record.center.y) - float(stage) * LAYOUT.FLOOR_HEIGHT) < 0.01, "Floor %02d encounter data uses its own height" % (stage + 1))
	check(DATA.record(9).boss_id == "grand_boss" and DATA.record(9).soldier_id == "grand_soldier", "The Grand Guard and its grounded retinue hold floor ten")
	check(DATA.record(10).boss_id == "main_boss" and DATA.record(10).soldier_id == "grand_soldier", "The main reaper and its faction hold floor eleven")
	check(DATA.HEALTH[10] > DATA.HEALTH[9] and DATA.HEALTH[9] > DATA.HEALTH[8], "Final-floor guardian health climbs in sequence")

	game.arena.set_stage(8)
	check(absf(game.arena.stage_ring.position.y - 8.0 * LAYOUT.FLOOR_HEIGHT - 0.06) < 0.01, "The arena boundary ring follows the selected floor")
	game.arena.set_stage(10)
	check(absf(game.arena.stage_radius - 132.0) < 0.01, "Upper-floor changes do not shrink the shared arena")
	check(game.arena.floor_for_position(LAYOUT.floor_spawn(10)) == 10, "The final lift arrival is recognized as floor eleven")

	print("ARENA_CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for path in [game.settings_path, game.settings_path.get_basename() + "_progress.cfg"]:
		for suffix in ["", ".bak", ".tmp"]:
			var candidate: String = path + suffix
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	quit(0 if failures.is_empty() else 1)
