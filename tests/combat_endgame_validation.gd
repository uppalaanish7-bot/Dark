extends SceneTree
## Real-game regression: a lethal multi-target cast must finish the level safely.
var game: Node3D
var checks: int = 0
var failures: Array[String] = []
var save_path: String

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("ENDGAME CHECK: " + message)

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func run() -> void:
	save_path = "user://cathedral_endgame_%d.cfg" % Time.get_ticks_usec()
	game = load("res://ground.tscn").instantiate()
	game.settings_path = save_path
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	await frames()
	game.start_run()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.encounter_index = 10
	game.completed_encounters = 10
	game.player.position = game.ENCOUNTERS.CENTERS[10] + Vector3(0, 0.12, 4)
	game.player.attack_yaw = 0
	game.player.health = 83
	game.player.invulnerable = 0
	game.begin_encounter()
	for actor in get_nodes_in_group("enemies"):
		actor.set_physics_process(false)
	var boss: Node = get_first_node_in_group("bosses")
	var retinue: Array[Node] = get_nodes_in_group("enemies").filter(func(actor): return not actor.is_boss)
	check(is_instance_valid(boss) and retinue.size() == 7, "Final encounter has the sovereign and seven bound servants")
	# A removed caster must never leave an independently lethal projectile.
	var removed: CharacterBody3D = game.spawn_actor(false, game.player.position + Vector3(0, 0, -4))
	removed.fire_bolt(Vector3.BACK, 40, 100)
	var orphan: Node = get_nodes_in_group("magic_projectiles").back()
	orphan.set_physics_process(false)
	removed.free()
	orphan._physics_process(0.2)
	check(orphan.is_queued_for_deletion() and game.player.health == 83, "Projectile from a freed caster cancels before applying damage")
	var caster: Node = retinue[0]
	caster.fire_bolt(Vector3.FORWARD, 40, 100)
	var hostile: Node = get_nodes_in_group("magic_projectiles").back()
	hostile.set_physics_process(false)
	caster.line_at(game.player.position, 0, 8, 3, 0.1, 100)
	var ground_attack: Node = get_nodes_in_group("combat_hazards").back()
	ground_attack.set_physics_process(false)
	boss.health = 220
	for actor in retinue:
		actor.health = 50
	var coins_before: int = game.progress.coins
	var kills_before: int = game.kills
	var sky_spell := preload("res://scripts/player_sky_spell.gd").new()
	sky_spell.game = game
	sky_spell.caster = game.player
	sky_spell.element = "lightning" if OS.get_cmdline_user_args().has("lightning") else "fire"
	sky_spell.position = boss.position
	game.combatants.add_child(sky_spell)
	sky_spell.impact()
	check(boss.dead, "The lethal sky spell defeats Nox")
	check(game.kills == kills_before + 1 and game.progress.coins == coins_before + game.CAMPAIGN.BOSS_COINS, "Cached multi-target lists cannot reward dissolved servants")
	check(get_nodes_in_group("enemies").is_empty(), "All servants leave gameplay groups immediately")
	check(not caster.take_damage(9999), "A queued servant rejects subsequent same-frame damage")
	hostile._physics_process(0.2)
	ground_attack._physics_process(0.2)
	check(hostile.is_queued_for_deletion(), "A dissolved servant's in-flight projectile cancels immediately")
	check(ground_attack.is_queued_for_deletion(), "A dissolved servant's ground warning cancels immediately")
	check(game.player.health == 89, "No hostile spell damage interrupts the elimination's healing reward")
	await frames(3)
	check(game.level_complete and game.arena.portal_active and game.state == "playing", "The multi-target final blow opens the portal and keeps exploration active")
	check(game.kills == kills_before + 1 and game.progress.coins == coins_before + game.CAMPAIGN.BOSS_COINS + game.CAMPAIGN.CLEAR_COINS, "Completion grants only the sovereign reward and one first-clear bonus")
	check(game.player.health == game.player.MAX_HEALTH and game.player.mana == game.player.MAX_MANA, "The completion reward restores vitality and mana")
	check(get_nodes_in_group("combat_hazards").is_empty() and get_nodes_in_group("magic_projectiles").is_empty(), "No hostile attack survives into portal exploration")
	var progress_path: String = game.progress.path
	await create_timer(0.9).timeout
	# This test jumps from arrival directly to the final court; collect the
	# introductory background requests that normal progression would consume.
	for id in game.CATALOG.requested.keys():
		var prefetched: Node = game.CATALOG.instantiate(id)
		if is_instance_valid(prefetched): prefetched.free()
	game.queue_free()
	await frames(3)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(progress_path + suffix)
	DirAccess.remove_absolute(save_path)
	print("ENDGAME COMBAT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
