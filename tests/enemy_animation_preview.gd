extends SceneTree
const VISUAL = preload("res://scripts/provided_visual.gd")
const DATA = preload("res://scripts/encounter_data.gd")
var actors: Array[Node3D] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1600,1000)
	var world:=Node3D.new()
	root.add_child(world)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("102034")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("cfdef2")
	env.environment.ambient_light_energy=0.8
	world.add_child(env)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-30,30,0)
	light.light_energy=1.3
	world.add_child(light)
	var camera:=Camera3D.new()
	camera.position=Vector3(0,5.4,-24)
	world.add_child(camera)
	camera.look_at(Vector3(0,4.4,0))
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=12.2
	camera.current=true
	var ids: Array[String]=[]
	for n in 9: ids.append("subboss_"+str(n+1))
	ids.append_array(["grand_boss","main_boss","grand_soldier"])
	for n in 9: ids.append("soldier_"+str(n+1))
	for i in ids.size():
		var actor:=VISUAL.new()
		actor.asset_id=ids[i]
		actor.target_height=2.1
		world.add_child(actor)
		actor.position=Vector3((i%7-3)*2.4,(2-i/7)*3.25,0)
		actors.append(actor)
		var label:=Label3D.new()
		label.text=ids[i]
		label.font_size=30
		label.pixel_size=0.007
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
		label.position=actor.position+Vector3(0,-0.25,0)
	for actor in actors: actor.tick(0.05,0,true)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/enemies_rest.png")
	for frame in 36:
		for actor in actors:
			actor.set_motion_state(Vector3(0,0,-3.8),true,0,0,false,false)
			actor.tick(1.0/30,3.8,true)
		await process_frame
		if frame in [6,16,27]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/enemies_run_%02d.png"%frame)
	for i in actors.size():
		var cue: String = DATA.ANIMATION_CUES[i] if i<11 else ("Lava_Crash" if i==11 else DATA.ANIMATION_CUES[i-12])
		actors[i].action(cue,2.0)
	for frame in 45:
		for actor in actors: actor.tick(1.0/30,0,true)
		await process_frame
		if frame in [16,27,43]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/enemies_pose_%02d.png"%frame)
	print("ENEMY_ANIMATION_PREVIEW_READY")
	world.free()
	quit()
