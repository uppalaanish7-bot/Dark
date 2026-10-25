extends RefCounted
## Hero choreography in the CC0 source's anatomical space (+Z faces forward).
## Grounded sword choreography with anticipation, follow-through, breathing,
## and recovery timing fitted to the game's damage events.
const CUTS := ["Sword_Attack", "Sword_Attack02", "Sword_Attack03"]
const CASTS := ["Fire_Cast", "Cast", "Channel_Loop", "Cast_Release"]
const AIR := ["Jump_Start", "Double_Jump", "Jump_Loop", "Jump_Fall", "Jump_Land"]

static func source_clip(clip: String, fallback: String) -> String:
	if clip in CUTS or clip in CASTS or clip in ["Run_Stop","Sprint_Stop"]: return "Sword_Idle"
	return fallback

static func duration(clip: String, fallback: float) -> float:
	return {"Sword_Attack":0.32, "Sword_Attack02":0.37, "Sword_Attack03":0.53,
		"Idle_Loop":4.8, "Sword_Idle_Loop":3.6, "Run_Stop":0.26, "Sprint_Stop":0.34,
		"Fire_Cast":0.42, "Cast":1.20, "Cast_Release":0.30, "Channel_Loop":1.8,
		"Jump_Start":0.22, "Double_Jump":0.28, "Jump_Loop":0.8,
		"Jump_Fall":0.8, "Jump_Land":0.24, "Roll":0.44}.get(clip, fallback)

static func sample_time(clip: String, phase: float, source_length: float) -> float:
	if clip in CUTS or clip in CASTS or clip in ["Run_Stop","Sprint_Stop"]: return 0.0
	if clip in ["Jump_Start", "Double_Jump"]: return lerpf(0.38, 0.84, phase)
	if clip == "Jump_Loop": return lerpf(0.68, 0.78, sin(phase*TAU)*0.5+0.5)
	if clip == "Jump_Fall": return 1.20
	if clip == "Jump_Land": return lerpf(0.16, 0.90, phase)
	return phase*source_length

static func blade(builder: SceneTree, direction: Vector3, amount: float = 1.0) -> void:
	var rig: Skeleton3D = builder.src
	var hand := rig.find_bone("DEF-hand.R")
	var index := rig.find_bone("DEF-f_index.01.R")
	var pinky := rig.find_bone("DEF-f_pinky.01.R")
	var rest := rig.get_bone_global_rest(hand)
	var thumb_side := (rig.get_bone_global_rest(index).origin-rig.get_bone_global_rest(pinky).origin).normalized()
	var pose := rig.get_bone_global_pose(hand)
	var current := (pose.basis*rest.basis.inverse()*thumb_side).normalized()
	var correction := Quaternion.IDENTITY.slerp(Quaternion(current,direction.normalized()),amount)
	var parent := rig.get_bone_parent(hand)
	var parent_basis := rig.get_bone_global_pose(parent).basis.orthonormalized()
	rig.set_bone_pose_rotation(hand,(parent_basis.inverse()*Basis(correction)*pose.basis.orthonormalized()).get_rotation_quaternion())

static func point_joint(rig: Skeleton3D, bone: int, child: int, target: Vector3) -> void:
	var pose := rig.get_bone_global_pose(bone)
	var actual := rig.get_bone_global_pose(child).origin-pose.origin
	var desired := target-pose.origin
	if actual.length_squared() < 0.000001 or desired.length_squared() < 0.000001: return
	var correction := Basis(Quaternion(actual.normalized(),desired.normalized()))
	var parent := rig.get_bone_parent(bone)
	var parent_basis := rig.get_bone_global_pose(parent).basis.orthonormalized() if parent>=0 else Basis.IDENTITY
	rig.set_bone_pose_rotation(bone,(parent_basis.inverse()*correction*pose.basis.orthonormalized()).get_rotation_quaternion())

static func solve_limb(rig: Skeleton3D, first: int, middle: int, last: int, target: Vector3, bend: Vector3) -> void:
	var origin := rig.get_bone_global_pose(first).origin
	var elbow := rig.get_bone_global_pose(middle).origin
	var endpoint := rig.get_bone_global_pose(last).origin
	var upper := origin.distance_to(elbow)
	var lower := elbow.distance_to(endpoint)
	var reach := clampf(origin.distance_to(target),absf(upper-lower)+0.0001,upper+lower-0.0001)
	var axis := (target-origin).normalized()
	var pole := (bend-axis*bend.dot(axis)).normalized()
	var along := (upper*upper+reach*reach-lower*lower)/(2.0*reach)
	point_joint(rig,first,middle,origin+axis*along+pole*sqrt(maxf(upper*upper-along*along,0.0)))
	point_joint(rig,middle,last,target)

static func balanced_stance(builder: SceneTree, compression: float = 0.025) -> void:
	var rig: Skeleton3D = builder.src
	for name in ["root","DEF-hips","DEF-spine.001","DEF-spine.002","DEF-spine.003","DEF-neck","DEF-head","DEF-shoulder.L","DEF-shoulder.R"]:
		var bone := rig.find_bone(name)
		if bone >= 0: rig.set_bone_pose_rotation(bone,rig.get_bone_rest(bone).basis.get_rotation_quaternion())
	var hips := rig.find_bone("DEF-hips")
	if hips >= 0: rig.set_bone_pose_position(hips,rig.get_bone_rest(hips).origin+Vector3(0,-compression,0))
	for side in [".L",".R"]:
		var thigh := rig.find_bone("DEF-thigh"+side)
		var shin := rig.find_bone("DEF-shin"+side)
		var foot := rig.find_bone("DEF-foot"+side)
		var toe := rig.find_bone("DEF-toe"+side)
		for bone in [thigh,shin,foot,toe]:
			if bone >= 0: rig.set_bone_pose_rotation(bone,rig.get_bone_rest(bone).basis.get_rotation_quaternion())
		if thigh >= 0 and shin >= 0 and foot >= 0:
			var target := rig.get_bone_global_rest(foot).origin
			target.x = 0.135 if side==".L" else -0.135
			target.z += 0.035 if side==".L" else -0.035
			solve_limb(rig,thigh,shin,foot,target,Vector3(0,0,1))
			var parent_basis := rig.get_bone_global_pose(shin).basis.orthonormalized()
			rig.set_bone_pose_rotation(foot,(parent_basis.inverse()*rig.get_bone_global_rest(foot).basis.orthonormalized()).get_rotation_quaternion())

static func guard(builder: SceneTree, phase: float = 0.0) -> void:
	var breath := sin(phase*TAU)*0.016
	var sway := sin(phase*TAU*0.5)*0.008
	balanced_stance(builder, 0.025 + breath * 0.4)
	builder.turn_source("DEF-hips", Vector3.UP, sway * 0.3)
	builder.turn_source("DEF-spine.001", Vector3.RIGHT, breath * 0.2)
	builder.turn_source("DEF-spine.003", Vector3.RIGHT, breath * 0.4)
	builder.turn_source("DEF-neck", Vector3.RIGHT, -breath * 0.25)
	# Disciplined en-garde sword guard: blade angled forward-upward at an alert 45 degree angle.
	builder.aim_source("DEF-upper_arm.R", "DEF-forearm.R", Vector3(-0.28, -0.88, 0.38 + breath * 0.5), 1.0)
	builder.aim_source("DEF-forearm.R", "DEF-hand.R", Vector3(0.04, 0.32 + breath, 0.94), 1.0)
	builder.aim_source("DEF-upper_arm.L", "DEF-forearm.L", Vector3(0.24, -0.92, 0.12 - breath * 0.3), 1.0)
	builder.aim_source("DEF-forearm.L", "DEF-hand.L", Vector3(0.12, -0.80, 0.58), 1.0)
	blade(builder, Vector3(-0.16, 0.92, 0.34 + breath * 0.5))

static func pose(builder: SceneTree, clip: String, phase: float) -> void:
	if clip in ["Idle_Loop", "Sword_Idle_Loop"]:
		guard(builder,phase)
		if clip == "Idle_Loop":
			# Lower ready stance for exploration, with a slow breath and a small
			# head scan. The sword stays clear of the knee and floor.
			var breath := sin(phase*TAU)*0.016
			builder.aim_source("DEF-upper_arm.R", "DEF-forearm.R", Vector3(-0.32,-0.94,0.04),1.0)
			builder.aim_source("DEF-forearm.R", "DEF-hand.R", Vector3(-0.08,-0.40,0.92+breath),1.0)
			builder.aim_source("DEF-upper_arm.L", "DEF-forearm.L", Vector3(0.18,-0.98,0.01),1.0)
			builder.aim_source("DEF-forearm.L", "DEF-hand.L", Vector3(0.10,-0.93,0.35),1.0)
			builder.turn_source("DEF-head",Vector3.UP,sin(phase*TAU)*0.055)
			blade(builder,Vector3(-0.22,0.56,0.80+breath))
	elif clip in ["Run_Stop","Sprint_Stop"]:
		guard(builder,phase*0.12)
		var effort := sin(phase*PI)*(1.0-phase)
		var weight := 1.0 if clip == "Sprint_Stop" else 0.65
		balanced_stance(builder,0.025+effort*0.06*weight)
		builder.turn_source("DEF-spine.001",Vector3.RIGHT,-effort*0.12*weight)
		builder.turn_source("DEF-spine.003",Vector3.RIGHT,-effort*0.10*weight)
		builder.turn_source("DEF-head",Vector3.RIGHT,effort*0.10*weight)
		builder.aim_source("DEF-upper_arm.L","DEF-forearm.L",Vector3(0.42,-0.80,0.20),effort*weight)
	elif clip in ["Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop"]:
		var gait := sin(phase*TAU)
		var sprint := clip == "Sprint_Loop"
		if sprint:
			# High-speed athletic combat sprint: forward torso lean, sword swept aerodynamically along flank.
			builder.turn_source("DEF-spine.001", Vector3.RIGHT, 0.16)
			builder.turn_source("DEF-spine.002", Vector3.RIGHT, 0.10)
			builder.turn_source("DEF-spine.003", Vector3.RIGHT, 0.06)
			builder.turn_source("DEF-spine.003", Vector3.UP, gait * 0.08)
			builder.turn_source("DEF-head", Vector3.RIGHT, -0.22)
			builder.aim_source("DEF-upper_arm.R", "DEF-forearm.R", Vector3(-0.35, -0.85, -0.38 + gait * 0.12), 0.96)
			builder.aim_source("DEF-forearm.R", "DEF-hand.R", Vector3(-0.12, 0.18, 0.97 + gait * 0.08), 0.96)
			blade(builder, Vector3(-0.18, 0.82, -0.52 + gait * 0.08), 0.98)
			builder.aim_source("DEF-upper_arm.L", "DEF-forearm.L", Vector3(0.32, -0.82, -0.25 - gait * 0.38), 0.92)
			builder.aim_source("DEF-forearm.L", "DEF-hand.L", Vector3(0.14, 0.22, 0.96 - gait * 0.25), 0.92)
		else:
			builder.turn_source("DEF-spine.001", Vector3.RIGHT, 0.06)
			builder.turn_source("DEF-spine.003", Vector3.UP, gait * 0.05)
			builder.aim_source("DEF-upper_arm.R", "DEF-forearm.R", Vector3(-0.30, -0.88, -0.10 + gait * 0.16), 0.92)
			builder.aim_source("DEF-forearm.R", "DEF-hand.R", Vector3(-0.04, 0.12, 0.99), 0.96)
			blade(builder, Vector3(-0.16, 0.91, 0.36 + gait * 0.06), 0.98)
			builder.aim_source("DEF-upper_arm.L", "DEF-forearm.L", Vector3(0.24, -0.92, -0.10 - gait * 0.28), 0.88)
			builder.aim_source("DEF-forearm.L", "DEF-hand.L", Vector3(0.10, -0.45, 0.88 - gait * 0.15), 0.88)
	elif clip in CUTS:
		guard(builder)
		cut(builder,clip,phase)
	elif clip in CASTS:
		guard(builder)
		cast(builder,clip,phase)
	elif clip in AIR or clip == "Roll":
		armed_air(builder,clip,phase)

static func cut(builder: SceneTree, clip: String, phase: float) -> void:
	var contact: float = {"Sword_Attack":0.34375,"Sword_Attack02":0.2973,"Sword_Attack03":0.3396}[clip]
	# AAA non-linear timing: coiled anticipation -> explosive snap -> follow-through & recovery.
	var wind_up := pow(smoothstep(0.0, contact * 0.50, phase), 1.4)
	var snap := pow(smoothstep(contact * 0.60, contact, phase), 0.8)
	var recover := smoothstep(contact + 0.16, 1.0, phase)
	var power := (wind_up if phase < contact else 1.0) * (1.0 - recover)

	if clip == "Sword_Attack":
		# Combo 1: Horizontal Crescent Slash - explosive torso uncoil, wide cutting plane.
		var twist_hips := lerpf(-0.38, 0.44, snap) * power
		var twist_spine := lerpf(-0.52, 0.68, snap) * power
		var forward_bend := lerpf(-0.06, 0.14, snap) * power
		balanced_stance(builder, 0.025 + snap * 0.035 * (1.0 - recover))
		builder.turn_source("DEF-hips", Vector3.UP, twist_hips)
		builder.turn_source("DEF-spine.001", Vector3.UP, twist_spine * 0.4)
		builder.turn_source("DEF-spine.003", Vector3.UP, twist_spine * 0.6)
		builder.turn_source("DEF-spine.001", Vector3.RIGHT, forward_bend * 0.4)
		builder.turn_source("DEF-spine.003", Vector3.RIGHT, forward_bend * 0.6)
		builder.turn_source("DEF-head", Vector3.UP, -twist_spine * 0.65)
		var upper_wind := Vector3(-0.78, 0.12, -0.32)
		var upper_follow := Vector3(0.62, -0.18, 0.76)
		var lower_wind := Vector3(-0.16, 0.58, 0.78)
		var lower_follow := Vector3(0.78, -0.26, 0.56)
		var edge_wind := Vector3(-0.92, 0.38, -0.16)
		var edge_follow := Vector3(0.88, -0.28, 0.38)
		builder.aim_source("DEF-upper_arm.R", "DEF-forearm.R", upper_wind.lerp(upper_follow, snap), power)
		builder.aim_source("DEF-forearm.R", "DEF-hand.R", lower_wind.lerp(lower_follow, snap), power)
		builder.aim_source("DEF-upper_arm.L", "DEF-forearm.L", Vector3(0.48, -0.42, 0.55).lerp(Vector3(0.55, -0.65, -0.52), snap), power * 0.85)
		builder.aim_source("DEF-forearm.L", "DEF-hand.L", Vector3(0.18, -0.22, 0.92).lerp(Vector3(0.28, -0.38, 0.88), snap), power * 0.85)
		blade(builder, edge_wind.lerp(edge_follow, snap), power)

	elif clip == "Sword_Attack02":
		# Combo 2: Rising Dragon Cleave - upward diagonal cut leveraging momentum from Combo 1.
		var twist_hips := lerpf(0.36, -0.42, snap) * power
		var twist_spine := lerpf(0.50, -0.62, snap) * power
		var upward_arch := lerpf(0.08, -0.14, snap) * power
		balanced_stance(builder, 0.025 + (1.0 - snap) * 0.03 * power)
		builder.turn_source("DEF-hips", Vector3.UP, twist_hips)
		builder.turn_source("DEF-spine.001", Vector3.UP, twist_spine * 0.4)
		builder.turn_source("DEF-spine.003", Vector3.UP, twist_spine * 0.6)
		builder.turn_source("DEF-spine.001", Vector3.RIGHT, upward_arch * 0.4)
		builder.turn_source("DEF-spine.003", Vector3.RIGHT, upward_arch * 0.6)
		builder.turn_source("DEF-head", Vector3.UP, -twist_spine * 0.65)
		var upper_wind := Vector3(0.48, -0.24, 0.84)
		var upper_follow := Vector3(-0.72, 0.12, 0.68)
		var lower_wind := Vector3(0.62, 0.32, 0.72)
		var lower_follow := Vector3(-0.62, 0.24, 0.74)
		var edge_wind := Vector3(0.82, 0.46, -0.32)
		var edge_follow := Vector3(-0.80, 0.42, 0.42)
		builder.aim_source("DEF-upper_arm.R", "DEF-forearm.R", upper_wind.lerp(upper_follow, snap), power)
		builder.aim_source("DEF-forearm.R", "DEF-hand.R", lower_wind.lerp(lower_follow, snap), power)
		builder.aim_source("DEF-upper_arm.L", "DEF-forearm.L", Vector3(-0.45, -0.35, -0.32).lerp(Vector3(0.35, -0.88, -0.22), snap), power * 0.82)
		builder.aim_source("DEF-forearm.L", "DEF-hand.L", Vector3(0.12, -0.42, 0.88), power * 0.82)
		blade(builder, edge_wind.lerp(edge_follow, snap), power)

	elif clip == "Sword_Attack03":
		# Combo 3: Titanic Overhead Leap Finisher - athletic leap, two-handed overhead hoist, crushing plunge.
		var leap := smoothstep(0.08, contact * 0.72, phase) * (1.0 - smoothstep(contact, contact + 0.18, phase))
		var impact := smoothstep(contact * 0.78, contact, phase)
		var downstroke := lerpf(-0.36, 0.44, impact) * power
		# Knees compress deeply on impact absorption.
		balanced_stance(builder, 0.025 + impact * 0.08 * (1.0 - recover) - leap * 0.04)
		builder.turn_source("DEF-hips", Vector3.RIGHT, downstroke * 0.3)
		builder.turn_source("DEF-spine.001", Vector3.RIGHT, downstroke * 0.35)
		builder.turn_source("DEF-spine.003", Vector3.RIGHT, downstroke * 0.55)
		builder.turn_source("DEF-head", Vector3.RIGHT, -downstroke * 0.55)
		var upper_wind := Vector3(-0.22, 0.96, 0.14)
		var upper_impact := Vector3(-0.18, -0.52, 0.82)
		var lower_wind := Vector3(0.04, 0.65, -0.75)
		var lower_impact := Vector3(0.08, -0.48, 0.86)
		var edge_wind := Vector3(-0.04, 0.96, -0.28)
		var edge_impact := Vector3(-0.06, -0.74, 0.66)
		builder.aim_source("DEF-upper_arm.R", "DEF-forearm.R", upper_wind.lerp(upper_impact, impact), power)
		builder.aim_source("DEF-forearm.R", "DEF-hand.R", lower_wind.lerp(lower_impact, impact), power)
		# Off hand assists the overhead grip throughout the strike.
		builder.aim_source("DEF-upper_arm.L", "DEF-forearm.L", Vector3(0.24, 0.94, 0.18).lerp(Vector3(0.20, -0.48, 0.85), impact), power * 0.9)
		builder.aim_source("DEF-forearm.L", "DEF-hand.L", Vector3(-0.06, 0.68, -0.72).lerp(Vector3(-0.08, -0.42, 0.90), impact), power * 0.9)
		blade(builder, edge_wind.lerp(edge_impact, impact), power)

static func cast(builder: SceneTree, clip: String, phase: float) -> void:
	if clip == "Fire_Cast":
		blade_shot(builder,phase)
		return
	var lift := smoothstep(0.0,0.30,phase)
	var pull := smoothstep(0.58,0.735,phase)
	var recovery := smoothstep(0.79,1.0,phase)
	if clip == "Channel_Loop":
		lift=1.0; pull=0.0; recovery=0.0
	if clip == "Cast_Release":
		lift=1.0; pull=smoothstep(0.0,0.40,phase); recovery=smoothstep(0.45,1.0,phase)
	var power := lift*(1.0-recovery)
	var effort := sin(clampf((phase-0.56)/0.22,0.0,1.0)*PI)
	balanced_stance(builder,0.025+0.075*effort+0.035*pull*(1.0-recovery))
	# Grand celestial invocation: chest lifted to the cosmos, then titanic downstroke release.
	var bend := lerpf(-0.24, 0.38, pull) * power
	builder.turn_source("DEF-hips", Vector3.RIGHT, bend * 0.22)
	builder.turn_source("DEF-spine.001", Vector3.RIGHT, bend * 0.32)
	builder.turn_source("DEF-spine.003", Vector3.RIGHT, bend * 0.52)
	builder.turn_source("DEF-head", Vector3.RIGHT, -bend * 0.65)
	builder.turn_source("DEF-spine.003", Vector3.UP, lerpf(-0.12, 0.14, pull) * power)
	var upper := Vector3(-0.22, 0.94, 0.28).lerp(Vector3(-0.18, -0.74, 0.65), pull)
	var lower := Vector3(0.18, 0.86, 0.46).lerp(Vector3(0.06, -0.12, 0.99), pull)
	var edge := Vector3(0.02, 0.998, 0.04).lerp(Vector3(0.04, -0.74, 0.67), pull)
	builder.aim_source("DEF-upper_arm.R", "DEF-forearm.R", upper, power)
	builder.aim_source("DEF-forearm.R", "DEF-hand.R", lower, power)
	blade(builder, edge, power)
	var rig: Skeleton3D = builder.src
	var right_hand := rig.get_bone_global_pose(rig.find_bone("DEF-hand.R")).origin
	var left_hand := rig.find_bone("DEF-hand.L")
	if left_hand >= 0:
		var target := rig.get_bone_global_pose(left_hand).origin.lerp(right_hand - edge.normalized() * 0.095 + Vector3(0.045, 0, 0), power)
		solve_limb(rig, rig.find_bone("DEF-upper_arm.L"), rig.find_bone("DEF-forearm.L"), left_hand, target, Vector3(0.8, -0.2, 0.15))

static func blade_shot(builder: SceneTree, phase: float) -> void:
	# Razor-sharp duelist magic thrust: side profile, laser-straight blade, crisp recoil absorption.
	var aim := smoothstep(0.0, 0.26, phase)
	var recover := smoothstep(0.62, 1.0, phase)
	var kick := smoothstep(0.38, 0.48, phase) * (1.0 - smoothstep(0.48, 0.66, phase))
	var power := aim * (1.0 - recover)
	builder.turn_source("DEF-hips", Vector3.UP, -0.16 * power)
	builder.turn_source("DEF-spine.001", Vector3.UP, -0.12 * power)
	builder.turn_source("DEF-spine.003", Vector3.UP, -0.24 * power)
	builder.turn_source("DEF-spine.003", Vector3.RIGHT, -0.14 * kick)
	builder.turn_source("DEF-head", Vector3.UP, 0.28 * power)
	builder.aim_source("DEF-upper_arm.R", "DEF-forearm.R", Vector3(-0.10, -0.04 - kick * 0.22, 0.99), power)
	builder.aim_source("DEF-forearm.R", "DEF-hand.R", Vector3(0.08, 0.02 + kick * 0.28, 0.99), power)
	builder.aim_source("DEF-upper_arm.L", "DEF-forearm.L", Vector3(0.36, -0.84, -0.38), power)
	builder.aim_source("DEF-forearm.L", "DEF-hand.L", Vector3(-0.10, -0.35, 0.93), power)
	blade(builder, Vector3(0.0, kick * 0.22, 1.0), power)

static func armed_air(builder: SceneTree, clip: String, phase: float) -> void:
	var roll := clip == "Roll"
	var rig: Skeleton3D = builder.src
	var chest := rig.find_bone("DEF-spine.003")
	var rest := rig.get_bone_global_rest(chest).basis.orthonormalized()
	var posed := rig.get_bone_global_pose(chest).basis.orthonormalized()
	var frame := posed*rest.inverse() if roll else Basis.IDENTITY
	builder.aim_source("DEF-upper_arm.R","DEF-forearm.R",frame*Vector3(-0.26,-0.65,0.42),0.96)
	builder.aim_source("DEF-forearm.R","DEF-hand.R",frame*Vector3(0.10,0.55,0.81),0.96)
	builder.aim_source("DEF-upper_arm.L","DEF-forearm.L",frame*Vector3(0.42,-0.45,0.60),0.92)
	builder.aim_source("DEF-forearm.L","DEF-hand.L",frame*Vector3(-0.10,0.70,0.70),0.92)
	blade(builder,frame*Vector3(-0.35,0.80,0.48),0.96)
	if clip == "Jump_Land":
		var settle := smoothstep(0.35, 1.0, phase)
		builder.aim_source("DEF-upper_arm.L","DEF-forearm.L",Vector3(0.36,-0.92,0.1),settle)
		builder.aim_source("DEF-forearm.L","DEF-hand.L",Vector3(0.1,-0.64,0.76),settle)
