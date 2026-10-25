extends SceneTree
const VISUAL = preload("res://scripts/provided_visual.gd")
var checks := 0
var failures: Array[String] = []
var worst_support := 0.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and label not in failures: failures.append(label)
func run() -> void:
	for height in [2.1, 3.0]:
		var actor := VISUAL.new()
		actor.asset_id = "subboss_7"
		actor.target_height = height
		root.add_child(actor)
		actor.rotation.y = 0.73
		var sk: Skeleton3D = actor.skeleton
		var loadout: Dictionary = actor._enemy_loadout
		var data: Dictionary = loadout.rifle
		var prop: MeshInstance3D = loadout.prop
		var scale_factor: float = height / 2.1
		var left: Array[int] = data.left
		var right: Array[int] = data.right
		var lengths: Dictionary = {}
		for chain in [left, right]:
			lengths[chain[0]] = sk.get_bone_global_rest(chain[0]).origin.distance_to(sk.get_bone_global_rest(chain[1]).origin)
			lengths[chain[1]] = sk.get_bone_global_rest(chain[1]).origin.distance_to(sk.get_bone_global_rest(chain[2]).origin)
		for cue in ["Rifle_Aim_Shot", "Rifle_Butt"]:
			actor.action(cue, 1.0)
			for frame in 61:
				actor.tick(1.0 / 60.0, 0.0, true)
				var phase: float = 1.0 - actor.one_shot_time
				check(actor.current_clip == cue or frame >= 59, "Named rifle animation runs to recovery")
				check(prop.global_transform.is_finite(), "Rifle transform stays finite")
				check(actor.casting_position().distance_to(data.muzzle.global_position) < 0.0001, "Rifle cast begins at its original barrel")
				check(prop.global_basis.get_scale().distance_to(Vector3.ONE * scale_factor) < 0.003, "Original rifle is rigid at both actor sizes")
				var expected: Transform3D = sk.global_transform * sk.get_bone_global_pose(loadout.hand) * loadout.mount
				check(prop.global_position.distance_to(expected.origin) < 0.0001, "Pistol grip stays attached to original right hand")
				var left_world: Transform3D = sk.global_transform * sk.get_bone_global_pose(left[2])
				var support_error: float = (left_world * data.palm_offset).distance_to(data.support.global_position) / scale_factor
				worst_support = maxf(worst_support, support_error)
				check(support_error < 0.025, "Left palm stays on source rifle foregrip")
				for chain in [left, right]:
					for segment in 2:
						var length: float = sk.get_bone_global_pose(chain[segment]).origin.distance_to(sk.get_bone_global_pose(chain[segment+1]).origin)
						check(absf(length - lengths[chain[segment]]) < 0.001, "Rifle solve never stretches the arms")
				if cue == "Rifle_Aim_Shot" and phase > 0.25 and phase < 0.75:
					var forward: Vector3 = -actor.global_basis.z.normalized()
					check((-prop.global_basis.z).normalized().dot(forward) > 0.99, "Sighted rifle points along the attack direction")
		actor.free()
	print("RIFLE_MOTION_CHECKS ", checks, " FAILURES ", failures.size(), " WORST_SUPPORT_METRES ", worst_support)
	for failure in failures: print("FAILED: ", failure)
	quit(0 if failures.is_empty() else 1)
