extends RefCounted
## Repair exported loose props without replacing any supplied weapon geometry.
## The source mesh and texture atlas are retained; only the rigid grip changes.
static var prop_meshes: Dictionary = {}

# These are the weapons visible in the supplied meshes. A sheathed blade is
# not a held blade: the empty-handed priests keep their spell/punch gestures.
# The side names match the fitted sculpt bones, including the raised axe grip.
const PROFILES := {
	"subboss_1": {"kind": "blade", "side": "r"},
	"soldier_1": {"kind": "blade", "side": "r"},
	"subboss_2": {"kind": "blade", "side": "r"},
	"subboss_3": {"kind": "fists", "side": "r"},
	"subboss_4": {"kind": "staff", "side": "l"},
	"subboss_5": {"kind": "blade", "side": "l"},
	"subboss_6": {"kind": "axe", "side": "l"},
	"subboss_7": {"kind": "rifle", "side": "r"},
	"subboss_8": {"kind": "blade", "side": "l"},
	"subboss_9": {"kind": "blade", "side": "l"},
	"soldier_2": {"kind": "fists", "side": "r"},
	"soldier_3": {"kind": "fists", "side": "r"},
	"soldier_4": {"kind": "fists", "side": "r"},
	"soldier_5": {"kind": "fists", "side": "r"},
	"soldier_6": {"kind": "staff", "side": "r"},
	"soldier_7": {"kind": "fists", "side": "r"},
	"soldier_8": {"kind": "fists", "side": "r"},
	"soldier_9": {"kind": "axe", "side": "r"},
	"grand_boss": {"kind": "dual_blade", "side": "r"},
	"grand_soldier": {"kind": "blade", "side": "l"},
	"main_boss": {"kind": "scythe", "side": "l"}
}
const NAMED_ACTIONS := {
	"Blade_Right_Slash": "Sword_Attack", "Blade_Right_Return": "Sword_Attack02",
	"Blade_Left_Slash": "Sword_Attack", "Blade_Left_Return": "Sword_Attack02",
	"Blade_Overhead": "Sword_Attack03", "Dual_Blade_Cross": "Sword_Attack02",
	"Axe_Chop": "Sword_Attack03", "Axe_Backhand": "Sword_Attack02",
	"Staff_Sweep": "Sword_Attack02", "Staff_Thrust": "Sword_Attack",
	"Scythe_Reap": "Sword_Attack02", "Scythe_Return": "Sword_Attack",
	"Rifle_Butt": "Sword_Idle_Loop", "Rifle_Aim_Shot": "Sword_Idle_Loop"
}

static func profile(id: String) -> Dictionary:
	return PROFILES.get(id, {"kind": "fists", "side": "r"})

static func melee_cue(id: String, sequence: int) -> String:
	var held := profile(id)
	var alternate: bool = posmod(sequence, 2) == 1
	match held.kind:
		"fists": return "Punch_Jab"
		"axe": return "Axe_Backhand" if alternate else "Axe_Chop"
		"staff": return "Staff_Thrust" if alternate else "Staff_Sweep"
		"scythe": return "Scythe_Return" if alternate else "Scythe_Reap"
		"rifle": return "Rifle_Butt"
		"dual_blade": return "Dual_Blade_Cross" if alternate else "Blade_Overhead"
	var side: String = "Left" if held.side == "l" else "Right"
	return "Blade_" + side + ("_Return" if alternate else "_Slash")

static func attack_cue(id: String, elemental_cue: String) -> String:
	if profile(id).kind == "rifle": return "Rifle_Aim_Shot"
	return elemental_cue

static func _install_actions(visual: Node3D) -> void:
	var animator: AnimationPlayer = visual.animator
	if animator == null or not animator.has_animation_library(""): return
	var current: String = animator.current_animation
	# Do not mutate the cached source library shared by other instances.
	var library: AnimationLibrary = animator.get_animation_library("").duplicate()
	animator.remove_animation_library("")
	animator.add_animation_library("", library)
	for name in NAMED_ACTIONS:
		if library.has_animation(name): continue
		var source: String = NAMED_ACTIONS[name]
		if not library.has_animation(source): continue
		if name.begins_with("Rifle_"):
			# The imported sword lunge kneels almost to the floor. The rifle uses
			# a standing base, with its own sighting/recoil/stock-strike arm solve.
			var rifle_clip: Animation = library.get_animation(source).duplicate()
			rifle_clip.loop_mode = Animation.LOOP_NONE
			library.add_animation(name, rifle_clip)
		else: library.add_animation(name, library.get_animation(source))
	if not current.is_empty(): animator.play(current, 0.0)

static func install(visual: Node3D) -> Dictionary:
	_install_actions(visual)
	var id: String = visual.asset_id
	if id not in ["soldier_1", "subboss_7"] or visual.skeleton == null: return {}
	var sk: Skeleton3D = visual.skeleton
	var hand_name := "R_wrist_063" if id == "soldier_1" else "npc_soldier_knight_arm_hand_rt_030"
	var hand := sk.find_bone(hand_name)
	if hand < 0: return {}
	var original: MeshInstance3D
	for piece in visual.model.find_children("*", "MeshInstance3D", true, false):
		if id == "soldier_1" and piece.name == "sword_sword_0": original = piece
		if id == "subboss_7" and piece.mesh != null:
			for surface in piece.mesh.get_surface_count():
				var material: Material = piece.mesh.surface_get_material(surface)
				if material != null and "sentinelrifl" in material.resource_name.to_lower(): original = piece
	if original == null: return {}
	if not prop_meshes.has(id): prop_meshes[id] = _rigid_mesh(original, id)
	var prop := MeshInstance3D.new()
	prop.name = "SuppliedSwordGrip" if id == "soldier_1" else "SuppliedRifleGrip"
	prop.mesh = prop_meshes[id]
	for surface in original.mesh.get_surface_count():
		prop.set_surface_override_material(surface, original.get_surface_override_material(surface))
	visual.add_child(prop)
	original.hide()
	# The soldier's scabbard is another loose node under the exporter bone.
	# Mount it at the belt so it cannot remain hovering beneath the feet.
	var scabbard: MeshInstance3D
	if id == "soldier_1":
		for piece in visual.model.find_children("*", "MeshInstance3D", true, false):
			if piece.name == "scabbard_2_sword_0": scabbard = piece
	var hand_rest := sk.global_transform * sk.get_bone_global_rest(hand)
	var origin: Vector3
	var fingers: Vector3
	var across: Vector3
	if id == "soldier_1":
		var middle := _rest_point(sk, "R_middle1_072")
		fingers = (middle - hand_rest.origin).normalized()
		across = (_rest_point(sk, "R_point1_068") - _rest_point(sk, "R_pink1_080")).normalized()
		origin = (_rest_point(sk, "R_thumb2_065") + _rest_point(sk, "R_middle2_073")) * 0.5
	else:
		fingers = (_rest_point(sk, "npc_soldier_knight_middle_part02_rt_049") - hand_rest.origin).normalized()
		across = (_rest_point(sk, "npc_soldier_knight_index_part02_rt_037") - _rest_point(sk, "npc_soldier_knight_pinky_part02_rt_045")).normalized()
		origin = (_rest_point(sk, "npc_soldier_knight_thumb_part03_rt_035") + _rest_point(sk, "npc_soldier_knight_middle_part03_rt_050")) * 0.5
	var y := (across - fingers * across.dot(fingers)).normalized()
	var z := fingers.cross(y).normalized() if id == "soldier_1" else -fingers
	var basis := Basis(y.cross(z).normalized(), y, z)
	var mounting := hand_rest.affine_inverse() * Transform3D(basis, origin)
	# Meshes are already normalized to a 2.1 metre actor; preserve boss scale.
	mounting.basis *= visual.target_height / 2.1
	var result := {"prop": prop, "hand": hand, "mount": mounting}
	if id == "subboss_7": _install_rifle_pose(visual, result)
	if scabbard != null:
		if not prop_meshes.has("soldier_1_scabbard"):
			prop_meshes["soldier_1_scabbard"] = _rigid_mesh(scabbard, "soldier_1")
		var sheath := MeshInstance3D.new()
		sheath.name = "SuppliedBeltScabbard"
		sheath.mesh = prop_meshes["soldier_1_scabbard"]
		for surface in scabbard.mesh.get_surface_count():
			sheath.set_surface_override_material(surface, scabbard.get_surface_override_material(surface))
		visual.add_child(sheath)
		scabbard.hide()
		var hip := sk.find_bone("Hips_033")
		if hip < 0:
			for bone in sk.get_bone_count():
				if sk.get_bone_name(bone).to_lower().begins_with("hips_"): hip = bone
		if hip >= 0:
			var rest := sk.global_transform * sk.get_bone_global_rest(hip)
			var sheath_basis: Basis = visual.global_basis * Basis.from_euler(Vector3(0.0,0.0,PI-0.20))
			var sheath_origin: Vector3 = visual.to_global(Vector3(-0.30,1.0,0.11)*visual.target_height/2.1)
			result["sheath"] = sheath
			result["hip"] = hip
			result["sheath_mount"] = rest.affine_inverse() * Transform3D(sheath_basis*visual.target_height/2.1,sheath_origin)
	update(visual, result)
	result["fingers"] = _close_grip(sk,prop,hand,hand_rest,id)
	if result.has("rifle"):
		var support: Node3D = result.rifle.support
		var left: int = result.rifle.left[2]
		result.fingers.merge(_close_grip(sk, support, left, sk.global_transform * sk.get_bone_global_rest(left), id, true))
	return result

static func update(visual: Node3D, loadout: Dictionary) -> void:
	if loadout.is_empty() or not is_instance_valid(loadout.get("prop")): return
	var sk: Skeleton3D = visual.skeleton
	var prop: MeshInstance3D = loadout.prop
	if loadout.has("rifle") and not visual._dead: _rifle_pose(visual, loadout)
	for bone in loadout.get("fingers", {}):
		sk.set_bone_pose_rotation(bone,loadout.fingers[bone])
	prop.global_transform = sk.global_transform * sk.get_bone_global_pose(loadout.hand) * loadout.mount
	if loadout.has("sheath"):
		loadout.sheath.global_transform = sk.global_transform * sk.get_bone_global_pose(loadout.hip) * loadout.sheath_mount

static func _install_rifle_pose(visual: Node3D, loadout: Dictionary) -> void:
	var sk: Skeleton3D = visual.skeleton
	var left: Array[int] = []
	var right: Array[int] = []
	for name in ["npc_soldier_knight_arm_upper_lf_0112", "npc_soldier_knight_arm_lower_lf_0113", "npc_soldier_knight_arm_hand_lf_0114"]: left.append(sk.find_bone(name))
	for name in ["npc_soldier_knight_arm_upper_rt_028", "npc_soldier_knight_arm_lower_rt_029", "npc_soldier_knight_arm_hand_rt_030"]: right.append(sk.find_bone(name))
	if -1 in left or -1 in right: return
	var hand: Transform3D = sk.global_transform * sk.get_bone_global_rest(left[2])
	var fingers: Vector3 = (_rest_point(sk, "npc_soldier_knight_middle_part02_lf_0125") - hand.origin).normalized()
	var across: Vector3 = (_rest_point(sk, "npc_soldier_knight_index_part02_lf_0133") - _rest_point(sk, "npc_soldier_knight_pinky_part02_lf_0118")).normalized()
	across = (across - fingers * fingers.dot(across)).normalized()
	var palm: Vector3 = (_rest_point(sk, "npc_soldier_knight_middle_part03_lf_0126") + _rest_point(sk, "npc_soldier_knight_thumb_part03_lf_0123")) * 0.5
	var support := Node3D.new()
	support.name = "OriginalRifleForegrip"
	loadout.prop.add_child(support)
	# The source's pistol grip is the mesh origin; this is its existing fore-end.
	support.transform = Transform3D(Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN), Vector3(0.0, 0.04, -0.24))
	var muzzle := Marker3D.new()
	muzzle.name = "OriginalRifleMuzzle"
	loadout.prop.add_child(muzzle)
	# Locate the original barrel's front-most vertices after rigid normalization.
	var mesh: Mesh = loadout.prop.mesh
	var front: float = mesh.get_aabb().position.z
	var tip := Vector3.ZERO
	var count := 0
	for surface in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for point in vertices:
			if point.z <= front + 0.025:
				tip += point
				count += 1
	muzzle.position = tip / maxf(count, 1)
	muzzle.position.z = front - 0.012
	loadout.rifle = {"left": left, "right": right, "support": support, "muzzle": muzzle, "palm_offset": hand.affine_inverse() * palm, "palm_basis": hand.basis.orthonormalized().inverse() * Basis(fingers, across, fingers.cross(across)), "hand_scale": hand.basis.get_scale()}

static func _rifle_pose(visual: Node3D, loadout: Dictionary) -> void:
	var sk: Skeleton3D = visual.skeleton
	var data: Dictionary = loadout.rifle
	var size: float = visual.target_height / 2.1
	var phase: float = clampf(1.0 - visual.one_shot_time / maxf(visual._action_duration, 0.01), 0.0, 1.0)
	var active: bool = visual.one_shot_time > 0.0
	var aiming: bool = active and visual.current_clip == "Rifle_Aim_Shot"
	var striking: bool = active and visual.current_clip == "Rifle_Butt"
	var raise: float = smoothstep(0.0, 0.24, phase) * (1.0 - smoothstep(0.76, 1.0, phase)) if aiming else 0.0
	var recoil: float = smoothstep(0.41, 0.44, phase) * (1.0 - smoothstep(0.44, 0.57, phase)) if aiming else 0.0
	var windup: float = smoothstep(0.0, 0.30, phase) * (1.0 - smoothstep(0.32, 0.42, phase)) if striking else 0.0
	var impact: float = smoothstep(0.32, 0.42, phase) * (1.0 - smoothstep(0.52, 0.88, phase)) if striking else 0.0
	if striking:
		var chest: int = sk.find_bone("npc_soldier_knight_spine_part05_md_026")
		if chest >= 0:
			var body: Transform3D = sk.global_transform * sk.get_bone_global_pose(chest)
			var turn: Basis = Basis(visual.global_basis.y.normalized(), windup * 0.18 - impact * 0.24) * Basis(visual.global_basis.x.normalized(), -windup * 0.035 + impact * 0.07)
			var parent_basis: Basis = (sk.global_transform * sk.get_bone_global_pose(sk.get_bone_parent(chest))).basis.orthonormalized()
			sk.set_bone_pose_rotation(chest, (parent_basis.inverse() * turn * body.basis.orthonormalized()).get_rotation_quaternion())
	# Both hands remain on this rifle in the low guard, sighted hold, recoil and
	# cross-body stock strike. Only rigid bone rotations are solved, never scales.
	var grip := Vector3(-0.12 + windup * 0.09 - impact * 0.06, 1.19 + raise * 0.23 + windup * 0.13 + impact * 0.10, -0.20 + recoil * 0.075 + windup * 0.08 - impact * 0.10)
	var rotation := Vector3(-0.32 * (1.0 - raise) + recoil * 0.055, windup * 1.05 - impact * 1.45, impact * 0.08)
	var desired: Transform3D = visual.global_transform * Transform3D(Basis.from_euler(rotation) * size, grip * size)
	var main_target: Transform3D = desired * loadout.mount.affine_inverse()
	_solve_rifle_arm(sk, data.right, main_target, visual.global_basis * Vector3(-0.65, -0.65, 0.20))
	# Compute support from the actual solved right grip so both hands agree even
	# if an unusually deep torso pose reaches the anatomical arm-length limit.
	var actual: Transform3D = sk.global_transform * sk.get_bone_global_pose(loadout.hand) * loadout.mount
	var palm_basis: Basis = actual.basis.orthonormalized() * Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP) * data.palm_basis.inverse()
	var support_basis: Basis = palm_basis.scaled(data.hand_scale)
	var support_origin: Vector3 = actual * data.support.position - support_basis * data.palm_offset
	_solve_rifle_arm(sk, data.left, Transform3D(support_basis, support_origin), visual.global_basis * Vector3(0.75, -0.65, 0.05))

static func _solve_rifle_arm(sk: Skeleton3D, chain: Array[int], target: Transform3D, pole: Vector3) -> void:
	var upper: Transform3D = sk.global_transform * sk.get_bone_global_pose(chain[0])
	var elbow: Transform3D = sk.global_transform * sk.get_bone_global_pose(chain[1])
	var wrist: Transform3D = sk.global_transform * sk.get_bone_global_pose(chain[2])
	var a: float = upper.origin.distance_to(elbow.origin)
	var b: float = elbow.origin.distance_to(wrist.origin)
	var offset: Vector3 = target.origin - upper.origin
	var distance: float = clampf(offset.length(), absf(a - b) + 0.0001, a + b - 0.0001)
	var direction: Vector3 = offset.normalized()
	var bend_direction: Vector3 = (pole - direction * pole.dot(direction)).normalized()
	var along: float = (a * a + distance * distance - b * b) / (2.0 * distance)
	var bend: float = sqrt(maxf(a * a - along * along, 0.0))
	var joint: Vector3 = upper.origin + direction * along + bend_direction * bend
	_rotate_bone_toward(sk, chain[0], elbow.origin - upper.origin, joint - upper.origin)
	elbow = sk.global_transform * sk.get_bone_global_pose(chain[1])
	wrist = sk.global_transform * sk.get_bone_global_pose(chain[2])
	_rotate_bone_toward(sk, chain[1], wrist.origin - elbow.origin, upper.origin + direction * distance - elbow.origin)
	var parent: int = sk.get_bone_parent(chain[2])
	var parent_basis: Basis = (sk.global_transform * sk.get_bone_global_pose(parent)).basis.orthonormalized()
	sk.set_bone_pose_rotation(chain[2], (parent_basis.inverse() * target.basis.orthonormalized()).get_rotation_quaternion())

static func _rotate_bone_toward(sk: Skeleton3D, bone: int, from: Vector3, to: Vector3) -> void:
	var current: Transform3D = sk.global_transform * sk.get_bone_global_pose(bone)
	var desired: Basis = Basis(Quaternion(from.normalized(), to.normalized())) * current.basis.orthonormalized()
	var parent: int = sk.get_bone_parent(bone)
	var parent_basis: Basis = (sk.global_transform * sk.get_bone_global_pose(parent)).basis.orthonormalized()
	sk.set_bone_pose_rotation(bone, (parent_basis.inverse() * desired).get_rotation_quaternion())

static func _rest_point(sk: Skeleton3D, name: String) -> Vector3:
	return sk.to_global(sk.get_bone_global_rest(sk.find_bone(name)).origin)

static func _close_grip(sk: Skeleton3D, prop: Node3D, hand: int, rest_hand: Transform3D, id: String, left_hand: bool = false) -> Dictionary:
	# These exports have unmapped fingers in an open pose. Curl only their
	# phalanges around the supplied handle, leaving wrist and palm animation.
	var chains: Array = []
	if id == "soldier_1":
		chains = [["R_point1_068","R_point2_069","R_point3_070"],["R_middle1_072","R_middle2_073","R_middle3_074"],["R_ring1_076","R_ring2_077","R_ring3_078"],["R_pink1_080","R_pink2_081","R_pink3_082"],["R_thumb2_065","R_thumb3_066"]]
	elif left_hand:
		chains = [["npc_soldier_knight_index_part02_lf_0133", "npc_soldier_knight_index_part03_lf_0134", "npc_soldier_knight_index_part04_lf_0135"], ["npc_soldier_knight_middle_part02_lf_0125", "npc_soldier_knight_middle_part03_lf_0126", "npc_soldier_knight_middle_part04_lf_0127"], ["npc_soldier_knight_ring_part02_lf_0129", "npc_soldier_knight_ring_part03_lf_0130", "npc_soldier_knight_ring_part04_lf_0131"], ["npc_soldier_knight_pinky_part02_lf_0118", "npc_soldier_knight_pinky_part03_lf_0119", "npc_soldier_knight_pinky_part04_lf_0120"], ["npc_soldier_knight_thumb_part02_lf_0122", "npc_soldier_knight_thumb_part03_lf_0123"]]
	else:
		chains = [["npc_soldier_knight_index_part02_rt_037","npc_soldier_knight_index_part03_rt_038","npc_soldier_knight_index_part04_rt_039"],["npc_soldier_knight_middle_part02_rt_049","npc_soldier_knight_middle_part03_rt_050","npc_soldier_knight_middle_part04_rt_051"],["npc_soldier_knight_ring_part02_rt_041","npc_soldier_knight_ring_part03_rt_042","npc_soldier_knight_ring_part04_rt_043"],["npc_soldier_knight_pinky_part02_rt_045","npc_soldier_knight_pinky_part03_rt_046","npc_soldier_knight_pinky_part04_rt_047"],["npc_soldier_knight_thumb_part02_rt_034","npc_soldier_knight_thumb_part03_rt_035"]]
	var hand_change: Transform3D = sk.global_transform * sk.get_bone_global_pose(hand) * rest_hand.affine_inverse()
	var result: Dictionary = {}
	for chain in chains:
		var bones: Array[int] = []
		var points: Array[Vector3] = []
		for name in chain:
			var bone := sk.find_bone(name)
			bones.append(bone)
			points.append(prop.to_local(hand_change*_rest_point(sk,name)))
			sk.set_bone_pose_rotation(bone,sk.get_bone_rest(bone).basis.get_rotation_quaternion())
		var radial := Vector3(points[0].x,0,points[0].z)
		var direction := 1.0 if Vector3.UP.cross(radial).dot(points[1]-points[0]) >= 0 else -1.0
		var radius := maxf(0.028, radial.length()*0.60)
		var angle := 0.0
		for n in bones.size():
			var bone: int = bones[n]
			var segment: Vector3 = (points[n+1]-points[n]) if n+1<points.size() else (points[n]-points[n-1])*0.8
			angle += clampf(segment.length()/maxf(radial.length(),0.035),0.45,1.1)*direction
			var target := radial.normalized().rotated(Vector3.UP,angle)*radius
			target.y=points[0].y
			var posed := sk.global_transform*sk.get_bone_global_pose(bone)
			var rest_world := sk.global_transform*sk.get_bone_global_rest(bone)
			var rest_segment: Vector3
			if n+1<bones.size(): rest_segment=_rest_point(sk,chain[n+1])-_rest_point(sk,chain[n])
			else: rest_segment=_rest_point(sk,chain[n])-_rest_point(sk,chain[n-1])
			var actual := posed.basis.orthonormalized()*rest_world.basis.orthonormalized().inverse()*rest_segment.normalized()
			var desired := (prop.to_global(target)-posed.origin).normalized()
			var turned := Basis(Quaternion(actual.normalized(),desired))*posed.basis.orthonormalized()
			var parent := sk.global_basis*sk.get_bone_global_pose(sk.get_bone_parent(bone)).basis
			var rotation := (parent.orthonormalized().inverse()*turned).get_rotation_quaternion()
			sk.set_bone_pose_rotation(bone,rotation)
			result[bone]=rotation
	return result

static func _rigid_mesh(original: MeshInstance3D, id: String) -> ArrayMesh:
	var result := ArrayMesh.new()
	# Both exports contain a complete, rigid prop mesh. The rifle's arrays are
	# already in normalized model space; its broken skin binds it to a zeroed
	# weapon joint at the floor. Removing those weights preserves the surface.
	var rotation := Basis(Vector3(0,0,1),Vector3(0,-1,0),Vector3(1,0,0)) if id == "soldier_1" else Basis(Vector3(0,0,-1),Vector3.UP,Vector3.RIGHT)
	var factor := 0.011501 if id == "soldier_1" else 1.0
	var grip := Vector3.ZERO if id == "soldier_1" else Vector3(-0.19,0.08,0)
	for surface in original.mesh.get_surface_count():
		var arrays: Array = original.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for n in points.size():
			points[n] = rotation * (points[n]-grip) * factor
			if n < normals.size(): normals[n] = rotation * normals[n]
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		arrays[Mesh.ARRAY_TANGENT] = null
		for custom in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]: arrays[custom] = null
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(surface,original.mesh.surface_get_material(surface))
	return result
