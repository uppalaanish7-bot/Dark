extends SceneTree
const VISUAL = preload("res://scripts/provided_visual.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("202736")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=0.9
	world.add_child(environment)
	var light:=DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees=Vector3(-30,30,0)
	light.light_energy=2
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.position=Vector3(0,2,-7)
	camera.look_at(Vector3(0,1.1,0))
	camera.fov=35
	camera.current=true
	for i in 4:
		var visual:=VISUAL.new()
		visual.asset_id=["subboss_2", "subboss_3", "subboss_6", "subboss_8"][i]
		visual.position.x=-2.7+i*1.8
		world.add_child(visual)
		visual.rotation.y=0
		for instance in visual.model.find_children("*","MeshInstance3D",true,false):
			for s in instance.mesh.get_surface_count():
				var mat:StandardMaterial3D=instance.mesh.surface_get_material(s)
				print(visual.asset_id," ",instance.name," material ",mat.albedo_color," metal ",mat.metallic," rough ",mat.roughness," normal ",mat.normal_enabled," alpha ",mat.transparency)
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/boss_rig_front_reference.png")
	quit()
