extends SceneTree
## Drives the real character against the shipped world and collision geometry.
var game: Node3D
var checks: int = 0
var failures: Array[String] = []
var save_path: String
var lowest_y: float = 1000.0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("CONTACT CHECK: " + message)

func release() -> void:
	for action in ["forward", "back", "left", "right", "sprint"]:
		Input.action_release(action)

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
		if is_instance_valid(game): lowest_y = minf(lowest_y, game.player.position.y)

func settle_at(point: Vector3) -> void:
	release()
	game.player.position = point
	game.player.velocity = Vector3.ZERO
	game.player.external_velocity = Vector3.ZERO
	game.player.dash_timer = 0
	game.player.jump_buffer = 0
	await frames(20)

func run_to(point: Vector3, label: String) -> void:
	var initial: Vector3 = game.player.position
	var distance: float = Vector2(point.x - initial.x, point.z - initial.z).length()
	var frame_limit: int = ceili((distance / 13.0 + 2.0) * 60.0)
	var before: int = game.player.recovery_count
	var start_state: String = game.state
	Input.action_press("sprint")
	Input.action_press("forward")
	for i in range(frame_limit):
		var offset: Vector3 = point - game.player.position
		offset.y = 0
		if offset.length() < 0.55 or game.state != start_state: break
		game.player.yaw = atan2(-offset.x, -offset.z)
		await frames(1)
	release()
	var remaining: float = Vector2(point.x - game.player.position.x, point.z - game.player.position.z).length()
	check(remaining < 0.65 or game.state != start_state, "%s traversed physically (remaining %.2fm, at %s)" % [label, remaining, game.player.position])
	check(game.player.recovery_count == before, "%s needs no geometry rescue" % label)
	await frames(12)

func solid(point: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = point
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	game.story_world.add_child(body)
	return body

func run() -> void:
	save_path = "user://cathedral_contact_%d.cfg" % Time.get_ticks_usec()
	game = load("res://ground.tscn").instantiate()
	game.settings_path = save_path
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	await frames(3)
	game.progress.set_quest("active")
	game.begin_courtyard()
	game.set_process(false)
	await frames(30)
	check(game.player.is_on_floor() and game.player.supported_pose(game.player.position), "Exterior spawn settles on a clear supported surface")
	var mana_start: float = 38.0
	game.player.mana = mana_start
	await run_to(Vector3(0, 0, 210), "Approach behind the refuge")
	check(game.player.mana > mana_start, "Sustained natural sprint restores mana")
	await run_to(Vector3(120, 0, 210), "East grounds")
	await run_to(Vector3(120, 0, -130), "East side of the complete tower")
	await run_to(Vector3(-120, 0, -130), "Rear grounds behind the complete tower")
	await run_to(Vector3(-120, 0, 210), "West side of the complete tower")
	await run_to(Vector3(0, 0, 210), "Return through the west grounds")
	check(lowest_y > -0.05, "Full exterior loop never falls below the continuous floor")
	# A small masonry lip should be climbed without jumping; a real wall must block.
	var curb: StaticBody3D = solid(Vector3(20, 0.14, 210), Vector3(4, 0.28, 6))
	await settle_at(Vector3(14, 0.12, 210))
	game.player.yaw = -PI * 0.5
	Input.action_press("forward")
	var highest: float = game.player.position.y
	var recoveries: int = game.player.recovery_count
	for i in range(90):
		await frames(1)
		highest = maxf(highest, game.player.position.y)
	release()
	check(highest > 0.23 and game.player.position.x > 24, "Controller steps over a 28cm curb without jumping")
	check(game.player.recovery_count == recoveries, "Stepping over a curb does not invoke recovery")
	curb.queue_free()
	await frames(3)
	var wall: StaticBody3D = solid(Vector3(40, 2, 210), Vector3(1, 4, 12))
	await settle_at(Vector3(35, 0.12, 210))
	game.player.yaw = 0
	Input.action_press("right")
	await frames(80)
	release()
	check(game.player.position.x < 39.2 and game.player.position.x > 38.8, "A four-metre wall blocks movement without climbing or penetration")
	check(game.player.pose_clear(game.player.position), "Capsule remains clear while pressing into a wall")
	var wall_z: float = game.player.position.z
	Input.action_press("right")
	Input.action_press("forward")
	await frames(42)
	release()
	check(game.player.position.z < wall_z - 3, "Diagonal input slides along a wall instead of sticking")
	check(game.player.recovery_count == recoveries, "Ordinary wall contact never needs recovery")
	wall.queue_free()
	await settle_at(Vector3(0, 0.12, 215))
	game.player.jump_buffer = 0.15
	await frames(10)
	check(not game.player.is_on_floor() and game.player.velocity.y > 0, "Ground jump launches immediately")
	game.player.jump_buffer = 0.15
	await frames(2)
	check(game.player.air_jumps == 0 and game.player.velocity.y > 8, "Second jump is an independent air impulse")
	var previous_vertical: float = game.player.velocity.y
	game.player.jump_buffer = 0.15
	await frames(3)
	check(game.player.air_jumps == 0 and game.player.velocity.y < previous_vertical, "Repeated jump input cannot grant a third jump")
	await frames(65)
	check(game.player.is_on_floor() and game.player.air_jumps == 1, "Landing restores the next double jump")
	game.player.mana = 50
	game.player.dash_cooldown = 0
	var dodge_start: Vector3 = game.player.position
	game.player.dodge()
	await frames(18)
	check(game.player.position.distance_to(dodge_start) > 5, "Dodge makes a committed agile displacement on the floor")
	check(game.player.mana >= 50, "Dodge and landing never consume movement mana")
	await settle_at(Vector3(0, 0.12, 210))
	var anchor: Vector3 = game.player.safe_position
	var hp: float = game.player.health
	recoveries = game.player.recovery_count
	game.player.position = Vector3(500, 0.1, 500)
	await frames(25)
	check(game.player.recovery_count == recoveries + 1 and game.player.position.distance_to(anchor) < 0.3, "Out-of-bounds pose recovers once to the last validated exterior anchor")
	check(game.player.supported_pose(game.player.position) and game.player.health == hp, "Geometry recovery preserves health and a supported pose")
	recoveries = game.player.recovery_count
	game.player.position.y = -9
	await frames(25)
	check(game.player.recovery_count == recoveries + 1 and game.state == "world", "A fallen pose recovers once without changing scenes")
	var embed: StaticBody3D = solid(Vector3(5, 1.5, 210), Vector3(3, 3, 3))
	await frames(3)
	recoveries = game.player.recovery_count
	game.player.position = Vector3(5, 0.03, 210)
	await frames(40)
	check(game.player.pose_clear(game.player.position) and game.player.supported_pose(game.player.position), "An embedded capsule escapes to a supported clear location")
	check(game.player.recovery_count <= recoveries + 1, "Embedded-body recovery cannot loop each frame")
	embed.queue_free()
	await settle_at(Vector3(223.8, 0.12, 205))
	game.player.yaw = -PI * 0.5
	recoveries = game.player.recovery_count
	Input.action_press("forward")
	await frames(100)
	release()
	check(game.player.position.x < 224.0 and game.player.position.x > 223.7, "World edge clamps into a stable supported contact")
	check(game.player.recovery_count == recoveries, "Holding movement into the perimeter never loops teleports")
	await settle_at(Vector3(0, 0.12, 5))
	await run_to(Vector3(0, 0, -14), "The actual tower doorway")
	check(game.state == "playing" and game.arena.is_inside_tree() and not game.story_world.is_inside_tree(), "Walking through the doorway enters the interior scene")
	check(game.player.visual.weapon_enabled, "Interior entry equips the supplied sword")
	await frames(25)
	await run_to(Vector3(0, 0, -216), "Full interior nave from the entry to the sovereign throne")
	check(game.player.supported_pose(game.player.position), "The throne approach is collision-supported")
	anchor = game.player.safe_position
	recoveries = game.player.recovery_count
	game.player.position = Vector3(400, -12, 400)
	await frames(25)
	check(game.state == "playing" and game.player.recovery_count == recoveries + 1 and game.player.position.distance_to(anchor) < 0.3, "Interior recovery uses its interior anchor instead of the exterior spawn")
	check(game.player.health == hp, "Traversal, walls, jumps and recovery never drain vitality")
	release()
	var progress_path: String = game.progress.path
	for id in game.CATALOG.requested.keys():
		var prefetched: Node = game.CATALOG.instantiate(id)
		if is_instance_valid(prefetched): prefetched.free()
	# Fixed-fps headless traversal outruns the audio mix thread; release its live
	# playbacks before shutting the engine down so the test has a clean teardown.
	for voice in game.sound.voices:
		voice.stop()
		voice.stream = null
	game.sound.ambience.stop()
	game.sound.ambience.stream = null
	OS.delay_msec(120)
	game.queue_free()
	await frames(3)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(progress_path + suffix)
	DirAccess.remove_absolute(save_path)
	print("MOVEMENT CONTACT: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures: print("FAILED: ", failure)
	quit(0 if failures.is_empty() else 1)
