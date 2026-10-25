extends SceneTree
## Four fixed views of the supplied equipment for physical attack classification.
const VISUAL = preload("res://scripts/provided_visual.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600, 700)
	root.position = Vector2i(2800,1800)
	root.title = "Enemy equipment inspection"
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("273240")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 1.0
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 25, 0)
	light.light_energy = 1.4
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1.35, -12)
	camera.look_at(Vector3(0, 1.35, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.3
	camera.current = true
	DirAccess.make_dir_recursive_absolute("res://art/asset_review/loadouts")
	var identities: Array = ["soldier_1", "soldier_2", "soldier_3", "soldier_4", "soldier_5", "soldier_7", "soldier_8", "subboss_3", "subboss_7"]
	if not OS.get_cmdline_user_args().is_empty(): identities = Array(OS.get_cmdline_user_args())
	for id in identities:
		var actors: Array[Node3D] = []
		for side in range(4):
			var actor := VISUAL.new()
			actor.asset_id = id
			actor.target_height = 2.1
			world.add_child(actor)
			actor.position.x = (float(side) - 1.5) * 1.8
			actor.rotation.y = side * PI * 0.5
			actor.tick(0.05, 0, true)
			actors.append(actor)
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/asset_review/loadouts/" + id + ".png")
		if id in ["soldier_1", "subboss_7"]:
			for phase in [0.20, 0.43, 0.74]:
				for actor in actors:
					actor.animator.play("Sword_Attack",0)
					actor.animator.seek(actor.animator.get_animation("Sword_Attack").length*phase,true)
					actor.update_weapon()
				for frame in 2: await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://art/asset_review/loadouts/%s_attack_%02d.png" % [id,int(phase*100)])
		for actor in actors: actor.free()
	print("LOADOUT_PREVIEWS_READY")
	quit()
