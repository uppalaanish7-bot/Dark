extends SceneTree
## Real input, evidence deductions, one-time XP and isolated profile round trips.
const STORY = preload("res://scripts/story_data.gd")
const PROGRESS = preload("res://scripts/progress.gd")
var game: Node3D
var test_save: String
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int = 3) -> void:
	for frame in count:
		await process_frame
		await physics_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func button_named(caption: String) -> Button:
	for node in game.hud.modal_root.find_children("*", "Button", true, false):
		if node.text == caption: return node
	return null

func run() -> void:
	var invalid: Dictionary = STORY.sanitize({"clues": [-1, 0, 0, 1.0, "2", 12, null], "solved": [0, 1, 99]})
	check(invalid.clues == [0] and invalid.solved.is_empty(), "Malformed, duplicated and unsupported evidence cannot unlock a mystery")
	check(STORY.sanitize("bad").clues.is_empty(), "Malformed legacy narrative is safely ignored")
	check(not STORY.truth_known({"clues": [], "solved": [0, 1, 2]}), "A forged ending flag cannot replace its evidence")
	game = load("res://ground.tscn").instantiate()
	test_save = "user://borrowed_dawn_test_%d.cfg" % Time.get_ticks_usec()
	game.settings_path = test_save
	game.capture_mouse = false
	root.add_child(game)
	current_scene = game
	await frames()
	game.enter_world()
	await frames()
	check(game.state == "dialogue", "A new world introduces Greywake and Mara")
	var next := button_named("KEEP LISTENING")
	check(next != null, "Long introductions have a next-page button")
	if next: next.pressed.emit()
	var accept := button_named("I WILL HELP")
	check(accept != null, "The last introduction page offers the quest")
	if accept: accept.pressed.emit()
	game.enter_portal()
	await frames()
	game.set_process(false)
	game.player.set_physics_process(false)
	check(game.arena._echoes.size() == 11, "All eleven floors contain a memory stand")
	check(not game.inspect_echo() and game.chronicle().clues.is_empty(), "An echo cannot be collected remotely")
	key(KEY_J)
	check(game.state == "paused" and paused and game.hud.is_journal_open, "Physical J opens the journal and freezes gameplay")
	game.hud.show_journal("echoes", 0)
	var hidden: RichTextLabel = game.hud.modal_root.find_child("EchoBody", true, false)
	check(hidden != null and not hidden.text.contains("bolt was withdrawn"), "Undiscovered pages do not reveal their story text")
	check(game.solve_mystery(0, 1).contains("Recover all"), "Knowing an answer cannot skip gathering its clues")
	var track: Button = game.hud.modal_root.find_child("TrackEcho", true, false)
	check(track != null and not track.disabled, "Current-floor echoes can be tracked")
	if track: track.pressed.emit()
	check(game.state == "playing" and game.objective_position() == STORY.echo_position(0), "Tracking updates the real compass and resumes play")
	var expected_xp := 0
	for index in STORY.ECHOES.size():
		game.completed_encounters = index
		game.encounter_index = index
		for lower in index:
			game.floor_keys[lower] = true
			game.arena.mark_encounter_complete(lower)
			game.arena.set_floor_key_collected(lower)
		game.player.position = STORY.echo_position(index) + Vector3(0, 0, 3)
		await frames()
		check(game.arena.is_walkable(game.player.position), "Echo %02d can be approached on walkable ground" % index)
		var ground := PhysicsRayQueryParameters3D.create(game.player.position + Vector3.UP, game.player.position + Vector3.DOWN * 2, 1)
		check(not game.get_world_3d().direct_space_state.intersect_ray(ground).is_empty(), "Echo %02d has solid ground at the reading position" % index)
		check(game.nearby_echo_index() == index, "Only the nearby floor's echo is interactable")
		key(KEY_T)
		expected_xp += STORY.ECHO_XP
		check(game.has_echo(index) and game.hud.is_journal_open and paused, "Physical T collects echo %02d and opens its page" % index)
		check(game.player.growth.xp == expected_xp, "A new echo awards exactly its discovery XP")
		check(game.arena._echoes[index].label.text == "ECHO RECORDED", "The memory stand reflects collection")
		game.resume()
		key(KEY_T)
		check(game.player.growth.xp == expected_xp, "Rereading echo %02d never awards duplicate XP" % index)
		if index in [2, 6, 10]:
			var case_index := 0 if index == 2 else (1 if index == 6 else 2)
			var mystery: Dictionary = STORY.MYSTERIES[case_index]
			game.hud.show_journal("mysteries", case_index)
			var wrong: String = game.solve_mystery(case_index, (int(mystery.answer) + 1) % 3)
			check(not wrong.is_empty() and case_index not in game.chronicle().solved and game.player.growth.xp == expected_xp, "An unsupported theory is explained without a reward or penalty")
			var correct: Button = game.hud.modal_root.find_child("Theory%d" % mystery.answer, true, false)
			check(correct != null, "Complete evidence exposes the deduction choices")
			if correct: correct.pressed.emit()
			expected_xp += int(mystery.xp)
			check(case_index in game.chronicle().solved and game.player.growth.xp == expected_xp, "The chosen theory resolves the correct mystery and awards its XP once")
			game.solve_mystery(case_index, mystery.answer)
			check(game.player.growth.xp == expected_xp, "A solved mystery cannot be rewarded again")
		key(KEY_J)
		check(game.state == "playing" and not paused, "J resumes after reading or solving")
	check(expected_xp == 610 and STORY.truth_known(game.chronicle()), "The eleven echoes and three mysteries unlock the complete truth")
	check(game.save_current_session(), "Narrative and XP save in one profile transaction")
	var profile_path: String = test_save.get_basename() + "_progress.cfg"
	var loaded := PROGRESS.new(profile_path)
	loaded.load_progress()
	check(loaded.current_world().chronicle == game.chronicle(), "Evidence and deductions survive a fresh disk load")
	check(loaded.session_for_world().growth.xp == expected_xp, "The same disk transaction preserves the narrative XP")
	var world_id: int = game.progress.active_world
	game.show_menu()
	check(game.progress.create_world("Another story"), "A second world can be created")
	game.enter_world()
	game.accept_quest()
	check(game.chronicle().clues.is_empty() and game.chronicle().solved.is_empty() and game.player.growth.xp == 0, "New worlds share neither clues nor story XP")
	game.show_menu()
	game.progress.select_world(world_id)
	game.enter_world()
	await frames()
	game.player.set_physics_process(false)
	check(STORY.truth_known(game.chronicle()) and game.player.growth.xp == expected_xp, "Returning to the first world restores its discoveries and rewards")
	game.return_to_courtyard()
	check(STORY.truth_known(game.chronicle()), "Visiting Orin preserves tower evidence")
	game.progress.current_world().quest = "healed"
	game.talk_to_elder(true)
	game.hud.show_story_dialogue(1)
	var ending: RichTextLabel = game.hud.modal_root.find_child("StoryDialogueBody", true, false)
	check(ending != null and ending.text.contains("THE NAMES WE CARRY"), "The full ending is available after healing, so clues cannot be permanently missed")
	check(STORY.dialogue("healed", STORY.sanitize({}), 0)[0].contains("DAWN RESTORED"), "The original rescue still has an ending without optional mysteries")
	check(STORY.dialogue("active", {"clues":[0,1,2], "solved":[0]}, 0)[0].contains("crescent is mine"), "Orin responds to newly resolved evidence")
	game.close_story_dialogue()
	game.progress.active_world = -1
	check(not game.inspect_echo() and not game.can_track_echo(0), "A stale runtime cannot modify another world's story")
	game.progress.active_world = world_id
	# Legacy profiles receive an empty chronicle while retaining their campaign.
	var config := ConfigFile.new()
	config.load(profile_path)
	var old_worlds: Array = config.get_value("profile", "worlds")
	for world in old_worlds: world.erase("chronicle")
	config.set_value("profile", "worlds", old_worlds)
	var legacy_path := test_save.get_basename() + "_legacy.cfg"
	config.save(legacy_path)
	var legacy := PROGRESS.new(legacy_path)
	legacy.load_progress()
	check(legacy.current_world().chronicle.clues.is_empty() and legacy.session_for_world().growth.xp == expected_xp, "Existing saves gain the story without resetting their XP or checkpoint")
	# This abbreviated test can end before background guardian previews load.
	for id in game.CATALOG.requested.keys():
		game.CATALOG.scene_cache[id] = ResourceLoader.load_threaded_get(game.CATALOG.path_for(id))
		game.CATALOG.requested.erase(id)
	game.free()
	paused = false
	await process_frame
	await process_frame
	for prefix in [test_save, profile_path, legacy_path]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(prefix + suffix): DirAccess.remove_absolute(prefix + suffix)
	print("BORROWED DAWN: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
