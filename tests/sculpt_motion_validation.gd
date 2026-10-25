extends SceneTree
## Exercise the real fitted meshes at both minion and final-boss scale. Inspect
## ankle contact and segment lengths after runtime blending, not just key data.
const VISUAL = preload("res://scripts/provided_visual.gd")
const DATA = preload("res://scripts/encounter_data.gd")
var checks: int = 0
var failures: Array[String] = []
var worst_contact: float = 0.0
var worst_segment: float = 0.0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and message not in failures: failures.append(message)

func inspect(v: Node3D, planted: bool, label: String) -> void:
	var rig: Skeleton3D = v.skeleton
	var state: Dictionary = rig.get_meta("sculpt_live_motion")
	var scale_factor: float = v.target_height / 2.1
	for side in ["l", "r"]:
		var thigh: int = state.bones["sculpt_thigh_" + side]
		var shin: int = state.bones["sculpt_shin_" + side]
		var foot: int = state.bones["sculpt_foot_" + side]
		var hip: Transform3D = rig.get_bone_global_pose(thigh)
		var knee: Transform3D = rig.get_bone_global_pose(shin)
		var ankle: Transform3D = rig.get_bone_global_pose(foot)
		check(hip.is_finite() and knee.is_finite() and ankle.is_finite(), label + ": finite limb transforms")
		var error_a: float = absf(hip.origin.distance_to(knee.origin) - rig.get_bone_rest(shin).origin.length())
		var error_b: float = absf(knee.origin.distance_to(ankle.origin) - rig.get_bone_rest(foot).origin.length())
		worst_segment = maxf(worst_segment, maxf(error_a, error_b))
		check(error_a < 0.0001 and error_b < 0.0001, label + ": limb lengths remain rigid")
		if rig.get_meta("spectral", false): continue
		var running: float = smoothstep(2.0, 5.3, state.speed)
		var duty: float = lerpf(0.64, 0.43, running)
		var gait: float = fposmod((state.phase + (0.0 if side == "l" else PI)) / TAU, 1.0)
		if planted or gait < duty:
			var rest_y: float = rig.get_bone_global_rest(foot).origin.y * scale_factor
			var contact_error: float = absf(rig.to_global(ankle.origin).y - rest_y)
			worst_contact = maxf(worst_contact, contact_error)
			check(contact_error < 0.008 * scale_factor, label + ": stance ankle stays on its ground plane")
	for bone in rig.get_bone_count():
		check(rig.get_bone_pose_scale(bone).distance_to(Vector3.ONE) < 0.0001, label + ": animation never stretches a bone")

func run() -> void:
	var ids: Array[String] = []
	for n in range(1, 10): ids.append_array(["subboss_" + str(n), "soldier_" + str(n)])
	ids.append_array(["grand_boss", "grand_soldier", "main_boss"])
	var actors: int = 0
	for id in ids:
		var v := VISUAL.new()
		v.asset_id = id
		root.add_child(v)
		if not v._sculpt_motion:
			v.free()
			continue
		actors += 1
		for speed in [0.0, 2.4, 6.2]:
			for frame in range(100):
				v.set_motion_state(Vector3(0, 0, -speed), true, 0, 0, false, false)
				v.tick(1.0 / 60.0, speed, true)
				if frame >= 40: inspect(v, speed == 0, id + " gait " + str(speed))
		# Stop fully before inspecting planted anticipation and impact.
		for frame in 65: v.tick(1.0 / 60.0, 0, true)
		var cue: String = "Void_Reap" if id == "main_boss" else ("Lava_Crash" if id in ["grand_boss", "grand_soldier"] else DATA.ANIMATION_CUES[int(id.get_slice("_", 1)) - 1])
		for action in [cue, "Sword_Attack", "Sword_Attack02", "Sword_Attack03", "Punch_Jab", "Hit_Chest"]:
			v.action(action, 1.0)
			for frame in 66:
				v.tick(1.0 / 60.0, 0, true)
				inspect(v, true, id + " " + action)
			check(v.one_shot_time == 0, id + " recovers from " + action)
		v.action("Death01", 1.5)
		for frame in 100:
			v.tick(1.0 / 60.0, 0, true)
			check(v.motion.transform.is_finite(), id + " death stays finite")
		v.free()
	for id in ["subboss_3", "grand_boss"]:
		var v := VISUAL.new()
		v.asset_id = id
		v.target_height = 4.6
		root.add_child(v)
		for frame in 140:
			v.set_motion_state(Vector3(1.5, 0, -6.0), true, 0, 1.2, false, false)
			v.tick(1.0 / 60.0, 6.18, true)
			if frame > 40: inspect(v, false, id + " scaled directional gait")
		v.free()
	print("SCULPT_MOTION_CHECKS ", checks, " ACTORS ", actors, " FAILURES ", failures.size(), " WORST_CONTACT_METRES ", worst_contact, " WORST_SEGMENT_ERROR ", worst_segment)
	for failure in failures: print("FAILED: ", failure)
	quit(0 if failures.is_empty() else 1)
