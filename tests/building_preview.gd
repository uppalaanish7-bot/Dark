extends SceneTree
## Reproducible views of the actual imported building in the story world.
var game: Node3D
var capture_errors := 0
const OUTPUT := "res://art/hollow_spire/previews/"
const CAMERA_FAR := 650.0

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUTPUT + filename + ".png")
	if error != OK:
		push_error("Could not save building preview: " + filename)
		capture_errors += 1

func camera_view(position: Vector3, target: Vector3, fov: float) -> void:
	game.menu_camera.position = position
	game.menu_camera.look_at(target)
	game.menu_camera.fov = fov
	game.menu_camera.near = 1.0 if position.distance_to(target) > 50.0 else 0.08
	game.menu_camera.far = CAMERA_FAR
	game.menu_camera.make_current()

func hide_portal_overlays() -> Dictionary:
	# Inspect the imported stone room without the courtyard's translucent veil.
	# Save each prior state so the following gameplay capture keeps its portal.
	var overlays: Array[Node3D] = [game.story_world.portal_surface]
	for ring in game.story_world.portal_rings:
		overlays.append(ring)
	for child in game.story_world.get_children():
		if child is Label3D and child.text == "THE HOLLOW SPIRE":
			overlays.append(child)
	var visibility := {}
	for overlay in overlays:
		visibility[overlay] = overlay.visible
		overlay.hide()
	return visibility

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	game = load("res://ground.tscn").instantiate()
	game.settings_path = "user://building_preview_%d.cfg" % Time.get_ticks_usec()
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	game.menu_camera.far = CAMERA_FAR
	game.player.camera.far = CAMERA_FAR
	await capture("lobby")
	game.enter_world()
	game.accept_quest()
	await process_frame
	game.hud.hide()
	game.touch_controls.hide()
	game.player.hide()
	# Imported bounds in this world: x=-80..80, y=0..150, z=-90..-10.
	camera_view(Vector3(165, 100, 145), Vector3(0, 68, -50), 50)
	await capture("building_overview")
	camera_view(Vector3(46, 2.2, 92), Vector3(-3, 67, -50), 76)
	await capture("building_low_angle")
	camera_view(Vector3(6.5, 2.6, 1.8), Vector3(0, 2.8, -11.2), 65)
	await capture("building_entrance")
	camera_view(Vector3(-165, 103, -244), Vector3(0, 70, -50), 50)
	await capture("building_rear")
	camera_view(Vector3(100, 206, 36), Vector3(0, 124, -50), 52)
	await capture("building_roof")
	var overlay_visibility := hide_portal_overlays()
	camera_view(Vector3(0.7, 2, -10.35), Vector3(0, 2, -16), 82)
	await capture("building_vestibule")
	for overlay in overlay_visibility:
		overlay.visible = overlay_visibility[overlay]
	game.player.show()
	game.hud.show()
	game.player.position = Vector3(0, 0.1, 22)
	game.player.yaw = 0
	game.player.pitch = 0.65
	game.player.update_camera(1)
	game.player.camera.make_current()
	await capture("building_gameplay")
	if capture_errors == 0:
		print("BUILDING_RENDER_OK draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var settings: String = game.settings_path
	var progress: String = game.progress.path
	game.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(progress + suffix)
	DirAccess.remove_absolute(settings)
	quit(0 if capture_errors == 0 else 1)
