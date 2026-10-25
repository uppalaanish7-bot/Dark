extends SceneTree
const VISUAL = preload("res://scripts/provided_visual.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1400, 750)
	root.position = Vector2i(2800, 1800)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("273240")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.9
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	sun.light_energy = 1.5
	world.add_child(sun)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1.25, -10)
	camera.look_at(Vector3(0, 1.25, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	camera.current = true
	var actors: Array[Node3D] = []
	for side in 3:
		var actor := VISUAL.new()
		actor.asset_id = "subboss_7"
		world.add_child(actor)
		actor.position.x = (side - 1) * 1.8
		actor.rotation.y = side * PI * 0.25
		actors.append(actor)
	for clip in ["Rifle_Aim_Shot", "Rifle_Butt"]:
		for actor in actors: actor.action(clip, 1.0)
		for frame in 61:
			for actor in actors: actor.tick(1.0 / 60.0, 0.0, true)
			if frame in [0, 17, 25, 43, 60]:
				for i in 2: await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://art/asset_review/loadouts/%s_%02d.png" % [clip, frame])
	print("RIFLE_PREVIEW_READY")
	quit()
