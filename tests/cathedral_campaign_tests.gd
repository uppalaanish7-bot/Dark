extends SceneTree
var game: Node3D
var failures: int = 0
var checks: int = 0
var test_save: String

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func frames(count: int = 3) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func run() -> void:
	game = load("res://ground.tscn").instantiate()
	# Keep temporary saves writable when testing directly from the packaged build.
	test_save = "user://cathedral_campaign_%d.cfg" % Time.get_ticks_usec()
	game.settings_path = test_save
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	await frames()
	check(game.player is CharacterBody3D, "Main scene instantiates functional player controller")
	check(game.player.visual.asset_id == "female", "Girl Knight is the default player")
	check(game.player.visual.source_available, "Player uses the supplied model")
	game.select_skin(1)
	check(game.player.visual.asset_id == "omega", "Omega Knight is selectable")
	game.select_skin(0)
	game.enter_world()
	game.accept_quest()
	await frames()
	check(game.state == "world", "Story dialogue returns to courtyard")
	game.enter_portal()
	await frames()
	check(game.state == "playing" and game.arena.is_inside_tree(), "Tower door enters cathedral")
	check(game.player.position.distance_to(game.arena.floor_spawn(0)) < 1.0, "Player enters on the first boss floor")
	check(not game.encounter_active, "Courts activate only when approached")
	check(game.arena.portal_active == false, "Exit is hidden before completion")
	game.player.position = game.ENCOUNTERS.CENTERS[0] + Vector3(0, 0.2, 18)
	await frames()
	check(game.encounter_active, "Approaching first sigil starts the court")
	check(get_nodes_in_group("bosses").size() == 1, "Each court has one distinct boss")
	check(get_nodes_in_group("enemies").size() == 5, "First court includes its four soldiers")
	game.player.mana = 37
	game.player.ultimate_cooldown = 17.0
	game.player.enchantment_time = 9.0
	game.player.health = 92
	var boss: Node = get_first_node_in_group("bosses")
	boss.health = 321
	boss.recalled_servants = 2
	var soldier: Node = get_nodes_in_group("enemies").filter(func(e): return not e.is_boss)[0]
	soldier.take_damage(9999)
	await frames()
	game.save_current_session()
	var snapshot: Dictionary = game.progress.session_for_world().duplicate(true)
	var remaining: int = get_nodes_in_group("enemies").size()
	game.begin_arena(snapshot)
	await frames()
	check(game.encounter_active and get_nodes_in_group("enemies").size() == remaining, "Resuming preserves defeated soldiers")
	check(is_equal_approx(get_first_node_in_group("bosses").health, 321), "Resuming preserves boss damage")
	check(get_first_node_in_group("bosses").recalled_servants == 2, "Resuming preserves the bounded servant-summoning budget")
	check(game.player.mana >= 37 and game.player.mana < 45, "Resuming preserves mana")
	check(game.player.ultimate_cooldown == 0, "Resuming removes the retired ultimate cooldown")
	check(game.player.enchantment_time > 8 and game.player.visual.weapon.has_node("LivingBladeFire"), "Resuming restores the active sword enchantment and its visual")
	game.pause_game()
	check(game.state == "paused" and paused, "Pause freezes the encounter")
	game.resume()
	check(game.state == "playing" and not paused, "Resume restores combat")
	game.player.award_xp(1200)
	game.pause_game()
	game.hud.show_growth()
	check(game.hud.is_growth_open and game.hud.growth_rows.size() == 6, "Pause exposes all six recovery and upgrade choices")
	for kind in ["power", "health", "magic", "overall"]:
		check(game.player.purchase_growth(kind), "Can purchase the " + kind + " upgrade in the saved world")
	var growth: Dictionary = game.player.growth_snapshot()
	var vital: float = game.player.health
	check(game.save_current_session() and game.progress.error.is_empty(), "XP and vital snapshot writes successfully")
	var upgraded: Dictionary = game.progress.session_for_world().duplicate(true)
	game.begin_arena(upgraded)
	await frames()
	check(game.player.growth_snapshot() == growth and is_equal_approx(game.player.health, vital), "Reload retains spent XP, every stat level and current HP")
	check(game.player.max_health == 240 and game.player.max_mana == 120 and is_equal_approx(game.player.damage_multiplier(), 1.2), "Saved levels restore their real combat capacities")
	var roaming: Node = game.spawn_actor(false, game.LAYOUT.room_centers(0)[0], 0, true)
	roaming.health = 31
	game.roaming_timer = 8.0
	game.save_current_session()
	var patrol_save: Dictionary = game.progress.session_for_world().duplicate(true)
	game.begin_arena(patrol_save)
	await frames()
	var patrols: Array = get_nodes_in_group("enemies").filter(func(e): return e.roaming)
	check(patrols.size() == 1 and patrols[0].health == 31 and patrols[0].encounter_index == 0, "Roaming survivor retains its own floor, identity and damage")
	check(game.roaming_timer < 8 and game.roaming_timer > 6, "Reload preserves the random spawn countdown")
	var before_patrol_xp: int = game.player.growth.xp
	var before_patrol_position: Vector3 = game.player.position
	game.player.position = patrols[0].position + Vector3(0, 0, 3)
	patrols[0].take_damage(9999)
	check(game.player.growth.xp == before_patrol_xp + 28, "Roaming minion awards floor-scaled XP")
	var patrol_dead: Dictionary = game.progress.session_for_world().duplicate(true)
	check(not patrol_dead.checkpoint.enemies.any(func(e): return e.roaming), "Reward transaction excludes the defeated roaming minion")
	check(not patrols[0].take_damage(9999) and game.player.growth.xp == before_patrol_xp + 28, "A defeated minion cannot grant its XP twice")
	game.player.position = before_patrol_position
	for index in range(11):
		if index > 0:
			game.player.position = game.ENCOUNTERS.CENTERS[index] + Vector3(0, 0.2, 18)
			await frames()
		check(game.encounter_index == index and game.encounter_active, "Court %02d activates in sequence" % (index + 1))
		var current: Node = get_first_node_in_group("bosses")
		check(is_instance_valid(current) and current.asset_id == game.ENCOUNTERS.record(index).boss_id, "Court %02d uses its supplied guardian" % (index + 1))
		if index == 3:
			var retry_soldier: Node = get_nodes_in_group("enemies").filter(func(e): return not e.is_boss and not e.roaming)[0]
			retry_soldier.take_damage(9999)
			current.health = 123
			var retry_growth: Dictionary = game.player.growth_snapshot()
			var retry_coins: int = game.progress.coins
			var retry_survivors: int = game.active_encounter_foes()
			game.player.invulnerable = 0
			game.player.receive_damage(9999)
			check(game.state == "dead", "Lethal damage opens defeat screen")
			game.retry_run()
			await frames()
			check(game.completed_encounters == 3 and game.player.health == game.player.max_health, "Retry retains cleared courts and restores upgraded vitality")
			check(game.player.growth_snapshot() == retry_growth and game.progress.coins == retry_coins, "Retry retains earned XP and coins without granting them again")
			check(game.encounter_active and game.active_encounter_foes() == retry_survivors and get_first_node_in_group("bosses").health == 123, "Retry retains damaged survivors and never respawns the rewarded soldier")
			game.player.position = game.ENCOUNTERS.CENTERS[index] + Vector3(0, 0.2, 18)
			await frames()
		if index == 10:
			get_first_node_in_group("bosses").take_damage(99999)
		else:
			for actor in get_nodes_in_group("enemies"):
				actor.take_damage(99999)
		await frames(5)
		check(game.completed_encounters == index + 1, "Court %02d clear is saved" % (index + 1))
		check(not game.arena.floor_unlocked(index) and not game.floor_keys[index], "Floor %02d stairs stay locked after the guardian falls without its key" % (index + 1))
		check(game.safe_floor_index() == index, "Checkpoint recovery cannot skip floor %02d's missing key" % (index + 1))
		if index == 0:
			var before_courtyard: Dictionary = game.player.growth_snapshot()
			game.return_to_courtyard()
			await frames()
			check(game.player.growth_snapshot() == before_courtyard, "Courtyard visit retains this world's XP and levels")
			game.pause_game()
			check(game.player.purchase_growth("power"), "Courtyard can spend earned XP on a power level")
			var courtyard_growth: Dictionary = game.player.growth_snapshot()
			game.resume()
			game.start_run()
			await frames()
			check(game.completed_encounters == 1 and not game.encounter_active and game.player.growth_snapshot() == courtyard_growth, "Tower return preserves the clear and courtyard XP purchase without respawning rewarded foes")
			check(game.arena.floor_for_position(game.player.position) == 0, "Tower return arrives below the still-locked first staircase")
		game.player.position = game.LAYOUT.key_position(index)
		game.player.velocity = Vector3.ZERO
		await frames()
		check(game.floor_keys[index] and game.arena.floor_unlocked(index), "Floor %02d key collection unlocks its defeated guardian's stairs" % (index + 1))
		check(game.key_room_discovered(index), "Floor %02d key room is recorded as explored" % (index + 1))
		if index < 10:
			check(not game.arena.portal_active, "Portal remains sealed after court %02d" % (index + 1))
	check(game.level_complete and game.arena.portal_active, "Main boss death unlocks the terrace and reveals the potion")
	check(get_nodes_in_group("enemies").is_empty(), "Final retinue dissolves with its sovereign")
	check(game.state == "playing", "Victory preserves movement toward the portal")
	check(game.progress.current_world().completed == 1, "Campaign completion recorded")
	check(not game.potion_collected and game.progress.current_world().quest == "active", "Defeating Nox does not grant the terrace potion remotely")
	game.player.position = game.arena.potion_position + Vector3(0, 0.2, 0)
	await frames()
	check(game.potion_collected and game.progress.current_world().quest == "elixir", "Reaching the terrace bottle collects the healing potion")
	game.player.position = game.arena.exit_position + Vector3(0, 0.2, 0)
	game.portal_cooldown = 0
	await frames()
	check(game.state == "construction", "Walking into portal enters next-level notice")
	var labels: Array[Node] = game.hud.modal_root.find_children("*", "RichTextLabel", true, false)
	check(labels.any(func(n): return n.text == "Next Level — Under Construction"), "Exact requested next-level message is visible")
	game.leave_next_portal()
	await frames()
	check(game.state == "playing" and game.player.position.distance_to(game.arena.exit_position) > 5, "Return avoids instantly reentering portal")
	game.save_current_session()
	var final_snapshot: Dictionary = game.progress.session_for_world().duplicate(true)
	game.begin_arena(final_snapshot)
	await frames()
	check(game.level_complete and game.arena.portal_active and not game.encounter_active, "Completed cathedral and portal survive resume")
	check(game.potion_collected and game.player.position.y > 197, "Terrace height and collected potion survive resume")
	var bad: Dictionary = final_snapshot.duplicate(true)
	bad.position = Vector3(INF, 0, 0)
	bad.checkpoint.player.mana = NAN
	var clean: Dictionary = game.SESSION.sanitize(bad, 1)
	check(clean.position.is_finite() and clean.checkpoint.player.mana == game.player.max_mana, "Invalid saved coordinates and mana respect upgraded capacity")
	check(game.SESSION.position(Vector3(190,0.1,180),"courtyard") == Vector3(190,0.1,180), "Expanded estate checkpoints remain valid beyond the old courtyard")
	check(game.SESSION.position(Vector3(250,0,0),"courtyard") == game.SESSION.COURTYARD_SPAWN, "Estate checkpoints outside solid ground return to the safe arrival")
	game.show_menu()
	for page in ["characters", "bestiary", "worlds", "lobby"]:
		game.hud.menu_root.open_page(page)
		await frames(1)
	check(game.state == "menu", "All updated lobby pages open")
	game.hud.show_controls()
	game.hud.show_settings()
	var progress_path: String = game.progress.path
	game.queue_free()
	await frames()
	for path in [progress_path, test_save]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	print("CATHEDRAL CAMPAIGN: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
