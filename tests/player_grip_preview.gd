extends SceneTree
const CHARACTER = preload("res://scripts/character_visual.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1100, 720)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("172539")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("cad9f4")
	env.environment.ambient_light_energy = 0.9
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	sun.rotation_degrees = Vector3(-35,-25,0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	var floor := MeshInstance3D.new()
	floor.mesh = PlaneMesh.new()
	floor.mesh.size = Vector2(200,200)
	world.add_child(floor)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("273c54")
	floor.material_override = mat
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(3,2.5,-6.5)
	camera.look_at(Vector3(0,0.95,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.8
	camera.current = true
	var actors: Array[Node3D] = []
	for n in 2:
		var actor := CHARACTER.new()
		actor.asset_id = "female" if n==0 else "omega"
		world.add_child(actor)
		actor.position.x = -1.1 if n==0 else 1.1
		actors.append(actor)
	var label := Label.new()
	root.add_child(label)
	label.position = Vector2(30,25)
	label.add_theme_font_size_override("font_size",24)
	DirAccess.make_dir_recursive_absolute("res://art/asset_review/player_grip")
	for clip in ["Sword_Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Sword_Attack", "Sword_Attack02", "Sword_Attack03"]:
		for phase in [0.18,0.36,0.62]:
			label.text = "%s • %.0f%%" % [clip, phase*100]
			for actor in actors:
				actor.skeleton.reset_bone_poses()
				actor.motion.position = Vector3.ZERO
				actor.model.position = actor._model_origin
				actor.model.rotation = actor._model_rotation
				actor.animator.play(clip, 0)
				actor.animator.seek(actor.animator.get_animation(clip).length*phase,true)
				actor.update_weapon()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://art/asset_review/player_grip/%s_%02d.png"%[clip,int(phase*100)])
	print("PLAYER_GRIP_PREVIEW_READY")
	quit()
