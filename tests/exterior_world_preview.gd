extends "res://tests/exterior_world_tests.gd"
var camera: Camera3D
func capture(label: String, at: Vector3, focus: Vector3, fov: float = 67) -> void:
	camera.position = at
	camera.look_at(focus)
	camera.fov = fov
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/exterior_" + label + ".png")
	print("EXTERIOR_CAPTURE ", label, " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " triangles=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
func run() -> void:
	var holder := ReviewGame.new()
	root.add_child(holder)
	holder.add_child(holder.player)
	var world: Node3D = load("res://scripts/story_world.gd").new()
	world.game = holder
	holder.add_child(world)
	holder.player.position = world.SPAWN
	camera = Camera3D.new()
	camera.near = 0.2
	camera.far = 1500
	holder.add_child(camera)
	camera.make_current()
	await capture("arrival", Vector3(0, 5, 184), Vector3(0, 55, -35), 66)
	await capture("estate", Vector3(202, 144, 270), Vector3(0, 39, 22), 67)
	await capture("gate", Vector3(15, 5, 36), Vector3(0, 11, -10), 65)
	await capture("side", Vector3(163, 12, 33), Vector3(20, 39, -47), 69)
	print("EXTERIOR_PREVIEW_OK")
	quit()
