extends Node3D
## Supplied character meshes with retargeted skeletal motion and deliberately
## authored elemental motion for static spectral sculptures.
const ART = preload("res://scripts/visuals.gd")
const CATALOG = preload("res://scripts/asset_catalog.gd")
const SCULPT_LOCOMOTION = preload("res://scripts/sculpt_locomotion.gd")
const ENEMY_LOADOUT = preload("res://scripts/enemy_loadout.gd")
var asset_id: String = "soldier_1"
var target_height: float = 2.1
var skin_index: int = 0
var weapon_enabled: bool = false
var sword_equipped: bool = false
var model: Node3D
var motion: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var weapon: Node3D
var muzzle: Marker3D
var current_clip: String = ""
var one_shot_time: float = 0.0
var recoil: float = 0.0
var hand: int = -1
var age: float = 0.0
var stride: float = 0.0
var is_player: bool = false
var source_available: bool = true
var resting_bones: Dictionary = {}
var bone_slots: Dictionary = {}
var sword_mount := Basis.IDENTITY
var _action_duration: float = 0.0
var _dead: bool = false
var _model_origin := Vector3.ZERO
var _model_rotation := Vector3.ZERO
var _source_animator: AnimationPlayer
var _source_clip: String = ""
static var runtime_materials: Dictionary = {}
var _authored_motion: bool = false
var _motion_velocity := Vector3.ZERO
var _vertical_speed: float = 0.0
var _turn_rate: float = 0.0
var _dodging: bool = false
var _locomotion_clock: float = 0.0
var _cloth_angle: float = 0.0
var _cloth_segments: Dictionary = {}
var _ground_offset: float = 0.0
var _upper_body: Array[int] = []
var _foot_bones: Array[int] = []
var _locomotion_blend_tracks: Dictionary = {}
var _cloth_bones: Array[int] = []
var _wing_bones: Array[int] = []
var _sculpt_motion: bool = false
var _enemy_loadout: Dictionary = {}
var combat_phase: int = 1

func set_motion_state(local_velocity: Vector3, _grounded: bool, vertical_speed: float, turn_rate: float, dodging: bool, _casting: bool) -> void:
	_motion_velocity = local_velocity
	_vertical_speed = vertical_speed
	_turn_rate = turn_rate
	_dodging = dodging

func _ready() -> void:
	set_asset(asset_id, target_height)

func set_asset(id: String, height: float = 2.1) -> void:
	asset_id = id
	target_height = height
	is_player = id in ["female", "omega"]
	_enemy_loadout = {}
	for child in get_children():
		remove_child(child)
		child.queue_free()
	motion = Node3D.new()
	motion.name = "Motion"
	add_child(motion)
	model = CATALOG.instantiate(id)
	source_available = model != null
	if model == null: model = _make_missing_visual()
	model.name = "SourceModel"
	motion.add_child(model)
	model.scale = Vector3.ONE * target_height / (1.82 if is_player else 2.1)
	# Controllers face local -Z; the reaper source faces +X.
	model.rotation.y = PI/2 if id in ["main_boss", "subboss_2", "subboss_6", "subboss_7", "subboss_8"] else PI
	_prepare_materials()
	_model_origin = model.position
	_model_rotation = model.rotation
	skeleton = null
	hand = -1
	bone_slots.clear()
	resting_bones.clear()
	_cloth_segments.clear()
	_cloth_angle = 0.0
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if not rigs.is_empty():
		skeleton = rigs[0] as Skeleton3D
		for rig in rigs:
			if rig.get_bone_count() > skeleton.get_bone_count(): skeleton = rig
		_cache_rig()
	_sculpt_motion = skeleton != null and skeleton.has_meta("sculpt_motion")
	_source_animator = null
	_source_clip = ""
	for source_animator in model.find_children("*", "AnimationPlayer", true, false):
		source_animator.stop()
		source_animator.active = false
		if asset_id == "soldier_1":
			for clip in source_animator.get_animation_list():
				if "tposeidlewalk" in clip.to_lower():
					_source_animator = source_animator
					_source_clip = clip
					source_animator.active = true
					source_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
					source_animator.play(clip)
	animator = AnimationPlayer.new()
	animator.name = "CombatAnimator"
	add_child(animator)
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_build_motion_library()
	_cache_locomotion_blend_tracks()
	weapon = Node3D.new()
	weapon.name = "AbilityHand"
	add_child(weapon)
	muzzle = Marker3D.new()
	muzzle.name = "MagicOrigin"
	weapon.add_child(muzzle)
	if _authored_motion:
		animator.play("Sword_Idle_Loop")
		animator.advance(0.15)
	if is_player or sword_equipped: equip_sword()
	current_clip = ""
	one_shot_time = 0
	_dead = false
	play("Idle_Loop")
	animator.advance(0)
	_enemy_loadout = ENEMY_LOADOUT.install(self)
	update_weapon()

func set_skin(index: int) -> void:
	skin_index = index
	set_asset("female" if is_player else "soldier_" + str(posmod(index, 9) + 1), target_height)

func _cache_rig() -> void:
	_upper_body.clear()
	_foot_bones.clear()
	_cloth_bones.clear()
	_wing_bones.clear()
	for i in skeleton.get_bone_count():
		var key: String = skeleton.get_bone_name(i).to_lower()
		resting_bones[i] = skeleton.get_bone_pose_rotation(i)
		if key.begins_with("foot"): _foot_bones.append(i)
		if key in ["wing_l", "wing_r"]: _wing_bones.append(i)
		if "cape" in key or "skirtback" in key: _cloth_bones.append(i)
		var side := "l" if ".l" in key or "_l" in key or key.begins_with("l_") else "r"
		if "twist" in key or "deform" in key or "pad" in key or "collision" in key: continue
		if "hand.r" in key or "r_hand" in key or "hand_r" in key or "righthand" in key: hand = i
		if "thigh" in key or ("leg" in key and "knee" not in key and "stretch" not in key): bone_slots["thigh_" + side] = i
		elif "leg_stretch" in key or "knee" in key or "shin" in key or "calf" in key: bone_slots["shin_" + side] = i
		elif ("arm_stretch" in key and "fore" not in key) or "upperarm" in key or "upper_arm" in key: bone_slots["arm_" + side] = i
		elif "forearm" in key or "lowerarm" in key: bone_slots["forearm_" + side] = i
		elif "spine_01" in key: bone_slots["spine"] = i
		elif "head" in key and "end" not in key: bone_slots["head"] = i
		if "arm" in key or "hand" in key or "clavicle" in key: _upper_body.append(i)
	if is_player:
		_relax_player_arms()

func _relax_player_arms() -> void:
	# Convert each source A-pose into a relaxed sword-ready shoulder pose using
	# its actual rest axes, so both independently authored rigs behave correctly.
	for side in ["l", "r"]:
		var slot: String = "arm_" + side
		if not bone_slots.has(slot): continue
		var bone: int = bone_slots[slot]
		var rest := skeleton.get_bone_global_rest(bone)
		var world_basis := (skeleton.global_basis * rest.basis).orthonormalized()
		var shoulder := to_local(skeleton.to_global(rest.origin))
		var outward: float = 1.0 if shoulder.x > 0 else -1.0
		var target := Vector3(outward * (0.42 if side == "r" else 0.23), -0.91, -0.12).normalized()
		var bone_direction := world_basis.y.normalized()
		if bone_slots.has("forearm_" + side):
			var elbow: Transform3D = skeleton.get_bone_global_rest(bone_slots["forearm_" + side])
			bone_direction = (skeleton.global_basis * (elbow.origin - rest.origin)).normalized()
		var turn := Quaternion(bone_direction, (global_basis * target).normalized())
		var parent: int = skeleton.get_bone_parent(bone)
		var parent_basis := skeleton.global_basis
		if parent >= 0: parent_basis *= skeleton.get_bone_global_rest(parent).basis
		resting_bones[bone] = (parent_basis.orthonormalized().inverse() * Basis(turn) * world_basis).get_rotation_quaternion()

func _prepare_materials() -> void:
	for instance in model.find_children("*", "MeshInstance3D", true, false):
		for surface in instance.mesh.get_surface_count():
			var original: Material = instance.mesh.surface_get_material(surface)
			if not original is StandardMaterial3D: continue
			var key: String = asset_id + ":" + str(original.get_instance_id())
			if not runtime_materials.has(key):
				var mat := original.duplicate() as StandardMaterial3D
				# Dark authored metallic sculpts need diffuse response in a sunless
				# hall. Keep their albedo/roughness maps and prevent glittering from
				# source normal maps that use a second, unsupported UV channel.
				if not is_player:
					mat.metallic = minf(mat.metallic, 0.35)
					mat.roughness = maxf(mat.roughness, 0.72)
					mat.normal_enabled = false
					mat.rim_enabled = true
					mat.rim = 0.28
					mat.rim_tint = 0.45
					mat.emission_enabled = true
					mat.emission = Color(0.35, 0.35, 0.35)
					mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
					mat.emission_texture = mat.albedo_texture
					mat.emission_energy_multiplier = 1.0
					mat.albedo_color = Color(1.25, 1.25, 1.25, 1.0)
				runtime_materials[key] = mat
			instance.set_surface_override_material(surface, runtime_materials[key])

func _build_motion_library() -> void:
	_authored_motion = false
	var path := "res://assets/motion/" + asset_id + "_combat.res"
	if ResourceLoader.exists(path):
		animator.add_animation_library("", load(path))
		_authored_motion = true
		return
	var library := AnimationLibrary.new()
	for clip in ["Idle_Loop", "Sword_Idle_Loop", "Pistol_Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Jump_Loop", "Jump_Fall", "Crouch_Fwd_Loop", "Crouch_Idle_Loop", "Dance_Loop"]:
		var animation := Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(clip, animation)
	for clip in ["Sword_Attack", "Sword_Attack02", "Sword_Attack03", "Punch_Jab", "Fire_Cast", "Cast", "Channel_Loop", "Cast_Release", "Roll", "Hit_Chest", "Death01", "Jump_Start", "Jump_Land", "Double_Jump"]:
		var animation := Animation.new()
		animation.length = 0.65 if clip != "Death01" else 1.25
		if clip == "Death01":
			_add_keys(animation, "Motion:rotation", [Vector3.ZERO, Vector3(0.3, 0, 0.3), Vector3(1.5, 0, 0.12)], [0.0, 0.3, 1.25])
			_add_keys(animation, "Motion:position", [Vector3.ZERO, Vector3(0, 0.05, 0), Vector3(0, 0.18, 0.7)], [0.0, 0.3, 1.25])
		elif clip == "Roll":
			_add_keys(animation, "Motion:rotation", [Vector3.ZERO, Vector3(-PI, 0, 0), Vector3(-TAU, 0, 0)], [0.0, 0.3, 0.65])
			_add_keys(animation, "Motion:position", [Vector3.ZERO, Vector3(0, target_height, 0), Vector3.ZERO], [0.0, 0.3, 0.65])
		elif clip == "Hit_Chest":
			_add_keys(animation, "Motion:rotation", [Vector3.ZERO, Vector3(-0.18, 0, 0.1), Vector3.ZERO], [0.0, 0.09, 0.65])
		else:
			var swing: float = 0.65 if "Sword" in clip or "Punch" in clip else 0.18
			if clip == "Sword_Attack02": swing = -0.9
			if clip == "Sword_Attack03": swing = 0.28
			_add_keys(animation, "Motion:rotation", [Vector3.ZERO, Vector3(-0.08, -swing, 0.09), Vector3(0.18, swing, -0.06), Vector3.ZERO], [0.0, 0.19, 0.32, 0.65])
			_add_keys(animation, "Motion:position", [Vector3.ZERO, Vector3(0, 0.04, 0.10), Vector3(0, 0, -0.20), Vector3.ZERO], [0.0, 0.19, 0.32, 0.65])
		library.add_animation(clip, animation)
	_build_elemental_motion(library)
	animator.add_animation_library("", library)

func _build_elemental_motion(library: AnimationLibrary) -> void:
	# These are cinematic motions of the original complete sculpt, not deformation
	# rigs. Contact at 42% matches the enemy's delayed damage/VFX cue. A readable
	# hold, quick release, follow-through and slow recovery distinguish each court.
	var poses := {
		"Stone_Slam": [Vector3(-0.14,-0.16,0),Vector3(-0.20,-0.22,0),Vector3(0.18,0.12,0),Vector3(0.08,0.10,0),Vector3.ZERO],
		"Water_Sweep": [Vector3(0,-0.55,-0.10),Vector3(0,-0.62,-0.12),Vector3(0,0.90,0.10),Vector3(0,0.58,0.06),Vector3.ZERO],
		"Fire_Combo": [Vector3(-0.08,-0.5,0.04),Vector3(-0.1,-0.6,0.06),Vector3(0.1,0.72,-0.06),Vector3(0.08,-0.72,0.05),Vector3.ZERO],
		"Soul_Channel": [Vector3(-0.05,-0.1,-0.025),Vector3(-0.08,0,0),Vector3(0.08,0.16,0),Vector3(-0.04,0.1,0),Vector3.ZERO],
		"Lightning_Lunge": [Vector3(-0.16,-0.2,0.08),Vector3(-0.2,-0.2,0.10),Vector3(0.22,0.1,-0.08),Vector3(0.07,0.08,-0.03),Vector3.ZERO],
		"Wind_Cyclone": [Vector3(0,-0.6,-0.06),Vector3(0,-0.7,-0.08),Vector3(0,PI,0.06),Vector3(0,TAU,0),Vector3(0,TAU,0)],
		"Poison_Cast": [Vector3(0.10,-0.28,0.06),Vector3(0.13,-0.3,0.07),Vector3(-0.10,0.30,-0.05),Vector3(-0.04,0.15,0),Vector3.ZERO],
		"Ice_Cleave": [Vector3(-0.17,-0.12,-0.06),Vector3(-0.23,-0.15,-0.05),Vector3(0.24,0.16,0.08),Vector3(0.10,0.1,0.03),Vector3.ZERO],
		"Gravity_Pulse": [Vector3(-0.06,-0.22,0),Vector3(-0.10,-0.25,0),Vector3(0.04,0.16,0),Vector3(-0.03,0.12,0),Vector3.ZERO],
		"Lava_Crash": [Vector3(-0.12,-0.12,0),Vector3(-0.20,-0.15,0),Vector3(0.18,0.10,0),Vector3(0.10,0.06,0),Vector3.ZERO],
		"Void_Reap": [Vector3(-0.06,-0.70,-0.06),Vector3(-0.12,-0.86,-0.10),Vector3(0.16,1.12,0.08),Vector3(0.08,0.78,0.06),Vector3.ZERO]
	}
	poses.merge({
		"Eclipse_Wave": [Vector3(-0.18,-0.38,0.05),Vector3(-0.28,-0.46,0.06),Vector3(0.32,0.48,-0.08),Vector3(0.12,0.24,-0.02),Vector3.ZERO],
		"Apocalypse": [Vector3(-0.10,-0.20,0.04),Vector3(-0.16,-0.25,0.05),Vector3(0.22,0.28,-0.04),Vector3(0.08,0.16,0.0),Vector3.ZERO],
		"Black_Beam": [Vector3(-0.06,-0.12,0.0),Vector3(-0.12,-0.22,0.02),Vector3(0.18,0.16,-0.02),Vector3(0.08,0.08,0.0),Vector3.ZERO],
		"Dark_Sphere": [Vector3(-0.08,-0.18,-0.04),Vector3(-0.14,-0.25,-0.06),Vector3(0.20,0.20,0.04),Vector3(0.10,0.12,0.02),Vector3.ZERO],
		"Storm_Lance": [Vector3(-0.16,-0.32,0.04),Vector3(-0.22,-0.40,0.06),Vector3(0.23,0.12,-0.03),Vector3(0.08,0.04,0.0),Vector3.ZERO],
		"Ember_Burst": [Vector3(-0.10,-0.30,0.0),Vector3(-0.14,-0.36,0.02),Vector3(0.19,0.28,-0.02),Vector3(0.08,0.12,0.0),Vector3.ZERO],
		"Frost_Lattice": [Vector3(-0.12,-0.28,0.02),Vector3(-0.18,-0.34,0.04),Vector3(0.20,0.24,-0.04),Vector3(0.08,0.10,0.0),Vector3.ZERO],
		"Gale_Shear": [Vector3(-0.04,-0.50,0.0),Vector3(-0.08,-0.62,0.0),Vector3(0.12,0.90,0.0),Vector3(0.06,0.40,0.0),Vector3.ZERO],
		"Kamehameha": [Vector3(-0.16,-0.24,0.08),Vector3(-0.28,-0.38,0.12),Vector3(-0.18,-0.48,0.10),Vector3(0.08,0.12,-0.02),Vector3(0.04,0.08,0.0)],
		"Spirit_Bomb": [Vector3(-0.12,-0.10,0.0),Vector3(-0.22,-0.18,0.02),Vector3(-0.30,-0.12,0.04),Vector3(0.08,0.10,-0.01),Vector3.ZERO]
	})
	var offsets := {
		"Stone_Slam": [Vector3(0,0,0.10),Vector3(0,0,0.12),Vector3(0,0,-0.24),Vector3(0,0,-0.15),Vector3.ZERO],
		"Water_Sweep": [Vector3(-0.12,0.08,0.08),Vector3(-0.16,0.1,0.08),Vector3(0.18,0.05,-0.18),Vector3(0.08,0.04,-0.10),Vector3.ZERO],
		"Fire_Combo": [Vector3(0.10,0,0.12),Vector3(0.12,0,0.15),Vector3(-0.08,0,-0.25),Vector3(0.07,0,-0.3),Vector3.ZERO],
		"Soul_Channel": [Vector3(0,0.22,0),Vector3(0,0.35,0),Vector3(0,0.40,-0.10),Vector3(0,0.30,0),Vector3.ZERO],
		"Lightning_Lunge": [Vector3(0,0,0.13),Vector3(0,0,0.2),Vector3(0,0,-0.50),Vector3(0,0,-0.24),Vector3.ZERO],
		"Wind_Cyclone": [Vector3(0,0.10,0),Vector3(0,0.20,0),Vector3(0,0.30,-0.12),Vector3(0,0.16,0),Vector3.ZERO],
		"Poison_Cast": [Vector3(0,0.05,0.12),Vector3(0,0.08,0.16),Vector3(0,0.16,-0.1),Vector3(0,0.10,0),Vector3.ZERO],
		"Ice_Cleave": [Vector3(0,0,0.12),Vector3(0,0.04,0.18),Vector3(0,0,-0.28),Vector3(0,0,-0.14),Vector3.ZERO],
		"Gravity_Pulse": [Vector3(0,0.32,0),Vector3(0,0.58,0),Vector3(0,0.64,-0.10),Vector3(0,0.40,0),Vector3.ZERO],
		"Lava_Crash": [Vector3(0,0.42,0.1),Vector3(0,0.75,0.14),Vector3(0,0,-0.32),Vector3(0,0.06,-0.18),Vector3.ZERO],
		"Void_Reap": [Vector3(-0.10,0.12,0.20),Vector3(-0.15,0.18,0.24),Vector3(0.12,0.04,-0.44),Vector3(0.1,0.10,-0.22),Vector3.ZERO]
	}
	offsets.merge({
		"Eclipse_Wave": [Vector3(0,0.08,0.12),Vector3(0,0.18,0.18),Vector3(0,-0.02,-0.22),Vector3(0,0.03,-0.10),Vector3.ZERO],
		"Apocalypse": [Vector3(0,0.18,0.0),Vector3(0,0.28,0.04),Vector3(0,0.08,-0.16),Vector3(0,0.12,-0.08),Vector3.ZERO],
		"Black_Beam": [Vector3(0,0.04,0.08),Vector3(0,0.08,0.12),Vector3(0,0.02,-0.18),Vector3(0,0.06,-0.10),Vector3.ZERO],
		"Dark_Sphere": [Vector3(0,0.15,0.12),Vector3(0,0.24,0.16),Vector3(0,0.18,-0.25),Vector3(0,0.12,-0.10),Vector3.ZERO],
		"Storm_Lance": [Vector3(0,0.03,0.10),Vector3(0,0.10,0.15),Vector3(0,0.02,-0.46),Vector3(0,0.05,-0.20),Vector3.ZERO],
		"Ember_Burst": [Vector3(0,0.10,0.08),Vector3(0,0.20,0.14),Vector3(0,0.14,-0.22),Vector3(0,0.08,-0.08),Vector3.ZERO],
		"Frost_Lattice": [Vector3(0,0.12,0.10),Vector3(0,0.20,0.12),Vector3(0,0.10,-0.20),Vector3(0,0.06,-0.08),Vector3.ZERO],
		"Gale_Shear": [Vector3(0,0.08,0.10),Vector3(0,0.16,0.16),Vector3(0,0.18,-0.20),Vector3(0,0.10,-0.10),Vector3.ZERO],
		"Kamehameha": [Vector3(0,0.08,0.08),Vector3(0,0.12,0.16),Vector3(0,0.20,0.10),Vector3(0,0.10,-0.30),Vector3(0,0.04,-0.16)],
		"Spirit_Bomb": [Vector3(0,0.12,0),Vector3(0,0.26,0.02),Vector3(0,0.38,0.02),Vector3(0,0.18,-0.10),Vector3(0,0.06,-0.08)]
	})
	for cue in poses:
		var animation := Animation.new()
		animation.length = 2.0
		_add_keys(animation,"Motion:rotation",[Vector3.ZERO]+poses[cue],[0.0,0.38,0.66,0.84,1.20,2.0])
		_add_keys(animation,"Motion:position",[Vector3.ZERO]+offsets[cue],[0.0,0.38,0.66,0.84,1.20,2.0])
		library.add_animation(cue,animation)

func _cache_locomotion_blend_tracks() -> void:
	_locomotion_blend_tracks.clear()
	if not _authored_motion or animator == null or skeleton == null:
		return
	for clip in ["Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop"]:
		if not animator.has_animation(clip):
			continue
		var animation: Animation = animator.get_animation(clip)
		var cached: Array[Dictionary] = []
		for track in animation.get_track_count():
			var track_type: Animation.TrackType = animation.track_get_type(track)
			if track_type not in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D]:
				continue
			var bone_name: String = animation.track_get_path(track).get_subname(0)
			var is_position: bool = track_type == Animation.TYPE_POSITION_3D
			if is_position:
				if "pelvis" not in bone_name and "hips" not in bone_name:
					continue
			else:
				if not ("thigh" in bone_name or "calf" in bone_name or "foot" in bone_name or "ball" in bone_name):
					continue
			var bone: int = skeleton.find_bone(bone_name)
			if bone >= 0:
				cached.append({"track": track, "bone": bone, "position": is_position})
		_locomotion_blend_tracks[clip] = cached

func _add_keys(animation: Animation, path: String, values: Array, times: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	for i in values.size(): animation.track_insert_key(track, times[i], values[i])

func _clip_name(clip: String) -> String:
	if animator != null and animator.has_animation(clip): return clip
	var lower := clip.to_lower()
	if lower in ["death", "die", "dead"]: return "Death01"
	if "hit" in lower: return "Hit_Chest"
	if "slash" in lower or "attack" in lower: return "Sword_Attack"
	if "cast_release" in lower: return "Cast_Release"
	if "channel" in lower: return "Channel_Loop"
	if lower == "cast": return "Cast"
	if "cast" in lower or "fire" in lower or "magic" in lower: return "Fire_Cast"
	if "dash" in lower or "dodge" in lower: return "Roll"
	return clip

func play(clip: String, speed: float = 1.0, force: bool = false) -> void:
	if animator == null or (one_shot_time > 0 and not force): return
	clip = _clip_name(clip)
	if not animator.has_animation(clip): clip = "Idle_Loop"
	if current_clip == clip and not force:
		animator.speed_scale = speed
		return
	var blend_time: float = 0.11 if force else (0.25 if clip == "Idle_Loop" and current_clip == "Sword_Idle_Loop" else (0.16 if clip == "Jump_Loop" else (0.20 if clip == "Jump_Fall" else 0.19)))
	var old_phase: float = 0.0
	var preserve_phase: bool = _authored_motion and current_clip in ["Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop"] and clip in ["Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop"]
	if preserve_phase:
		old_phase = fposmod(animator.current_animation_position / maxf(animator.current_animation_length, 0.01), 1.0)
	current_clip = clip
	animator.play(clip, blend_time, speed)
	if preserve_phase: animator.seek(old_phase * animator.get_animation(clip).length, true)

func action(clip: String, duration: float = -1.0) -> void:
	clip = _clip_name(clip)
	if animator == null: return
	if not animator.has_animation(clip): clip = "Sword_Attack"
	play(clip, 1.0, true)
	var length := animator.get_animation(clip).length
	one_shot_time = length if duration < 0 else duration
	_action_duration = one_shot_time
	animator.speed_scale = length / maxf(one_shot_time, 0.01)
	_dead = clip == "Death01"
	if _dead and is_instance_valid(weapon): weapon.visible = false

func tick(delta: float, speed: float, grounded: bool, casting: bool = false, crouching: bool = false) -> void:
	if model == null or animator == null: return
	age += delta
	if _authored_motion:
		_tick_authored(delta, speed, grounded, casting, crouching)
		return
	stride += delta * speed * TAU / (lerpf(1.65,3.4,smoothstep(1.5,6.0,speed)) * target_height / 2.1)
	one_shot_time = maxf(0, one_shot_time - delta)
	animator.advance(delta)
	if _dead:
		if _sculpt_motion: SCULPT_LOCOMOTION.animate(self,delta,0)
		return
	var movement := clampf(speed / 3.8, 0, 1)
	if one_shot_time <= 0:
		motion.rotation = Vector3.ZERO
		motion.position = Vector3.ZERO
		play("Sprint_Loop" if speed > 7 else ("Jog_Fwd_Loop" if speed > 0.3 else "Idle_Loop"))
		model.position = _model_origin + Vector3(0, absf(sin(stride)) * 0.052 * movement + sin(age * 2.8) * 0.008, 0)
		model.rotation = _model_rotation + Vector3(0.075 * movement, 0, sin(stride) * 0.025 * movement)
	else:
		model.rotation = _model_rotation
		model.position = _model_origin
	if asset_id == "grand_boss" or (skeleton == null and asset_id in ["subboss_4", "subboss_5", "subboss_9", "soldier_4", "soldier_5", "soldier_9", "grand_soldier"]):
		# The supplied unrigged courts are spectral figures: hover deliberately
		# rather than dragging a rigid A-pose across the ground.
		model.position.y += 0.09 + sin(age * 2.2) * 0.045
		model.rotation.z += sin(age * 1.6) * 0.02
	if not grounded: model.rotation.x = 0.14
	if crouching: model.position.y -= 0.22
	if _source_animator != null:
		var sample: float = 2.55 + fmod(age * maxf(speed / 3.5, 0.3), 1.6) if speed > 0.3 else 1.1 + fmod(age * 0.5, 0.65)
		_source_animator.seek(sample, true)
	elif _sculpt_motion:
		SCULPT_LOCOMOTION.animate(self,delta,speed)
	elif skeleton != null:
		_animate_rig(movement, grounded, casting)
		_animate_wings()
	update_weapon()

func _animate_wings() -> void:
	if _wing_bones.is_empty(): return
	var lift: float = sin(age*2.7)*0.065
	if one_shot_time>0 and _action_duration>0:
		var phase:=1.0-one_shot_time/_action_duration
		lift += 0.26*smoothstep(0.02,0.30,phase)*(1-smoothstep(0.38,0.5,phase))
		lift -= 0.18*smoothstep(0.36,0.43,phase)*(1-smoothstep(0.5,0.88,phase))
	for index in _wing_bones:
		var side:float=1.0 if skeleton.get_bone_name(index)=="wing_l" else -1.0
		var rest:=skeleton.get_bone_global_rest(index)
		var parent:=skeleton.get_bone_parent(index)
		var parent_basis:=skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent>=0 else Basis.IDENTITY
		var desired:=Basis(Vector3.BACK,lift*side)*rest.basis.orthonormalized()
		skeleton.set_bone_pose_rotation(index,(parent_basis.inverse()*desired).get_rotation_quaternion())

func _combat_stance_timer() -> float:
	var parent: Node = get_parent()
	if is_instance_valid(parent) and "_combat_stance_timer" in parent:
		return float(parent._combat_stance_timer)
	# Preview actors and NPC holders have no stance controller. Keep their
	# armed guard stable instead of treating a missing timer as expired.
	return 1.0

func _tick_authored(delta: float, speed: float, grounded: bool, _casting: bool, crouching: bool) -> void:
	var resume_action_gait := one_shot_time > 0.0 and one_shot_time <= delta
	one_shot_time = maxf(0, one_shot_time - delta)
	# 3-Tier ground locomotion with phase-synced playback rates
	var locomotion: String
	var cadence: float
	if speed > 11.5:
		locomotion = "Sprint_Loop"
		cadence = clampf(speed / 13.5, 0.9, 1.28)
	elif speed > 5.8:
		locomotion = "Jog_Fwd_Loop"
		cadence = clampf(speed / 9.5, 0.85, 1.2)
	else:
		locomotion = "Walk_Loop"
		cadence = clampf(speed / 4.5, 0.75, 1.25)
	var gait_length: float = animator.get_animation(locomotion).length
	_locomotion_clock = fposmod(_locomotion_clock + delta * cadence/maxf(gait_length,0.01),1.0)
	if one_shot_time <= 0 and not _dead:
		if not grounded:
			# Full airborne state machine
			if _vertical_speed > 1.0:
				if current_clip != "Jump_Loop":
					play("Jump_Loop", 1.0)
			else:
				if current_clip != "Jump_Fall":
					play("Jump_Fall", 1.0)
		elif crouching:
			play("Crouch_Fwd_Loop" if speed > 0.3 else "Crouch_Idle_Loop", 1.0)
		elif speed > 0.35:
			play(locomotion, cadence)
			if resume_action_gait:
				animator.seek(fposmod(_locomotion_clock-delta*cadence/maxf(gait_length,0.01),1.0)*gait_length,true)
		else:
			# Choose from gameplay state, never from the previously selected
			# idle: that alternated the clips and restarted their blend each tick.
			play("Sword_Idle_Loop" if is_player and _combat_stance_timer() > 0 else "Idle_Loop", 1.0)
	animator.advance(delta)
	if current_clip in ["Walk_Loop","Jog_Fwd_Loop","Sprint_Loop"]:
		_locomotion_clock=fposmod(animator.current_animation_position/maxf(animator.current_animation_length,0.01),1.0)
	if _dead:
		update_weapon()
		return
	motion.position = Vector3.ZERO
	model.position = _model_origin
	var lean: float = 0.0 if is_player else clampf(_turn_rate * -0.012, -0.12, 0.12) * clampf(speed/5.0,0,1)
	# Player sprint lean is authored into the spine. Tilting the entire mesh
	# again rotates its ankles and exaggerates the forward pitch.
	var sprint_lean: float = 0.0 if is_player else (0.11 if speed > 11.5 else 0.0)
	model.rotation = _model_rotation + Vector3(sprint_lean, 0, lean)
	# Keep the authored sword/spell upper body while the legs continue moving.
	if speed > 1.0 and grounded and one_shot_time > 0 and current_clip not in ["Roll", "Jump_Start", "Jump_Land", "Double_Jump", "Death01"]:
		var movement: Animation = animator.get_animation(locomotion)
		var sample := _locomotion_clock * movement.length
		for entry: Dictionary in _locomotion_blend_tracks.get(locomotion, []):
			var track: int = entry.track
			var bone: int = entry.bone
			if entry.position:
				skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone).lerp(movement.position_track_interpolate(track,sample),0.9))
			else:
				var pose: Quaternion = movement.rotation_track_interpolate(track, sample)
				skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(pose, 0.9))
	# Secondary cloth follows acceleration/air state on the supplied cape bones.
	var target_cloth: float = clampf(speed * 0.018 - _vertical_speed * 0.012, -0.16, 0.28)
	_cloth_angle = lerpf(_cloth_angle, target_cloth, 1.0-exp(-7.0*delta))
	for index in _cloth_bones:
		if asset_id == "female":
			# Preserve the cape's attachment to the animated waist. Using a
			# global rest basis counter-rotated it whenever the torso turned.
			var cloth_name := skeleton.get_bone_name(index)
			var section := 2.0 if cloth_name == "cape_tip" else (1.0 if cloth_name == "cape_mid" else 0.0)
			var desired_angle := _cloth_angle * (0.48 if section == 0 else 0.40) + sin(age*4.2-section*0.75)*0.014*clampf(speed/7.0,0,1)
			var previous_angle: float = _cloth_segments.get(index, 0.0)
			var angle := lerpf(previous_angle,desired_angle,1.0-exp(-(8.0-section*1.5)*delta))
			_cloth_segments[index] = angle
			var lateral := clampf(-_turn_rate*0.012,-0.06,0.06)*(0.35+section*0.25)
			skeleton.set_bone_pose_rotation(index,skeleton.get_bone_rest(index).basis.get_rotation_quaternion()*Quaternion.from_euler(Vector3(angle,0,lateral)))
			continue
		var cloth_rest := skeleton.get_bone_global_rest(index)
		var cloth_parent := skeleton.get_bone_parent(index)
		var desired_cloth := cloth_rest.basis.orthonormalized() * Basis(Vector3.RIGHT, _cloth_angle + sin(age*5.0+index)*0.025*clampf(speed/8,0,1))
		var parent_cloth := skeleton.get_bone_global_pose(cloth_parent).basis.orthonormalized() if cloth_parent >= 0 else Basis.IDENTITY
		skeleton.set_bone_pose_rotation(index, (parent_cloth.inverse()*desired_cloth).get_rotation_quaternion())
	_animate_wings()
	if grounded and not _dodging and current_clip != "Roll":
		var lowest: float = 100.0
		for index in _foot_bones:
			var sole := skeleton.to_global(skeleton.get_bone_global_rest(index).origin).y
			var posed := skeleton.to_global(skeleton.get_bone_global_pose(index).origin).y
			lowest = minf(lowest, posed-sole)
		if lowest < 10:
			_ground_offset = lerpf(_ground_offset, clampf(-lowest, -0.32, 0.32), 1-exp(-18*delta))
	else:
		_ground_offset = move_toward(_ground_offset, 0, delta*3)
	motion.position.y = _ground_offset
	update_weapon()

func _pose(slot: String, angles: Vector3) -> void:
	if not bone_slots.has(slot): return
	var bone: int = bone_slots[slot]
	var base: Quaternion = resting_bones[bone]
	skeleton.set_bone_pose_rotation(bone, base * Quaternion.from_euler(angles))

func _animate_rig(movement: float, grounded: bool, casting: bool) -> void:
	var step := sin(stride) * movement
	_pose("thigh_l", Vector3(step * 0.55, 0, 0))
	_pose("thigh_r", Vector3(-step * 0.55, 0, 0))
	_pose("shin_l", Vector3(maxf(0, -step) * 0.75, 0, 0))
	_pose("shin_r", Vector3(maxf(0, step) * 0.75, 0, 0))
	_pose("spine", Vector3(movement * 0.08, sin(stride) * movement * 0.065, 0))
	_pose("head", Vector3(sin(age * 1.9) * 0.02, 0, 0))
	var attack := sin((1.0 - one_shot_time / maxf(_action_duration, 0.01)) * PI) if one_shot_time > 0 else 0.0
	_pose("arm_l", Vector3(-step * 0.35 - (0.9 if casting else 0.0), 0, 0))
	var slash_direction: float = -1.0 if current_clip == "Sword_Attack02" else 1.0
	var overhead: float = 1.8 if current_clip == "Sword_Attack03" else 1.2
	_pose("arm_r", Vector3(step * 0.25 - attack * overhead, attack * 0.35 * slash_direction, attack * 0.5 * slash_direction))
	_pose("forearm_l", Vector3(0, 0, -0.2 if casting else 0))
	_pose("forearm_r", Vector3(-0.18 - attack * 0.8, 0, 0))
	if current_clip == "Kamehameha" and one_shot_time > 0:
		_pose("arm_l", Vector3(-0.98, 0.10, -0.28))
		_pose("arm_r", Vector3(-0.98, -0.10, 0.28))
		_pose("forearm_l", Vector3(-0.48, 0, 0))
		_pose("forearm_r", Vector3(-0.48, 0, 0))
	elif current_clip == "Spirit_Bomb" and one_shot_time > 0:
		_pose("arm_l", Vector3(-1.86, 0.0, -0.48))
		_pose("arm_r", Vector3(-1.86, 0.0, 0.48))
		_pose("forearm_l", Vector3(-0.30, 0, -0.18))
		_pose("forearm_r", Vector3(-0.30, 0, 0.18))
	if not grounded:
		_pose("thigh_l", Vector3(-0.5, 0, 0))
		_pose("shin_r", Vector3(0.85, 0, 0))

func update_weapon() -> void:
	ENEMY_LOADOUT.update(self,_enemy_loadout)
	if weapon == null: return
	weapon.visible = weapon_enabled and (is_player or sword_equipped) and not _dead
	if skeleton != null and hand >= 0:
		var pose := skeleton.get_bone_global_pose(hand)
		weapon.global_position = skeleton.to_global(pose.origin)
		weapon.global_basis = (skeleton.global_basis * pose.basis).orthonormalized() * sword_mount
	else:
		weapon.position = Vector3(0.32, target_height * 0.52, -0.12)
		weapon.rotation = Vector3(-0.28, 0, -0.18)
		if one_shot_time > 0 and _action_duration > 0:
			weapon.rotation.z += sin((1.0 - one_shot_time / _action_duration) * PI) * 1.8

func weapon_position() -> Vector3:
	return muzzle.global_position if is_instance_valid(muzzle) else global_position + Vector3.UP * target_height * 0.6

func casting_position() -> Vector3:
	if not _enemy_loadout.is_empty():
		if _enemy_loadout.has("rifle"):
			return _enemy_loadout.rifle.muzzle.global_position
		return _enemy_loadout.prop.global_position
	if _sculpt_motion:
		var bone: int = skeleton.find_bone("sculpt_arm_r")
		return skeleton.to_global(skeleton.get_bone_global_pose(bone)*Vector3(-0.08,-0.32,-0.10))
	if skeleton != null and hand >= 0:
		return skeleton.to_global(skeleton.get_bone_global_pose(hand).origin)
	return weapon_position()

func equip_sword() -> void:
	sword_equipped = true
	weapon_enabled = true
	if not is_instance_valid(weapon): return
	for child in weapon.get_children():
		weapon.remove_child(child)
		child.queue_free()
	weapon.name = "DaVinciEmberSword"
	var provided_sword: Node3D = CATALOG.instantiate("sword")
	if provided_sword != null:
		weapon.add_child(provided_sword)
		for piece in provided_sword.find_children("*","MeshInstance3D",true,false):
			for surface in piece.mesh.get_surface_count():
				var source_material: Material=piece.mesh.surface_get_material(surface)
				if source_material is StandardMaterial3D:
					var material_key: String="sword:"+str(source_material.get_instance_id())
					if not runtime_materials.has(material_key):
						var sword_material:=source_material.duplicate() as StandardMaterial3D
						# Preserve the brass/steel atlas while making it readable without
						# an outdoor HDR reflection map in the dark interior.
						sword_material.metallic=0.42
						sword_material.roughness=0.48
						sword_material.roughness_texture=null
						sword_material.normal_enabled=false
						runtime_materials[material_key]=sword_material
					piece.set_surface_override_material(surface,runtime_materials[material_key])
		muzzle = Marker3D.new()
		muzzle.name = "MagicOrigin"
		weapon.add_child(muzzle)
		muzzle.position = Vector3(0, 1.10, 0)
		if skeleton != null and hand >= 0:
			var grip_basis := (skeleton.global_basis * skeleton.get_bone_global_pose(hand).basis).orthonormalized()
			sword_mount = grip_basis.inverse() * global_basis.orthonormalized() * Basis.from_euler(Vector3(-0.35, 0, -0.12))
		update_weapon()
		return
	var steel := ART.material(Color("c9dae0"), 0.82)
	var gold := ART.material(Color("d99a50"), 0.7)
	var grip := ART.material(Color("251d29"), 0.2)
	var fire := ART.material(Color("ff7a35"), 0.1, 2.5)
	ART.cylinder(weapon, Vector3(0, -0.05, 0), 0.035, 0.23, grip)
	ART.cylinder(weapon, Vector3(0, -0.18, 0), 0.055, 0.045, gold)
	ART.box(weapon, Vector3(0, 0.085, 0), Vector3(0.28, 0.055, 0.06), gold)
	ART.box(weapon, Vector3(0, 0.61, 0), Vector3(0.09, 1.03, 0.028), steel)
	var tip := ART.cylinder(weapon, Vector3(0, 1.20, 0), 0.045, 0.2, steel, false, 0)
	tip.scale.z = 0.32
	ART.box(weapon, Vector3(0, 0.61, -0.017), Vector3(0.012, 1.0, 0.005), fire)
	ART.box(weapon, Vector3(0, 0.61, 0.017), Vector3(0.012, 1.0, 0.005), fire)
	muzzle = Marker3D.new()
	muzzle.name = "MagicOrigin"
	weapon.add_child(muzzle)
	muzzle.position = Vector3(0, 1.27, 0)
	if skeleton != null and hand >= 0:
		sword_mount = skeleton.get_bone_global_pose(hand).basis.inverse() * Basis.from_euler(Vector3(-0.12, 0, 0.08))
	update_weapon()

func _make_missing_visual() -> Node3D:
	# Neutral diagnostic marker for a missing runtime dependency. Every shipped
	# actor has a validated supplied asset; this is never presented as source art.
	var root := Node3D.new()
	var marker := ART.material(Color("ff43c3"), 0.0, 1.0)
	ART.box(root, Vector3(0, 0.8, 0), Vector3(0.5, 1.6, 0.5), marker)
	push_error("Missing provided runtime asset: " + asset_id)
	return root
