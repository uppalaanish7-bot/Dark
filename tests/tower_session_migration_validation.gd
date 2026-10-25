extends SceneTree
## Check saved hall progress against the tower's new vertical coordinates.
const SESSION = preload("res://scripts/world_session.gd")
const LAYOUT = preload("res://scripts/tower_layout.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	for stage in range(11):
		var legacy: Dictionary = legacy_session(stage)
		var migrated: Dictionary = SESSION.migrate({"session": legacy})
		var checkpoint: Dictionary = migrated.checkpoint
		check(migrated.version == SESSION.VERSION and checkpoint.version == SESSION.VERSION, "Floor %d upgrades both save versions" % (stage + 1))
		check(migrated.position.is_equal_approx(Vector3(7, stage * 18.0 + 0.12, 16)), "Floor %d preserves player's chamber-relative location" % (stage + 1))
		check(checkpoint.encounter_index == stage and checkpoint.completed_encounters == stage and checkpoint.encounter_active, "Floor %d preserves the active encounter and cleared count" % (stage + 1))
		check(checkpoint.enemies.size() == 2 and checkpoint.enemies[0].boss and checkpoint.enemies[0].health == 321 and checkpoint.enemies[0].recalled_servants == 2, "Floor %d preserves survivors, boss damage and summon budget" % (stage + 1))
		check(checkpoint.enemies[0].position.is_equal_approx(Vector3(-3, stage * 18.0 + 0.12, -6)) and checkpoint.enemies[1].position.is_equal_approx(Vector3(8, stage * 18.0 + 0.12, 9)), "Floor %d moves both enemies to their own chamber" % (stage + 1))
		check(checkpoint.player.health == 92 and checkpoint.player.mana == 37 and checkpoint.player.enchantment_time == 9 and checkpoint.player.ultimate_cooldown == 0, "Floor %d preserves resources and removes retired ultimate cooldown" % (stage + 1))
		check(SESSION.sanitize(migrated, 1) == migrated, "Floor %d migration is idempotent on later loads" % (stage + 1))
		legacy.checkpoint.encounter_active = false
		var between: Dictionary = SESSION.sanitize(legacy, 1)
		check(between.position.is_equal_approx(LAYOUT.floor_spawn(stage)) and between.checkpoint.enemies.is_empty() and between.checkpoint.completed_encounters == stage, "Floor %d inactive checkpoint restarts at its safe arrival" % (stage + 1))
	var cleared: Dictionary = legacy_session(10)
	cleared.checkpoint.completed_encounters = 11
	cleared.checkpoint.level_complete = true
	var final: Dictionary = SESSION.sanitize(cleared, 1)
	check(final.checkpoint.level_complete and final.checkpoint.completed_encounters == 11 and not final.checkpoint.encounter_active and final.checkpoint.enemies.is_empty(), "A completed legacy tower stays clear")
	check(not final.checkpoint.potion_collected, "A legacy checkpoint alone does not remotely collect the terrace potion")
	check(final.position.is_equal_approx(LAYOUT.floor_spawn(10)), "A completed legacy save resumes on the final floor below the terrace")
	var current: Dictionary = final.duplicate(true)
	current.position = LAYOUT.POTION_POSITION
	current.checkpoint.potion_collected = true
	var terrace: Dictionary = SESSION.sanitize(current, 1)
	check(terrace.position.is_equal_approx(LAYOUT.POTION_POSITION) and terrace.checkpoint.potion_collected, "Current saves preserve terrace height and potion collection")
	current.position = Vector3(LAYOUT.UPPER_FLIGHT_X, 171.25, LAYOUT.STAIR_TURN_Z + LAYOUT.STEP_RUN)
	check(SESSION.sanitize(current, 1).position.is_equal_approx(current.position), "Current saves preserve an upper-floor staircase location")
	var corrupt: Dictionary = legacy_session(6)
	corrupt.position = Vector3(INF, 0, 0)
	corrupt.checkpoint.enemies[0].position = Vector3(NAN, 0, 0)
	var repaired: Dictionary = SESSION.sanitize(corrupt, 1)
	check(repaired.position.is_equal_approx(Vector3(0, 108.12, 0)) and repaired.checkpoint.enemies[0].position.is_equal_approx(Vector3(0, 108.12, 0)), "Invalid legacy positions recover on their own floor")
	var old_arena: Dictionary = legacy_session(3)
	old_arena.version = 1
	old_arena.checkpoint.version = 1
	check(SESSION.sanitize(old_arena, 1).checkpoint.is_empty() and SESSION.sanitize(old_arena, 1).position == SESSION.ARENA_SPAWN, "Retired gun-arena checkpoints restart at the new entrance")
	print("TOWER SESSION MIGRATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func legacy_session(stage: int) -> Dictionary:
	var center: Vector3 = SESSION.LEGACY_CENTERS[stage]
	return {
		"version": 2, "visited": true, "place": "arena", "position": center + Vector3(7, 0.12, 16), "yaw": 0.4, "pitch": 0.15,
		"checkpoint": {
			"version": 2, "encounter_index": stage, "completed_encounters": stage, "encounter_active": true, "level_complete": false,
			"player": {"health": 92, "mana": 37, "enchantment_time": 9, "ultimate_cooldown": 17},
			"enemies": [
				{"boss": true, "position": center + Vector3(-3, 0.12, -6), "health": 321, "recalled_servants": 2},
				{"boss": false, "position": center + Vector3(8, 0.12, 9), "health": 64}
			]
		}
	}

func check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("MIGRATION CHECK: " + detail)
