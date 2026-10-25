extends SceneTree
## Regressions for stable stance selection, interrupted braking, and the
## Girl Knight cape that previously stretched with the legs during locomotion.
const CHARACTER = preload("res://scripts/character_visual.gd")
class Controller extends Node3D:
	var _combat_stance_timer: float = 0.0
var failures: Array[String] = []
var records: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func advance(actor: Node3D, count: int, speed: float = 0.0) -> void:
	actor.set_motion_state(Vector3(0,0,-speed),true,0,0,false,false)
	for frame in count: actor.tick(1.0/60.0,speed,true)
func run() -> void:
	for identity in ["female","omega"]:
		var controller := Controller.new()
		root.add_child(controller)
		var actor := CHARACTER.new()
		actor.asset_id=identity
		controller.add_child(actor)
		advance(actor,90)
		check(actor.current_clip=="Idle_Loop",identity+": expired combat stance must select relaxed idle")
		var relaxed_phase: float = actor.animator.current_animation_position
		advance(actor,30)
		check(actor.current_clip=="Idle_Loop" and actor.animator.current_animation_position > relaxed_phase+0.45,identity+": relaxed idle restarts its blend every frame")
		var relaxed_tip: Vector3=actor.weapon_position()
		controller._combat_stance_timer=6.0
		advance(actor,45)
		check(actor.current_clip=="Sword_Idle_Loop",identity+": combat stance must select guard")
		check(actor.weapon_position().y>relaxed_tip.y+0.25,identity+": exploration and combat idle must have distinct sword silhouettes")
		advance(actor,60,13.5)
		advance(actor,1)
		check(actor.current_clip=="Sprint_Stop",identity+": releasing sprint has no weight recovery")
		advance(actor,1,9.5)
		check(actor.current_clip=="Jog_Fwd_Loop" and actor.one_shot_time<=0,identity+": braking blocks renewed movement")
		advance(actor,30)
		check(actor.current_clip=="Sword_Idle_Loop",identity+": braking fails to recover")
		if identity=="female": validate_cape(actor)
		records.append({"id":identity,"bones":actor.skeleton.get_bone_count(),"clips":actor.animator.get_animation_list().size(),"idle_phase_advanced":true})
		controller.free()
	for failure in failures: push_error(failure)
	var report := FileAccess.open("res://art/asset_review/female_character_validation.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"actors":records,"failures":failures},"\t"))
	print("FEMALE_CHARACTER_VALIDATION actors=",records.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
func validate_cape(actor: Node3D) -> void:
	var sk: Skeleton3D=actor.skeleton
	check(sk.find_bone("cape_mid")>=0 and sk.find_bone("cape_tip")>=0,"female: cape needs independent middle and hem articulation")
	var source: Node3D=load("res://assets/provided/female.glb").instantiate()
	root.add_child(source)
	var source_mesh: MeshInstance3D=source.find_children("*","MeshInstance3D",true,false)[0]
	var mesh: MeshInstance3D=sk.find_children("*","MeshInstance3D",true,false)[0]
	var arrays: Array=mesh.mesh.surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var original: PackedVector3Array=source_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(points==original,"female: binding repair must preserve supplied mesh vertices")
	var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var cape_vertices := 0
	var rest_error := 0.0
	for vertex in points.size():
		var rest_point := Vector3.ZERO
		var total := 0.0
		var cape_weight := 0.0
		for slot in 4:
			var bind := bones[vertex*4+slot]
			var weight := weights[vertex*4+slot]
			var name: String=mesh.skin.get_bind_name(bind)
			var bone := sk.find_bone(name)
			check(bone>=0,"female: invalid named bind "+name)
			if bone<0: continue
			total+=weight
			rest_point+=(sk.get_bone_global_rest(bone)*mesh.skin.get_bind_pose(bind)*points[vertex])*weight
			if name.begins_with("cape"): cape_weight+=weight
		check(absf(total-1.0)<0.001,"female: unnormalized skin weight")
		rest_error=maxf(rest_error,rest_point.distance_to(points[vertex]))
		# Source topology separates the 78-vertex cape at |x| <= .1516 m
		# from the two calf armor vertices at |x| = .158 m. Keep those
		# armor points on the legs instead of misclassifying them as cloth.
		if points[vertex].y<0.92 and points[vertex].z< -0.04 and absf(points[vertex].x)<0.155:
			cape_vertices+=1
			check(cape_weight>0.999,"female: hanging cape still follows a leg bone at vertex "+str(vertex)+" "+str(points[vertex])+" cape weight="+str(cape_weight))
		if points[vertex].y<0.92 and points[vertex].z< -0.04 and absf(points[vertex].x)>=0.155:
			check(cape_weight<0.001,"female: calf armor must follow the leg instead of the cape")
	check(cape_vertices>=70,"female: missing hanging cape region")
	check(rest_error<0.0001,"female: new skin binds changed the rest mesh")
	advance(actor,60,13.5)
	for name in ["cape","cape_mid","cape_tip"]:
		var index := sk.find_bone(name)
		check(sk.get_bone_pose_rotation(index).angle_to(sk.get_bone_rest(index).basis.get_rotation_quaternion())>0.02,"female: inactive cloth segment "+name)
	print("FEMALE_CAPE vertices=",cape_vertices," max_rest_error_m=",rest_error)
	source.free()
