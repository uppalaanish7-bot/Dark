extends SceneTree
## Uses the actual touch pad and integrated controller, with an isolated profile.
var game: Node3D
var checks: int = 0
var failures: Array[String] = []
var test_save: String

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("TOUCH CHECK: " + message)

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func touch(id: int, point: Vector2, pressed: bool = true, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	game.touch_controls._input(event)

func drag(id: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = point
	event.relative = relative
	game.touch_controls._input(event)

func run() -> void:
	test_save = "user://cathedral_touch_%d.cfg" % Time.get_ticks_usec()
	game = load("res://ground.tscn").instantiate()
	game.settings_path = test_save
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	await frames(3)
	check(game.mobile_controls, "Touch mode activates without mouse capture")
	game.start_run()
	game.set_process(false)
	game.player.invulnerable = 999
	await frames(5)
	var pad: Control = game.touch_controls
	var size: Vector2 = pad.size
	for dimensions in [Vector2(960, 600), Vector2(1067, 600), Vector2(1300, 600)]:
		pad.size = dimensions
		pad.update_layout()
		var visible_actions: Array = []
		for action in pad.buttons:
			if pad.action_visible(action): visible_actions.append(action)
		for i in visible_actions.size():
			var action: String = visible_actions[i]
			var area: Rect2 = pad.buttons[action]
			check(Rect2(Vector2.ZERO, dimensions).encloses(area), "%s fits landscape %s" % [action, dimensions])
			check(pad.hit_action(action, area.get_center()) and not pad.hit_action(action, area.position), "%s has a circular hit target" % action)
			for j in range(i + 1, visible_actions.size()):
				check(not area.intersects(pad.buttons[visible_actions[j]]), "%s and %s do not overlap at %s" % [action, visible_actions[j], dimensions])
	pad.size = size
	pad.update_layout()
	var sword: Vector2 = pad.buttons.fire.get_center()
	for action in pad.buttons:
		check(Rect2(Vector2.ZERO, size).encloses(pad.buttons[action]), "Touch %s remains within the viewport" % action)
	var shots: int = game.shots
	touch(1, sword)
	touch(1, sword, false)
	check(game.shots == shots + 1, "Quick sword tap registers between physics frames")
	check(game.player.mana == 100, "Touch sword is free")
	game.player.fire_timer = 0
	game.player.attack_pending = 0
	var origin := Vector2(110, size.y - 150)
	var start: Vector3 = game.player.position
	touch(2, origin)
	drag(2, origin + Vector2(0, -130), Vector2(0, -130))
	check(pad.movement.length() <= 1.001 and pad.is_held("sprint"), "Joystick clamps movement and enables free sprint")
	touch(3, Vector2(size.x * 0.52, 250))
	var yaw: float = game.player.yaw
	drag(3, Vector2(size.x * 0.52 + 25, 250), Vector2(25, 0))
	touch(4, sword)
	await frames(27)
	check(game.player.position.distance_to(start) > 3, "Player runs while a separate touch holds sword combat")
	check(game.player.yaw != yaw, "Independent camera finger changes aim")
	check(game.shots >= shots + 3, "Holding sword repeats the combo")
	touch(2, origin, false)
	check(pad.movement == Vector2.ZERO and pad.is_held("fire"), "Releasing movement leaves sword held")
	touch(5, sword)
	touch(4, sword, false)
	check(pad.is_held("fire"), "Two fingers on one action do not release it prematurely")
	touch(5, sword, false, true)
	check(not pad.is_held("fire"), "Canceled final touch clears the sword trigger")
	touch(3, Vector2.ZERO, false)
	pad.release_all()
	game.player.attack_pending = 0
	game.player.attack_kind = ""
	game.player.fire_timer = 0
	game.player.magic_cooldown = 0
	game.player.mana = 100
	var fire: Vector2 = pad.buttons.aim.get_center()
	touch(6, fire)
	check(game.player.mana == 88 and pad.is_held("aim"), "Touch FIRE immediately casts for twelve mana")
	await frames(26)
	check(game.player.mana <= 76, "Held FIRE repeats its magic cast")
	touch(6, fire, false, true)
	check(not pad.is_held("aim"), "Canceled FIRE stops continuous magic")
	await frames(12) # Let the last aimed shot reach its release before enchanting.
	game.player.mana = 100
	game.player.slash_cooldown = 0
	touch(7, pad.buttons.magic_slash.get_center())
	touch(7, Vector2.ZERO, false)
	check(game.player.mana == 74 and game.player.enchantment_time == 12, "Touch ENCHANT activates a twelve-second elemental sword")
	game.player.attack_pending = 0
	game.player.attack_kind = ""
	game.player.mana = 100
	game.player.ultimate_cooldown = 0
	touch(8, pad.buttons.ultimate.get_center())
	touch(8, Vector2.ZERO, false)
	check(game.player.mana == 30 and game.player.ultimate_cooldown == 0 and game.player.attack_kind == "ultimate", "Touch sky spell uses mana without a separate cooldown")
	game.player.attack_pending = 0
	game.player.attack_kind = ""
	game.player.position = game.arena.spawn_position
	game.player.velocity = Vector3.ZERO
	await frames(5)
	touch(9, pad.buttons.jump.get_center())
	touch(9, Vector2.ZERO, false)
	await frames(3)
	check(game.player.velocity.y > 0, "Touch jump lifts the player from the floor")
	touch(9, pad.buttons.jump.get_center())
	touch(9, Vector2.ZERO, false)
	await frames(2)
	check(game.player.air_jumps == 0, "Second touch jump spends the air jump")
	var mana: float = game.player.mana
	touch(10, pad.buttons.dodge.get_center())
	check(game.player.mana == mana and game.player.dash_timer > 0, "Touch dodge is free even in the air")
	touch(10, Vector2.ZERO, false)
	touch(11, sword)
	touch(12, fire)
	touch(13, pad.buttons.pause.get_center())
	check(game.state == "paused" and paused, "Touch pause stops the game")
	check(pad.fingers.is_empty() and pad.held_actions.is_empty() and pad.movement == Vector2.ZERO, "Pause clears every touch and movement vector")
	game.resume()
	check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "Touch resume keeps the pointer uncaptured")
	touch(14, sword)
	pad.size += Vector2(10, 0)
	check(pad.fingers.is_empty() and pad.held_actions.is_empty(), "Resizing the pad releases old finger ownership")
	# Run cleanup removes attached spells/telegraphs before the next session.
	game.player.attack_pending = 0
	game.player.attack_kind = ""
	game.player.dash_timer = 0
	game.player.magic_cooldown = 0
	game.player.mana = 100
	game.player.cast_firebolt()
	game.player.visual.tick(0.17, 0, true)
	game.player.attack_pending = 0
	game.player.resolve_attack()
	game.encounter_index = 2
	var actor: CharacterBody3D = game.spawn_actor(true, game.ENCOUNTERS.CENTERS[2])
	actor.begin_attack()
	check(not get_nodes_in_group("magic_projectiles").is_empty() and not get_nodes_in_group("combat_hazards").is_empty(), "Cleanup fixture has real spells and warnings")
	var epoch: int = game.session_id
	game.clear_run()
	check(game.session_id == epoch + 1, "Reset advances the combat session identity")
	check(game.combatants.get_child_count() == 0 and game.fx.get_child_count() == 0, "Reset detaches combatants and transient effects immediately")
	check(get_nodes_in_group("enemies").is_empty() and get_nodes_in_group("magic_projectiles").is_empty() and get_nodes_in_group("combat_hazards").is_empty(), "Old actors and spells no longer belong to live gameplay groups")
	check(pad.fingers.is_empty() and pad.held_actions.is_empty(), "Run reset clears held touch actions")
	var progress_path: String = game.progress.path
	# This fixture leaves before normal progression consumes its prefetched
	# second court. Collect those requests and let transient callbacks expire.
	for id in game.CATALOG.requested.keys():
		var prefetched: Node = game.CATALOG.instantiate(id)
		if is_instance_valid(prefetched): prefetched.free()
	await create_timer(0.9).timeout
	game.queue_free()
	await frames(3)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(progress_path + suffix)
	DirAccess.remove_absolute(test_save)
	print("TOUCH COMBAT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
