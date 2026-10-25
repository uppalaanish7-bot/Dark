extends SceneTree
var game: Node3D
var failures: Array[String]=[]
class InputTrace extends Node:
	var hero: CharacterBody3D
	func _input(event: InputEvent) -> void:
		trace("input", event)
	func _unhandled_input(event: InputEvent) -> void:
		trace("unhandled", event)
	func trace(phase: String, event: InputEvent) -> void:
		if event is InputEventKey and event.pressed:
			print("INPUT_TRACE phase=",phase," key=",event.physical_keycode," frame=",Engine.get_process_frames()," state=",hero.game.state," mode=",Input.mouse_mode," mana=",hero.mana," slash=",hero.slash_cooldown," dash=",hero.dash_timer," pending=",hero.attack_pending," enchant=",hero.enchantment_time," attack=",hero.attack_kind," focus=",get_viewport().gui_get_focus_owner())
class FocusIndependentGame extends "res://scripts/game.gd":
	func _notification(what: int) -> void:
		if what not in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
			super._notification(what)
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func key(code: Key) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=true
	if "--trace-input" in OS.get_cmdline_user_args():
		print("INPUT_PUSH key=",code," frame=",Engine.get_process_frames()," handled_before=",root.is_input_handled())
	root.push_input(event)
	if "--trace-input" in OS.get_cmdline_user_args():
		print("INPUT_RETURN key=",code," frame=",Engine.get_process_frames()," handled_after=",root.is_input_handled()," enchant=",game.player.enchantment_time," attack=",game.player.attack_kind)
	event=event.duplicate()
	event.pressed=false
	root.push_input(event)
func run() -> void:
	game=load("res://ground.tscn").instantiate()
	game.set_script(FocusIndependentGame)
	game.settings_path="user://input_review_%d.cfg"%Time.get_ticks_usec()
	root.add_child(game)
	if "--trace-input" in OS.get_cmdline_user_args():
		var trace := InputTrace.new()
		trace.hero = game.player
		game.add_child(trace)
	game.progress.create_world("Input regression")
	game.show_menu()
	game.select_skin(1)
	game.start_run()
	await process_frame
	await process_frame
	# Exercise input after the first presented gameplay frame, when a player
	# can actually use the window. Launch-time viewport input can be disabled
	# before presentation on Windows.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	game.capture_controls()
	print("INPUT_CONTEXT state=",game.state," mode=",Input.mouse_mode," mobile=",game.mobile_controls," capture=",game.capture_mouse," processed=",game.player.is_processing_unhandled_input())
	key(KEY_Q)
	check(game.player.enchantment_time>11,"Physical Q input reaches enchantment")
	game.player.magic_cooldown=0
	game.player.mana=100
	key(KEY_R)
	check(game.player.attack_kind=="ultimate","Physical R input reaches ultimate")
	for n in 120: await physics_frame
	game.player.mana=100
	key(KEY_R)
	check(game.player.attack_kind=="ultimate","R input casts again after recovery")
	for n in 120: await physics_frame
	game.pause_game()
	game.resume()
	await process_frame
	game.player.mana=100
	key(KEY_Q)
	check(game.player.enchantment_time>11,"Physical Q still reaches player after pause/resume")
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	root.push_input(click)
	check(game.player.attack_kind=="sword","Mouse click reaches sword attack after resume")
	for f in failures: push_error(f)
	print("LIVE_INPUT_CHECKS 5 FAILURES ",failures.size())
	game.progress.delete_world(game.progress.active_world)
	game.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
