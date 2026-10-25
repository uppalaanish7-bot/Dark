extends SceneTree
## Regressions for source normalization, parent-space root motion and blade grip.
const PLAYER = preload("res://scripts/character_visual.gd")
const ENEMY = preload("res://scripts/provided_visual.gd")
var failures: Array[String] = []
var records: Array = []
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
func rest_bounds(actor: Node3D) -> AABB:
	var sk: Skeleton3D = actor.skeleton
	var low := Vector3(INF,INF,INF)
	var high := Vector3(-INF,-INF,-INF)
	for mesh in sk.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin == null: continue
		for surface in mesh.mesh.get_surface_count():
			var a: Array = mesh.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			for n in points.size():
				var point := Vector3.ZERO
				for k in 4:
					var bind: int = bones[n*4+k]
					var bone: int = mesh.skin.get_bind_bone(bind)
					if bone < 0: bone = sk.find_bone(mesh.skin.get_bind_name(bind))
					point += (sk.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind)*points[n])*weights[n*4+k]
				point = sk.to_global(point)
				low = low.min(point)
				high = high.max(point)
	return AABB(low,high-low)
func run() -> void:
	for identity in ["female","omega","subboss_1"]:
		var actor: Node3D = PLAYER.new() if identity != "subboss_1" else ENEMY.new()
		actor.asset_id = identity
		root.add_child(actor)
		var sk: Skeleton3D = actor.skeleton
		actor.animator.stop()
		sk.reset_bone_poses()
		var bounds := rest_bounds(actor)
		check(absf(bounds.position.y) < 0.015, identity+": rest mesh is not at floor height")
		check(absf(bounds.size.y-(2.1 if identity=="subboss_1" else 1.82))<0.025,identity+": rest body height changed")
		var pelvis := -1
		for bone in sk.get_bone_count():
			var key := sk.get_bone_name(bone).to_lower()
			if "pelvis" in key or "hips" in key: pelvis = bone
		var rest_hip := sk.to_global(sk.get_bone_global_rest(pelvis).origin)
		actor.animator.play("Sword_Idle_Loop",0)
		actor.animator.seek(actor.animator.get_animation("Sword_Idle_Loop").length*0.35,true)
		var hip_delta := sk.to_global(sk.get_bone_global_pose(pelvis).origin)-rest_hip
		if identity == "subboss_1":
			check(hip_delta.y < -0.07,identity+": guardian guard compression must move pelvis vertically")
		else:
			check(absf(hip_delta.y) < 0.065,identity+": neutral player stance must stay upright over the feet")
		check(absf(hip_delta.z)<0.065,identity+": pelvis vertical motion leaked into forward axis")
		var paths: Dictionary = {}
		var grip_error := 0.0
		var source_grip: Node3D = actor.model.find_child("AuthoredSword",true,false)
		if identity == "subboss_1": check(source_grip != null,identity+": source sword is not attached to its hand")
		for clip in ["Sword_Attack","Sword_Attack02","Sword_Attack03","Sprint_Loop","Roll","Jump_Land"]:
			actor.animator.stop()
			actor.animator.play(clip,0)
			var positions: Array[Vector3] = []
			for n in 31:
				sk.reset_bone_poses()
				actor.animator.seek(actor.animator.get_animation(clip).length*n/30.0,true)
				actor.update_weapon()
				for bone in sk.get_bone_count():
					check(sk.get_bone_global_pose(bone).is_finite(),identity+": nonfinite pose in "+clip)
				if identity != "subboss_1":
					var palm: Vector3 = sk.to_global(sk.get_bone_global_pose(actor.hand)*actor._palm_offset)
					var hilt: Vector3 = actor.weapon.to_global(Vector3(0,-0.085,0))
					grip_error = maxf(grip_error,palm.distance_to(hilt))
					positions.append(actor.weapon.to_global(Vector3(0,1.1,0)))
				elif source_grip != null:
					await process_frame
					var hand := sk.find_bone("QuickRigCharacter_RightHand_019")
					var wrist := sk.to_global(sk.get_bone_global_pose(hand).origin)
					grip_error=maxf(grip_error,absf(source_grip.global_position.distance_to(wrist)-0.07))
			paths[clip] = positions
		check(grip_error<0.001,identity+": hilt slips from palm during animation")
		var separation: Array[float] = []
		if identity != "subboss_1":
			for pair in [["Sword_Attack","Sword_Attack02"],["Sword_Attack02","Sword_Attack03"],["Sword_Attack","Sword_Attack03"]]:
				var difference := 0.0
				for n in 31: difference=maxf(difference,paths[pair[0]][n].distance_to(paths[pair[1]][n]))
				separation.append(difference)
				check(difference>0.55,identity+": combo blade paths are not distinct")
			var overhead: Array = paths["Sword_Attack03"]
			var wind_y: float = overhead[6].y
			var contact_y: float = overhead[13].y
			check(wind_y-contact_y>0.6,identity+": overhead strike lacks downward release")
		actor.action("Sword_Attack03",0.48)
		for n in 40: actor.tick(1.0/60,0,true)
		var recovered_clip := "Idle_Loop" if identity == "subboss_1" else "Sword_Idle_Loop"
		check(actor.one_shot_time<=0 and actor.current_clip==recovered_clip,identity+": action fails to recover to its idle")
		records.append({"id":identity,"rest_height_m":bounds.size.y,"rest_floor_m":bounds.position.y,"guard_pelvis_delta":str(hip_delta),"max_grip_drift_m":grip_error,"combo_tip_separation_m":separation})
		actor.free()
	var output := FileAccess.open("res://art/asset_review/player_combat_validation.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"actors":records,"failures":failures},"\t"))
	for failure in failures: push_error(failure)
	print("PLAYER_COMBAT_VALIDATION actors=",records.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
