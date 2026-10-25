extends SceneTree
const VFX = preload("res://scripts/elemental_vfx.gd")
const FX = preload("res://scripts/effects.gd")
const ELEMENTS := ["stone","water","fire","soul","lightning","wind","poison","ice","gravity","lava","void"]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("07111d")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d7e4f5")
	environment.environment.ambient_light_energy = 0.8
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-30,0)
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,13,16)
	camera.look_at(Vector3(0,0,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19
	camera.current = true
	for i in ELEMENTS.size():
		var visual := VFX.new()
		visual.element = ELEMENTS[i]
		visual.radius = 0.42
		visual.position = Vector3((i%4-1.5)*4.4,0,(i/4-1)*4.5)
		visual.rotation.y = -0.35
		world.add_child(visual)
		var label := Label3D.new()
		label.text = ELEMENTS[i].to_upper()
		label.position = visual.position + Vector3(0,1.7,0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 34
		label.modulate = Color("c3dce7")
		world.add_child(label)
	for frame in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/elemental_projectiles.png")
	print("ELEMENTAL_RENDER_COMPLETE")
	quit()
