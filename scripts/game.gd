extends Node3D
const ART = preload("res://scripts/visuals.gd")
const ENEMY = preload("res://scripts/enemy.gd")
const ENCOUNTERS = preload("res://scripts/encounter_data.gd")
const CATALOG = preload("res://scripts/asset_catalog.gd")
const CAMPAIGN = preload("res://scripts/campaign_data.gd")
const SESSION = preload("res://scripts/world_session.gd")
const LAYOUT = preload("res://scripts/tower_layout.gd")
const STORY = preload("res://scripts/story_data.gd")
const SESSION_SAVE_INTERVAL := 10.0
const MAX_SUMMONED_SOLDIERS := 12
const ARENA_STORY_BRIEFING := "Climb the eleven-floor boss tower. Defeat each guardian and its faction, then ride the central lift to the next arena. The Grand Guard awaits on floor ten; the Sovereign holds the summit."
var encounter_index: int = 0
var encounter_active: bool = false
var completed_encounters: int = 0
var level_complete: bool = false
var potion_collected: bool = false
var portal_cooldown: float = 0.0
var progress: RefCounted
var current_level: int = 1
var run_coins: int = 0
var bosses_alive: int = 11
var stage_boss_defeated: bool = false
var stage_clear_delay: float = -1.0
var lift_activated: bool = false
var lift_transition_active: bool = false
var last_health_restore_floor: int = 0
var health_restore_count: int = 0
var ally_bot: CharacterBody3D
var state: String = "menu"
var player: CharacterBody3D
var arena: Node3D
var story_world: Node3D
var paused_from: String = "playing"
var hud: Control
var fx: Node3D
var sound: Node
var menu_camera: Camera3D
var combatants: Node3D
var pickups: Node3D
var wave: int = 0
var score: int = 0
var kills: int = 0
var shots: int = 0
var hits: int = 0
var best_score: int = 0
var wave_timer: float = 0
var spawn_timer: float = 0
var spawn_remaining: int = 0
var pending_floor_soldiers: Array[Vector3] = []
var floor_soldier_spawn_stage: int = -1
var combo: int = 0
var combo_timer: float = 0
var elapsed: float = 0
var sensitivity: float = 0.0025
var camera_shake: bool = true
var selected_skin: int = 0
var volume: float = 0.7
var render_scale: float = 1.0
var session_id: int = 0
var settings_path: String = "user://relic_settings.cfg"
var mobile_controls: bool = false
var capture_mouse: bool = true
var touch_controls: Control
var browser_pause_callback: JavaScriptObject
var runtime_world_id: int = 0
var session_save_timer: float = SESSION_SAVE_INTERVAL
var session_save_error: String = ""
var floor_keys: Array[bool] = [false,false,false,false,false,false,false,false,false,false,false]
var discovered_rooms: Array[int] = [0,0,0,0,0,0,0,0,0,0,0]
var roaming_timer: float = 16.0
var exploration_floor: int = -1
var tracked_echo: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mobile_controls = not capture_mouse or OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available() or "--touch-controls" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		capture_mouse = bool(JavaScriptBridge.eval("window.relicMouseCapture !== false"))
		mobile_controls = mobile_controls or bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0"))
		browser_pause_callback = JavaScriptBridge.create_callback(func(_args: Array) -> void: call_deferred("pause_game"))
		JavaScriptBridge.get_interface("window").relicPause = browser_pause_callback
		JavaScriptBridge.eval("document.addEventListener('pointerlockchange', () => { if (!document.pointerLockElement) window.relicPause(); }); document.addEventListener('visibilitychange', () => { if (document.hidden) window.relicPause(); });")
	if mobile_controls:
		get_tree().quit_on_go_back = false
		get_window().content_scale_size = Vector2i(960, 600)
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		get_viewport().scaling_3d_scale = 0.75
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	setup_input()
	load_settings()
	set_render_scale(render_scale)
	progress = preload("res://scripts/progress.gd").new(settings_path.get_basename() + "_progress.cfg")
	progress.load_progress()
	arena = preload("res://scripts/tower_arena.gd").new()
	add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	story_world = preload("res://scripts/story_world.gd").new()
	story_world.game = self
	add_child(story_world)
	story_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	remove_child(story_world)
	fx = preload("res://scripts/effects.gd").new()
	fx.name = "Effects"
	add_child(fx)
	fx.process_mode = Node.PROCESS_MODE_PAUSABLE
	sound = preload("res://scripts/sound.gd").new()
	add_child(sound)
	combatants = Node3D.new()
	add_child(combatants)
	combatants.process_mode = Node.PROCESS_MODE_PAUSABLE
	pickups = Node3D.new()
	add_child(pickups)
	pickups.process_mode = Node.PROCESS_MODE_PAUSABLE
	player = preload("res://player.tscn").instantiate()
	player.game = self
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.visual.set_skin(selected_skin)
	menu_camera = Camera3D.new()
	menu_camera.fov = 43
	menu_camera.near = 1.0
	menu_camera.far = 650
	add_child(menu_camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = preload("res://scripts/hud.gd").new()
	hud.game = self
	layer.add_child(hud)
	touch_controls = preload("res://scripts/touch_controls.gd").new()
	touch_controls.game = self
	layer.add_child(touch_controls)
	set_volume(volume)
	if progress.has_visited_world():
		enter_world()
	else:
		show_menu()

func setup_input() -> void:
	var bindings := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "jump": KEY_SPACE, "sprint": KEY_SHIFT, "ultimate": KEY_R, "magic_slash": KEY_Q, "dodge": KEY_CTRL, "melee": KEY_V, "shoulder": KEY_E, "pause_game": KEY_ESCAPE, "interact": KEY_T, "hero_growth":KEY_U, "journal":KEY_J}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = bindings[action]
		InputMap.action_add_event(action, key)
	for action in ["fire", "aim"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT if action == "fire" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, button)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("journal") and not event.is_echo():
		if state == "paused" and hud.is_journal_open: resume()
		elif state in ["playing", "world", "paused"]: hud.open_journal()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("hero_growth") and not event.is_echo():
		if state == "paused" and hud.is_growth_open: resume()
		elif state in ["playing","world","paused"]: hud.open_growth()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause_game"):
		if state in ["playing", "world"]:
			pause_game()
		elif state == "paused":
			resume()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact") and not event.is_echo() and state in ["world", "playing"]:
		interact()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var mode: int = DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		save_current_session()
		if what != NOTIFICATION_WM_CLOSE_REQUEST and state in ["playing", "world"]:
			pause_game()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state in ["playing", "world"]:
			pause_game()
		elif state == "paused":
			resume()

func capture_controls() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mobile_controls or not capture_mouse else Input.MOUSE_MODE_CAPTURED

func release_controls() -> void:
	player.release_input()
	if is_instance_valid(touch_controls):
		touch_controls.release_all()

func show_menu() -> void:
	save_current_session()
	runtime_world_id = 0
	get_tree().paused = false
	state = "menu"
	release_controls()
	clear_run()
	activate_place(false)
	player.reset()
	player.visual.weapon_enabled = false
	player.visual.weapon.hide()
	player.position = Vector3(2.5, 0.06, 13)
	player.visual.rotation.y = 0.48
	player.visual.show()
	menu_camera.position = Vector3(140, 78, 170)
	menu_camera.look_at(Vector3(0, 69, -50))
	menu_camera.fov = 50
	menu_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_menu()

func select_skin(index: int) -> void:
	if state != "menu":
		return
	selected_skin = posmod(index, 2)
	player.visual.set_skin(selected_skin)
	save_settings()

func start_run() -> void:
	begin_arena()

func begin_arena(_saved: Dictionary = {}) -> void:
	if progress.current_world().is_empty():
		if progress.worlds.is_empty():
			progress.create_world("The Hollow Spire")
		else:
			progress.select_world(progress.worlds[0].id)
	get_tree().paused = false
	activate_place(true)
	runtime_world_id = int(progress.current_world().id)
	current_level = 1
	clear_run()
	state = "playing"
	score = 0
	kills = 0
	shots = 0
	hits = 0
	run_coins = 0
	elapsed = 0
	combo = 0
	combo_timer = 0
	encounter_index = 0
	completed_encounters = 0
	encounter_active = true
	stage_boss_defeated = false
	stage_clear_delay = -1.0
	lift_activated = false
	lift_transition_active = false
	last_health_restore_floor = 0
	health_restore_count = 0
	level_complete = false
	potion_collected = false
	arena.reset_progress()

	# Every attempt starts on floor one. Only its guardian and retinue spawn.
	bosses_alive = 11
	if is_instance_valid(arena) and arena.has_method("set_stage"):
		arena.set_stage(0)

	# Spawn Player at Vector3(-4, 0.12, 95)
	# Matches restart with fresh opponents, while the selected world's earned
	# hero levels survive retries, switching worlds and reopening the app.
	player.restore_growth(progress.session_for_world(runtime_world_id).growth)
	player.reset()
	player.visual.set_skin(selected_skin)
	player.visual.weapon_enabled = true
	player.visual.weapon.show()
	player.position = Vector3(-4.0, 0.12, 95.0)
	player.yaw = PI
	player.pitch = -0.15
	player.update_camera(1)
	player.camera.make_current()

	# Spawn Ally Bot at Vector3(4, 0.12, 95) with other skin
	if is_instance_valid(ally_bot):
		ally_bot.queue_free()
	ally_bot = preload("res://scripts/ally_bot.gd").new()
	ally_bot.game = self
	ally_bot.bot_skin_index = 1 - selected_skin
	ally_bot.position = Vector3(4.0, 0.12, 95.0)
	combatants.add_child(ally_bot)

	# The next guardian is gated behind a cleared encounter and a completed lift ride.
	spawn_all_bosses()

	hud.show_game()
	capture_controls()
	hud.announce("THE DRAGON CORE", ARENA_STORY_BRIEFING)
	hud.banner_timer = 8.0
	sound.play("wave")
	save_current_session()

func spawn_all_bosses() -> void:
	spawn_battle_stage(0)

func spawn_battle_stage(stage: int) -> void:
	if stage < 0 or stage >= 11 or state != "playing":
		return
	pending_floor_soldiers.clear()
	floor_soldier_spawn_stage = -1
	encounter_index = stage
	stage_boss_defeated = false
	stage_clear_delay = -1.0
	if arena.has_method("set_stage"):
		arena.set_stage(stage)
	var data: Dictionary = ENCOUNTERS.record(stage)
	var center: Vector3 = player.global_position
	var forward := Vector3(sin(player.yaw), 0.0, cos(player.yaw))
	var boss_pos: Vector3 = center + forward * 23.0
	boss_pos = arena.clamp_to_stage(boss_pos, 7.0) if arena.has_method("clamp_to_stage") else boss_pos
	boss_pos.y = float(stage) * LAYOUT.FLOOR_HEIGHT + 0.12
	var boss: CharacterBody3D = spawn_actor(true, boss_pos, stage)
	boss.home_position = boss_pos
	queue_floor_soldiers(stage, boss_pos, forward, int(data.soldiers))
	hud.announce(data.name + "  /  " + data.title.to_upper(), data.description)
	hud.banner_timer = 5.0
	sound.play("wave")

func advance_battle_stage() -> void:
	if not stage_boss_defeated or active_encounter_foes() > 0 or floor_soldier_spawn_stage >= 0 or lift_activated or lift_transition_active:
		return
	stage_clear_delay = -1.0
	if encounter_index >= 10:
		finish(true)
		return
	completed_encounters = encounter_index + 1
	if is_instance_valid(arena) and arena.has_method("mark_stage_complete"):
		arena.mark_stage_complete(encounter_index)
	lift_activated = true
	if is_instance_valid(arena) and arena.has_method("activate_elevator"):
		arena.activate_elevator(encounter_index)
	prefetch_next_floor()
	hud.announce("FLOOR %02d CLEARED" % (encounter_index + 1), "The central lift is active. Step onto its platform to ascend.")
	sound.play("portal")
	save_current_session()

func start_lift_transition() -> void:
	if state != "playing" or not lift_activated or lift_transition_active or active_encounter_foes() > 0:
		return
	if not arena.player_is_on_elevator(player):
		return
	var riders: Array[CharacterBody3D] = [player]
	if is_instance_valid(ally_bot) and not ally_bot.is_queued_for_deletion():
		ally_bot.global_position = player.global_position + Vector3(2.4, 0.0, 2.0)
		riders.append(ally_bot)
	var next_floor: int = encounter_index + 1
	lift_transition_active = true
	lift_activated = false
	release_controls()
	state = "lift"
	if not arena.ride_elevator_to_floor(next_floor, riders):
		state = "playing"
		lift_transition_active = false
		lift_activated = true
		capture_controls()
		return
	hud.announce("ASCENDING TO FLOOR %02d" % (next_floor + 1), "The central lift is carrying your party upward.")

func on_lift_arrived(floor_index: int) -> void:
	if state != "lift" or not lift_transition_active or floor_index != encounter_index + 1 or floor_index >= 11:
		return
	lift_transition_active = false
	state = "playing"
	encounter_index = floor_index
	if last_health_restore_floor != floor_index:
		player.health = player.max_health
		player.mana = player.max_mana
		player.mana_regen_delay = 0.0
		last_health_restore_floor = floor_index
		health_restore_count += 1
	player.growth_feedback = "Floor transition complete · Health and mana restored."
	stage_boss_defeated = false
	stage_clear_delay = -1.0
	lift_activated = false
	encounter_active = true
	spawn_battle_stage(floor_index)
	capture_controls()
	save_current_session()

func spawn_soldier_for_boss(boss: CharacterBody3D, spawn_pos: Vector3 = Vector3.ZERO) -> CharacterBody3D:
	if not is_instance_valid(boss) or boss.dead or state != "playing":
		return null
	if active_floor_soldier_count(boss.encounter_index) >= ENCOUNTERS.SOLDIERS_PER_FLOOR:
		return null
	var active_soldiers := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.dead and not enemy.is_queued_for_deletion() and is_instance_valid(enemy.get("summoner_boss")):
			active_soldiers += 1
	if active_soldiers >= MAX_SUMMONED_SOLDIERS:
		return null
	if spawn_pos == Vector3.ZERO:
		var offset := Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
		spawn_pos = boss.global_position + offset
	var soldier: CharacterBody3D = spawn_actor(false, spawn_pos, boss.encounter_index)
	soldier.summoner_boss = boss
	soldier.home_position = spawn_pos
	fx.burst(spawn_pos + Vector3.UP, boss.color, 16)
	fx.ring(spawn_pos, 2.0, boss.color, 0.6)
	sound.play("enemy_cast", -8)
	return soldier

func active_floor_soldier_count(stage: int) -> int:
	var count: int = 0
	for actor in combatants.get_children():
		if actor is CharacterBody3D and actor.is_in_group("enemies") and not actor.is_boss and not actor.dead and not actor.is_queued_for_deletion() and actor.encounter_index == stage:
			count += 1
	return count

func on_boss_killed(boss: CharacterBody3D, critical: bool = false) -> void:
	if state != "playing" or not runtime_world_is_current() or not is_instance_valid(player):
		return
	if not is_instance_valid(boss) or not boss.is_boss or not boss.dead or boss.get_meta("reward_claimed", false):
		return
	boss.set_meta("reward_claimed", true)
	# Boss rewards do not restore vital bars; only reaching the next floor does.
	award_elimination(boss.global_position, critical, true, boss.encounter_index + 1)
	var grew: bool = player.growth.grant_boss_level()
	bosses_alive = max(0, bosses_alive - 1)
	score += 1500
	player.growth_feedback = "Guardian defeated · Clear the remaining soldiers to activate the lift."
	if grew:
		player.growth_feedback = "Hero level %d · Power, maximum health and mana increased." % player.growth.level
	hud.announce(ENCOUNTERS.NAMES[boss.encounter_index] + "  /  DEFEATED", player.growth_feedback)
	fx.ring(player.global_position, 2.4, Color("87f4cd"), 0.8)
	stage_boss_defeated = true
	stage_clear_delay = 1.1
	if bosses_alive <= 0 and active_encounter_foes() <= 0:
		advance_battle_stage()
	else:
		hud.announce("%s  /  DEFEATED" % ENCOUNTERS.NAMES[boss.encounter_index], "Clear the remaining fighters to summon the next guardian.")
		save_current_session()

func retry_run() -> void:
	begin_arena()

func clear_run() -> void:
	tracked_echo = -1
	pending_floor_soldiers.clear()
	floor_soldier_spawn_stage = -1
	if is_instance_valid(touch_controls):
		touch_controls.release_all()
	session_id += 1
	ally_bot = null
	for container in [combatants, pickups, fx]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	spawn_remaining = 0
	wave_timer = 0

func pause_game() -> void:
	if not state in ["playing", "world"]:
		return
	save_current_session()
	paused_from = state
	state = "paused"
	release_controls()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_pause()

func resume() -> void:
	if state != "paused":
		return
	state = paused_from
	get_tree().paused = false
	release_controls()
	capture_controls()
	if state == "world":
		hud.show_world()
	else:
		hud.show_game()

func finish(won: bool) -> void:
	if state != "playing":
		return
	if won and player.health <= 0.0:
		won = false
	if won:
		level_complete = true
		completed_encounters = 11
		bosses_alive = 0
		encounter_active = false
		score += 10000
		var first_clear: bool = int(progress.current_world().completed) < 1
		progress.complete_level(1, false)
		if first_clear:
			run_coins += CAMPAIGN.CLEAR_COINS
		player.shake = 0.25
		sound.play("portal")
		fx.burst(player.global_position + Vector3.UP * 2.0, Color("ffdda2"), 80)
		hud.announce("THE SPIRE IS CONQUERED", "ALL 11 GUARDIANS HAVE FALLEN. THE SUMMIT IS YOURS.")
		hud.banner_timer = 8.0
		state = "victory"
		release_controls()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_result(true)
	else:
		state = "dead"
		release_controls()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_result(false)
	best_score = maxi(best_score, score)
	save_current_session()
	save_settings()

func _process(delta: float) -> void:
	if state in ["playing", "world"]:
		if not runtime_world_is_current():
			show_menu()
			return
		session_save_timer -= delta
		if session_save_timer <= 0:
			save_current_session()
	if state != "playing":
		return
	process_pending_floor_soldier()
	if player.health <= 0.0:
		hud.announce("RUN ENDED", "Your warrior has fallen. Restart to begin again on floor one.")
		finish(false)
		return
	if stage_boss_defeated and active_encounter_foes() <= 0:
		stage_clear_delay -= delta
		if stage_clear_delay <= 0.0:
			advance_battle_stage()
			if state != "playing":
				return
	if lift_activated and arena.player_is_on_elevator(player):
		start_lift_transition()
		if state != "playing":
			return
	elapsed += delta
	combo_timer = maxf(0, combo_timer - delta)
	if combo_timer <= 0:
		combo = 0

	# There are no combat pickups; vital bars do not regenerate on a floor.

func begin_encounter() -> void:
	if encounter_active or level_complete or completed_encounters >= 11 or encounter_index > safe_floor_index():
		return
	encounter_active = true
	wave = encounter_index + 1
	var data: Dictionary = ENCOUNTERS.record(encounter_index)
	var boss_pos: Vector3 = data.center
	var boss: CharacterBody3D = spawn_actor(true, boss_pos)
	boss.home_position = boss_pos
	var forward := Vector3(sin(player.yaw), 0.0, cos(player.yaw))
	queue_floor_soldiers(encounter_index, boss_pos, forward, int(data.soldiers))
	hud.announce(data.name, STORY.GUARDIAN_LINES[encounter_index] + "\n" + data.description)
	hud.banner_timer = 6.0
	sound.play("wave")
	save_current_session()

func queue_floor_soldiers(stage: int, boss_pos: Vector3, forward: Vector3, soldier_count: int) -> void:
	pending_floor_soldiers.clear()
	floor_soldier_spawn_stage = stage if soldier_count > 0 else -1
	var columns: int = 10
	var right := Vector3(forward.z, 0.0, -forward.x)
	for i in range(soldier_count):
		var row: int = floori(float(i) / float(columns))
		var column: int = i % columns
		var side_offset: float = (float(column) - 4.5) * 2.3 + (1.15 if row % 2 == 1 else 0.0)
		var back_offset: float = 2.4 + float(row) * 2.25
		var offset: Vector3 = right * side_offset - forward * back_offset
		var soldier_pos: Vector3 = arena.clamp_to_stage(boss_pos + offset, 3.0) if arena.has_method("clamp_to_stage") else boss_pos + offset
		soldier_pos.y = float(stage) * LAYOUT.FLOOR_HEIGHT + 0.12
		pending_floor_soldiers.append(soldier_pos)

func process_pending_floor_soldier() -> void:
	if pending_floor_soldiers.is_empty():
		floor_soldier_spawn_stage = -1
		return
	if floor_soldier_spawn_stage < 0:
		pending_floor_soldiers.clear()
		return
	var soldier_pos: Vector3 = pending_floor_soldiers.pop_front()
	var soldier: CharacterBody3D = spawn_actor(false, soldier_pos, floor_soldier_spawn_stage)
	soldier.home_position = soldier_pos
	if pending_floor_soldiers.is_empty():
		floor_soldier_spawn_stage = -1

func spawn_actor(boss: bool, pos: Vector3, stage: int = -1, roaming: bool = false) -> CharacterBody3D:
	stage = encounter_index if stage < 0 else clampi(stage,0,10)
	var data: Dictionary = ENCOUNTERS.record(stage)
	var actor: CharacterBody3D = ENEMY.new()
	actor.game = self
	actor.encounter_index = stage
	actor.is_boss = boss
	actor.roaming = roaming and not boss
	actor.asset_id = data.boss_id if boss else data.soldier_id
	actor.home_position = pos if actor.roaming else data.center
	actor.position = pos
	combatants.add_child(actor)
	return actor

func complete_encounter() -> void:
	if not encounter_active or level_complete or not stage_boss_defeated or active_encounter_foes() > 0:
		return
	encounter_active = false
	advance_battle_stage()

func safe_floor_index() -> int:
	# A boss may be defeated before its key is found. Returning or recovering
	# from an invalid pose must stay below the first still-locked staircase.
	for stage in mini(completed_encounters, LAYOUT.FLOOR_COUNT):
		if not floor_keys[stage]: return stage
	return mini(completed_encounters, LAYOUT.FLOOR_COUNT)

func objective_position() -> Vector3:
	if lift_activated and is_instance_valid(arena) and is_instance_valid(arena.elevator_car):
		return arena.elevator_car.global_position
	var closest_pos := Vector3.ZERO
	var closest_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.dead and is_instance_valid(player):
			var d := player.global_position.distance_to(enemy.global_position)
			if d < closest_dist:
				closest_dist = d
				closest_pos = enemy.global_position
	return closest_pos

func objective_text() -> String:
	if lift_activated:
		return "FLOOR %02d CLEARED · ENTER THE CENTRAL LIFT" % (encounter_index + 1)
	if stage_boss_defeated:
		return "FLOOR %02d · CLEAR THE RETINUE" % (encounter_index + 1)
	return "FLOOR %02d / 11 · %s" % [encounter_index + 1, ENCOUNTERS.NAMES[encounter_index]]

func key_room_discovered(stage: int) -> bool:
	var key: Vector3 = LAYOUT.key_position(stage)
	for room in LAYOUT.ROOM_SIZES.size():
		if LAYOUT.room_rect(room).has_point(Vector2(key.x,key.z)):
			return (discovered_rooms[stage] & (1<<room)) != 0
	return false

func room_search_objective(stage: int) -> Vector3:
	if key_room_discovered(stage): return LAYOUT.key_position(stage)
	var closest := Vector3.INF
	var distance := INF
	var centers: Array[Vector3] = LAYOUT.room_centers(stage)
	for room in centers.size():
		if discovered_rooms[stage] & (1<<room): continue
		var next_distance := player.position.distance_squared_to(centers[room])
		if next_distance < distance:
			distance=next_distance
			closest=centers[room]
	return LAYOUT.key_position(stage) if closest == Vector3.INF else closest

func active_encounter_foes() -> int:
	var count := 0
	for actor in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(actor) and not actor.dead and not actor.roaming and actor.encounter_index == encounter_index: count+=1
	return count

func update_exploration(delta: float) -> void:
	var stage: int = LAYOUT.floor_for_position(player.position)
	if stage != exploration_floor:
		if tracked_echo != stage: tracked_echo = -1
		exploration_floor = stage
		roaming_timer = randf_range(12.0,22.0)
		for actor in get_tree().get_nodes_in_group("enemies"):
			if actor.roaming and actor.encounter_index != stage:
				actor.remove_from_group("enemies")
				actor.queue_free()
	if stage >= 11 or absf(player.position.y-LAYOUT.center(stage).y)>3.0: return
	var changed := false
	for room in LAYOUT.ROOM_SIZES.size():
		if LAYOUT.room_rect(room).has_point(Vector2(player.position.x,player.position.z)) and not (discovered_rooms[stage] & (1<<room)):
			discovered_rooms[stage] |= 1<<room
			changed=true
	if not floor_keys[stage] and player.position.distance_to(LAYOUT.key_position(stage)) < 2.6:
		floor_keys[stage]=true
		arena.set_floor_key_collected(stage,true)
		fx.burst(LAYOUT.key_position(stage)+Vector3.UP,Color("f5d077"),20)
		sound.play("pickup")
		hud.announce("FLOOR %02d KEY RECOVERED" % (stage+1), "Ascent unlocked." if completed_encounters>stage else "Defeat this floor's guardian to unlock the stairs.")
		changed=true
		if stage==10 and completed_encounters==11 and not level_complete: finish(true)
	roaming_timer-=delta
	if roaming_timer<=0:
		roaming_timer=randf_range(12.0,22.0)
		if spawn_roaming_minion(stage): changed=true
	if changed: save_current_session()

func chronicle() -> Dictionary:
	var world: Dictionary = progress.current_world()
	if world.is_empty(): return STORY.sanitize({})
	if not world.get("chronicle") is Dictionary:
		world.chronicle = STORY.sanitize({})
	return world.chronicle

func has_echo(index: int) -> bool:
	return index in chronicle().clues

func nearby_echo_index() -> int:
	if state != "playing" or not runtime_world_is_current(): return -1
	var index: int = LAYOUT.floor_for_position(player.position)
	if index >= STORY.ECHOES.size(): return -1
	return index if player.position.distance_to(STORY.echo_position(index)) < 4.2 else -1

func interact() -> void:
	if state == "world": talk_to_elder()
	elif state == "playing": inspect_echo()

func inspect_echo() -> bool:
	var index := nearby_echo_index()
	if index < 0: return false
	var notice := "Recorded in this world's journal."
	if not has_echo(index):
		chronicle().clues.append(index)
		chronicle().clues.sort()
		var earned: int = player.award_xp(STORY.ECHO_XP)
		arena.refresh_echoes(chronicle().clues)
		tracked_echo = -1
		sound.play("pickup")
		notice = "Memory recovered  /  +%d XP" % earned
		if not save_current_session(): notice += "  /  Save pending"
	pause_game()
	hud.show_journal("echoes", index, notice)
	return true

func can_track_echo(index: int) -> bool:
	return runtime_world_is_current() and index >= 0 and index < STORY.ECHOES.size() and not has_echo(index) and (state == "playing" or (state == "paused" and paused_from == "playing")) and LAYOUT.floor_for_position(player.position) == index

func track_echo(index: int) -> void:
	if not can_track_echo(index): return
	tracked_echo = index
	if state == "paused": resume()
	hud.announce("FOLLOW THE BLUE ECHO", STORY.location(index) + "  /  Press T beside the memory stand.")

func solve_mystery(index: int, answer: int) -> String:
	if not runtime_world_is_current() or state != "paused" or not hud.is_journal_open or player.health <= 0:
		return "Open the journal in your world to compare the evidence."
	if index < 0 or index >= STORY.MYSTERIES.size(): return "Unknown mystery."
	var evidence: Dictionary = chronicle()
	var mystery: Dictionary = STORY.MYSTERIES[index]
	if index in evidence.solved: return "This mystery is already resolved."
	if not STORY.can_solve(evidence, index): return "Recover all of this mystery's echoes first."
	if answer < 0 or answer >= mystery.options.size(): return "Choose a theory from the journal."
	if answer != mystery.answer: return mystery.wrong
	evidence.solved.append(index)
	evidence.solved.sort()
	var earned: int = player.award_xp(mystery.xp)
	sound.play("pickup")
	var notice := "Mystery resolved  /  +%d XP" % earned
	if not save_current_session(): notice += "  /  Save pending"
	return notice

func spawn_roaming_minion(stage: int) -> bool:
	if stage < 0 or stage >= 11 or stage > completed_encounters: return false
	var count := 0
	for actor in get_tree().get_nodes_in_group("enemies"):
		if actor.roaming and actor.encounter_index==stage and not actor.dead: count+=1
	if count>=6: return false
	for attempt in 30:
		var region: int = randi_range(0,LAYOUT.ROOM_SIZES.size())
		var at: Vector3
		if region<LAYOUT.ROOM_SIZES.size():
			var rect: Rect2=LAYOUT.room_rect(region).grow(-5.0)
			at=Vector3(randf_range(rect.position.x,rect.end.x),LAYOUT.center(stage).y,randf_range(rect.position.y,rect.end.y))
		else:
			at=LAYOUT.center(stage)+Vector3(randf_range(-LAYOUT.ROOM_HALF_WIDTH+6,LAYOUT.ROOM_HALF_WIDTH-6),0,randf_range(-LAYOUT.ROOM_HALF_DEPTH+6,LAYOUT.ROOM_HALF_DEPTH-6))
		if at.distance_to(player.position)<14.0 or not arena.is_walkable(at): continue
		# Check real props and walls as well as the walkable footprint.
		var shape := SphereShape3D.new()
		shape.radius=0.75
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=shape
		query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP)
		query.collision_mask=1
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
		spawn_actor(false,at,stage,true)
		return true
	return false

func collect_terrace_potion() -> void:
	# The boss tower has no healing pickups; this remains only as a legacy hook.
	return

func prefetch_encounters() -> void:
	if level_complete:
		return
	for index in range(encounter_index, mini(encounter_index + 2, 11)):
		var data: Dictionary = ENCOUNTERS.record(index)
		CATALOG.request(data.boss_id)
		CATALOG.request(data.soldier_id)

func prefetch_next_floor() -> void:
	if encounter_index >= 10:
		return
	var data: Dictionary = ENCOUNTERS.record(encounter_index + 1)
	CATALOG.request(data.boss_id)
	CATALOG.request(data.soldier_id)

func enter_next_portal() -> void:
	if not level_complete or not potion_collected or state != "playing":
		return
	state = "construction"
	release_controls()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_next_level()
	save_current_session()

func leave_next_portal() -> void:
	state = "playing"
	player.position = arena.exit_position + Vector3(0, 0.2, 7)
	portal_cooldown = 3.0
	hud.show_game()
	capture_controls()

func next_wave() -> void:
	begin_encounter()

func spawn_enemy() -> void:
	spawn_actor(false, ENCOUNTERS.CENTERS[encounter_index] + Vector3(8, 0, 8))

func enemy_defeated(pos: Vector3, critical: bool, elite: bool) -> void:
	if state != "playing" or not runtime_world_is_current():
		return
	award_elimination(pos, critical, elite)
	# Currency, XP and the defeated-enemy checkpoint share one atomic write.
	save_current_session()

func award_elimination(pos: Vector3, critical: bool, elite: bool, floor_number: int = -1) -> void:
	var reward: int = CAMPAIGN.BOSS_COINS if elite else CAMPAIGN.KILL_COINS
	run_coins += reward
	progress.earn(reward, false)
	if floor_number < 1:
		floor_number = clampi(LAYOUT.floor_for_position(pos),0,10)+1
	floor_number = clampi(floor_number, 1, 11)
	player.award_xp((150+30*floor_number) if elite else (25+3*floor_number))
	kills += 1
	combo = mini(combo + 1, 5)
	combo_timer = 4.0
	score += (500 if elite else 100) * combo + (50 if critical else 0)
	sound.play("kill", -4)
	# Elimination rewards are XP and score only. The lift transition owns healing.

func register_hit(critical: bool) -> void:
	hits += 1
	hud.hit_timer = 0.16
	hud.critical_hit = critical
	sound.play("hit", -5)

func set_volume(value: float) -> void:
	volume = value
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.001)))
	AudioServer.set_bus_mute(0, value <= 0.001)

func set_render_scale(value: float) -> void:
	render_scale = clampf(value, 0.65, 1.0)
	get_viewport().scaling_3d_scale = render_scale

func load_settings() -> void:
	render_scale = 0.75 if mobile_controls else 0.85
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		selected_skin = clampi(config.get_value("game", "knight_skin", 0), 0, 1)
		best_score = maxi(0, config.get_value("game", "best", 0))
		sensitivity = clampf(config.get_value("settings", "sensitivity", 0.0025), 0.0008, 0.006)
		camera_shake = config.get_value("settings", "shake", true)
		volume = clampf(config.get_value("settings", "volume", 0.7), 0, 1)
		render_scale = clampf(config.get_value("settings", "render_scale", render_scale), 0.65, 1.0)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "knight_skin", selected_skin)
	config.set_value("game", "best", best_score)
	config.set_value("settings", "sensitivity", sensitivity)
	config.set_value("settings", "shake", camera_shake)
	config.set_value("settings", "volume", volume)
	config.set_value("settings", "render_scale", render_scale)
	config.save(settings_path)

func level_data() -> Dictionary:
	return CAMPAIGN.LEVELS[clampi(current_level - 1, 0, CAMPAIGN.LEVELS.size() - 1)]

func next_level() -> void:
	enter_next_portal()

func activate_place(use_arena: bool) -> void:
	player.camera.far = 520.0 if use_arena else 420.0
	var active: Node3D = arena if use_arena else story_world
	var inactive: Node3D = story_world if use_arena else arena
	if inactive.is_inside_tree():
		remove_child(inactive)
	if not active.is_inside_tree():
		add_child(active)
	if not use_arena:
		story_world.refresh_story()

func enter_world() -> void:
	save_current_session()
	if progress.current_world().is_empty():
		show_menu()
		hud.menu_root.open_page("worlds")
		return
	var world_id: int = int(progress.current_world().id)
	var saved_run: Dictionary = progress.session_for_world(world_id)
	var checkpoint: Dictionary = saved_run.get("checkpoint", {})
	if checkpoint.get("status", "") == "dead":
		show_saved_run_over(world_id, saved_run)
		return
	start_run()

func show_saved_run_over(world_id: int, saved_run: Dictionary) -> void:
	get_tree().paused = false
	clear_run()
	activate_place(true)
	runtime_world_id = world_id
	state = "dead"
	encounter_index = 0
	completed_encounters = 0
	player.restore_growth(saved_run.get("growth", {}))
	player.health = 0.0
	player.position = LAYOUT.floor_spawn(0)
	player.yaw = 0.0
	player.pitch = -0.15
	player.visual.set_skin(selected_skin)
	player.visual.weapon_enabled = true
	player.visual.weapon.show()
	player.update_camera(1.0)
	player.camera.make_current()
	hud.show_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_result(false)

func return_to_courtyard() -> void:
	start_run()

func begin_courtyard(_saved: Dictionary = {}) -> void:
	start_run()

func enter_portal() -> void:
	start_run()

func talk_to_elder(_introduction: bool = false) -> void:
	pass

func close_story_dialogue() -> void:
	pass

func accept_quest() -> void:
	pass

func deliver_elixir() -> void:
	pass

func runtime_world_is_current() -> bool:
	return progress != null and runtime_world_id > 0 and progress.active_world == runtime_world_id and not progress.world_by_id(runtime_world_id).is_empty()

func save_current_session() -> bool:
	# Menu characters are decorative staging, never the world's actual location.
	# Dialogue/paused saves resolve to their playable place, not a frozen UI mode.
	if not runtime_world_is_current() or not is_instance_valid(player):
		return false
	var place_state := paused_from if state == "paused" else state
	if place_state == "dialogue":
		place_state = "world"
	if not place_state in ["world", "playing", "victory", "dead", "construction"]:
		return false
	var place := "courtyard" if place_state == "world" else "arena"
	var saved := {"version": SESSION.VERSION, "visited": true, "place": place, "position": player.position, "yaw": player.yaw, "pitch": player.pitch, "level": current_level, "growth": player.growth_snapshot(), "player": player_vitals(), "checkpoint": {}}
	if place == "arena":
		saved.checkpoint = make_checkpoint(place_state)
	else:
		# Keep the tower's survivors when visiting Orin. Courtyard purchases must
		# update the same XP/vital snapshot used when the tower resumes.
		saved.checkpoint = progress.session_for_world(runtime_world_id).checkpoint.duplicate(true)
		if not saved.checkpoint.is_empty():
			saved.checkpoint.growth = saved.growth.duplicate(true)
			saved.checkpoint.player = saved.player.duplicate(true)
	if place_state == "dead":
		saved.position = LAYOUT.floor_spawn(0)
		saved.yaw = 0.0
		saved.pitch = -0.15
	session_save_timer = SESSION_SAVE_INTERVAL
	var saved_ok: bool = progress.update_session(runtime_world_id, saved)
	if not saved_ok:
		if session_save_error != progress.error:
			session_save_error = progress.error
			push_warning(session_save_error)
	else:
		session_save_error = ""
	return saved_ok

func player_vitals() -> Dictionary:
	var result := {}
	for key in ["health", "mana", "shoulder", "magic_cooldown", "slash_cooldown", "ultimate_cooldown", "mana_regen_delay", "dash_cooldown", "enchantment_time"]:
		result[key] = player.get(key)
	return result

func make_checkpoint(place_state: String) -> Dictionary:
	var run_dead: bool = place_state == "dead"
	var checkpoint := {"version": SESSION.VERSION, "level": 1, "status": "dead" if run_dead else "playing", "encounter_index": encounter_index, "completed_encounters": completed_encounters, "encounter_active": encounter_active and not run_dead, "level_complete": level_complete, "player": {}, "enemies": []}
	checkpoint.potion_collected = potion_collected
	checkpoint.growth = player.growth_snapshot()
	checkpoint.floor_keys = floor_keys.duplicate()
	checkpoint.discovered_rooms = discovered_rooms.duplicate()
	checkpoint.roaming_timer = roaming_timer
	for key in ["score", "kills", "shots", "hits", "run_coins", "combo", "combo_timer", "elapsed"]:
		checkpoint[key] = get(key)
	checkpoint.player = player_vitals()
	if run_dead:
		checkpoint.player.health = 0.0
	else:
		for actor in combatants.get_children():
			if actor is CharacterBody3D and actor.is_in_group("enemies") and not actor.dead and not actor.is_queued_for_deletion():
				checkpoint.enemies.append({"boss": actor.is_boss, "roaming": actor.roaming, "stage": actor.encounter_index, "home": actor.home_position, "position": actor.position, "health": actor.health, "recalled_servants": actor.recalled_servants})
	return checkpoint

func restore_checkpoint(raw: Dictionary) -> void:
	var checkpoint: Dictionary = SESSION.sanitize_checkpoint(raw, 1)
	if checkpoint.is_empty():
		player.position = arena.spawn_position
		return
	for key in ["encounter_index", "completed_encounters", "encounter_active", "level_complete", "score", "kills", "shots", "hits", "run_coins", "combo", "combo_timer", "elapsed"]:
		set(key, checkpoint[key])
	floor_keys.assign(checkpoint.floor_keys)
	discovered_rooms.assign(checkpoint.discovered_rooms)
	roaming_timer = checkpoint.roaming_timer
	exploration_floor = LAYOUT.floor_for_position(player.position)
	player.restore_growth(checkpoint.growth)
	for key in checkpoint.player:
		player.set(key, checkpoint.player[key])
	potion_collected = checkpoint.potion_collected or (level_complete and progress.current_world().get("quest", "unmet") in ["elixir", "healed"])
	player.update_enchantment_visual()
	player.visual.rotation.y = player.yaw
	for i in range(completed_encounters):
		arena.mark_encounter_complete(i)
	for i in floor_keys.size():
		arena.set_floor_key_collected(i, floor_keys[i])
	for saved in checkpoint.enemies:
		var actor: CharacterBody3D = spawn_actor(saved.boss, saved.position, saved.stage, saved.roaming)
		actor.home_position = saved.home
		actor.health = minf(saved.health, actor.max_health)
		actor.recalled_servants = saved.recalled_servants
		actor.update_health_label()
	if level_complete:
		arena.reveal_portal()
		arena.set_potion_collected(potion_collected)

func validate_resumed_pose(expected_world: int, expected_run: int, place: String) -> void:
	# Wait until newly attached collision shapes are visible to physics queries.
	await get_tree().physics_frame
	if not is_inside_tree() or not runtime_world_is_current() or runtime_world_id != expected_world or session_id != expected_run:
		return
	if not is_instance_valid(player) or (place == "arena") != arena.is_inside_tree():
		return
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.75
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, player.global_position + Vector3.UP * 0.96)
	query.collision_mask = 1
	var space := get_world_3d().direct_space_state
	var blocked := not space.intersect_shape(query, 1).is_empty()
	var ground_query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.1, player.global_position + Vector3.DOWN * 70, 1)
	var unsupported := space.intersect_ray(ground_query).is_empty()
	if blocked or unsupported:
		player.position = arena.floor_spawn(safe_floor_index()) if place == "arena" else SESSION.COURTYARD_SPAWN
		player.velocity = Vector3.ZERO
		player.update_camera(1)
		save_current_session()

func _exit_tree() -> void:
	save_current_session()
	# The inactive place is cached outside the tree between visits.
	for place in [arena, story_world]:
		if is_instance_valid(place) and place.get_parent() == null:
			place.free()
