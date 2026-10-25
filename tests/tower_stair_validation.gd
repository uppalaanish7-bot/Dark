extends SceneTree
## Exercise real player capsule stepping against the authored tread colliders.
const TOWER = preload("res://scripts/tower_arena.gd")
const PLAYER = preload("res://player.gd")
var world: Node3D
var tower: Node3D
var player: CharacterBody3D
var failures: int = 0
var door_assistance: bool = false

class TowerGameContext extends Node3D:
	var state: String = "playing"
	var arena: Node3D
	var courtyard: Node3D
	var camera_shake: bool = false
	func safe_floor_index() -> int:
		return 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Engine.physics_ticks_per_second = 120
	Engine.time_scale = 6
	world = TowerGameContext.new()
	root.add_child(world)
	tower = TOWER.new()
	world.add_child(tower)
	world.arena = tower
	tower.set_physics_process(false)
	player = PLAYER.new()
	player.game = world
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	await physics_frame
	if OS.get_cmdline_user_args().has("descents-only"):
		await validate_descents()
		print("TOWER_DESCENT_VALIDATION failures=", failures)
		quit(1 if failures else 0)
		return
	for room in range(5):
		var doorway: Vector3 = tower.LAYOUT.ROOM_DOORS[room]
		var inward: Vector3 = Vector3(signf(doorway.x), 0, 0) if room < 4 else Vector3.FORWARD
		player.position = doorway - inward * 4 + Vector3.UP * 0.12
		player.velocity = Vector3.ZERO
		tower.update_room_doors(PackedVector3Array(), 1)
		await settle(10)
		await walk_to(doorway + inward * 4, 100)
		check((player.position - doorway).dot(inward) < 0, "Room %d closed door blocks the capsule" % (room + 1))
		door_assistance = true
		await walk_to(doorway + inward * 4, 200)
		check((player.position - doorway).dot(inward) > 3, "Room %d opens and admits the capsule through its 3m doorway" % (room + 1))
		await walk_to(doorway - inward * 4, 200)
		check((player.position - doorway).dot(inward) < -3, "Room %d admits the capsule back to the hall" % (room + 1))
		door_assistance = false
	# The roaming minions use a wider capsule than the player. Exercise that
	# exact footprint through each physical doorway in both directions too.
	var collider: CollisionShape3D = player.get_children().filter(func(child): return child is CollisionShape3D)[0]
	var capsule: CapsuleShape3D = collider.shape
	capsule.radius = 0.43
	capsule.height = 1.9
	for room in range(5):
		var doorway: Vector3 = tower.LAYOUT.ROOM_DOORS[room]
		var inward: Vector3 = Vector3(signf(doorway.x), 0, 0) if room < 4 else Vector3.FORWARD
		player.position = doorway - inward * 4 + Vector3.UP * 0.12
		player.velocity = Vector3.ZERO
		door_assistance = true
		await walk_to(doorway + inward * 4, 200)
		check((player.position - doorway).dot(inward) > 3, "Room %d admits the minion capsule" % (room + 1))
		await walk_to(doorway - inward * 4, 200)
		check((player.position - doorway).dot(inward) < -3, "Room %d lets the minion capsule return to the hall" % (room + 1))
		door_assistance = false
	capsule.radius = 0.34
	capsule.height = 1.85
	if OS.get_cmdline_user_args().has("doors-only"):
		print("TOWER_DOOR_VALIDATION failures=", failures)
		quit(1 if failures else 0)
		return
	player.global_position = tower.stair_entry(0)
	await settle(20)
	await walk_to(Vector3(208, 0, 264), 160)
	check(player.position.z > 265.8 and player.position.y < 1, "Locked first-floor gate stops the player")
	tower.set_floor_key_collected(0, true)
	await physics_frame
	await walk_to(Vector3(208, 0, 264), 120)
	check(not tower.floor_unlocked(0) and player.position.z > 265.8, "A key alone cannot bypass the living guardian")
	tower.set_floor_key_collected(0, false)
	tower.mark_encounter_complete(0)
	await physics_frame
	await walk_to(Vector3(208, 0, 264), 120)
	check(not tower.floor_unlocked(0) and player.position.z > 265.8, "A defeated guardian alone cannot bypass the missing key")
	for index in range(11):
		tower.mark_encounter_complete(index)
		tower.set_floor_key_collected(index, true)
		await physics_frame
		check(tower.floor_unlocked(index) and tower._gate_collisions[index * 2].disabled, "Floor %d key and guardian open the physical gate" % (index + 1))
		player.position = tower.stair_entry(index)
		player.velocity = Vector3.ZERO
		await settle(10)
		await walk_to(Vector3(208, 0, 243.5), 500)
		check(absf(player.position.y - (index * 18 + 9)) < 0.4, "Floor %d lower flight reaches 9m landing" % (index + 1))
		await walk_to(Vector3(216, 0, 243.5), 200)
		await walk_to(Vector3(216, 0, 270), 500)
		check(absf(player.position.y - ((index + 1) * 18)) < 0.4, "Floor %d upper flight reaches next floor" % (index + 1))
		await walk_to(Vector3(104, 0, 270), 1500)
		await walk_to(Vector3(104, 0, 256), 250)
		check(player.position.z < 257 and absf(player.position.y - ((index + 1) * 18)) < 0.4, "Floor %d landing connects through the small hall doorway" % (index + 1))
	await validate_descents()
	player.position = tower.floor_spawn(0)
	player.velocity = Vector3.ZERO
	await settle(10)
	for frame in range(6000):
		await physics_frame
		if player.position.y > 17.8 and player.position.z < 258.5:
			break
		var target: Vector3 = tower.stair_waypoint(player.position, 1)
		var direction: Vector3 = target - player.position
		direction.y = 0
		direction = direction.normalized()
		player.velocity.x = direction.x * 10
		player.velocity.z = direction.z * 10
		player.velocity.y = -1 if player.is_on_floor() else player.velocity.y - 28.0 / 120.0
		if player.is_on_floor():
			player.try_step(direction * 10.0 / 120.0)
		player.move_and_slide()
	check(player.position.y > 17.8 and player.position.z < 258.5, "Navigation waypoints guide complete hall-to-hall ascent")
	tower.reveal_portal()
	check(tower.portal.visible, "Healing potion appears on terrace")
	check(tower.potion_position.distance_to(tower.exit_position) >= 10, "Potion and exit have separate interaction space")
	tower.set_potion_collected(true)
	check(not tower.portal.visible and tower._roof_exit.visible, "Collecting potion reveals return exit")
	print("TOWER_STAIR_VALIDATION failures=", failures)
	quit(1 if failures else 0)

func validate_descents() -> void:
	for index in range(tower.LAYOUT.FLOOR_COUNT - 1, -1, -1):
		tower.mark_encounter_complete(index)
		tower.set_floor_key_collected(index, true)
		await physics_frame
		player.position = Vector3(tower.LAYOUT.UPPER_FLIGHT_X, (index + 1) * tower.LAYOUT.FLOOR_HEIGHT + 0.12, 270)
		player.velocity = Vector3.ZERO
		await settle(10)
		await walk_to(Vector3(tower.LAYOUT.UPPER_FLIGHT_X, 0, 243.5), 500)
		check(absf(player.position.y - (index * tower.LAYOUT.FLOOR_HEIGHT + 9)) < 0.4, "Floor %d upper flight descends to the landing" % (index + 1))
		await walk_to(Vector3(tower.LAYOUT.LOWER_FLIGHT_X, 0, 243.5), 200)
		await walk_to(tower.stair_entry(index), 500)
		check(absf(player.position.y - index * tower.LAYOUT.FLOOR_HEIGHT) < 0.4 and player.position.z > 269, "Floor %d lower flight descends to its corridor" % (index + 1))

func settle(frames: int) -> void:
	for frame in range(frames):
		await physics_frame
		if door_assistance:
			tower.update_room_doors(PackedVector3Array([player.position]), 1.0 / 120.0)
		player.velocity = Vector3(0, -1, 0)
		player.move_and_slide()

func walk_to(target: Vector3, frames: int) -> void:
	for frame in range(frames):
		await physics_frame
		if door_assistance:
			tower.update_room_doors(PackedVector3Array([player.position]), 1.0 / 120.0)
		var diff: Vector3 = target - player.position
		diff.y = 0
		if diff.length() < 0.15:
			break
		var direction: Vector3 = diff.normalized()
		player.velocity.x = direction.x * 10
		player.velocity.z = direction.z * 10
		player.velocity.y = -1 if player.is_on_floor() else player.velocity.y - 28.0 / 120.0
		if player.is_on_floor():
			player.try_step(direction * 10.0 / 120.0)
		player.move_and_slide()
	await settle(5)

func check(condition: bool, detail: String) -> void:
	print("PASS: " if condition else "FAIL: ", detail, " ", player.position)
	if not condition:
		failures += 1
