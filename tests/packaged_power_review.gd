extends SceneTree
## Standalone-pack review: all game resources come from Hero.pck. The unique
## profile keeps manual input and testing away from the player's real save.
var game: Node3D
var last_cast: bool = false
var casts: int = 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.title="Hero — Packaged Elemental Review"
	game=load("res://ground.tscn").instantiate()
	game.settings_path="user://packaged_elements_%d.cfg"%Time.get_ticks_usec()
	root.add_child(game)
	current_scene=game
	game.progress.create_world("Elemental input review")
	game.show_menu()
	game.select_skin(0 if OS.get_cmdline_user_args().has("fire") else 1)
	game.start_run()
	game.encounter_index=1
	game.completed_encounters=1
	game.arena.mark_encounter_complete(0)
	game.arena.set_encounter(1)
	game.player.position=game.ENCOUNTERS.CENTERS[1]+Vector3(0,0.1,15)
	game.player.invulnerable=9999
	game.player.pitch=-0.05
	game.player.update_camera(1)
	game.begin_encounter()
	print("PACKAGED_ELEMENTAL_READY element=",game.player.element()," health=",game.player.health)
func _process(_delta: float) -> bool:
	if not is_instance_valid(game) or not is_instance_valid(game.player): return false
	var casting: bool=game.player.attack_kind=="ultimate"
	if casting and not last_cast:
		casts+=1
		print("PACKAGED_R_CAST ",casts," element=",game.player.element()," mana=",game.player.mana)
	last_cast=casting
	return false
