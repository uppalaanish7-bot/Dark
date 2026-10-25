extends SceneTree
const VISUAL = preload("res://scripts/character_visual.gd")
const ENEMY_VISUAL = preload("res://scripts/provided_visual.gd")
const FX = preload("res://scripts/effects.gd")
var actor: Node3D
var fx: Node3D
var title: Label
var mode := "female"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): mode=args[0]
	var rear := args.size()>1 and args[1]=="rear"
	root.size=Vector2i(960,640)
	var folder := "res://art/asset_review/motion_frames/"+mode+("_rear" if rear else "")
	DirAccess.make_dir_recursive_absolute(folder)
	var world:=Node3D.new()
	root.add_child(world)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("091321")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("c5d2ed")
	env.environment.ambient_light_energy=0.8
	world.add_child(env)
	for item in [[Vector3(3,5,-4),Color("ffcf98"),2.0],[Vector3(-3,3,-1),Color("91c9ff"),1.8]]:
		var light:=OmniLight3D.new()
		world.add_child(light)
		light.position=item[0];light.light_color=item[1];light.light_energy=item[2];light.omni_range=16
		light.shadow_enabled=true
	var floor_mesh:=MeshInstance3D.new()
	floor_mesh.mesh=PlaneMesh.new()
	floor_mesh.mesh.size=Vector2(200,200)
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("1b293a");material.roughness=0.75
	floor_mesh.material_override=material
	world.add_child(floor_mesh)
	var ring:=MeshInstance3D.new()
	ring.mesh=TorusMesh.new();ring.mesh.inner_radius=1.65;ring.mesh.outer_radius=1.68
	ring.scale.y=0.08;ring.position.y=0.012
	var ring_material:=StandardMaterial3D.new();ring_material.albedo_color=Color("4b647e")
	ring.material_override=ring_material;world.add_child(ring)
	var cam:=Camera3D.new()
	world.add_child(cam)
	cam.position=Vector3(-3.6,2.3,5.0) if rear else Vector3(3.6,2.3,-5.0)
	cam.look_at(Vector3(0,1.35,0))
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=4.7;cam.current=true
	actor=VISUAL.new() if mode in ["female","omega"] else ENEMY_VISUAL.new()
	actor.asset_id=mode
	actor.target_height=1.82 if mode in ["female","omega"] else 2.1
	world.add_child(actor)
	fx=FX.new();world.add_child(fx)
	var canvas:=CanvasLayer.new();root.add_child(canvas)
	title=Label.new();canvas.add_child(title)
	title.position=Vector2(28,24);title.add_theme_font_size_override("font_size",24)
	var sub:=Label.new();canvas.add_child(sub);sub.position=Vector2(28,59)
	sub.text="Provided character • authored animation review";sub.modulate=Color("9ab4d4")
	for n in 6:
		actor.tick(1.0/24,0,true)
		await process_frame
	var last_segment := -1
	for frame in 360 if mode in ["female","omega"] else 144:
		var time:float=frame/24.0
		var speed:=0.0
		var grounded:=true
		var vertical:=0.0
		var segment:=int(time)
		if mode in ["female","omega"]:
			var captions := ["Balanced sword guard", "Walk → jog", "Agile sprint", "Dodge roll", "Jump and landing", "Sword combo • opening cut", "Sword combo • reverse cut", "Sword combo • overhead finisher", "Recovery to guard", "R • raise, gather and pull", "R • weighted recovery", "Q • enchant without changing pose", "Right-click • point sword and release", "Recovery to guard", "Agile sprint"]
			title.text=captions[segment]
			if segment==1: speed=lerpf(2,8,fposmod(time,1))
			if segment==2: speed=12
			if segment==14: speed=12
			if segment==4:
				var phase:=fposmod(time,1)
				grounded=phase>0.85
				actor.position.y=sin(minf(phase/0.85,1)*PI)*0.65
				vertical=cos(minf(phase/0.85,1)*PI)*4.0
			else: actor.position.y=0
			if segment!=last_segment:
				if segment==3: actor.action("Roll",0.65)
				if segment==4: actor.action("Jump_Start",0.25)
				if segment in [5,6,7]: actor.action({5:"Sword_Attack",6:"Sword_Attack02",7:"Sword_Attack03"}[segment],{5:0.32,6:0.37,7:0.53}[segment])
				if segment==9: actor.action("Cast",1.2)
				if segment==11: fx.ignite_blade(actor.weapon,2.6)
				if segment==12: actor.action("Fire_Cast",0.42)
			if frame==int(4.86*24): actor.action("Jump_Land",0.14)
		else:
			var cue:String={"subboss_1":"Stone_Slam","subboss_7":"Poison_Cast","soldier_1":"Sword_Attack","grand_boss":"Lava_Crash","grand_boss_wing_review":"Lava_Crash","main_boss":"Void_Reap"}.get(mode,"Ice_Cleave")
			title.text=mode+" • "+cue
			if segment==1 and segment!=last_segment: actor.action(cue,2.0)
			if segment>=4: speed=3.0
		actor.set_motion_state(Vector3(0,0,-speed),grounded,vertical,0,segment==3,false)
		actor.tick(1.0/24,speed,grounded)
		last_segment=segment
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/%04d.png"%frame)
	print("MOTION_PREVIEW_READY ",mode," ",folder)
	quit()
