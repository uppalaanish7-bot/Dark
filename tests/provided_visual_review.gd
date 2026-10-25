extends SceneTree
const VISUAL = preload("res://scripts/character_visual.gd")
var visuals: Array[Node3D] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1000, 700)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("171e29")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c2cce8")
	environment.environment.ambient_light_energy = 0.65
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1.65, -4.8)
	camera.look_at(Vector3(0, 1, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.6
	camera.current = true
	for entry in [[Vector3(2,4,-3),Color("ffbe8c"),2.5],[Vector3(-3,3,-1),Color("70afff"),1.8]]:
		var light := OmniLight3D.new()
		world.add_child(light)
		light.position=entry[0]
		light.light_color=entry[1]
		light.light_energy=entry[2]
		light.omni_range=12
	for i in 2:
		var visual := VISUAL.new()
		world.add_child(visual)
		visual.position.x = -0.72 + i * 1.44
		visual.set_skin(i)
		visuals.append(visual)
		print("MODEL ",i," source=",visual.source_available," bones=",visual.skeleton.get_bone_count()," hand=",visual.hand," sword=",visual.weapon.get_child_count())
	for i in 12:
		for visual in visuals: visual.tick(1.0/60.0,0,true)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/provided_characters_idle.png")
	for visual in visuals: visual.action("Sword_Attack",0.65)
	for i in 18:
		for visual in visuals: visual.tick(1.0/60.0,0,true)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/provided_characters_slash.png")
	for i in 30:
		for visual in visuals: visual.tick(1.0/60.0,10,true)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/provided_characters_run.png")
	print("PROVIDED_VISUAL_REVIEW_COMPLETE")
	quit()
