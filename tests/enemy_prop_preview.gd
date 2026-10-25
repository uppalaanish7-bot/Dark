extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1100,700)
	root.position=Vector2i(2800,1800)
	var world:=Node3D.new()
	root.add_child(world)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("273240")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=1.2
	world.add_child(env)
	var sun:=DirectionalLight3D.new()
	world.add_child(sun)
	sun.rotation_degrees=Vector3(-30,-20,0)
	sun.light_energy=2
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.position=Vector3(0,0.4,5)
	camera.look_at(Vector3(0,0.4,0))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1.7
	camera.current=true
	for identity in ["soldier_1","subboss_7"]:
		var source:Node3D=load("res://assets/provided/"+identity+".glb").instantiate()
		root.add_child(source)
		for original in source.find_children("*","MeshInstance3D",true,false):
			if not (original.name=="sword_sword_0" or original.name=="Object_193"): continue
			var mesh:=ArrayMesh.new()
			for surface in original.mesh.get_surface_count():
				var a:Array=original.mesh.surface_get_arrays(surface)
				a[Mesh.ARRAY_BONES]=null
				a[Mesh.ARRAY_WEIGHTS]=null
				a[Mesh.ARRAY_TANGENT]=null
				for custom in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]: a[custom]=null
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
				mesh.surface_set_material(surface,original.mesh.surface_get_material(surface))
			var prop:=MeshInstance3D.new()
			prop.mesh=mesh
			world.add_child(prop)
			prop.position.x=-0.6 if identity=="soldier_1" else 0.35
			if identity=="soldier_1": prop.basis=Basis(Vector3(0,0,1),Vector3(0,-1,0),Vector3(1,0,0))*0.011501
			else: prop.position.y=0.15
		source.free()
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/asset_review/loadouts/props.png")
	quit()
