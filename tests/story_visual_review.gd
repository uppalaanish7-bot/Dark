extends SceneTree
## Render the actual dialogue, memory stand, journal and both endings with a private profile.
const STORY = preload("res://scripts/story_data.gd")
var game: Node3D
var test_save: String
var output_dir: String
var failures := 0
var captures := 0

class ReviewGame extends "res://scripts/game.gd":
	func _notification(what: int) -> void:
		if what not in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: super._notification(what)

func _initialize() -> void:
	call_deferred("run")

func capture(tag: String) -> void:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if picture == null or picture.is_empty() or picture.save_png(output_dir.path_join(tag + ".png")) != OK:
		failures += 1
		push_error("Capture failed: " + tag)
	else:
		captures += 1
		print("STORY_CAPTURE ", tag, " size=", picture.get_size())
	# Every narrative panel and its buttons must remain inside the viewport.
	for panel in game.hud.modal_root.get_children():
		if panel is Panel and game.hud.modal_root.visible:
			var bounds: Rect2 = panel.get_global_rect()
			if not Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(bounds):
				failures += 1
				push_error("Panel outside viewport: " + tag)
			for control in panel.find_children("*", "Button", true, false):
				if not bounds.encloses(control.get_global_rect()):
					failures += 1
					push_error("Button outside panel: " + tag + " / " + control.text)

func place(index: int) -> void:
	game.player.position = STORY.echo_position(index) + Vector3(0, 0, 6.5)
	game.player.yaw = 0
	game.player.pitch = -0.08
	game.player.visual.rotation.y = 0
	game.player.update_camera(1)
	game.arena.update_floor_visibility(game.player.position)

func run() -> void:
	root.title = "Hero — The Borrowed Dawn review"
	root.size = Vector2i(1440, 900)
	output_dir = ProjectSettings.globalize_path("res://tests/story-review")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output_dir = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://ground.tscn").instantiate()
	game.set_script(ReviewGame)
	test_save = "user://borrowed_dawn_visual_%d.cfg" % Time.get_ticks_usec()
	game.settings_path = test_save
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	game.enter_world()
	if "--manual" in OS.get_cmdline_user_args():
		root.title = "Hero — The Borrowed Dawn live review"
		game.accept_quest()
		game.start_run()
		game.chronicle().clues = [1, 2]
		game.player.award_xp(40)
		game.arena.refresh_echoes(game.chronicle().clues)
		place(0)
		game.player.position = STORY.echo_position(0) + Vector3(0, 0, 3)
		game.player.invulnerable = 99999
		game.roaming_timer = 99999
		game.hud.banner_timer = 0
		game.capture_mouse = true
		game.capture_controls()
		print("PRIVATE_STORY_REVIEW_READY | T reads the nearby echo | J opens the journal | normal save untouched")
		return
	await capture("01_orin_intro_desktop")
	game.hud.show_story_dialogue(1)
	root.size = Vector2i(960, 600)
	await capture("02_orin_instructions_small")
	game.accept_quest()
	game.enter_portal()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.invulnerable = 99999
	root.size = Vector2i(1440, 900)
	place(0)
	game.hud.banner_timer = 0
	await capture("03_memory_stand")
	game.player.position = STORY.echo_position(0) + Vector3(0, 0, 3)
	game.inspect_echo()
	await capture("04_echo_journal_desktop")
	root.size = Vector2i(960, 600)
	await capture("05_echo_journal_small")
	game.chronicle().clues = [0, 1, 2]
	game.hud.show_journal("mysteries", 0)
	await capture("06_deduction_small")
	game.hud.show_journal("mysteries", 0, game.solve_mystery(0, 0))
	await capture("07_wrong_theory_small")
	game.hud.show_journal("mysteries", 0, game.solve_mystery(0, 1))
	await capture("08_resolved_small")
	game.hud.show_journal("echoes", 10)
	await capture("09_missing_echo_small")
	game.resume()
	game.return_to_courtyard()
	game.progress.current_world().quest = "healed"
	game.talk_to_elder(true)
	await capture("10_rescue_ending_small")
	game.chronicle().clues = range(11)
	game.chronicle().solved = [0, 1, 2]
	game.hud.show_story_dialogue()
	await capture("11_truth_ending_small")
	game.hud.show_story_dialogue(1)
	await capture("12_epilogue_small")
	game.close_story_dialogue()
	game.start_run()
	game.player.set_physics_process(false)
	place(0)
	game.player.position = STORY.echo_position(0) + Vector3(0, 0, 3)
	game.touch_controls.update_layout()
	game.hud.banner_timer = 0
	await capture("13_touch_echo_prompt")
	game.touch_controls.begin_touch(7, game.hud.journal_access.get_global_rect().get_center())
	await capture("14_touch_journal")
	print("BORROWED DAWN VISUAL: %d captures, %d failures" % [captures, failures])
	for id in game.CATALOG.requested.keys():
		game.CATALOG.scene_cache[id] = ResourceLoader.load_threaded_get(game.CATALOG.path_for(id))
		game.CATALOG.requested.erase(id)
	game.free()
	paused = false
	await process_frame
	await process_frame
	for prefix in [test_save, test_save.get_basename() + "_progress.cfg"]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(prefix + suffix): DirAccess.remove_absolute(prefix + suffix)
	quit(0 if failures == 0 else 1)

func _finalize() -> void:
	if test_save.is_empty(): return
	for prefix in [test_save, test_save.get_basename() + "_progress.cfg"]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(prefix + suffix): DirAccess.remove_absolute(prefix + suffix)
