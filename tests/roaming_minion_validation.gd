extends SceneTree
## Regression for roaming actors on the live Battle Royale arena.
const ENEMY = preload("res://scripts/enemy.gd")
var checks := 0
var failures := 0
var game: Node3D
var minion: CharacterBody3D
var review_save: String

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
	else:
		print("PASS: ", detail)

func run() -> void:
	game = load("res://ground.tscn").instantiate()
	game.capture_mouse = false
	review_save = "user://roaming_validation_%d.cfg" % Time.get_ticks_usec()
	game.settings_path = review_save
	root.add_child(game)
	game.progress.create_world("Roaming arena regression")
	game.start_run()
	game.set_process(false)
	game.set_physics_process(false)
	game.arena.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.invulnerable = 9999
	var baseline_foes: int = game.active_encounter_foes()
	minion = game.spawn_actor(false, Vector3(-60, 0.12, 0), 0, true)
	minion.set_physics_process(false)
	await physics_frame
	check(game.arena.has_method("route"), "Live tower arena exposes route navigation")
	var path: PackedVector2Array = game.arena.route(Vector3(-60, 0.12, 0), Vector3(60, 0.12, 0))
	check(path.size() > 1, "Live arena computes a path across its open floor")
	game.player.position = Vector3(60, 0.12, 0)
	check(not minion.outside_court(), "Roaming minion can engage across the open arena")
	game.player.position.y += 8.0
	check(minion.outside_court(), "Roaming minion respects the vertical combat leash")
	game.player.position.y -= 8.0
	var count_before: int = game.active_encounter_foes()
	check(count_before == baseline_foes, "Roaming minion is excluded from guardian encounter counts")
	var boss: CharacterBody3D = game.spawn_actor(true, Vector3(85, 0.12, -30), 0)
	boss.set_physics_process(false)
	game.encounter_active = true
	check(game.active_encounter_foes() == baseline_foes + 1, "Active guardian counts independently of roaming minions")
	game.free()
	await process_frame
	for file_path in [review_save, review_save.get_basename() + "_progress.cfg"]:
		var absolute_path: String = ProjectSettings.globalize_path(file_path)
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(absolute_path + suffix):
				DirAccess.remove_absolute(absolute_path + suffix)
	print("ROAMING_MINION_VALIDATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
