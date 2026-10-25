extends SceneTree
## Retarget authored Quaternius CC0 motions onto the provided rigs. Rotations
## are rebuilt in global rest space, with A/T-pose direction calibration and
## target parent transforms; gameplay remains in control of world translation.
const SOURCES := {
	"Idle_Loop":"Sword_Idle", "Sword_Idle_Loop":"Sword_Idle", "Walk_Loop":"Walk",
	"Jog_Fwd_Loop":"Jog_Fwd", "Sprint_Loop":"Sprint", "Jump_Start":"Jump_Start",
	"Jump_Loop":"Jump", "Jump_Fall":"Jump", "Double_Jump":"Jump_Start",
	"Jump_Land":"Jump_Land", "Roll":"Roll", "Death01":"Death01",
	"Hit_Chest":"Hit_Chest", "Sword_Attack":"Sword_Attack",
	"Sword_Attack02":"Sword_Attack", "Sword_Attack03":"Sword_Attack",
	"Fire_Cast":"Spell_Simple_Shoot", "Cast":"Spell_Simple_Enter",
	"Channel_Loop":"Spell_Simple_Idle", "Cast_Release":"Spell_Simple_Exit",
	"Run_Stop":"Sword_Idle", "Sprint_Stop":"Sword_Idle",
	"Crouch_Idle_Loop":"Crouch_Idle", "Crouch_Fwd_Loop":"Crouch_Fwd",
	"Dance_Loop":"Dance", "Punch_Jab":"Punch_Jab",
	"Stone_Slam":"Sword_Attack", "Water_Sweep":"Sword_Attack",
	"Fire_Combo":"Sword_Attack", "Soul_Channel":"Spell_Simple_Idle",
	"Lightning_Lunge":"Punch_Cross", "Wind_Cyclone":"Sword_Attack",
	"Poison_Cast":"Spell_Simple_Shoot", "Ice_Cleave":"Sword_Attack",
	"Gravity_Pulse":"Spell_Simple_Enter", "Lava_Crash":"Sword_Attack",
	"Void_Reap":"Sword_Attack"
}
const PLAYER_MOTION = preload("res://tools/player_motion_authoring.gd")
var src: Skeleton3D
var playback: AnimationPlayer
var targets: Array[String] = ["female", "omega", "subboss_1", "subboss_7", "soldier_1"]
var report: Array = []

func _initialize() -> void:
	call_deferred("build")

func map_name(name: String) -> String:
	var key := name.to_lower()
	if "scalecompensation" in key: return ""
	if key == "_rootjoint": return "root"
	if key.begins_with("quickrigcharacter_"):
		key = key.trim_prefix("quickrigcharacter_")
		var side := ".L" if key.begins_with("left") else ".R"
		key = key.trim_prefix("left").trim_prefix("right")
		for match_key in {"hips_":"DEF-hips","spine_":"DEF-spine.001","spine1_":"DEF-spine.002","spine2_":"DEF-spine.003","neck_":"DEF-neck","head_":"DEF-head"}:
			if key.begins_with(match_key): return {"hips_":"DEF-hips","spine_":"DEF-spine.001","spine1_":"DEF-spine.002","spine2_":"DEF-spine.003","neck_":"DEF-neck","head_":"DEF-head"}[match_key]
		for match_key in {"upleg_":"DEF-thigh","leg_":"DEF-shin","foot_":"DEF-foot","toebase_":"DEF-toe","shoulder_":"DEF-shoulder","arm_":"DEF-upper_arm","forearm_":"DEF-forearm","hand_":"DEF-hand"}:
			if key.begins_with(match_key): return {"upleg_":"DEF-thigh","leg_":"DEF-shin","foot_":"DEF-foot","toebase_":"DEF-toe","shoulder_":"DEF-shoulder","arm_":"DEF-upper_arm","forearm_":"DEF-forearm","hand_":"DEF-hand"}[match_key]+side
		return ""
	if key.begins_with("npc_soldier_knight_"):
		key = key.trim_prefix("npc_soldier_knight_")
		var side := ".L" if "_lf_" in key else ".R"
		for part in {"hips_part01":"DEF-hips","spine_part02":"DEF-spine.001","spine_part03":"DEF-spine.002","spine_part05":"DEF-spine.003","neck_part01":"DEF-neck","head_part01":"DEF-head"}:
			if key.begins_with(part): return {"hips_part01":"DEF-hips","spine_part02":"DEF-spine.001","spine_part03":"DEF-spine.002","spine_part05":"DEF-spine.003","neck_part01":"DEF-neck","head_part01":"DEF-head"}[part]
		for part in {"leg_upper":"DEF-thigh","leg_lower":"DEF-shin","leg_foot":"DEF-foot","leg_ball":"DEF-toe","arm_clavicle":"DEF-shoulder","arm_upper":"DEF-upper_arm","arm_lower":"DEF-forearm","arm_hand":"DEF-hand"}:
			if key.begins_with(part): return {"leg_upper":"DEF-thigh","leg_lower":"DEF-shin","leg_foot":"DEF-foot","leg_ball":"DEF-toe","arm_clavicle":"DEF-shoulder","arm_upper":"DEF-upper_arm","arm_lower":"DEF-forearm","arm_hand":"DEF-hand"}[part]+side
		return ""
	if key.begins_with("hips_"): return "DEF-hips"
	if key == "spine_034": return "DEF-spine.001"
	if key.begins_with("chest_"): return "DEF-spine.003"
	if key.begins_with("l_") or key.begins_with("r_"):
		var side := ".L" if key.begins_with("l_") else ".R"
		key=key.substr(2)
		for part in {"leg_":"DEF-thigh","knee_":"DEF-shin","ankle_":"DEF-foot","foot_":"DEF-toe","shoulder_":"DEF-shoulder","arm_":"DEF-upper_arm","elbow_":"DEF-forearm","wrist_":"DEF-hand"}:
			if key.begins_with(part): return {"leg_":"DEF-thigh","knee_":"DEF-shin","ankle_":"DEF-foot","foot_":"DEF-toe","shoulder_":"DEF-shoulder","arm_":"DEF-upper_arm","elbow_":"DEF-forearm","wrist_":"DEF-hand"}[part]+side
		return ""
	var side := ".L" if "_l" in key or ".l" in key else ".R"
	if "twist" in key or "deform" in key or "pad" in key or "metacarpal" in key or "collision" in key: return ""
	if key == "root" or key.begins_with("root_"): return "root"
	if key.begins_with("pelvis"): return "DEF-hips"
	if key.begins_with("spine_01"): return "DEF-spine.001"
	if key.begins_with("spine_02"): return "DEF-spine.001"
	if key.begins_with("spine_03"): return "DEF-spine.002"
	if key.begins_with("spine_04") or key.begins_with("spine_05"): return "DEF-spine.003"
	if key.begins_with("neck"): return "DEF-neck"
	if key.begins_with("head"): return "DEF-head"
	if key.begins_with("clavicle"): return "DEF-shoulder" + side
	if key.begins_with("upperarm"): return "DEF-upper_arm" + side
	if key.begins_with("lowerarm"): return "DEF-forearm" + side
	if key.begins_with("hand"): return "DEF-hand" + side
	if key.begins_with("thigh"): return "DEF-thigh" + side
	if key.begins_with("calf"): return "DEF-shin" + side
	if key.begins_with("foot"): return "DEF-foot" + side
	if key.begins_with("ball"): return "DEF-toe" + side
	for finger in ["index", "middle", "ring", "pinky", "thumb"]:
		if key.begins_with(finger + "_"):
			for number in ["01", "02", "03"]:
				if "_" + number + "_" in key:
					return ("DEF-thumb." if finger == "thumb" else "DEF-f_" + finger + ".") + number + side
	return ""

func child_direction(sk: Skeleton3D, index: int, mapped: Dictionary) -> Vector3:
	var point := sk.get_bone_global_rest(index).origin
	# Hand orientation follows the middle knuckle. Choosing the first mapped
	# child can select a thumb on one rig and an index finger on another,
	# twisting the wrist and everything mounted in its grip.
	if "hand" in sk.get_bone_name(index).to_lower():
		var side := ".r" if ".r" in sk.get_bone_name(index).to_lower() or "_r" in sk.get_bone_name(index).to_lower() else ".l"
		for candidate in sk.get_bone_count():
			var key := sk.get_bone_name(candidate).to_lower()
			if "middle" in key and (".01" in key or "_01" in key) and (side in key or side.replace(".","_") in key):
				return (sk.global_basis * (sk.get_bone_global_rest(candidate).origin-point)).normalized()
		# The Stelae exporter uses bone X for its hand, with no finger joints.
		# Continue the forearm through the palm instead of interpreting Y as
		# a finger direction and turning the attached sword into the torso.
		if sk.get_bone_name(index).begins_with("QuickRigCharacter_"):
			var parent := sk.get_bone_parent(index)
			if parent >= 0:
				return (sk.global_basis * (point-sk.get_bone_global_rest(parent).origin)).normalized()
		return (sk.global_basis * sk.get_bone_global_rest(index).basis.y).normalized()
	for child in sk.get_bone_children(index):
		if mapped.has(child):
			var difference := sk.get_bone_global_rest(child).origin - point
			if difference.length() > 0.005: return (sk.global_basis * difference).normalized()
	return (sk.global_basis * sk.get_bone_global_rest(index).basis.y).normalized()

func build() -> void:
	if not OS.get_cmdline_user_args().is_empty(): targets.assign(OS.get_cmdline_user_args())
	DirAccess.make_dir_recursive_absolute("res://assets/motion")
	var source: Node3D = load("res://Godot/AnimationLibrary_Godot_Standard.glb").instantiate()
	root.add_child(source)
	src = source.find_children("*", "Skeleton3D", true, false)[0]
	playback = source.find_children("*", "AnimationPlayer", true, false)[0]
	playback.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for identity in targets: bake(identity)
	var file := FileAccess.open("res://art/asset_review/motion_retarget_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"source":"Quaternius Universal Animation Library · CC0", "assets":report}, "\t"))
	source.free()
	quit()

func aim_source(name: String, child_name: String, direction: Vector3, amount: float) -> void:
	var bone := src.find_bone(name)
	var child := src.find_bone(child_name)
	if bone < 0 or child < 0: return
	var current := src.get_bone_global_pose(bone)
	var actual := (src.get_bone_global_pose(child).origin-current.origin).normalized()
	var turn := Quaternion.IDENTITY.slerp(Quaternion(actual,direction.normalized()),amount)
	var desired := Basis(turn)*current.basis.orthonormalized()
	var parent := src.get_bone_parent(bone)
	var parent_basis := src.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	src.set_bone_pose_rotation(bone,(parent_basis.inverse()*desired).get_rotation_quaternion())

func author_pose(destination: String, phase: float) -> void:
	# AAA combat choreography for rigged enemies: distinct windups, explosive releases, and heavy kinetic follow-through.
	if destination in ["Sword_Attack03","Stone_Slam","Ice_Cleave","Lava_Crash"]:
		var wind := Vector3(-0.28, 0.98, -0.22)
		var contact := Vector3(-0.22, -0.62, 0.85)
		var amount: float = smoothstep(0.0, 0.22, phase) * (1.0 - smoothstep(0.58, 0.96, phase))
		var strike: float = smoothstep(0.25, 0.44, phase)
		var direction := wind.lerp(contact, strike)
		turn_source("DEF-spine.001", Vector3.RIGHT, lerpf(-0.18, 0.32, strike) * amount)
		turn_source("DEF-spine.003", Vector3.RIGHT, lerpf(-0.22, 0.45, strike) * amount)
		aim_source("DEF-upper_arm.R", "DEF-forearm.R", direction, amount)
		aim_source("DEF-forearm.R", "DEF-hand.R", Vector3(0.08, 0.92, 0.38).lerp(Vector3(0.02, -0.52, 0.98), strike), amount)
		if destination in ["Stone_Slam", "Lava_Crash"]:
			aim_source("DEF-upper_arm.L", "DEF-forearm.L", Vector3(-direction.x, direction.y, direction.z), amount * 0.92)
			aim_source("DEF-forearm.L", "DEF-hand.L", Vector3(0, -0.35, 0.92), amount * 0.85)
	elif destination in ["Water_Sweep", "Wind_Cyclone", "Void_Reap", "Sword_Attack", "Sword_Attack02"]:
		var reverse: float = -1.0 if destination in ["Water_Sweep", "Sword_Attack02"] else 1.0
		var strike: float = smoothstep(0.24, 0.46, phase)
		var amount: float = smoothstep(0.0, 0.20, phase) * (1.0 - smoothstep(0.60, 0.95, phase))
		turn_source("DEF-spine.001", Vector3.UP, reverse * lerpf(-0.35, 0.52, strike) * amount)
		turn_source("DEF-spine.003", Vector3.UP, reverse * lerpf(-0.45, 0.72, strike) * amount)
		var arm_wind := Vector3(-0.65 * reverse, 0.15, -0.35)
		var arm_follow := Vector3(0.68 * reverse, -0.18, 0.72)
		aim_source("DEF-upper_arm.R", "DEF-forearm.R", arm_wind.lerp(arm_follow, strike), amount)
		aim_source("DEF-forearm.R", "DEF-hand.R", Vector3(0.1, 0.45, 0.88).lerp(Vector3(0.65 * reverse, -0.22, 0.72), strike), amount)
	elif destination in ["Soul_Channel", "Gravity_Pulse", "Poison_Cast"]:
		var amount := sin(phase * PI) * 0.92
		turn_source("DEF-spine.001", Vector3.RIGHT, -0.18 * amount)
		turn_source("DEF-spine.003", Vector3.RIGHT, -0.26 * amount)
		aim_source("DEF-upper_arm.R", "DEF-forearm.R", Vector3(-0.75, 0.65, 0.22), amount)
		aim_source("DEF-forearm.R", "DEF-hand.R", Vector3(-0.15, 0.82, 0.55), amount)
		aim_source("DEF-upper_arm.L", "DEF-forearm.L", Vector3(0.75, 0.65, 0.22), amount)
		aim_source("DEF-forearm.L", "DEF-hand.L", Vector3(0.15, 0.82, 0.55), amount)
	elif destination in ["Lightning_Lunge", "Punch_Cross"]:
		var strike: float = smoothstep(0.20, 0.38, phase)
		var amount: float = smoothstep(0.0, 0.18, phase) * (1.0 - smoothstep(0.55, 0.92, phase))
		turn_source("DEF-spine.003", Vector3.RIGHT, 0.18 * strike * amount)
		aim_source("DEF-upper_arm.R", "DEF-forearm.R", Vector3(-0.15, 0.05, 0.99), amount)
		aim_source("DEF-forearm.R", "DEF-hand.R", Vector3(0.05, 0.02, 0.99), amount)
	elif destination == "Hit_Chest":
		var flinch := smoothstep(0.0, 0.15, phase) * (1.0 - smoothstep(0.22, 1.0, phase))
		turn_source("DEF-spine.001", Vector3.RIGHT, -0.25 * flinch)
		turn_source("DEF-spine.003", Vector3.RIGHT, -0.35 * flinch)
		turn_source("DEF-head", Vector3.RIGHT, 0.30 * flinch)

func turn_source(name: String, axis: Vector3, angle: float) -> void:
	var index := src.find_bone(name)
	if index < 0: return
	var posed := src.get_bone_global_pose(index)
	var desired := Basis(axis,angle)*posed.basis.orthonormalized()
	var parent := src.get_bone_parent(index)
	var parent_basis := src.get_bone_global_pose(parent).basis.orthonormalized() if parent>=0 else Basis.IDENTITY
	src.set_bone_pose_rotation(index,(parent_basis.inverse()*desired).get_rotation_quaternion())

func player_pose(destination: String, phase: float) -> void:
	# Original fast arena-combat poses layered on the CC0 library's footwork.
	# Keep an armed running posture and make each combo a different cut; never
	# reverse a complete motion, which also reverses its step and recovery.
	if destination in ["Idle_Loop", "Sword_Idle_Loop"]:
		aim_source("DEF-upper_arm.R","DEF-forearm.R",Vector3(-0.42,-0.74,0.38),0.8)
		aim_source("DEF-forearm.R","DEF-hand.R",Vector3(-0.06,0.22,0.97),0.8)
		aim_source("DEF-upper_arm.L","DEF-forearm.L",Vector3(0.40,-0.81,0.18),0.65)
		aim_source("DEF-forearm.L","DEF-hand.L",Vector3(0.02,-0.75,0.58),0.65)
	elif destination in ["Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop"]:
		var sprint := destination == "Sprint_Loop"
		var gait := sin(phase*TAU)
		aim_source("DEF-upper_arm.R","DEF-forearm.R",Vector3(-0.30,-0.87,-0.22+gait*0.22),0.80)
		aim_source("DEF-forearm.R","DEF-hand.R",Vector3(-0.10,-0.38,0.92+gait*0.15),0.82)
		if sprint:
			turn_source("DEF-spine.001",Vector3.RIGHT,0.05)
			turn_source("DEF-spine.003",Vector3.UP,gait*0.055)
	elif destination in ["Sword_Attack", "Sword_Attack02", "Sword_Attack03"]:
		var wind := smoothstep(0.0,0.18,phase)
		var release := smoothstep(0.22,0.39,phase)
		var recover := smoothstep(0.58,1.0,phase)
		var amount := wind*(1.0-recover)
		var upper := Vector3(-0.72,0.08,0.38)
		var lower := Vector3(0.15,0.20,0.97)
		var finish_upper := Vector3(0.75,-0.13,0.64)
		var finish_lower := Vector3(0.82,-0.30,0.45)
		var twist := lerpf(-0.30,0.43,release)*amount
		if destination == "Sword_Attack02":
			upper = Vector3(0.35,-0.08,0.85)
			lower = Vector3(0.65,0.3,0.65)
			finish_upper = Vector3(-0.75,0.04,0.45)
			finish_lower = Vector3(-0.65,0.15,0.75)
			twist = lerpf(0.33,-0.40,release)*amount
		elif destination == "Sword_Attack03":
			upper = Vector3(-0.20,0.95,0.18)
			lower = Vector3(0.03,0.45,-0.88)
			finish_upper = Vector3(-0.25,-0.48,0.84)
			finish_lower = Vector3(0,-0.55,0.84)
			twist = lerpf(-0.12,0.18,release)*amount
			turn_source("DEF-spine.003",Vector3.RIGHT,lerpf(-0.12,0.24,release)*amount)
		turn_source("DEF-spine.003",Vector3.UP,twist)
		aim_source("DEF-upper_arm.R","DEF-forearm.R",upper.lerp(finish_upper,release),amount)
		aim_source("DEF-forearm.R","DEF-hand.R",lower.lerp(finish_lower,release),amount)
		aim_source("DEF-upper_arm.L","DEF-forearm.L",Vector3(0.45,-0.4,-0.30),amount*0.6)
		aim_source("DEF-forearm.L","DEF-hand.L",Vector3(0.35,-0.30,0.78),amount*0.55)

func bake(identity: String) -> void:
	var model_path := "res://assets/sculpt_motion/"+identity+".scn"
	if not ResourceLoader.exists(model_path): model_path = "res://assets/provided/"+identity+".glb"
	var model: Node3D = load(model_path).instantiate()
	root.add_child(model)
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		push_error("Cannot retarget unrigged asset: "+identity)
		model.free()
		return
	var sk: Skeleton3D = rigs[0]
	for candidate in rigs:
		if candidate.get_bone_count() > sk.get_bone_count(): sk = candidate
	var facing := Basis(Vector3.UP,-PI/2) if identity in ["subboss_2","subboss_6","subboss_7","subboss_8","main_boss"] else Basis.IDENTITY
	var pairs: Dictionary = {}
	var reverse: Dictionary = {}
	var corrections: Dictionary = {}
	var pelvis := -1
	for index in sk.get_bone_count():
		var name := map_name(sk.get_bone_name(index))
		if identity == "female" and name == "DEF-spine.001": name = "DEF-spine.003"
		if identity != "omega" and sk.get_bone_name(index).begins_with("spine_03"): name = "DEF-spine.003"
		var source_index := src.find_bone(name)
		if source_index >= 0:
			pairs[index] = source_index
			reverse[source_index] = index
			if name == "DEF-hips": pelvis = index
	for index in pairs:
		var source_index: int = pairs[index]
		var target_rest := (facing * sk.global_basis * sk.get_bone_global_rest(index).basis).orthonormalized()
		var source_rest := (src.global_basis * src.get_bone_global_rest(source_index).basis).orthonormalized()
		var source_direction := child_direction(src, source_index, reverse)
		var target_direction := facing * child_direction(sk, index, pairs)
		var align := Basis(Quaternion(target_direction, source_direction))
		# For pelvis/spine/head preserve anatomical upright roll, while limbs
		# explicitly compensate for the A-pose versus source T-pose.
		var bone_name := sk.get_bone_name(index).to_lower()
		var source_name := src.get_bone_name(source_index)
		if not ("arm" in source_name or "hand" in source_name or "thigh" in source_name or "shin" in source_name or "foot" in source_name or "toe" in source_name or "index" in source_name or "middle" in source_name or "ring" in source_name or "pinky" in source_name or "thumb" in source_name): align = Basis.IDENTITY
		corrections[index] = source_rest.inverse() * align * target_rest
	var hip_rest := sk.get_bone_rest(pelvis).origin
	var hip_parent := sk.get_bone_parent(pelvis)
	var hip_parent_basis := sk.global_basis
	if hip_parent >= 0: hip_parent_basis *= sk.get_bone_global_rest(hip_parent).basis
	var source_hip := src.find_bone("DEF-hips")
	var height_ratio: float = sk.to_global(sk.get_bone_global_rest(pelvis).origin).y / src.get_bone_global_rest(source_hip).origin.y
	var bone_path := "Motion/SourceModel/" + str(model.get_path_to(sk))
	var library := AnimationLibrary.new()
	for destination in SOURCES:
		var source_name: String = SOURCES[destination]
		var player_clip := identity in ["female", "omega"]
		if player_clip: source_name = PLAYER_MOTION.source_clip(destination, source_name)
		var original: Animation = playback.get_animation(source_name)
		var animation := Animation.new()
		animation.length = PLAYER_MOTION.duration(destination, original.length) if player_clip else original.length
		animation.loop_mode = Animation.LOOP_LINEAR if destination.ends_with("Loop") else Animation.LOOP_NONE
		var tracks: Dictionary = {}
		for index in pairs:
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath(bone_path + ":" + sk.get_bone_name(index)))
			tracks[index] = track
		var position_track := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(position_track, NodePath(bone_path + ":" + sk.get_bone_name(pelvis)))
		var root_turn_track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(root_turn_track, NodePath("Motion:rotation"))
		playback.stop()
		src.reset_bone_poses()
		playback.play(source_name)
		var sample_rate := 60.0 if player_clip else 30.0
		var frame_count := ceili(animation.length * sample_rate)
		for frame in frame_count + 1:
			var time := minf(frame/sample_rate, animation.length)
			var sample := animation.length - time if destination in ["Sword_Attack02","Water_Sweep"] and identity not in ["female","omega"] else time
			var phase: float = time/maxf(animation.length,0.001)
			if player_clip: sample = PLAYER_MOTION.sample_time(destination, phase, original.length)
			src.reset_bone_poses()
			playback.seek(sample, true)
			if player_clip:
				PLAYER_MOTION.pose(self, destination, phase)
			else:
				author_pose(destination, phase)
			sk.reset_bone_poses()
			var displacement := src.get_bone_global_pose(source_hip).origin - src.get_bone_global_rest(source_hip).origin
			# Position tracks are relative to the pelvis's parent. Omega's root
			# rotates its rest rig by 90 degrees, so skeleton-space displacement
			# would send crouches and landing compression horizontally.
			var hip_position: Vector3 = hip_rest + hip_parent_basis.inverse() * facing.inverse() * Vector3(clampf(displacement.x,-0.06,0.06), displacement.y, 0) * height_ratio
			sk.set_bone_pose_position(pelvis, hip_position)
			animation.position_track_insert_key(position_track, time, hip_position)
			for index in pairs:
				var source_index: int = pairs[index]
				var source_basis := (src.global_basis * src.get_bone_global_pose(source_index).basis).orthonormalized()
				var desired: Basis = facing.inverse() * source_basis * corrections[index]
				var parent := sk.get_bone_parent(index)
				var parent_basis := sk.global_basis.orthonormalized()
				if parent >= 0: parent_basis = (sk.global_basis * sk.get_bone_global_pose(parent).basis).orthonormalized()
				var rotation_value := (parent_basis.inverse() * desired).get_rotation_quaternion().normalized()
				sk.set_bone_pose_rotation(index, rotation_value)
				animation.rotation_track_insert_key(tracks[index], time, rotation_value)
			var turn: float = TAU*smoothstep(0.15,0.85,phase) if destination == "Wind_Cyclone" else (-0.9*sin(phase*PI) if destination == "Void_Reap" else 0.0)
			animation.track_insert_key(root_turn_track,time,Vector3(0,turn,0))
		library.add_animation(destination, animation)
	var status := ResourceSaver.save(library, "res://assets/motion/"+identity+"_combat.res")
	report.append({"id":identity,"mapped_bones":pairs.size(),"clips":SOURCES.size(),"save_error":status})
	print("COMBAT_MOTION_BAKED ",identity," bones=",pairs.size()," clips=",SOURCES.size()," status=",status)
	model.free()
