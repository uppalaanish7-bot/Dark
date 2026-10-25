extends SceneTree
## Compare preserved source geometry, guarded pose, windup and contact.
const VISUAL = preload("res://scripts/provided_visual.gd")
const LOADOUT = preload("res://scripts/enemy_loadout.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1600,760)
	root.position=Vector2i(2800,1800)
	var world:=Node3D.new()
	root.add_child(world)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("273240")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=1.1
	world.add_child(env)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-35,25,0)
	light.light_energy=1.5
	world.add_child(light)
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.position=Vector3(0,1.4,-12)
	camera.look_at(Vector3(0,1.4,0))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_WIDTH
	camera.size=10.3
	camera.current=true
	DirAccess.make_dir_recursive_absolute("res://art/asset_review/equipment")
	for id in OS.get_cmdline_user_args():
		var holders:Array[Node3D]=[]
		var raw:Node3D=load("res://assets/provided/"+id+".glb").instantiate()
		root.add_child(raw)
		var facing:=Basis(Vector3.UP,PI/2 if id in ["main_boss","subboss_2","subboss_4","subboss_5","subboss_6","subboss_8","soldier_3","soldier_4"] else PI)
		var source:=Node3D.new()
		world.add_child(source)
		source.position.x=3.45
		holders.append(source)
		var geometry:Array=[]
		for piece in raw.find_children("*","MeshInstance3D",true,false):
			var transform:Transform3D=Transform3D(facing,Vector3.ZERO)*raw.global_transform.affine_inverse()*piece.global_transform
			var mesh:=ArrayMesh.new()
			for s in piece.mesh.get_surface_count():
				var arrays:Array=piece.mesh.surface_get_arrays(s)
				var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				var points:Array=[]
				for n in vertices.size():
					vertices[n]=transform*vertices[n]
					normals[n]=(transform.basis.inverse().transposed()*normals[n]).normalized()
					points.append([vertices[n].x,vertices[n].y,vertices[n].z])
				geometry.append({"points":points,"indices":Array(arrays[Mesh.ARRAY_INDEX])})
				arrays[Mesh.ARRAY_VERTEX]=vertices
				arrays[Mesh.ARRAY_NORMAL]=normals
				for slot in [Mesh.ARRAY_TANGENT,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS,Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]: arrays[slot]=null
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				var mat:StandardMaterial3D=piece.get_active_material(s).duplicate()
				mat.metallic=0.2
				mat.normal_enabled=false
				mat.albedo_color=Color(1.25,1.25,1.25)
				mesh.surface_set_material(s,mat)
			var instance:=MeshInstance3D.new()
			instance.mesh=mesh
			source.add_child(instance)
		raw.free()
		var output:=FileAccess.open("res://art/asset_review/equipment/"+id+"_source.json",FileAccess.WRITE)
		output.store_string(JSON.stringify(geometry))
		for i in range(1,4):
			var actor:=VISUAL.new()
			actor.asset_id=id
			world.add_child(actor)
			actor.position.x=3.45-i*2.3
			for n in 30: actor.tick(1.0/60,0,true)
			if i>1:
				actor.action(LOADOUT.melee_cue(id,0),1.0)
				for n in (18 if i==2 else 27): actor.tick(1.0/60,0,true)
			holders.append(actor)
		for i in 4:
			var label:=Label3D.new()
			holders[i].add_child(label)
			label.position.y=2.8
			label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			label.text=id+"\n"+["SOURCE","IDLE","WINDUP","CONTACT"][i]
			label.font_size=26
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/asset_review/equipment/"+id+".png")
		for holder in holders: holder.free()
	print("SCULPT_EQUIPMENT_REVIEW_READY")
	quit()
