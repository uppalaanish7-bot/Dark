extends SceneTree
const VISUAL = preload("res://scripts/character_visual.gd")
var failures: Array[String] = []
var records: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func advance(actor: Node3D, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.000001:
		var delta := minf(1.0 / 120.0, remaining)
		actor.tick(delta, 0.0, true)
		remaining -= delta
func run() -> void:
	for id in ["female", "omega"]:
		var actor := VISUAL.new()
		actor.asset_id = id
		root.add_child(actor)
		actor.rotation.y = 0.41
		advance(actor, 1.0)
		actor.action("Cast", 1.20)
		advance(actor, 0.60)
		var gather: Vector3 = actor.weapon_position()
		var gather_axis: Vector3 = actor.weapon.global_basis.y.normalized()
		check(gather_axis.y > 0.97, id + ": R holds the actual blade vertically while gathering")
		check(gather.y > actor.target_height + 0.60, id + ": R lifts the blade tip above the head")
		advance(actor, 0.24)
		var release: Vector3 = actor.weapon_position()
		var release_axis: Vector3 = actor.weapon.global_basis.y.normalized()
		check(release.y < gather.y - 1.0, id + ": R downstroke is visible at the .84-second mana release")
		check(release_axis.y < -0.20, id + ": R blade points down through its release")
		advance(actor, 0.70)
		check(actor.current_clip == "Sword_Idle_Loop", id + ": R recovers to guard")
		var worst_alignment: float = 1.0
		for target in [Vector3(0,1.4,-12), Vector3(3,4,-12), Vector3(-3,0,-12)]:
			var aim: Vector3 = actor.to_global(target)
			actor.set_cast_target(aim)
			actor.action("Fire_Cast", 0.42)
			advance(actor, 0.17)
			var actual: Vector3 = actor.weapon.global_basis.y.normalized()
			var desired: Vector3 = (aim - actor.weapon.global_position).normalized()
			var alignment: float = actual.dot(desired)
			worst_alignment = minf(worst_alignment, alignment)
			check(alignment > 0.995, id + ": RMB points the actual sword at the target at .17 seconds")
			var palm: Vector3 = actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(actor.hand) * actor._palm_offset)
			check(palm.distance_to(actor.weapon.to_global(Vector3(0,-0.085,0))) < 0.001, id + ": aimed hilt stays inside the hand")
			advance(actor, 0.50)
			check(actor.current_clip == "Sword_Idle_Loop", id + ": RMB recovers to guard")
		records.append({"id": id, "r_gather_tip_height_m": gather.y, "r_release_tip_height_m": release.y, "r_release_downward_component": release_axis.y, "rmb_worst_alignment_dot": worst_alignment})
		actor.free()
	var output := FileAccess.open("res://art/asset_review/player_cast_motion_validation.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"actors": records, "failures": failures}, "\t"))
	print("PLAYER_CAST_MOTION_VALIDATION actors=", records.size(), " failures=", failures.size())
	for record in records: print(record)
	for failure in failures: print("FAILED: ", failure)
	quit(0 if failures.is_empty() else 1)
