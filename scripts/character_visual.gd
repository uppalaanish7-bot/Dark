extends "res://scripts/provided_visual.gd"
## User-selected Girl Knight / Omega Knight, both wielding the Da Vinci sword.
const SKINS := ["Girl Knight", "Omega Knight"]
const COLORS := [Color("ff9854"), Color("6ecdfa")]
var _palm_offset := Vector3.ZERO
var _landing_settle: float = 0.0
var _landing_duration: float = 0.24
var _last_velocity := Vector3.ZERO
var _acceleration_lean := Vector2.ZERO
var _pre_land_velocity_y: float = 0.0
var _player_feet: Array[Dictionary] = []
var _plant_targets: Dictionary = {}
var _cast_target := Vector3.INF
var _recent_moving_speed: float = 0.0
var _was_moving: bool = false

func set_cast_target(world_point: Vector3) -> void:
	_cast_target = world_point

func set_asset(id: String, height: float = 2.1) -> void:
	super.set_asset(id,height)
	_player_feet.clear()
	_plant_targets.clear()
	_last_velocity = Vector3.ZERO
	_acceleration_lean = Vector2.ZERO
	_landing_settle = 0.0
	_pre_land_velocity_y = 0.0
	_cast_target = Vector3.INF
	_recent_moving_speed = 0.0
	_was_moving = false
	if skeleton == null: return
	for side in ["l","r"]:
		var foot := -1
		var shin := -1
		var thigh := -1
		var toe := -1
		for index in skeleton.get_bone_count():
			var name := skeleton.get_bone_name(index).to_lower()
			if "twist" in name or "corrective" in name or "deform" in name: continue
			if not ("_"+side in name or "."+side in name): continue
			if name.begins_with("foot"): foot=index
			elif name.begins_with("calf"): shin=index
			elif name.begins_with("thigh"): thigh=index
			elif name.begins_with("ball") or name.begins_with("toe"): toe=index
		if foot >= 0 and shin >= 0 and thigh >= 0:
			var rest := to_local(skeleton.to_global(skeleton.get_bone_global_rest(foot).origin))
			_player_feet.append({"foot":foot,"shin":shin,"thigh":thigh,"toe":toe,"height":rest.y})

func action(clip: String, duration: float = -1.0) -> void:
	# Gameplay's short dash remains responsive; the visual has a few extra
	# frames to uncoil and regain its footing instead of snapping upright.
	if clip == "Roll" and duration > 0: duration=maxf(duration,0.44)
	if clip == "Jump_Land":
		# Scale landing settle based on downward impact speed
		var impact_scale: float = clampf(absf(_pre_land_velocity_y) / 14.0, 0.4, 1.25)
		duration=maxf(0.24, maxf(duration, 0.24) * impact_scale)
		_landing_settle=duration
		_landing_duration=duration
	super.action(clip,duration)

func _tick_authored(delta: float, speed: float, grounded: bool, casting: bool, crouching: bool) -> void:
	if speed > 0.35:
		_recent_moving_speed = maxf(speed, _recent_moving_speed-delta*6.0)
		if current_clip in ["Run_Stop","Sprint_Stop"]: one_shot_time=0.0
	elif _was_moving and grounded and not crouching and one_shot_time <= 0.0 and _recent_moving_speed > 4.0:
		var stop_clip := "Sprint_Stop" if _recent_moving_speed > 11.5 else "Run_Stop"
		if animator.has_animation(stop_clip): action(stop_clip)
		_recent_moving_speed=0.0
	_was_moving = speed > 0.35
	super._tick_authored(delta,speed,grounded,casting,crouching)
	if _dead or skeleton == null: return
	# Track vertical velocity for landing impact scaling
	_pre_land_velocity_y = _vertical_speed if not grounded else _pre_land_velocity_y
	var acceleration := (_motion_velocity-_last_velocity)/maxf(delta,0.001)
	_last_velocity = _motion_velocity
	var target := Vector2(clampf(-acceleration.z*0.0012,-0.065,0.065),clampf(-acceleration.x*0.0011,-0.055,0.055))
	if not grounded or _dodging: target=Vector2.ZERO
	_acceleration_lean = _acceleration_lean.lerp(target,1.0-exp(-12.0*delta))
	# Dynamic centripetal banking into turns (lean into corners like athletic runners).
	var sprint_bank: float = 1.0 + clampf((speed - 11.5) / 3.0, 0.0, 0.5)
	var bank: float = clampf(_turn_rate * -0.010 * sprint_bank, -0.09, 0.09) * clampf(speed / 5.0, 0.0, 1.0)
	model.rotation.x += _acceleration_lean.x
	model.rotation.z += bank + _acceleration_lean.y
	_landing_settle = maxf(0.0, _landing_settle - delta)
	if _landing_settle > 0.0:
		motion.position.y -= sin((_landing_settle / _landing_duration) * PI) * 0.025
	if speed < 0.2 and grounded and one_shot_time <= 0:
		var breath := sin(age * 2.2) * 0.008
		motion.position.y += breath * 0.5
		model.rotation.z += sin(age * 1.1) * 0.006
	if grounded and current_clip not in ["Roll","Jump_Start","Double_Jump"]:
		# The generic retargeter follows the lowest ankle. Resolve the last
		# few centimetres after leaning, then settle both feet for planted cuts
		# and guard. This prevents a raised boot or float on attack recovery.
		var lowest := INF
		for leg in _player_feet:
			var point := to_local(skeleton.to_global(skeleton.get_bone_global_pose(leg.foot).origin))
			lowest=minf(lowest,point.y-float(leg.height))
		if is_finite(lowest): motion.position.y-=clampf(lowest,-0.12,0.12)
		if speed < 0.4:
			for leg in _player_feet: _settle_foot(leg)
		else:
			_plant_targets.clear()
	else:
		_plant_targets.clear()
	update_weapon()
	if current_clip == "Fire_Cast" and one_shot_time > 0 and _cast_target.is_finite():
		_aim_cast_blade()
		update_weapon()

func _aim_cast_blade() -> void:
	if hand < 0: return
	var desired := (_cast_target - weapon.global_position).normalized()
	if desired.length_squared() < 0.1: return
	var phase := 1.0 - one_shot_time / maxf(_action_duration, 0.01)
	var strength := smoothstep(0.0, 0.285, phase) * (1.0 - smoothstep(0.64, 1.0, phase))
	var turn := Quaternion.IDENTITY.slerp(Quaternion(weapon.global_basis.y.normalized(), desired), strength)
	var pose := skeleton.get_bone_global_pose(hand)
	var aimed := skeleton.global_basis.inverse() * Basis(turn) * skeleton.global_basis * pose.basis.orthonormalized()
	var parent := skeleton.get_bone_parent(hand)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	skeleton.set_bone_pose_rotation(hand, (parent_basis.inverse() * aimed).orthonormalized().get_rotation_quaternion())

func _rotate_joint_to(bone: int, child: int, target: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var actual := skeleton.get_bone_global_pose(child).origin-pose.origin
	var desired := target-pose.origin
	if actual.length_squared()<0.000001 or desired.length_squared()<0.000001: return
	var correction := Basis(Quaternion(actual.normalized(),desired.normalized()))
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent>=0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(bone,(parent_basis.inverse()*correction*pose.basis.orthonormalized()).get_rotation_quaternion())

func _settle_foot(leg: Dictionary) -> void:
	var hip := skeleton.get_bone_global_pose(leg.thigh).origin
	var knee := skeleton.get_bone_global_pose(leg.shin).origin
	var ankle := skeleton.get_bone_global_pose(leg.foot).origin
	var target_local := to_local(skeleton.to_global(ankle))
	# Limit IK to a small retarget correction. Deep crouches and rolls must
	# retain their authored silhouettes instead of stretching the legs.
	if absf(target_local.y-float(leg.height))>0.18: return
	if not _plant_targets.has(leg.foot): _plant_targets[leg.foot]=target_local
	var planted: Vector3 = _plant_targets[leg.foot]
	if Vector2(planted.x-target_local.x,planted.z-target_local.z).length()<0.36:
		target_local.x=planted.x
		target_local.z=planted.z
	else:
		_plant_targets[leg.foot]=target_local
	target_local.y=leg.height
	var target := skeleton.to_local(to_global(target_local))
	var upper := hip.distance_to(knee)
	var lower := knee.distance_to(ankle)
	var reach := clampf(hip.distance_to(target),absf(upper-lower)+0.0001,upper+lower-0.0001)
	var direction := (target-hip).normalized()
	var pole := knee-hip-direction*(knee-hip).dot(direction)
	if pole.length_squared()<0.0001:
		# A relaxed, almost straight leg still needs a stable knee direction.
		# Returning here left the boot tilted on the standing pose.
		pole = skeleton.global_basis.inverse() * -global_basis.z
		pole -= direction * pole.dot(direction)
	if pole.length_squared()<0.000001: return
	pole= pole.normalized()
	var along := (upper*upper+reach*reach-lower*lower)/(2.0*reach)
	var knee_target := hip+direction*along+pole*sqrt(maxf(upper*upper-along*along,0.0))
	# Both source rigs have different heel lengths. Returning the sole to
	# its calibrated rest plane plants the boot, not just the ankle joint.
	var foot_basis := skeleton.get_bone_global_rest(leg.foot).basis.orthonormalized()
	_rotate_joint_to(leg.thigh,leg.shin,knee_target)
	_rotate_joint_to(leg.shin,leg.foot,target)
	var parent := skeleton.get_bone_parent(leg.foot)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	skeleton.set_bone_pose_rotation(leg.foot,(parent_basis.inverse()*foot_basis).get_rotation_quaternion())
	# Omega has a separately skinned forefoot. After the ankle is planted,
	# its retargeted toe roll must settle too or the boot bends into the floor.
	if leg.toe >= 0:
		skeleton.set_bone_pose_rotation(leg.toe,skeleton.get_bone_rest(leg.toe).basis.get_rotation_quaternion())

func equip_sword() -> void:
	super.equip_sword()
	_calibrate_grip()
	update_weapon()

func _find_right_bone(prefix: String) -> int:
	if skeleton == null: return -1
	for index in skeleton.get_bone_count():
		var key := skeleton.get_bone_name(index).to_lower()
		if key.begins_with(prefix) and ("_r" in key or ".r" in key): return index
	return -1

func _calibrate_grip() -> void:
	_palm_offset = Vector3.ZERO
	if skeleton == null or hand < 0: return
	# Derive the hilt from the palm's anatomy, independent of the currently
	# playing pose. The blade points out through the thumb side of the fist.
	var rest := skeleton.get_bone_global_rest(hand)
	var index := _find_right_bone("index_01")
	var pinky := _find_right_bone("pinky_01")
	var middle := _find_right_bone("middle_01")
	var blade := Vector3.BACK
	var fingers := rest.basis.y.normalized()
	var palm := rest.origin + fingers * 0.065
	if index >= 0 and pinky >= 0 and middle >= 0:
		blade = (skeleton.get_bone_global_rest(index).origin - skeleton.get_bone_global_rest(pinky).origin).normalized()
		fingers = (skeleton.get_bone_global_rest(middle).origin - rest.origin).normalized()
		palm = rest.origin.lerp(skeleton.get_bone_global_rest(middle).origin, 0.68)
	# The generated Girl Knight has a single rigid glove bone. Its palm faces
	# inward and the thumb is on the front of the original +Z-facing model.
	blade = (blade - fingers * blade.dot(fingers)).normalized()
	var edge := -fingers
	var face := edge.cross(blade).normalized()
	edge = blade.cross(face).normalized()
	sword_mount = rest.basis.orthonormalized().inverse() * Basis(edge, blade, face)
	# The sword origin sits near its guard; put the centre of its grip in
	# the palm, rather than fastening the guard directly to the wrist joint.
	_palm_offset = rest.basis.inverse() * (palm - rest.origin)

func update_weapon() -> void:
	super.update_weapon()
	if not is_instance_valid(weapon) or skeleton == null or hand < 0: return
	var pose := skeleton.get_bone_global_pose(hand)
	weapon.global_position = skeleton.to_global(pose * _palm_offset) + weapon.global_basis.y * 0.085

func _init() -> void:
	asset_id = "female"
	target_height = 1.82
	is_player = true
	weapon_enabled = true
	sword_equipped = true

func set_skin(index: int) -> void:
	skin_index = posmod(index, SKINS.size())
	set_asset("female" if skin_index == 0 else "omega", 1.82)
