extends SceneTree
## Regression checks for guardian rewards: capacity may grow, current health may not.
const GAME_SCENE := preload("res://ground.tscn")
var game: Node3D
var checks: int = 0
var failures: Array[String] = []
var settings_path: String

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("BOSS REWARD: " + detail)

func run() -> void:
	settings_path = "user://boss_reward_validation_%d.cfg" % Time.get_ticks_usec()
	game = GAME_SCENE.instantiate()
	game.settings_path = settings_path
	game.capture_mouse = false
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.start_run()
	var boss: CharacterBody3D
	for actor in game.combatants.get_children():
		if actor is CharacterBody3D and actor.is_in_group("bosses"):
			boss = actor
			break
	check(is_instance_valid(boss), "The floor-one guardian is available for a real defeat callback")
	if is_instance_valid(boss):
		game.player.health = 23.0
		game.player.mana = 6.0
		boss.die(false)
		check(game.player.health == 23.0 and game.player.mana == 6.0, "Guardian rewards do not restore either vital bar")
		check(game.player.max_health == 220.0 and game.player.max_mana == 110.0, "Guardian reward raises capacity without filling it")
		check(game.player.growth.level == 2 and game.player.growth.xp > 0, "Guardian reward still grants growth and XP")
		var growth: Dictionary = game.player.growth_snapshot()
		game.on_boss_killed(boss)
		check(game.player.growth_snapshot() == growth and game.player.health == 23.0, "A duplicate reward callback has no effect")
		check(game.player.growth_purchase_reason("heal") != "", "The healing upgrade stays blocked during a floor")
	for actor in game.combatants.get_children():
		if actor is CharacterBody3D and actor.is_in_group("enemies") and not actor.dead:
			actor.die(false)
			actor.queue_free()
	game.advance_battle_stage()
	check(game.lift_activated and game.encounter_index == 0, "Clearing all floor-one fighters activates the lift and keeps floor two locked")
	check(game.player.health == 23.0, "The floor clear itself does not heal before ascent")
	for failure in failures:
		print("BOSS_REWARD_FAILED ", failure)
	print("BOSS_REWARD_CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for path in [settings_path, settings_path.get_basename() + "_progress.cfg"]:
		for suffix in ["", ".bak", ".tmp"]:
			var candidate: String = path + suffix
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	quit(0 if failures.is_empty() else 1)
