extends SceneTree
## Launch with build/Hero.exe --main-pack build/Hero.pck and this absolute script.
## Manual input review uses an isolated profile and never loads the normal save.
var game: Node3D
var test_save: String
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.title = "Hero — Packaged Review"
	test_save = "user://packaged_manual_%d.cfg" % Time.get_ticks_usec()
	game = load("res://ground.tscn").instantiate()
	game.settings_path = test_save
	root.add_child(game)
	current_scene = game
	game.progress.create_world("Packaged Review")
	game.hud.menu_root.open_page("lobby")
	print("PACKAGED_MANUAL_READY | private profile | build resources loaded")
	# Begin close to the doorway after the initial quest, then use the real
	# entrance trigger. This keeps manual input review bounded on the huge estate.
	while game.state not in ["world","playing"]:
		await process_frame
	if game.state == "world":
		game.player.position = Vector3(0,0.1,-8.6)
		game.player.safe_position = game.player.position
		game.player.yaw = 0
		game.player.pitch = -0.07
		game.player.update_camera(1)
	while game.state != "playing": await process_frame
	game.player.invulnerable = 9999
	game.player.position = game.ENCOUNTERS.CENTERS[0] + Vector3(0,0.1,17)
	game.player.safe_position = game.player.position
	game.player.update_camera(1)
	print("PACKAGED_COMBAT_READY | real inputs enabled")
