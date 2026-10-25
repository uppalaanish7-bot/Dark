extends SceneTree
const VISUAL = preload("res://scripts/character_visual.gd")
const EFFECTS = preload("res://scripts/effects.gd")
var actor: Node3D
var fx: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,800)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("081323")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b9cee8")
	env.environment.ambient_light_energy = 0.55
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,30,0)
	light.light_energy = 1.2
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(3.0,2.2,-4.5)
	camera.look_at(Vector3(0,1,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	camera.current = true
	actor = VISUAL.new()
	world.add_child(actor)
	actor.set_skin(0)
	if OS.get_cmdline_user_args().has("omega"): actor.set_skin(1)
	fx = EFFECTS.new()
	world.add_child(fx)
	fx.ignite_blade(actor.weapon,2.0)
	for i in 30:
		actor.tick(1.0/60,0,true)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/burning_sword.png")
	actor.action("Sword_Attack03",0.7)
	for i in 18:
		actor.tick(1.0/60,0,true)
		await process_frame
	camera.position = Vector3(8,5,7)
	camera.look_at(Vector3(0,1,-1.8))
	camera.size = 11.0
	fx.fire_slash(Vector3(0,1,0),0,5.0)
	for i in 4:
		actor.tick(1.0/60,0,true)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/living_fire_slash.png")
	print("FIRE_MAGIC_RENDER_COMPLETE")
	quit()
