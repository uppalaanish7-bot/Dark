extends Control
## Finger ownership keeps move, camera and action touches independent.
var game: Node3D
var movement := Vector2.ZERO
var fingers: Dictionary = {}
var held_actions: Dictionary = {}
var stick_id: int = -1
var look_id: int = -1
var stick_origin := Vector2.ZERO
var stick_tip := Vector2.ZERO
var buttons: Dictionary = {}
const STICK_RADIUS: float = 72.0
const ICONS := {
	"fire": preload("res://assets/ui/controls/sword.svg"),
	"jump": preload("res://assets/ui/controls/jump.svg"),
	"dodge": preload("res://assets/ui/controls/dodge.svg"),
	"aim": preload("res://assets/ui/controls/flame.svg"),
	"lightning": preload("res://assets/ui/controls/lightning.svg"),
	"magic_slash": preload("res://assets/ui/controls/enchant.svg"),
	"ultimate": preload("res://assets/ui/controls/meteor.svg"),
	"storm": preload("res://assets/ui/controls/storm.svg"),
	"shoulder": preload("res://assets/ui/controls/shoulder.svg"),
	"pause": preload("res://assets/ui/controls/pause.svg"),
	"interact": preload("res://assets/ui/controls/interact.svg")
}
const MANA_COST := {"aim": 12.0, "magic_slash": 26.0, "ultimate": 70.0}
const THUMB_ARC := {"fire": Vector3(107, 185, 96), "jump": Vector3(65, 66, 70), "dodge": Vector3(165, 62, 66), "aim": Vector3(215, 218, 72), "magic_slash": Vector3(263, 120, 66), "ultimate": Vector3(323, 220, 78), "shoulder": Vector3(65, 295, 52), "interact": Vector3(222, 190, 76)}
var control_scale: float = 1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func() -> void: release_all(); update_layout())
	update_layout()

func update_layout() -> void:
	control_scale = clampf(minf(size.x / 960.0, size.y / 600.0), 0.75, 1.25)
	# Staggered thumb arc leaves the middle/right view open for aiming.
	buttons.clear()
	for action in THUMB_ARC:
		var geometry: Vector3 = THUMB_ARC[action]
		var diameter := geometry.z * control_scale
		buttons[action] = Rect2(size - Vector2(geometry.x, geometry.y) * control_scale - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter)
	buttons.pause = Rect2(Vector2(size.x - 75 * control_scale, 20), Vector2.ONE * 52 * control_scale)

func hit_action(action: String, point: Vector2) -> bool:
	var rect: Rect2 = buttons[action]
	return point.distance_to(rect.get_center()) <= rect.size.x * 0.5

func is_held(action: String) -> bool:
	if action == "sprint":
		return movement.length() > 0.85
	return held_actions.has(action)

func release_all() -> void:
	fingers.clear()
	held_actions.clear()
	movement = Vector2.ZERO
	stick_id = -1
	look_id = -1
	queue_redraw()

func _process(_delta: float) -> void:
	visible = game.mobile_controls and game.state in ["playing", "world"]
	if not visible and not fingers.is_empty():
		release_all()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not game.mobile_controls or not game.state in ["playing", "world"]:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			begin_touch(event.index, event.position)
		else:
			end_touch(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == stick_id:
			stick_tip = stick_origin + (event.position - stick_origin).limit_length(STICK_RADIUS * control_scale)
			var raw := (stick_tip - stick_origin) / (STICK_RADIUS * control_scale)
			movement = Vector2.ZERO if raw.length() < 0.12 else raw
		elif event.index == look_id:
			game.player.look(event.relative * 1.7)
		get_viewport().set_input_as_handled()

func begin_touch(id: int, point: Vector2) -> void:
	# The touch layer owns screen events before GUI dispatch, so route the
	# visible upgrade button explicitly instead of swallowing its tap.
	var growth_button: Control = game.hud.growth_access if game.state == "playing" else game.hud.world_growth_access
	if is_instance_valid(growth_button) and growth_button.get_global_rect().has_point(point):
		game.hud.open_growth()
		return
	var journal_button: Control = game.hud.journal_access if game.state == "playing" else game.hud.world_journal_access
	if is_instance_valid(journal_button) and journal_button.is_visible_in_tree() and journal_button.get_global_rect().has_point(point):
		game.hud.open_journal()
		return
	var echo_button: Control = game.hud.echo_prompt
	if game.state == "playing" and echo_button.is_visible_in_tree() and echo_button.get_global_rect().has_point(point):
		game.inspect_echo()
		return
	for action in buttons:
		if not action_visible(action):
			continue
		if hit_action(action, point):
			if action == "pause":
				game.pause_game()
				return
			if action == "interact":
				game.interact()
				return
			fingers[id] = action
			held_actions[action] = true
			match action:
				"fire":
					if game.player.fire_timer <= 0:
						game.player.shoot()
				"jump": game.player.jump_buffer = 0.15
				"dodge": game.player.dodge()
				"ultimate": game.player.ultimate()
				"aim": game.player.cast_firebolt()
				"magic_slash": game.player.fire_slash()
				"shoulder": game.player.shoulder *= -1
			return
	if point.x < size.x * 0.4 and point.y > size.y * 0.45 and stick_id == -1:
		stick_id = id
		stick_origin = point
		stick_tip = point
		fingers[id] = "move"
	elif point.x >= size.x * 0.4 and look_id == -1:
		look_id = id
		fingers[id] = "look"

func end_touch(id: int) -> void:
	var action: String = fingers.get(id, "")
	fingers.erase(id)
	if not action in fingers.values():
		held_actions.erase(action)
	if id == stick_id:
		stick_id = -1
		movement = Vector2.ZERO
	if id == look_id:
		look_id = -1

func _draw() -> void:
	if not game.mobile_controls or not game.state in ["playing", "world"]:
		return
	var font: Font = game.hud.title_font
	var origin := stick_origin if stick_id != -1 else Vector2(132 * control_scale, size.y - 125 * control_scale)
	var tip := stick_tip if stick_id != -1 else origin
	var radius := STICK_RADIUS * control_scale
	draw_circle(origin, radius, Color(0.035, 0.045, 0.06, 0.25))
	draw_arc(origin, radius, 0, TAU, 64, Color(1, 1, 1, 0.28), 1.5, true)
	draw_arc(origin, radius - 8, -PI * 0.76, -PI * 0.24, 28, Color(1, 1, 1, 0.7 if is_held("sprint") else 0.22), 3, true)
	for n in 2:
		var arrow := origin + Vector2(0, -radius - 15 - n * 8)
		draw_polyline(PackedVector2Array([arrow + Vector2(-7, 4), arrow, arrow + Vector2(7, 4)]), Color(1, 1, 1, 0.85 if is_held("sprint") else 0.35), 2, true)
	draw_circle(tip, 29 * control_scale, Color(1, 1, 1, 0.16))
	draw_arc(tip, 29 * control_scale, 0, TAU, 48, Color(1, 1, 1, 0.75), 2, true)
	draw_circle(tip, 5 * control_scale, Color(1, 1, 1, 0.7))
	for action in buttons:
		if not action_visible(action):
			continue
		var rect: Rect2 = buttons[action]
		var active := is_held(action)
		var center := rect.get_center()
		var button_radius := rect.size.x * 0.5
		var cost: float = MANA_COST.get(action, 0.0)
		var ready: bool = game.player.mana >= cost
		if action == "dodge": ready = game.player.dash_cooldown <= 0.0
		var accent: Color = game.player.element_color() if cost > 0 else Color("f4f1e7")
		if action == "fire": accent = Color("efd3a2")
		draw_circle(center + Vector2(0, 2), button_radius + 2, Color(0, 0, 0, 0.16))
		draw_circle(center, button_radius, Color(0.08, 0.11, 0.15, 0.68 if active else 0.38))
		if active: draw_circle(center, button_radius - 3, Color(accent, 0.2))
		draw_arc(center, button_radius, 0, TAU, 64, Color(accent, 0.8 if active else 0.4), 2 if action == "fire" else 1.3, true)
		draw_arc(center, button_radius - 4, -PI * 0.85, -PI * 0.15, 24, Color(1, 1, 1, 0.15), 1, true)
		var icon_key: String = action
		if game.player.element() == "lightning":
			if action == "aim": icon_key = "lightning"
			if action == "ultimate": icon_key = "storm"
		var icon_size := rect.size * (0.62 if cost > 0 else 0.64)
		var icon_center := center - Vector2(0, 3 if cost > 0 else 0)
		draw_texture_rect(ICONS[icon_key], Rect2(icon_center - icon_size * 0.5, icon_size), false, Color(1, 1, 1, 0.95 if ready else 0.33))
		if cost > 0:
			var value := str(int(cost))
			var fill: float = clampf(game.player.mana / cost, 0, 1)
			if action == "magic_slash" and game.player.enchantment_time > 0:
				fill = game.player.enchantment_time / 12.0
				value = str(ceili(game.player.enchantment_time))
			draw_arc(center, button_radius - 2, -PI / 2, -PI / 2 + TAU * fill, 64, Color(accent, 0.8 if ready else 0.45), 2.5, true)
			var text_width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(font, center + Vector2(-text_width * 0.5, button_radius - 8), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(accent, 0.9))
		elif action == "dodge" and not ready:
			draw_arc(center, button_radius - 2, -PI / 2, -PI / 2 + TAU * (1.0 - game.player.dash_cooldown / 0.68), 48, Color(1, 1, 1, 0.65), 2.5, true)

func action_visible(action: String) -> bool:
	if game.state == "world":
		return action in ["jump", "dodge", "pause"] or (action == "interact" and game.story_world.near_elder())
	return action != "interact"
