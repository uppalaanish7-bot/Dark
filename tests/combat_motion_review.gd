extends SceneTree
## Isolated manual review; no changes to the player's saved campaign.
var game: Node3D
var last_attacks: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.title="Hero — Combat Motion Review"
	game=load("res://ground.tscn").instantiate()
	game.settings_path="user://motion_review_%d.cfg"%Time.get_ticks_usec()
	root.add_child(game)
	current_scene=game
	game.progress.create_world("Combat motion review")
	game.show_menu()
	game.select_skin(0 if OS.get_cmdline_user_args().has("fire") else 1)
	game.start_run()
	game.encounter_index=2
	game.completed_encounters=2
	for i in 2: game.arena.mark_encounter_complete(i)
	game.arena.set_encounter(2)
	game.player.position=game.ENCOUNTERS.CENTERS[2]+Vector3(0,0.1,12)
	game.player.invulnerable=9999
	game.player.pitch=-0.10
	game.player.update_camera(1)
	game.begin_encounter()
	print("COMBAT_MOTION_REVIEW_READY ",game.player.element())
func _process(_delta: float) -> bool:
	if not is_instance_valid(game) or not is_instance_valid(game.player): return false
	for enemy in get_nodes_in_group("enemies"):
		if enemy.attack_is_melee and enemy.attack_serial!=last_attacks.get(enemy.get_instance_id(),-1):
			last_attacks[enemy.get_instance_id()]=enemy.attack_serial
			print("REVIEW_MELEE ",enemy.asset_id," ",enemy.visual.current_clip," distance=",snappedf(enemy.global_position.distance_to(game.player.global_position),0.01))
	return false
