extends SceneTree
## Contact sheets from the actual runtime rigs and supplied-weapon profiles.
const VISUAL = preload("res://scripts/provided_visual.gd")
const LOADOUT = preload("res://scripts/enemy_loadout.gd")
var folder := "res://art/asset_review/choreography"

func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600, 720)
	root.title = "Enemy choreography review"
	DirAccess.make_dir_recursive_absolute(folder)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("162130")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d3dfeb")
	environment.environment.ambient_light_energy = 0.9
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 20, 0)
	light.light_energy = 1.3
	light.shadow_enabled = true
	world.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(35, 20)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("344255")
	material.roughness = 0.8
	floor_mesh.material_override = material
	world.add_child(floor_mesh)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0.0, 2.9, -15.0)
	camera.look_at(Vector3(0, 1.3, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.0
	camera.current = true
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var caption := Label.new()
	canvas.add_child(caption)
	caption.position = Vector2(30, 20)
	caption.add_theme_font_size_override("font_size", 25)
	var ids: Array[String] = []
	for n in range(1, 10): ids.append_array(["subboss_" + str(n), "soldier_" + str(n)])
	ids.append_array(["grand_boss", "grand_soldier", "main_boss"])
	if not OS.get_cmdline_user_args().is_empty(): ids.assign(OS.get_cmdline_user_args())
	for id in ids:
		var actors: Array[Node3D] = []
		var cue: String = LOADOUT.melee_cue(id, 0)
		caption.text = id + " / " + LOADOUT.profile(id).kind + " / " + cue + "     |     guard - run - anticipation - contact"
		for index in 4:
			var actor := VISUAL.new()
			actor.asset_id = id
			world.add_child(actor)
			# The front camera looks toward +Z, so screen-right is world -X.
			actor.position.x = (1.5 - index) * 2.35
			actor.rotation.y = -0.26
			for frame in 50: actor.tick(1.0 / 60.0, 0.0, true)
			if index == 1:
				for frame in 44:
					actor.set_motion_state(Vector3(0, 0, -4.7), true, 0, 0, false, false)
					actor.tick(1.0 / 60.0, 4.7, true)
			if index > 1:
				actor.action(cue, 1.0)
				for frame in (18 if index == 2 else 28): actor.tick(1.0 / 60.0, 0.0, true)
			actors.append(actor)
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "/" + id + ".png")
		for actor in actors: actor.free()
	print("ENEMY_CHOREOGRAPHY_REVIEW_READY ", ids.size())
	quit()
