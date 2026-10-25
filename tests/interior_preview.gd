extends SceneTree
var arena: Node3D
var camera: Camera3D
func _initialize() -> void:
	call_deferred("run")
func capture(label: String, at: Vector3, target: Vector3, fov: float = 65) -> void:
	camera.position = at
	camera.look_at(target)
	camera.fov = fov
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/interior_" + label + ".png")
	print("CAPTURE ", label, " | draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " | primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
func run() -> void:
	arena = load("res://scripts/arena.gd").new()
	root.add_child(arena)
	camera = Camera3D.new()
	camera.near = 0.2
	camera.far = 580
	arena.add_child(camera)
	camera.make_current()
	arena.set_encounter(0)
	await capture("arrival", Vector3(0, 5.5, 195), Vector3(-12, 13, 97), 73)
	await capture("court", Vector3(-34, 6, 170), Vector3(-44, 4, 132), 72)
	await capture("vault", Vector3(23, 8, 160), Vector3(0, 65, 20), 74)
	arena.set_encounter(10)
	arena.reveal_portal()
	await create_timer(1.9).timeout
	await capture("portal", Vector3(9, 5, -205), Vector3(0, 5, -222), 64)
	print("INTERIOR_RENDER_OK")
	quit()
