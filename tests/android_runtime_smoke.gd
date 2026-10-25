extends SceneTree
## Injected into the validation ZIP made from the APK's assets. This exercises
## startup and gameplay against packaged resources with an isolated profile.
var game: Node3D
var checks := 0
var failures: Array[String] = []
var profile: String

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error(detail)

func frames(count: int) -> void:
	for n in count:
		await physics_frame
		await process_frame

func run() -> void:
	profile = "user://apk_runtime_smoke_%d.cfg" % Time.get_ticks_usec()
	game = load("res://ground.tscn").instantiate()
	game.settings_path = profile
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	check(game.state == "menu" and game.mobile_controls, "Packaged mobile lobby starts")
	game.start_run()
	game.set_process(false)
	game.player.invulnerable = 999
	for foe in game.combatants.get_children(): foe.set_physics_process(false)
	await frames(5)
	check(game.state == "playing" and get_nodes_in_group("bosses").size() == 11, "Packaged arena starts with eleven bosses")
	check(game.player.visual.asset_id == "female" and game.player.visual.animator.get_animation_list().size() >= 51, "Packaged female model and expanded motion load")
	var pad: Control = game.touch_controls
	var initial_shots: int = game.shots
	pad.begin_touch(91, pad.buttons.fire.get_center())
	pad.end_touch(91)
	check(game.shots == initial_shots + 1, "Packaged sword icon triggers a cut")
	await frames(35)
	pad.begin_touch(92, pad.buttons.jump.get_center())
	pad.end_touch(92)
	await frames(3)
	check(game.player.velocity.y > 0, "Packaged jump icon launches the hero")
	game.player.mana = 100
	pad.begin_touch(93, pad.buttons.aim.get_center())
	pad.end_touch(93)
	check(game.player.mana == 88, "Packaged ranged icon spends twelve mana")
	await frames(30)
	var boss: CharacterBody3D = get_first_node_in_group("bosses")
	game.player.health = 1
	game.player.mana = 0
	boss.die(false)
	check(game.player.health == 220 and game.player.mana == 110 and game.player.growth.level == 2, "Packaged boss victory grants growth and fills new vitality capacities")
	game.pause_game()
	check(game.state == "paused" and pad.fingers.is_empty(), "Packaged pause clears touch ownership")
	game.resume()
	game.show_menu()
	game.select_skin(1)
	game.start_run()
	check(game.player.visual.asset_id == "omega" and game.player.element() == "lightning", "Packaged character selection loads Omega lightning")
	check(game.player.growth.level == 2, "Packaged match restart keeps earned growth")
	game.show_menu()
	for id in game.CATALOG.requested.keys():
		var prefetched: Node = game.CATALOG.instantiate(id)
		if is_instance_valid(prefetched): prefetched.free()
	await create_timer(1.5).timeout
	game.free()
	await frames(2)
	for path in [profile, profile.get_basename() + "_progress.cfg"]:
		for suffix in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(path + suffix)
	print("ANDROID_PACKAGED_RUNTIME: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
