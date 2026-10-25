extends SceneTree
var checks: int = 0
var failed: int = 0
func expect(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS ", description)
	else:
		failed += 1
		push_error(description)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena: Node3D = load("res://scripts/tower_arena.gd").new()
	root.add_child(arena)
	await process_frame
	expect(arena.encounter_positions.size() == 11, "Nine boss floors, a guard-boss floor, and a main-boss floor")
	expect(arena.is_walkable(arena.spawn_point()), "Arrival is walkable")
	expect(arena.is_walkable(arena.potion_position) and arena.potion_position.y > 197, "Healing potion has walkable terrace ground")
	expect(arena.is_walkable(arena.exit_position) and arena.exit_position.distance_to(arena.potion_position) > 10, "Terrace exit has separate walkable ground")
	expect(not arena.is_walkable(Vector3(160, 0, 0)), "Cathedral bounds reject outside points")
	for index in range(11):
		var center: Vector3 = arena.encounter_positions[index]
		expect(arena.room_centers(index).size() == 5, "Floor %d has five exploration rooms" % (index + 1))
		for room in arena.room_centers(index):
			expect(arena.is_walkable(room) and arena.route(center, room).size() > 0, "Floor %d room at %s connects to its hall" % [index + 1, room])
		expect(arena.is_walkable(arena.key_position(index)) and arena.route(center, arena.key_position(index)).size() > 0, "Floor %d key can be reached inside a chamber" % (index + 1))
		expect(arena.is_walkable(center) and arena.floor_for_position(center) == index, "Floor %d has a clear center at its own elevation" % (index + 1))
		expect(arena.route(arena.floor_spawn(index), center).size() > 0, "Floor %d has a route from its chamber arrival" % (index + 1))
		if index > 0:
			expect(arena.route(arena.encounter_positions[index - 1], center).is_empty(), "Floor %d enemies cannot navigate through another floor" % (index + 1))
		expect(arena._gates[index * 2].visible and arena._gates[index * 2 + 1].visible, "Floor %d ascent starts locked" % (index + 1))
	arena.set_encounter(7)
	expect(arena.active_encounter == 7 and arena._court_lights[0].visible, "Active court receives combat lighting")
	arena.mark_encounter_complete(7)
	await process_frame
	expect(arena.cleared_encounters.has(7), "Cleared floor remembers victory")
	expect(arena._gates[14].visible and not arena._gate_collisions[14].disabled, "Defeating the guardian alone leaves the key lock shut")
	arena.set_floor_key_collected(7, true)
	await process_frame
	expect(not arena._gates[14].visible and not arena._gates[15].visible and arena._gate_collisions[14].disabled and arena._gate_collisions[15].disabled, "Boss clear plus key opens both stair gates")
	expect(not arena._key_nodes[7].visible, "Collected floor key disappears")
	arena.set_floor_key_collected(8, true)
	await process_frame
	expect(arena._gates[16].visible and not arena._gate_collisions[16].disabled, "Collecting a key before its boss leaves ascent locked")
	arena.mark_encounter_complete(8)
	await process_frame
	expect(not arena._gates[16].visible and arena._gate_collisions[16].disabled, "Key collected before boss also unlocks after victory")
	expect(arena._gates[12].visible and not arena._gate_collisions[12].disabled, "Clearing a floor leaves other locked ascents intact")
	arena.reveal_portal()
	expect(arena.portal_active and arena.portal.visible and not arena._roof_exit.visible, "Completion reveals the potion before the terrace exit")
	arena.set_potion_collected(true)
	expect(not arena.portal.visible and arena._roof_exit.visible, "Potion collection reveals the separate terrace exit")
	arena.reset_progress()
	await process_frame
	expect(not arena.portal_active and not arena.portal.visible and not arena._roof_exit.visible and arena.active_encounter == -1, "Replay resets the potion, exit and encounters")
	expect(arena._gates[14].visible and not arena._gate_collisions[14].disabled and arena.cleared_encounters.is_empty(), "Replay relocks cleared stair gates")
	print("INTERIOR RESULT: %d checks, %d failures" % [checks, failed])
	arena.queue_free()
	await process_frame
	quit(1 if failed else 0)
