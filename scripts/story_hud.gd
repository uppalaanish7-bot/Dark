extends Control
var game: Node3D
var hud: Control
var canvas: Control
var objective: Label
var world_name: Label
var prompt: Label
var toast: Label
var toast_time := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas = Control.new()
	add_child(canvas)
	canvas.size = Vector2(1440, 900)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade: TextureRect = hud.gradient_overlay(canvas, false)
	shade.size = Vector2(1440, 170)
	hud.label(canvas, "H E R O", Vector2(38, 24), 38)
	hud.label(canvas, "T H E   H O L L O W   S P I R E", Vector2(40, 78), 16, hud.TEAL)
	world_name = hud.label(canvas, "", Vector2(942, 33), 23, hud.GOLD, 420)
	world_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if game.mobile_controls:
		world_name.position.x = 820
	world_name.clip_text = true
	world_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var card := Panel.new()
	canvas.add_child(card)
	card.position = Vector2(38, 128)
	card.size = Vector2(416, 165)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", hud.style(Color(0.025, 0.04, 0.075, 0.86), Color("66708c")))
	hud.label(card, "MOONWELL ELIXIR", Vector2(20, 14), 22, hud.GOLD, 380)
	objective = hud.label(card, "", Vector2(20, 55), 20, hud.WHITE, 374)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.size.y = 97
	prompt = hud.label(canvas, "", Vector2(395, 745), 25, hud.GOLD, 650)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast = hud.label(canvas, "", Vector2(315, 322), 25, hud.WHITE, 810)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var controls: Label = hud.label(canvas, "WASD  Move     MOUSE  Look     SPACE  Jump     T  Talk     J  Journal     ESC  Pause", Vector2(280, 847), 18, hud.WHITE, 940)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.visible = not game.mobile_controls

func notify(message: String) -> void:
	toast.text = message
	toast_time = 4.0

func _process(delta: float) -> void:
	var ratio := minf(size.x / 1440.0, size.y / 900.0)
	canvas.scale = Vector2.ONE * ratio
	canvas.position = (size - canvas.size * ratio) * 0.5
	if not visible:
		return
	toast_time = maxf(0, toast_time - delta)
	toast.visible = toast_time > 0
	var world: Dictionary = game.progress.current_world()
	world_name.text = str(world.get("name", ""))
	match str(world.get("quest", "unmet")):
		"unmet": objective.text = "Speak to Elder Orin in Greywake. Carry the Canticle Blade into the Spire."
		"active": objective.text = "Ascend the 11 floors, sever the wardens' seals, and recover the Moonwell Elixir above Nox. Collect Mara's echoes."
		"elixir": objective.text = "Moonwell Elixir recovered! Bring the unspent water to Elder Orin in Greywake."
		"healed": objective.text = "Greywake is restored: The Names We Carry. Speak to Orin to reflect on the dawn." if game.STORY.truth_known(game.chronicle()) else "Greywake is healed: Dawn Restored. Solve the 3 Mysteries to return the village's stolen memories."
	prompt.text = ("TALK  /  ELDER ORIN" if game.mobile_controls else "[ T ]  TALK TO ELDER ORIN") if game.story_world.near_elder() else "WALK THROUGH THE GLOWING DOOR TO ENTER"
	prompt.visible = game.state == "world"
