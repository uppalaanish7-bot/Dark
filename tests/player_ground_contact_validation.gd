extends "res://tests/player_combat_validation.gd"
## Inspect skinned boot vertices: ankle orientation alone misses toe deformation.
func run() -> void:
	for identity in ["female", "omega"]:
		var actor: Node3D = PLAYER.new()
		actor.asset_id = identity
		root.add_child(actor)
		for frame in 60: actor.tick(1.0 / 60.0, 0, true)
		var worst_contact: float = absf(rest_bounds(actor).position.y)
		for clip in ["Sword_Attack", "Sword_Attack02", "Sword_Attack03", "Cast", "Fire_Cast"]:
			actor.action(clip)
			var frames: int = ceili(actor._action_duration * 60.0) + 12
			for frame in frames:
				actor.tick(1.0 / 60.0, 0, true)
				if frame % 6 != 0 and frame != frames - 1: continue
				var floor_error: float = absf(rest_bounds(actor).position.y)
				worst_contact = maxf(worst_contact, floor_error)
				check(floor_error < 0.008, identity + ": skinned boot leaves its floor plane in " + clip + " by " + str(floor_error) + "m")
		check(actor.current_clip == "Sword_Idle_Loop", identity + ": grounded action recovers to guard")
		records.append({"id": identity, "max_skinned_sole_error_m": worst_contact})
		actor.free()
	var output := FileAccess.open("res://art/asset_review/player_ground_contact_validation.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"actors": records, "failures": failures}, "\t"))
	print("PLAYER_GROUND_CONTACT_VALIDATION actors=", records.size(), " failures=", failures.size())
	for record in records: print(record)
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
