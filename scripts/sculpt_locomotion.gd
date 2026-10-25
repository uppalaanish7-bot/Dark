extends RefCounted
## Grounded motion in the fitted rigs' common axes (-Z forward). A two-link
## solve compensates the hips before placing each ankle; limb lengths never change.
## AAA kinetic choreography: distinct anticipation, explosive whip releases,
## heavyweight impacts, multi-harmonic spectral float, and visceral hit reactions.
const LOADOUT = preload("res://scripts/enemy_loadout.gd")
const HEAVY := ["subboss_3", "subboss_8", "subboss_9", "grand_boss"]
const PHASES := [0.0, 0.20, 0.32, 0.42, 0.56, 0.78, 1.0]

static func animate(v: Node3D, delta: float, speed: float) -> void:
	var rig: Skeleton3D = v.skeleton
	var state: Dictionary = _state(rig)
	var scale_factor: float = maxf(v.target_height / 2.1, 0.1)
	state.speed = lerpf(state.speed, speed / scale_factor, 1.0 - exp(-12.0 * delta))
	var moving: float = smoothstep(0.04, 0.85, state.speed)
	var running: float = smoothstep(2.0, 5.3, state.speed)
	var spectral: bool = rig.get_meta("spectral", false)
	var final_boss: bool = v.asset_id == "main_boss"
	var heavy: bool = v.asset_id in HEAVY
	var held: Dictionary = LOADOUT.profile(v.asset_id)
	var unarmed: bool = held.kind == "fists"
	var main_side: String = held.side
	var other_side: String = "r" if main_side == "l" else "l"
	var side_sign: float = 1.0 if main_side == "l" else -1.0
	var acting: bool = v.one_shot_time > 0.0 or v._dead
	var phase: float = clampf(1.0 - v.one_shot_time / maxf(v._action_duration, 0.01), 0.0, 1.0)
	var cue: String = v.current_clip if acting else ""

	# AAA multi-phase kinetic curves: coiled anticipation, hyper-accelerated strike, impact overshoot, recovery.
	var commitment: float = _curve(phase, [0.0, 0.96, 1.0, 1.0, 0.88, 0.35, 0.0]) if acting else 0.0
	var windup: float = _curve(phase, [0.0, 0.90, 1.0, 0.0, 0.0, 0.0, 0.0]) if acting else 0.0
	var contact: float = _curve(phase, [0.0, 0.0, 0.0, 1.0, 0.82, 0.20, 0.0]) if acting else 0.0
	var follow: float = _curve(phase, [0.0, 0.0, 0.0, 0.0, 1.0, 0.48, 0.0]) if acting else 0.0
	var gait_weight: float = moving * (1.0 - commitment * (0.48 if final_boss else 0.90))
	var aggression: float = 1.0 + float(maxi(v.combat_phase - 1, 0)) * 0.13 if final_boss else 1.0
	if final_boss:
		windup = minf(windup * aggression, 1.25)
		contact = minf(contact * aggression, 1.30)
		follow = minf(follow * aggression, 1.25)

	var local_motion: Vector3 = v._motion_velocity
	local_motion.y = 0.0
	if local_motion.length_squared() > 0.04:
		state.direction = state.direction.lerp(local_motion.normalized(), 1.0 - exp(-14.0 * delta)).normalized()
	state.turn = lerpf(state.turn, clampf(v._turn_rate, -5.0, 5.0), 1.0 - exp(-9.0 * delta))
	var duty: float = lerpf(0.64, 0.43, running)
	var leg_length: float = state.leg_length
	var half_stride: float = leg_length * lerpf(0.27, 0.52, running) * gait_weight
	var stride_distance: float = maxf(leg_length * lerpf(0.54, 1.04, running) / duty, 0.2)
	state.phase = fposmod(state.phase + delta * state.speed / stride_distance * TAU, TAU)
	var cycle: float = state.phase

	# Organic respiration and predatory biomechanics.
	var breath: float = sin(v.age * (2.35 if final_boss else (1.55 if heavy else 2.1))) * (0.030 if final_boss else (0.022 if heavy else 0.014))
	var sway: float = sin(cycle) * gait_weight
	var roll: float = cos(cycle) * 0.032 * gait_weight
	var step_dip: float = -absf(sin(cycle)) * leg_length * (0.038 if heavy else 0.024) * moving

	var poses: Dictionary = {}
	poses.sculpt_pelvis = Vector3(step_dip * 0.4, sway * 0.085, roll - state.turn * 0.016 * moving)
	poses.sculpt_spine = Vector3(-0.04 - running * gait_weight * 0.12 + breath, -sway * 0.13 - state.turn * 0.018 * moving, sway * 0.024 + state.turn * 0.012 * moving)
	poses.sculpt_head = Vector3(-breath * 0.6 + running * gait_weight * 0.065, sway * 0.045, 0.0)
	var body_offset := Vector3(sway * 0.022, -leg_length * 0.075 * moving + step_dip, 0.0)

	var feet: Dictionary = {}
	var foot_pitch: Dictionary = {}
	for side in ["l", "r"]:
		var offset: float = 0.0 if side == "l" else PI
		var gait: float = fposmod((cycle + offset) / TAU, 1.0)
		var foot_z: float
		var lift: float = 0.0
		var pitch: float = 0.0
		if gait < duty:
			foot_z = lerpf(-half_stride, half_stride, gait / duty)
			pitch = (-0.11 * (1.0 - smoothstep(0.0, 0.18, gait / duty)) + 0.14 * smoothstep(0.80, 1.0, gait / duty)) * gait_weight
		else:
			var swing: float = (gait - duty) / (1.0 - duty)
			foot_z = lerpf(half_stride, -half_stride, smoothstep(0.0, 1.0, swing))
			lift = pow(sin(swing * PI), 1.35) * leg_length * lerpf(0.12, 0.27, running) * gait_weight
			pitch = sin(swing * PI) * 0.18 * gait_weight
		var rest_foot: Vector3 = rig.get_bone_global_rest(state.bones["sculpt_foot_" + side]).origin
		var lead: float = -1.0 if side == main_side else 1.0
		feet[side] = rest_foot - state.direction * foot_z + Vector3(0.0, lift, lead * commitment * leg_length * 0.10)
		foot_pitch[side] = pitch
		var arm_swing: float = sin(cycle + offset) * lerpf(0.18, 0.35, running) * gait_weight
		poses["sculpt_arm_" + side] = Vector3(0.12 + (0.14 if unarmed else 0.0) - arm_swing, 0.0, 0.0)
		poses["sculpt_forearm_" + side] = Vector3((0.56 if unarmed else 0.22) + running * 0.20 + maxf(0.0, arm_swing) * 0.48, 0.0, 0.0)
		var sign_value: float = 1.0 if side == "l" else -1.0
		poses["sculpt_wing_" + side] = Vector3(0.0, sign_value * (sin(v.age * 2.1 - 0.45) * 0.075 + running * moving * 0.11), sign_value * sin(v.age * 2.1) * 0.065)
		poses["sculpt_hem_" + side] = Vector3(sin(cycle + offset - 0.45) * 0.065 * moving + running * moving * 0.06, 0.0, sign_value * sin(v.age * 1.6 - 0.4) * 0.035)

	if acting and cue not in ["Death01", "Hit_Chest"]:
		var overhead: bool = cue in ["Stone_Slam", "Ice_Cleave", "Lava_Crash", "Sword_Attack03", "Axe_Chop", "Blade_Overhead"]
		var channel: bool = cue in ["Soul_Channel", "Gravity_Pulse", "Poison_Cast", "Fire_Cast", "Cast"]
		var punch: bool = cue == "Punch_Jab" and unarmed
		var lunge: bool = cue in ["Lightning_Lunge", "Staff_Thrust"]
		var scythe: bool = held.kind == "scythe" and not channel
		var dual: bool = held.kind == "dual_blade" and not channel
		var reverse: float = -1.0 if cue in ["Water_Sweep", "Wind_Cyclone", "Sword_Attack02", "Blade_Left_Return", "Blade_Right_Return", "Scythe_Return", "Axe_Backhand"] else 1.0
		var swing_direction: float = side_sign * reverse

		# Deep kinematic anticipation & violent release down kinetic chain.
		poses.sculpt_pelvis += Vector3(windup * 0.05 - contact * 0.09, swing_direction * (windup * 0.18 - contact * 0.24), 0.0)
		poses.sculpt_spine += Vector3(windup * 0.14 - contact * 0.22, swing_direction * (windup * 0.38 - contact * 0.58 - follow * 0.14), 0.0)
		poses.sculpt_head += Vector3(-windup * 0.08 + contact * 0.12, -swing_direction * (windup * 0.18 - contact * 0.24), 0.0)
		body_offset += Vector3(swing_direction * (windup * 0.025 - contact * 0.040), -leg_length * (windup * 0.030 + contact * 0.060), leg_length * (windup * 0.070 - contact * 0.13))

		if punch:
			poses["sculpt_arm_" + main_side] = Vector3(0.24 + windup * 0.10 + contact * 0.78, swing_direction * (windup * 0.16 - contact * 0.14), 0.03 * side_sign)
			poses["sculpt_forearm_" + main_side] = Vector3(0.56 + windup * 0.38 - contact * 0.55, 0.0, 0.0)
			poses["sculpt_arm_" + other_side] = Vector3(0.24 + contact * 0.12, 0.0, -side_sign * 0.055)
			poses["sculpt_forearm_" + other_side] = Vector3(0.68, 0.0, 0.0)
		elif overhead:
			# Titanic overhead cleave: spine arches back 32 degrees, arms hoisted high overhead, catastrophic plunge.
			poses.sculpt_spine.x += windup * 0.22 - contact * 0.28
			poses.sculpt_pelvis.y *= 0.35
			for side in [main_side, other_side]:
				var main: float = 1.0 if side == main_side or dual or unarmed else 0.28
				poses["sculpt_arm_" + side] = Vector3(0.12 + windup * 1.55 * main + contact * 0.82 * main + follow * 0.28, 0.0, (0.12 if side == "l" else -0.12) * windup)
				poses["sculpt_forearm_" + side] = Vector3(0.22 + windup * 0.85 * main - contact * 0.20 * main, 0.0, 0.0)
			body_offset.y -= contact * leg_length * 0.075
		elif channel:
			# Majestic celestial/dark sorcery: arched spine, arms raised outward and upward in ominous invocation.
			poses.sculpt_spine.x -= 0.18 * contact
			poses.sculpt_spine.y *= 0.30
			poses.sculpt_pelvis.y *= 0.25
			for side in [main_side, other_side]:
				var main: float = 1.0 if side == main_side else 0.88
				poses["sculpt_arm_" + side] = Vector3(0.12 + windup * 0.28 + contact * 0.90 * main + follow * 0.14, 0.0, (1.0 if side == "l" else -1.0) * (windup * 0.10 + contact * 0.16))
				poses["sculpt_forearm_" + side] = Vector3(0.22 + windup * 0.48 + contact * 0.08, 0.0, 0.0)
		elif lunge:
			# Coiled crouch, then high-velocity fencer's spear/blade thrust.
			poses["sculpt_arm_" + main_side] = Vector3(0.16 + windup * 0.25 + contact * 1.15, swing_direction * windup * 0.26, 0.0)
			poses["sculpt_forearm_" + main_side] = Vector3(0.24 + windup * 0.92 - contact * 0.22, 0.0, 0.0)
			body_offset.z -= contact * leg_length * 0.085
			poses.sculpt_spine.x -= contact * 0.075
		else:
			# Sweeping cleave / horizontal reap: broad rotational arc.
			var breadth: float = 1.30 if scythe or held.kind == "staff" else 1.05
			poses["sculpt_arm_" + main_side] = Vector3(0.15 + windup * 0.48 + contact * 0.92 + follow * 0.20, swing_direction * (windup * 0.68 - contact * 0.95 - follow * 0.25) * breadth, side_sign * (windup * 0.24 - contact * 0.18))
			poses["sculpt_forearm_" + main_side] = Vector3(0.22 + windup * 0.68 - contact * 0.18, 0.0, 0.0)
			poses["sculpt_arm_" + other_side] = Vector3(0.12 + windup * 0.16 - contact * 0.16, swing_direction * contact * 0.10, -side_sign * contact * 0.06)
			poses["sculpt_forearm_" + other_side] = Vector3(0.28 + windup * 0.18 + contact * 0.14, 0.0, 0.0)
			if dual:
				poses["sculpt_arm_" + other_side] = Vector3(0.18 + windup * 0.60 + contact * 0.78, -swing_direction * (windup * 0.62 - contact * 0.82), -side_sign * (windup * 0.18 - contact * 0.16))
				poses["sculpt_forearm_" + other_side] = Vector3(0.22 + windup * 0.65 - contact * 0.15, 0.0, 0.0)

		if cue == "Fire_Combo":
			var second: float = smoothstep(0.52, 0.64, phase) * (1.0 - smoothstep(0.72, 0.95, phase))
			poses.sculpt_spine.y += swing_direction * second * 0.44
			poses["sculpt_arm_" + other_side].x += second * 0.60
			poses["sculpt_forearm_" + other_side].x -= second * 0.18
		if cue == "Wind_Cyclone":
			poses.sculpt_spine.y += swing_direction * (windup * 0.14 - contact * 0.16)
			poses["sculpt_arm_" + other_side].z -= side_sign * commitment * 0.26
		if cue == "Void_Reap":
			poses.sculpt_spine.y *= 1.35
			poses.sculpt_head.y *= 0.85
			poses.sculpt_spine.x += contact * 0.12
		if final_boss:
			var impact_snap: float = minf(contact * aggression, 1.35)
			match cue:
				"Black_Beam":
					poses.sculpt_spine.x -= windup * 0.10
					poses.sculpt_spine.y += swing_direction * (windup * 0.14 - impact_snap * 0.12)
					poses["sculpt_arm_" + main_side] = Vector3(0.14 + windup * 0.20 + impact_snap * 0.82 + follow * 0.14, swing_direction * 0.08, 0.0)
					poses["sculpt_forearm_" + main_side] = Vector3(0.26 + windup * 0.18 - impact_snap * 0.12, 0.0, 0.0)
					poses["sculpt_arm_" + other_side] = Vector3(0.18 + windup * 0.35 + impact_snap * 0.42, -swing_direction * 0.10, -side_sign * 0.08)
					poses["sculpt_forearm_" + other_side] = Vector3(0.30 + windup * 0.24, 0.0, 0.0)
				"Dark_Sphere":
					poses.sculpt_spine.x -= windup * 0.12
					for side in ["l", "r"]:
						poses["sculpt_arm_" + side] = Vector3(0.24 + windup * 0.44 + impact_snap * 0.34 + follow * 0.16, (1.0 if side == "l" else -1.0) * (0.16 + windup * 0.22), (1.0 if side == "l" else -1.0) * (0.10 + windup * 0.12))
						poses["sculpt_forearm_" + side] = Vector3(0.44 + windup * 0.28 - impact_snap * 0.16, 0.0, 0.0)
					body_offset += Vector3(0.0, windup * 0.06 - impact_snap * 0.035, -impact_snap * 0.045)
				"Storm_Lance":
					poses["sculpt_arm_" + main_side] = Vector3(0.16 + windup * 0.28 + impact_snap * 0.96 + follow * 0.12, swing_direction * (0.18 - impact_snap * 0.12), 0.0)
					poses["sculpt_forearm_" + main_side] = Vector3(0.28 + windup * 0.82 - impact_snap * 0.24, 0.0, 0.0)
					poses["sculpt_arm_" + other_side] = Vector3(0.28 + windup * 0.18, -swing_direction * 0.14, side_sign * 0.12)
					body_offset.z -= impact_snap * leg_length * 0.10
				"Ember_Burst":
					for side in ["l", "r"]:
						var spread: float = 1.0 if side == main_side else 0.86
						poses["sculpt_arm_" + side] = Vector3(0.18 + windup * 0.35 + impact_snap * 0.72 * spread + follow * 0.12, (1.0 if side == "l" else -1.0) * (windup * 0.16 + impact_snap * 0.08), (1.0 if side == "l" else -1.0) * windup * 0.13)
						poses["sculpt_forearm_" + side] = Vector3(0.28 + windup * 0.28 - impact_snap * 0.08, 0.0, 0.0)
				"Frost_Lattice":
					poses.sculpt_spine.y += swing_direction * (windup * 0.20 - impact_snap * 0.15)
					for side in ["l", "r"]:
						var side_value: float = 1.0 if side == "l" else -1.0
						poses["sculpt_arm_" + side] = Vector3(0.18 + windup * 0.30 + impact_snap * 0.64, side_value * (windup * 0.20 - impact_snap * 0.14), -side_value * (windup * 0.16 + impact_snap * 0.10))
						poses["sculpt_forearm_" + side] = Vector3(0.30 + windup * 0.28, 0.0, 0.0)
				"Gale_Shear":
					poses.sculpt_spine.y += swing_direction * (windup * 0.24 - impact_snap * 0.74 - follow * 0.18)
					for side in ["l", "r"]:
						var side_value: float = 1.0 if side == "l" else -1.0
						poses["sculpt_arm_" + side] = Vector3(0.14 + windup * 0.56 + impact_snap * 0.72, side_value * (windup * 0.34 - impact_snap * 0.40), side_value * (windup * 0.20 - impact_snap * 0.12))
						poses["sculpt_forearm_" + side] = Vector3(0.24 + windup * 0.42 - impact_snap * 0.12, 0.0, 0.0)
				"Eclipse_Wave", "Apocalypse":
					poses.sculpt_spine.x += windup * 0.18 - impact_snap * 0.18
					for side in ["l", "r"]:
						poses["sculpt_arm_" + side] = Vector3(0.14 + windup * 1.05 + impact_snap * 0.52 + follow * 0.18, 0.0, (1.0 if side == "l" else -1.0) * windup * 0.10)
						poses["sculpt_forearm_" + side] = Vector3(0.22 + windup * 0.58 - impact_snap * 0.16, 0.0, 0.0)
					body_offset.y += windup * 0.04 - impact_snap * 0.08
		for side in ["l", "r"]:
			poses["sculpt_wing_" + side].y += (1.0 if side == "l" else -1.0) * (windup * 0.25 - follow * 0.16)
			poses["sculpt_hem_" + side].x += contact * 0.09 + follow * 0.06

	if cue == "Hit_Chest":
		# High-impact visceral flinch: head snaps back, torso reels away from impact.
		var flinch: float = smoothstep(0.0, 0.12, phase) * (1.0 - smoothstep(0.22, 1.0, phase))
		poses.sculpt_spine = Vector3(0.28, -0.15, 0.06) * flinch
		poses.sculpt_head = Vector3(0.20, 0.10, -0.03) * flinch
		body_offset.z += flinch * 0.055
		body_offset.y -= flinch * 0.045
		for side in ["l", "r"]:
			var sign_val: float = 1.0 if side == "l" else -1.0
			poses["sculpt_arm_" + side] = Vector3(0.20 + flinch * 0.28, 0.0, sign_val * flinch * 0.18)

	v.motion.position = Vector3.ZERO
	v.motion.rotation = Vector3.ZERO
	v.model.position = v._model_origin
	v.model.rotation = v._model_rotation
	if spectral and not v._dead:
		v.model.position.y += (0.09 + sin(v.age * 1.7) * 0.035 + sin(v.age * 3.4) * 0.012 + windup * 0.08 + contact * 0.035) * scale_factor
		body_offset.y = 0.0
		poses.sculpt_pelvis.z = sin(v.age * 1.5) * 0.018
		poses.sculpt_spine.x -= moving * 0.08
		for side in ["l", "r"]: poses["sculpt_hem_" + side].x += moving * 0.16
	if v._dead:
		_death(v, rig, state, phase, poses, scale_factor)
		return

	if not spectral:
		for side in ["l", "r"]:
			var hip: Vector3 = rig.get_bone_global_rest(state.bones["sculpt_thigh_" + side]).origin
			var reach: Vector3 = feet[side] - hip - body_offset
			var length: float = state.lengths[side]
			var horizontal: float = Vector2(reach.x, reach.z).length_squared()
			var available: float = sqrt(maxf(length * length * 0.98 - horizontal, 0.001))
			body_offset.y = minf(body_offset.y, feet[side].y + available - hip.y)
	var pelvis: int = state.bones.sculpt_pelvis
	rig.set_bone_pose_position(pelvis, rig.get_bone_rest(pelvis).origin + body_offset)
	for name in poses:
		var bone: int = state.bones.get(name, -1)
		if bone >= 0:
			var rate: float = 30.0 if acting else 18.0
			if "hem" in name or "wing" in name: rate = 9.0
			rig.set_bone_pose_rotation(bone, rig.get_bone_pose_rotation(bone).slerp(Quaternion.from_euler(poses[name]), 1.0 - exp(-rate * delta)))
	for side in ["l", "r"]:
		if not spectral: _plant_leg(rig, state, side, feet[side], foot_pitch[side])

static func _state(rig: Skeleton3D) -> Dictionary:
	if rig.has_meta("sculpt_live_motion"): return rig.get_meta("sculpt_live_motion")
	var result: Dictionary = {"speed": 0.0, "phase": 0.0, "direction": Vector3.FORWARD, "turn": 0.0, "bones": {}, "lengths": {}, "leg_length": 1.0}
	for index in rig.get_bone_count(): result.bones[rig.get_bone_name(index)] = index
	for side in ["l", "r"]:
		var a: float = rig.get_bone_rest(result.bones["sculpt_shin_" + side]).origin.length()
		var b: float = rig.get_bone_rest(result.bones["sculpt_foot_" + side]).origin.length()
		result.lengths[side] = a + b
	result.leg_length = minf(result.lengths.l, result.lengths.r)
	rig.set_meta("sculpt_live_motion", result)
	return result

static func _plant_leg(rig: Skeleton3D, state: Dictionary, side: String, target: Vector3, foot_pitch: float) -> void:
	var thigh: int = state.bones["sculpt_thigh_" + side]
	var shin: int = state.bones["sculpt_shin_" + side]
	var foot: int = state.bones["sculpt_foot_" + side]
	var pelvis: int = rig.get_bone_parent(thigh)
	var hip_transform: Transform3D = rig.get_bone_global_pose(pelvis) * rig.get_bone_rest(thigh)
	var origin: Vector3 = hip_transform.origin
	var upper: Vector3 = rig.get_bone_rest(shin).origin
	var lower: Vector3 = rig.get_bone_rest(foot).origin
	var a: float = upper.length()
	var b: float = lower.length()
	var offset: Vector3 = target - origin
	var distance: float = clampf(offset.length(), absf(a - b) + 0.001, a + b - 0.0001)
	var direction: Vector3 = offset.normalized()
	var knee_direction: Vector3 = (Vector3.FORWARD - direction * Vector3.FORWARD.dot(direction)).normalized()
	var along: float = (a * a + distance * distance - b * b) / (2.0 * distance)
	var bend: float = sqrt(maxf(a * a - along * along, 0.0))
	var knee: Vector3 = origin + direction * along + knee_direction * bend
	var thigh_rotation := Quaternion(upper.normalized(), (knee - origin).normalized())
	var shin_rotation := Quaternion(lower.normalized(), (origin + direction * distance - knee).normalized())
	var parent_rotation: Quaternion = rig.get_bone_global_pose(pelvis).basis.get_rotation_quaternion()
	rig.set_bone_pose_rotation(thigh, parent_rotation.inverse() * thigh_rotation)
	rig.set_bone_pose_rotation(shin, thigh_rotation.inverse() * shin_rotation)
	rig.set_bone_pose_rotation(foot, shin_rotation.inverse() * Quaternion(Vector3.RIGHT, foot_pitch))

static func _curve(phase: float, values: Array) -> float:
	for i in range(PHASES.size() - 1):
		if phase <= PHASES[i + 1]:
			return lerpf(values[i], values[i + 1], smoothstep(PHASES[i], PHASES[i + 1], phase))
	return values[-1]

static func _death(v: Node3D, rig: Skeleton3D, state: Dictionary, phase: float, poses: Dictionary, scale_factor: float) -> void:
	var buckle: float = smoothstep(0.0, 0.32, phase)
	var fall: float = smoothstep(0.24, 0.82, phase)
	v.motion.rotation = Vector3(1.38 * fall, 0.10 * fall, 0.12 * fall)
	v.motion.position.y = (0.18 * fall - 0.06 * buckle * (1.0 - fall)) * scale_factor
	poses.sculpt_pelvis = Vector3(-0.12 * buckle, 0.09 * fall, 0.0)
	poses.sculpt_spine = Vector3(-0.24 * buckle, 0.09 * fall, 0.10 * fall)
	poses.sculpt_head = Vector3(-0.20 * buckle, 0.15 * fall, 0.0)
	for side in ["l", "r"]:
		var sign_value: float = 1.0 if side == "l" else -1.0
		poses["sculpt_arm_" + side] = Vector3(0.12 + buckle * 0.30, 0.0, sign_value * fall * 0.18)
		poses["sculpt_forearm_" + side] = Vector3(0.22 + buckle * 0.28, 0.0, 0.0)
		poses["sculpt_thigh_" + side] = Vector3(0.38 * buckle * (1.0 - fall * 0.65), 0.0, sign_value * fall * 0.09)
		poses["sculpt_shin_" + side] = Vector3(-0.76 * buckle * (1.0 - fall * 0.5), 0.0, 0.0)
		poses["sculpt_foot_" + side] = Vector3(0.18 * buckle, 0.0, 0.0)
	rig.set_bone_pose_position(state.bones.sculpt_pelvis, rig.get_bone_rest(state.bones.sculpt_pelvis).origin)
	for name in poses:
		var bone: int = state.bones.get(name, -1)
		if bone >= 0: rig.set_bone_pose_rotation(bone, Quaternion.from_euler(poses[name]))
