extends SceneTree
## Floor scale, traversable routes and visibility state without renderer timing.
const TOWER = preload("res://scripts/tower_arena.gd")
const LAYOUT = preload("res://scripts/tower_layout.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var tower := TOWER.new()
	root.add_child(tower)
	tower.set_process(false)
	tower.set_physics_process(false)
	var area: float = LAYOUT.ROOM_HALF_WIDTH * 2 * LAYOUT.ROOM_HALF_DEPTH * 2
	for size in LAYOUT.ROOM_SIZES:
		area += size.x * size.y
	check(area > 310 * 470, "Every storey has more usable floor area than the old single hall")
	check(LAYOUT.ROOM_OFFSETS.size() == 5 and LAYOUT.ROOM_DOORS.size() == 5, "Every floor has five separate exploration rooms")
	check(tower._room_doors.size() == 55 and tower._key_nodes.size() == 11, "Eleven floors contain 55 room doors and eleven keys")
	for floor_index in range(LAYOUT.FLOOR_COUNT):
		var key: Vector3 = LAYOUT.key_position(floor_index)
		check(LAYOUT.room_rect(floor_index % 5).grow(-2).has_point(Vector2(key.x, key.z)) and tower.is_walkable(key), "Floor %d key lies safely inside its assigned room" % (floor_index + 1))
		for room in range(5):
			var at: Vector3 = LAYOUT.room_centers(floor_index)[room]
			var route: PackedVector2Array = tower.route(LAYOUT.center(floor_index), at)
			var doorway: Vector3 = LAYOUT.ROOM_DOORS[room]
			var crosses_door: bool = false
			for point in route:
				if point.distance_to(Vector2(doorway.x, doorway.z)) <= 1.1:
					crosses_door = true
			check(not route.is_empty() and crosses_door, "Floor %d room %d routes through its small doorway" % [floor_index + 1, room + 1])
		tower.update_floor_visibility(LAYOUT.center(floor_index))
		check(tower._floor_roots[floor_index].visible and tower._floor_roots[floor_index + 1].visible and visible_floor_count(tower) == 2, "Floor %d shows its rooms and ceiling while culling remote storeys" % (floor_index + 1))
	tower.update_floor_visibility(Vector3(LAYOUT.UPPER_FLIGHT_X, 5 * LAYOUT.FLOOR_HEIGHT + 0.12, 268))
	check(visible_floor_count(tower) == 3 and tower._floor_roots[4].visible, "Upper stair landings retain the previous flight while descending")
	tower.update_floor_visibility(LAYOUT.POTION_POSITION)
	check(visible_floor_count(tower) == 1 and tower._floor_roots[11].visible, "Terrace exploration culls the enclosed storeys")
	tower.set_floor_key_collected(3, true)
	tower.update_floor_visibility(LAYOUT.center(3))
	check(not tower._key_nodes[3].is_visible_in_tree(), "Collected keys stay hidden when their floor becomes visible")
	tower.reset_progress()
	check(tower._key_nodes[3].is_visible_in_tree() and not tower.floor_unlocked(3), "Reset restores visible keys and locks stairs")
	print("TOWER_LAYOUT_VALIDATION: %d checks, %d failures, area=%dm2" % [checks, failures, area])
	quit(1 if failures else 0)

func visible_floor_count(tower: Node3D) -> int:
	var count: int = 0
	for floor_root in tower._floor_roots:
		if floor_root.visible:
			count += 1
	return count

func check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(detail)
