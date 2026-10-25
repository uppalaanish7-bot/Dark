extends SceneTree
## Repeatable close-up animation review on an actual shadow-receiving floor.
const VISUAL = preload("res://scripts/provided_visual.gd")
var actors: Array[Node3D] = []
var folder: String = "res://art/asset_review/enemy_motion_upgrade"

func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 680)
	DirAccess.make_dir_recursive_absolute(folder)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("111925")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c8d2e0")
	environment.environment.ambient_light_energy = 0.85
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 25, 0)
	light.light_color = Color("f5e4cb")
	light.light_energy = 1.5
	light.shadow_enabled = true
	world.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(30, 12)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("283445")
	material.roughness = 0.85
	floor_mesh.material_override = material
	world.add_child(floor_mesh)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(4.0, 4.3, -13.0)
	camera.look_at(Vector3(0, 1.15, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.4
	camera.current = true
	var ids: Array[String] = ["subboss_6", "subboss_3", "soldier_7", "main_boss"]
	for i in ids.size():
		var actor := VISUAL.new()
		actor.asset_id = ids[i]
		actor.target_height = 2.25
		world.add_child(actor)
		actor.position = Vector3((i - 1.5) * 2.3, 0.0, 0)
		actors.append(actor)
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var caption := Label.new()
	canvas.add_child(caption)
	caption.position = Vector2(30, 24)
	caption.add_theme_font_size_override("font_size", 25)
	for actor in actors:
		for i in 45: actor.tick(1.0 / 60.0, 0, true)
	for frame in 150:
		var speed: float = 0.0
		if frame < 24:
			caption.text = "Enemy motion / grounded guard"
		elif frame < 84:
			caption.text = "Enemy motion / preparation, impact, recovery"
			if frame == 24:
				actors[0].action("Sword_Attack", 2.0)
				actors[1].action("Fire_Combo", 2.0)
				actors[2].action("Punch_Jab", 2.0)
				actors[3].action("Void_Reap", 2.0)
		else:
			caption.text = "Enemy motion / planted stride and trailing cloth"
			speed = 4.4
		for actor in actors:
			actor.set_motion_state(Vector3(0, 0, -speed), true, 0, 0, false, false)
			actor.tick(1.0 / 30.0, speed, true)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "/%04d.png" % frame)
	print("ENEMY_MOTION_SHOWCASE_READY ", folder)
	quit()
