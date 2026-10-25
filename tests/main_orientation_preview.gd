extends SceneTree
const VISUAL = preload("res://scripts/provided_visual.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202736")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.9
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-30, 30, 0)
	light.light_energy = 2
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 2, -8)
	camera.look_at(Vector3(0, 1.1, 0))
	camera.fov = 35
	camera.current = true
	for i in 4:
		var visual := VISUAL.new()
		visual.asset_id = "main_boss"
		visual.position.x = -2.7 + i * 1.8
		world.add_child(visual)
		visual.rotation.y = i * PI / 2
		var label := Label3D.new()
		world.add_child(label)
		label.position = visual.position + Vector3(0, 2.35, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.text = "MAIN / %d deg" % (i * 90)
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/main_orientation.png")
	quit()
