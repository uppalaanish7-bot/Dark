extends SceneTree

const ARENA = preload("res://scripts/tower_arena.gd")
const PROGRESS = preload("res://scripts/progress.gd")
const DATA = preload("res://scripts/encounter_data.gd")

var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_audit")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("AUDIT FAILURE: " + detail)

func run_audit() -> void:
	print("==================================================")
	print("STARTING READ-ONLY AUDIT: ARENA & 11 BOSS BATTLE")
	print("==================================================")

	test_tower_arena_architecture()
	test_mocked_match_flow()

	print("==================================================")
	print("AUDIT COMPLETE: %d checks, %d failures" % [checks, failures.size()])
	print("==================================================")
	if failures.is_empty():
		print("AUDIT SUCCESSFUL: All arena and 11-boss systems validated!")
		quit(0)
	else:
		for f in failures:
			print("FAILED: " + f)
		quit(1)

func test_tower_arena_architecture() -> void:
	print("[1/2] Testing tower_arena.gd architecture...")
	var arena: Node3D = ARENA.new()
	root.add_child(arena)

	# 1. Bounds & Grid
	var bounds: Rect2 = arena.get_play_bounds()
	check(bounds.position.x == -138.0 and bounds.position.y == -138.0 and bounds.size.x == 276.0 and bounds.size.y == 276.0,
		"Arena play bounds are exactly 276m x 276m centered at (-138, -138)")

	# 2. Central Time Pillar
	check(arena.central_pillar != null, "Central Time Pillar exists")
	check(arena.pillar_beacon != null, "Monumental top beacon light exists")

	# Test initial position (10:00 -> ratio 1.0)
	arena.set_pillar_time_ratio(1.0)
	check(absf(arena.central_pillar.position.y - 0.0) < 0.01,
		"Pillar at ratio 1.0 (start: 10:00) is at y = 0.0 (full 40m height above floor)")

	# Test 5-minute position (5:00 -> ratio 0.5)
	arena.set_pillar_time_ratio(0.5)
	check(absf(arena.central_pillar.position.y - (-20.0)) < 0.01,
		"Pillar at ratio 0.5 (half-time: 5:00) is at y = -20.0m (descended by 20m)")

	# Test 0-minute position (0:00 -> ratio 0.0)
	arena.set_pillar_time_ratio(0.0)
	check(absf(arena.central_pillar.position.y - (-40.0)) < 0.01,
		"Pillar at ratio 0.0 (end: 0:00) is at y = -40.0m (flush with arena floor)")

	# 3. 11 Boss Perimeter Encounter Positions
	check(arena.encounter_positions.size() == 11, "Arena defines exactly 11 perimeter encounter positions")
	for i in range(11):
		var pos: Vector3 = arena.encounter_positions[i]
		var dist := Vector2(pos.x, pos.z).length()
		check(dist >= 74.0 and dist <= 96.0, "Boss position %d is on perimeter ring (r = %.1fm)" % [i, dist])

	# 4. Mobile Light Count Audit
	var omni_lights: Array[OmniLight3D] = []
	for child in arena.get_children():
		if child is OmniLight3D and not child.is_queued_for_deletion():
			omni_lights.append(child)
	# Should have 4 cardinal perimeter lights + 0 old cathedral lights
	check(omni_lights.size() == 4, "Perimeter lights consolidated to exactly 4 cardinal fill lights (found %d)" % omni_lights.size())

	# Central beacon is child of central_pillar
	var pillar_lights: int = 0
	for child in arena.central_pillar.get_children():
		if child is OmniLight3D:
			pillar_lights += 1
	check(pillar_lights == 1, "Central pillar has exactly 1 beacon light")

	# Total arena dynamic omni lights = 4 + 1 = 5 (strictly < 8 mobile limit)
	check(omni_lights.size() + pillar_lights <= 8, "Total arena dynamic omni lights (%d) is within mobile 8-light budget" % [omni_lights.size() + pillar_lights])

	# 5. Collision checks
	check(arena._body != null, "StaticBody3D collision exists")
	check(arena.is_walkable(Vector3(50, 0, 50)), "Arena stage is walkable")
	arena.set_pillar_time_ratio(1.0)
	check(not arena.is_walkable(Vector3(0, 0, 0)), "Central pillar base blocks walking when above floor")

	arena.queue_free()

func test_mocked_match_flow() -> void:
	print("[2/2] Testing match flow & 11 bosses with isolated mock profile...")
	var mock_settings_path := "user://audit_mock_settings_%d.cfg" % Time.get_ticks_usec()
	var mock_profile_path := "user://audit_mock_profile_%d.cfg" % Time.get_ticks_usec()

	var game_scene = load("res://ground.tscn")
	var game = game_scene.instantiate()

	# Route away from real user profile
	game.settings_path = mock_settings_path
	game.progress = PROGRESS.new(mock_profile_path)
	game.capture_mouse = false

	root.add_child(game)

	# Enter battle royale
	game.start_run()

	check(game.state == "playing", "Game state is 'playing'")
	check(game.match_time_remaining == 600.0, "Initial match time is 600.0s (10:00)")
	check(game.bosses_alive == 11, "Initial bosses_alive is 11")

	# Verify all 11 bosses exist in combatants
	var boss_count: int = 0
	var bosses: Array[CharacterBody3D] = []
	for child in game.combatants.get_children():
		if child is CharacterBody3D and child.get("is_boss") == true:
			boss_count += 1
			bosses.append(child)
	check(boss_count == 11, "Exactly 11 bosses spawned simultaneously in combatants")

	# Verify Player & Partner Bot
	check(game.player != null and is_instance_valid(game.player), "Player is active")
	check(game.ally_bot != null and is_instance_valid(game.ally_bot), "AI Partner Bot is active")
	check(absf(game.player.global_position.x - (-4.0)) < 0.5, "Player at x = -4")
	check(absf(game.ally_bot.global_position.x - 4.0) < 0.5, "Ally Bot at x = 4")

	# Simulate 60 seconds (1 minute elapsed)
	game._process(60.0)
	check(absf(game.match_time_remaining - 540.0) < 0.01, "Match time after 1 min is 540s (9:00)")
	check(absf(game.arena.central_pillar.position.y - (-4.0)) < 0.05, "Pillar descended 4m to y = -4.0m")
	check(game._last_minute_announced == 9, "9 minutes milestone announced")

	# Test Boss Defeat and Full Heal / Strength
	var first_boss = bosses[0]
	game.player.health = 50.0 # Damage player first
	first_boss.die(false)
	check(game.bosses_alive == 10, "Defeating boss decrements bosses_alive to 10")
	check(game.player.health == game.player.max_health, "Defeating boss grants full health recovery")
	check(game.player.mana == game.player.max_mana, "Defeating boss grants full mana recovery")

	# Clean up game node
	game.queue_free()

	# Remove mock test files
	var dir := DirAccess.open("user://")
	if dir != null:
		if dir.file_exists(mock_settings_path.replace("user://", "")):
			dir.remove(mock_settings_path.replace("user://", ""))
		if dir.file_exists(mock_profile_path.replace("user://", "")):
			dir.remove(mock_profile_path.replace("user://", ""))
		if dir.file_exists(mock_profile_path.replace("user://", "") + ".bak"):
			dir.remove(mock_profile_path.replace("user://", "") + ".bak")
