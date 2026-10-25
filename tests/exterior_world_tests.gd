extends SceneTree
class ReviewProgress extends RefCounted:
	func current_world() -> Dictionary:
		return {"quest": "active"}
class ReviewGame extends Node3D:
	var progress := ReviewProgress.new()
	var player := CharacterBody3D.new()
	var state: String = "world"
	func enter_portal() -> void:
		pass
var failures: int = 0
var checks: int = 0
func expect(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var holder := ReviewGame.new()
	root.add_child(holder)
	holder.add_child(holder.player)
	var world: Node3D = load("res://scripts/story_world.gd").new()
	world.game = holder
	holder.add_child(world)
	holder.player.position = world.SPAWN
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for x in [-210.0, -160.0, -108.0, -50.0, 0.0, 50.0, 108.0, 160.0, 210.0]:
		for z in [-225.0, -150.0, -105.0, -2.0, 55.0, 100.0, 160.0, 225.0]:
			var ray := PhysicsRayQueryParameters3D.create(Vector3(x, 0.15, z), Vector3(x, -2, z), 1)
			var hit: Dictionary = space.intersect_ray(ray)
			expect(not hit.is_empty() and absf(hit.position.y) < 0.01, "Missing continuous ground at %s" % Vector2(x, z))
	for side in [-1.0, 1.0]:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(side * 224, 2, 0), Vector3(side * 232, 2, 0), 1)
		expect(not space.intersect_ray(ray).is_empty(), "Side perimeter blocks leaving ground")
		ray = PhysicsRayQueryParameters3D.create(Vector3(0, 2, side * 244), Vector3(0, 2, side * 252), 1)
		expect(not space.intersect_ray(ray).is_empty(), "End perimeter blocks leaving ground")
	for x in [-1.1, 0.0, 1.1]:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(x, 1.0, -4), Vector3(x, 1.0, -10.7), 1)
		expect(space.intersect_ray(ray).is_empty(), "Door approach must be clear at x=%s" % x)
	expect(world.contains_player_position(world.SPAWN), "Spawn is within movement bounds")
	expect(world.contains_player_position(Vector3(0, 0.1, 18)), "Old courtyard save stays supported")
	print("EXTERIOR_GROUNDS_RESULT: %d checks, %d failures" % [checks, failures])
	holder.queue_free()
	await process_frame
	quit(failures)
