extends SceneTree
const VISUAL = preload("res://scripts/provided_visual.gd")
const ENCOUNTERS = preload("res://scripts/encounter_data.gd")
var failures: Array[String] = []
var report: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var identities: Array[String]=["female","omega"]
	for n in range(1,10): identities.append("subboss_"+str(n))
	for n in range(1,10): identities.append("soldier_"+str(n))
	identities.append_array(["grand_boss","grand_soldier","main_boss"])
	for identity in identities:
		var visual:=VISUAL.new()
		visual.asset_id=identity
		root.add_child(visual)
		if not visual.source_available: failures.append(identity+": missing source")
		if visual.skeleton==null: failures.append(identity+": missing articulated skeleton")
		var initial_pose: Array[Quaternion] = []
		if visual.skeleton!=null:
			for bone in visual.skeleton.get_bone_count(): initial_pose.append(visual.skeleton.get_bone_pose_rotation(bone))
		if visual._sculpt_motion:
			visual.skeleton.reset_bone_poses()
			for mesh_instance in visual.skeleton.get_children():
				if not mesh_instance is MeshInstance3D: continue
				for surface in mesh_instance.mesh.get_surface_count():
					var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
					var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
					for vertex in range(0,vertices.size(),maxi(1,vertices.size()/32)):
						var posed := Vector3.ZERO
						for slot in 4:
							var index: int = bones[vertex*4+slot]
							posed += (visual.skeleton.get_bone_global_pose(index)*mesh_instance.skin.get_bind_pose(index)*vertices[vertex])*weights[vertex*4+slot]
						if posed.distance_to(vertices[vertex])>0.002: failures.append(identity+": invalid skin rest binding")
		for cue in ENCOUNTERS.ANIMATION_CUES:
			if not visual.animator.has_animation(cue): failures.append(identity+": missing "+cue)
		var cue:String="Sword_Attack03"
		if identity.begins_with("subboss_"): cue=ENCOUNTERS.ANIMATION_CUES[int(identity.trim_prefix("subboss_"))-1]
		if identity.begins_with("soldier_"): cue=ENCOUNTERS.ANIMATION_CUES[int(identity.trim_prefix("soldier_"))-1]
		if identity in ["grand_boss","grand_soldier"]: cue="Lava_Crash"
		if identity=="main_boss": cue="Void_Reap"
		visual.action(cue,2.0)
		if visual.current_clip!=cue: failures.append(identity+": action fell back from "+cue)
		var bone_motion: float = 0.0
		for frame in 66:
			visual.tick(1.0/30,0,true)
			if not visual.motion.transform.is_finite(): failures.append(identity+": nonfinite actor transform")
			if visual.skeleton!=null:
				for bone in visual.skeleton.get_bone_count():
					if not visual.skeleton.get_bone_global_pose(bone).is_finite(): failures.append(identity+": nonfinite bone")
					bone_motion=maxf(bone_motion,initial_pose[bone].angle_to(visual.skeleton.get_bone_pose_rotation(bone)))
		if bone_motion<0.015: failures.append(identity+": attack has no visible articulated motion")
		report.append({"id":identity,"cue":cue,"authored_skeletal_motion":visual._authored_motion,"bones":visual.skeleton.get_bone_count() if visual.skeleton else 0,"recovered":visual.one_shot_time<=0})
		visual.queue_free()
		await process_frame
	var out:=FileAccess.open("res://art/asset_review/motion_validation.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"actors":report,"failures":failures},"\t"))
	for failure in failures: push_error(failure)
	print("PROVIDED_MOTION_VALIDATION actors=",report.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
