extends Control
const INK := Color("0d2028")
const WHITE := Color("eef1e5")
const MUTED := Color("9cacac")
const TEAL := Color("a9dce5")
const GOLD := Color("efbe83")
const NAMES := ["GIRL KNIGHT", "OMEGA KNIGHT"]
const ENCOUNTERS = preload("res://scripts/encounter_data.gd")
var game: Node3D
var menu_root: Control
var game_root: Control
var world_root: Control
var modal_root: Control
var health_text: Label
var mana_text: Label
var score_text: Label
var wave_text: Label
var status_text: Label
var operator_text: Label
var operator_description: Label
var preview_name: Label
var banner: Label
var banner_sub: Label
var skin_buttons: Array[Button] = []
var ui_scale: float = 1.0
var hit_timer: float = 0
var critical_hit: bool = false
var damage_flash: float = 0
var banner_timer: float = 0
var title_font: Font
var menu_gradient: TextureRect
var top_gradient: TextureRect
var bottom_gradient: TextureRect
var growth_access: Button
var world_growth_access: Button
var is_growth_open: bool = false
var growth_balance: Label
var growth_summary: Label
var growth_notice: Label
var growth_rows: Dictionary = {}
var journal_access: Button
var world_journal_access: Button
var echo_prompt: Button
var is_journal_open: bool = false
var journal_section: String = "echoes"
var journal_index: int = 0
var journal_view: RefCounted

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/Rajdhani-SemiBold.ttf"):
		title_font = load("res://assets/Rajdhani-SemiBold.ttf")
	else:
		title_font = ThemeDB.fallback_font
	var ui_theme := Theme.new()
	ui_theme.default_font = title_font
	ui_theme.default_font_size = 20
	theme = ui_theme
	build_menu()
	build_game()
	world_root = preload("res://scripts/story_hud.gd").new()
	world_root.game = game
	world_root.hud = self
	add_child(world_root)
	world_root.hide()
	world_growth_access = button(world_root.canvas, "U  ·  HERO UPGRADES", Vector2(38, 307), Vector2(290, 38), open_growth)
	world_growth_access.add_theme_font_size_override("font_size", 17)
	world_journal_access = button(world_root.canvas, "STORY JOURNAL" if game.mobile_controls else "J  ·  STORY JOURNAL", Vector2(38, 355), Vector2(290, 38), open_journal)
	world_journal_access.add_theme_font_size_override("font_size", 17)
	modal_root = Control.new()
	add_child(modal_root)
	modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.hide()
	if game.mobile_controls:
		modal_root.scale = Vector2.ONE * 0.76

func label(parent: Control, content: String, pos: Vector2, font_size: int = 20, color: Color = WHITE, width: float = 500) -> Label:
	var node := Label.new()
	parent.add_child(node)
	node.text = content
	node.position = pos
	node.size = Vector2(width, font_size + 10)
	node.add_theme_font_override("font", title_font)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func style(background: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 18
	box.content_margin_right = 18
	return box

func button(parent: Control, title: String, pos: Vector2, dimensions: Vector2, callback: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	parent.add_child(node)
	node.text = title
	node.position = pos
	node.size = dimensions
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", 24 if primary else 18)
	node.add_theme_color_override("font_color", INK if primary else WHITE)
	node.add_theme_color_override("font_hover_color", INK)
	node.add_theme_color_override("font_pressed_color", INK)
	node.add_theme_color_override("font_focus_color", INK if primary else WHITE)
	node.add_theme_stylebox_override("normal", style(TEAL if primary else Color(0.04, 0.12, 0.15, 0.88), Color("40595b")))
	node.add_theme_stylebox_override("hover", style(WHITE))
	node.add_theme_stylebox_override("pressed", style(GOLD))
	node.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, TEAL))
	node.add_theme_stylebox_override("disabled", style(Color("102027"), Color("2d4045")))
	node.add_theme_color_override("font_disabled_color", Color("76888b"))
	node.pressed.connect(callback)
	return node

func build_menu() -> void:
	menu_root = preload("res://scripts/lobby.gd").new()
	menu_root.game = game
	menu_root.hud = self
	add_child(menu_root)

func refresh_operator() -> void:
	menu_root.open_page(menu_root.section)

func build_game() -> void:
	game_root = Control.new()
	add_child(game_root)
	game_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_gradient = gradient_overlay(game_root, false)
	bottom_gradient = gradient_overlay(game_root, false)
	bottom_gradient.flip_v = true
	label(game_root, "H E R O", Vector2(36, 23), 32).visible = not game.mobile_controls
	label(game_root, "T H E   H O L L O W   S P I R E", Vector2(38, 66), 14, GOLD).visible = not game.mobile_controls
	wave_text = label(game_root, "", Vector2(-360, 25), 23, WHITE, 720)
	wave_text.set_meta("layout_anchor", Vector2(0.5, 0))
	wave_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_text = label(game_root, "", Vector2(-338, 27), 25, WHITE, 300)
	score_text.set_meta("layout_anchor", Vector2(1, 0))
	score_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	growth_access = button(game_root, "U  ·  HERO UPGRADES", Vector2(36, 102), Vector2(282, 36), open_growth)
	growth_access.add_theme_font_size_override("font_size", 17)
	journal_access = button(game_root, "J  ·  STORY JOURNAL", Vector2(36, 145), Vector2(282, 36), open_journal)
	journal_access.add_theme_font_size_override("font_size", 17)
	journal_access.hide()
	echo_prompt = button(game_root, "T  ·  READ MARA'S ECHO", Vector2(-230, -248), Vector2(460, 47), game.inspect_echo)
	echo_prompt.set_meta("layout_anchor", Vector2(0.5, 1))
	echo_prompt.hide()
	health_text = label(game_root, "", Vector2(40, -157), 23, WHITE, 320)
	health_text.set_meta("layout_anchor", Vector2(0, 1))
	mana_text = label(game_root, "", Vector2(40, -85), 17, TEAL, 330)
	mana_text.set_meta("layout_anchor", Vector2(0, 1))
	status_text = label(game_root, "", Vector2(-520, -180), 18, GOLD, 480)
	status_text.set_meta("layout_anchor", Vector2(1, 1))
	status_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var controls := label(game_root, "WASD  Move    SPACE  Jump    CTRL  Evade    LMB  Attack    RMB  Magic    Q  Enchant    R  Ultimate    ESC  Pause", Vector2(-560, -33), 16, Color("b5bdc9"), 1120)
	controls.set_meta("layout_anchor", Vector2(0.5, 1))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.visible = not game.mobile_controls
	banner = label(game_root, "", Vector2(-530, 245), 40, WHITE, 1060)
	banner.set_meta("layout_anchor", Vector2(0.5, 0))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub = label(game_root, "", Vector2(-555, 301), 21, GOLD, 1110)
	banner_sub.set_meta("layout_anchor", Vector2(0.5, 0))
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_sub.size.y = 88
	if game.mobile_controls:
		for item in [score_text, health_text, mana_text, wave_text]: item.hide()
		status_text.hide()
		growth_access.position = Vector2(237, 24)
		growth_access.size = Vector2(48, 48)
		growth_access.text = ""
		growth_access.icon = preload("res://assets/ui/controls/upgrade.svg")
		growth_access.expand_icon = true
		growth_access.add_theme_constant_override("icon_max_width", 29)
		var upgrade_style := style(Color(0.04, 0.06, 0.09, 0.45), Color(1, 1, 1, 0.3))
		upgrade_style.set_corner_radius_all(24)
		upgrade_style.content_margin_left = 9
		upgrade_style.content_margin_right = 9
		growth_access.add_theme_stylebox_override("normal", upgrade_style)
		growth_access.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		growth_access.size = Vector2(48, 48)
		growth_access.tooltip_text = "Hero upgrades"
		journal_access.position = Vector2(38, 272)
		echo_prompt.set_meta("layout_anchor", Vector2(0.5, 0))
		echo_prompt.position = Vector2(-180, 345)
		echo_prompt.size = Vector2(360, 48)
		banner.position = Vector2(-300, 155)
		banner.size.x = 600
		banner.add_theme_font_size_override("font_size", 26)
		banner_sub.position = Vector2(-270, 191)
		banner_sub.size.x = 540
		banner_sub.add_theme_font_size_override("font_size", 17)

func show_menu() -> void:
	is_growth_open = false
	is_journal_open = false
	world_root.hide()
	menu_root.show()
	game_root.hide()
	modal_root.hide()
	menu_root.open_page("lobby")
	queue_redraw()

func show_game() -> void:
	is_growth_open = false
	is_journal_open = false
	world_root.hide()
	menu_root.hide()
	game_root.show()
	modal_root.hide()
	queue_redraw()

func modal(title: String, subtitle: String, height: float = 560, width: float = 520) -> Control:
	is_growth_open = false
	is_journal_open = false
	for child in modal_root.get_children():
		modal_root.remove_child(child)
		child.queue_free()
	modal_root.show()
	var background := ColorRect.new()
	modal_root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.015, 0.035, 0.05, 0.78)
	var panel := Panel.new()
	modal_root.add_child(panel)
	panel.set_meta("layout_anchor", Vector2(0.5, 0.5))
	panel.position = Vector2(-width / 2, -height / 2)
	panel.size = Vector2(width, height)
	panel.add_theme_stylebox_override("panel", style(Color("11252d"), Color("4f7070")))
	label(panel, "H E R O   /   T H E   H O L L O W   S P I R E", Vector2(36, 26), 15, TEAL)
	label(panel, title, Vector2(34, 66), 51, WHITE, width - 70)
	label(panel, subtitle, Vector2(36, 133), 19, MUTED, width - 75)
	return panel

func show_pause() -> void:
	var panel: Control = modal("PAUSED", "The tower climb is paused.", 735)
	button(panel, "RESUME", Vector2(36, 203), Vector2(448, 58), game.resume, true).grab_focus()
	button(panel, "HERO UPGRADES  /  XP", Vector2(36, 279), Vector2(448, 48), show_growth)
	button(panel, "SETTINGS", Vector2(36, 345), Vector2(448, 48), show_settings)
	button(panel, "HOW TO PLAY", Vector2(36, 411), Vector2(448, 48), show_controls)
	button(panel, "RETURN TO LOBBY", Vector2(36, 558), Vector2(448, 48), game.show_menu)
	label(panel, "Your hero's earned strength is saved." if game.mobile_controls else "ESC  Resume      /      F11  Fullscreen", Vector2(36, 679), 16, MUTED)

func open_journal() -> void:
	if game.state in ["playing", "world"]: game.pause_game()
	if game.state == "paused": show_journal()

func show_journal(section: String = "", index: int = -1, notice: String = "") -> void:
	if game.state != "paused": return
	if section in ["echoes", "mysteries"]: journal_section = section
	if index >= 0: journal_index = index
	journal_index = clampi(journal_index, 0, 10 if journal_section == "echoes" else 2)
	if journal_view == null:
		journal_view = preload("res://scripts/story_journal.gd").new()
		journal_view.hud = self
		journal_view.game = game
	journal_view.build(journal_section, journal_index, notice)

func open_growth() -> void:
	if game.state in ["playing", "world"]: game.pause_game()
	if game.state == "paused": show_growth()

func show_growth() -> void:
	var panel: Control = modal("HERO GROWTH", "Spend battle XP to strengthen your hero. Health returns only on the next floor.", 790)
	is_growth_open = true
	growth_rows.clear()
	growth_balance = label(panel, "", Vector2(36, 171), 30, GOLD, 448)
	growth_summary = label(panel, "", Vector2(36, 212), 16, TEAL, 448)
	var entries := [
		["mana", "RESTORE MANA", "Refill your entire mana bar"],
		["power", "POWER", "+1 level · +10% base damage"],
		["health", "HEALTH", "+1 level · +20 maximum HP"],
		["magic", "MANA", "+1 level · +10 maximum mana"],
		["overall", "HERO LEVEL", "+1 to Power, Health and Mana levels"]
	]
	for i in entries.size():
		var entry: Array = entries[i]
		var kind: String = entry[0]
		var y := 255.0 + i * 66.0
		var title := label(panel, entry[1], Vector2(36, y), 21, WHITE, 273)
		label(panel, entry[2], Vector2(36, y+29), 14, MUTED, 284)
		var purchase := button(panel, "", Vector2(331, y+3), Vector2(153, 46), func() -> void:
			game.player.purchase_growth(kind)
			refresh_growth()
		)
		purchase.add_theme_font_size_override("font_size", 17)
		growth_rows[kind] = {"title":title, "button":purchase, "name":entry[1]}
	growth_notice = label(panel, "", Vector2(36, 661), 17, GOLD, 448)
	growth_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	growth_notice.size.y = 51
	button(panel, "RESUME  /  U OR ESC", Vector2(36, 724), Vector2(448, 44), game.resume, true).grab_focus()
	refresh_growth()

func refresh_growth() -> void:
	if not is_growth_open or not is_instance_valid(growth_balance): return
	var hero = game.player
	var stats: Dictionary = hero.growth_snapshot()
	growth_balance.text = "%d XP   /   HERO LEVEL %d" % [stats.xp, stats.level]
	growth_summary.text = "HP %d / %d   ·   MANA %d / %d   ·   DAMAGE %d%%" % [ceili(hero.health), ceili(hero.max_health), ceili(hero.mana), ceili(hero.max_mana), roundi(hero.damage_multiplier()*100)]
	for kind in growth_rows:
		var row: Dictionary = growth_rows[kind]
		var level_key: String = {"power":"power_level", "health":"health_level", "magic":"mana_level", "overall":"level"}.get(kind, "")
		row.title.text = row.name + ("  /  LV %d" % stats[level_key] if not level_key.is_empty() else "")
		var reason: String = hero.growth_purchase_reason(kind)
		row.button.disabled = not reason.is_empty()
		row.button.text = "MAX LEVEL" if hero.growth.capped(kind) else "%d XP" % hero.growth_cost(kind)
		row.button.tooltip_text = reason if not reason.is_empty() else "Spend %d XP" % hero.growth_cost(kind)
	growth_notice.text = hero.growth_feedback if not hero.growth_feedback.is_empty() else "Earn XP from minions and bosses. Upgrades stay with this saved game."

func show_result(won: bool) -> void:
	var title := "TOWER CONQUERED" if won else "RUN ENDED"
	var subtitle := "Eleven floors · Eleven guardians"
	var panel: Control = modal(title, subtitle, 690)
	label(panel, "%06d" % game.score, Vector2(34, 184), 70, TEAL)
	label(panel, "FINAL SCORE", Vector2(36, 268), 16, MUTED)
	label(panel, "%d FOES ELIMINATED      %d HITS LANDED" % [game.kills, game.hits], Vector2(36, 310), 23)
	label(panel, "+%d COINS    /    BALANCE %d" % [game.run_coins, game.progress.coins], Vector2(36, 350), 25, GOLD)
	label(panel, "PERSONAL BEST   %06d" % game.best_score, Vector2(36, 391), 19, MUTED)
	var message := "The final guardian is defeated. The tower is yours." if won else "Your run is over. Restart to begin a new attempt on floor one."
	label(panel, message, Vector2(36, 433), 17, TEAL, 448)
	button(panel, "RESTART FROM FLOOR 1", Vector2(36, 480), Vector2(448, 57), game.retry_run, true).grab_focus()
	button(panel, "RETURN TO LOBBY", Vector2(36, 553), Vector2(448, 48), game.show_menu)

func close_modal() -> void:
	game.save_settings()
	if game.state == "paused":
		show_pause()
	else:
		modal_root.hide()

func show_settings() -> void:
	var panel: Control = modal("SETTINGS", "Tune your view, sound and performance.", 650)
	label(panel, "LOOK SENSITIVITY", Vector2(36, 204), 19)
	var sensitivity := HSlider.new()
	panel.add_child(sensitivity)
	sensitivity.position = Vector2(36, 248)
	sensitivity.size = Vector2(448, 28)
	sensitivity.min_value = 0.0008
	sensitivity.max_value = 0.006
	sensitivity.step = 0.0001
	sensitivity.value = game.sensitivity
	sensitivity.value_changed.connect(func(value: float) -> void: game.sensitivity = value)
	label(panel, "SOUND VOLUME", Vector2(36, 291), 19)
	var volume_slider := HSlider.new()
	panel.add_child(volume_slider)
	volume_slider.position = Vector2(36, 333)
	volume_slider.size = Vector2(448, 28)
	volume_slider.min_value = 0
	volume_slider.max_value = 1
	volume_slider.step = 0.05
	volume_slider.value = game.volume
	volume_slider.value_changed.connect(game.set_volume)
	var scale_label := label(panel, "3D RENDER SCALE  /  %d%%" % roundi(game.render_scale * 100), Vector2(36, 376), 19)
	var render_slider := HSlider.new()
	panel.add_child(render_slider)
	render_slider.position = Vector2(36, 415)
	render_slider.size = Vector2(448, 28)
	render_slider.min_value = 0.65
	render_slider.max_value = 1.0
	render_slider.step = 0.05
	render_slider.value = game.render_scale
	render_slider.value_changed.connect(func(value: float) -> void:
		game.set_render_scale(value)
		scale_label.text = "3D RENDER SCALE  /  %d%%" % roundi(value * 100)
	)
	var shake := CheckButton.new()
	panel.add_child(shake)
	shake.text = "CAMERA SHAKE"
	shake.position = Vector2(30, 464)
	shake.size = Vector2(460, 42)
	shake.button_pressed = game.camera_shake
	shake.toggled.connect(func(enabled: bool) -> void: game.camera_shake = enabled)
	label(panel, "Lower 3D scale for smoother play. UI stays sharp.", Vector2(36, 517), 17, MUTED, 448)
	button(panel, "SAVE & BACK", Vector2(36, 568), Vector2(448, 54), close_modal, true)

func show_controls() -> void:
	var panel: Control = modal("COMBAT ARTS", "Watch their stance. Evade. Strike back.", 720)
	var instructions := ["W A S D / MOUSE|Move / look", "W-TAP / W-HOLD|Single stride / Continuous walk", "SHIFT / W+SPACE|Sprint (14.5m/s) / Sprint-Jump", "LEFT MOUSE|Three-hit sword combo", "RIGHT MOUSE|"+game.player.power_label("ranged")+" · 12 mana", "Q|Enchant sword · 26 mana", "R|"+game.player.power_label("ultimate")+" · 70 mana", "SPACE|Jump / double jump", "CTRL|Evade roll · always free", "E|Swap camera shoulder", "U / ESC / F11|Upgrades / pause / fullscreen"]
	if game.mobile_controls:
		label(panel, "Left thumb: move; push fully to run. Swipe to look.", Vector2(36, 179), 17, TEAL, 448)
		var pad: Control = game.touch_controls
		var entries := [
			["fire", "Sword combo · hold to keep attacking"],
			["aim", game.player.power_label("ranged") + " · 12 mana"],
			["magic_slash", "Enchant blade · 26 mana · lasts 12 seconds"],
			["ultimate", game.player.power_label("ultimate") + " · 70 mana"],
			["jump", "Jump · tap again in the air for double jump"],
			["dodge", "Evade · brief invulnerability · free"],
			["shoulder", "Switch camera shoulder"],
			["pause", "Pause the match"]
		]
		for i in entries.size():
			var icon_key: String = entries[i][0]
			if game.player.element() == "lightning":
				if icon_key == "aim": icon_key = "lightning"
				if icon_key == "ultimate": icon_key = "storm"
			var icon := TextureRect.new()
			panel.add_child(icon)
			icon.texture = pad.ICONS[icon_key]
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.position = Vector2(40, 215 + i * 38)
			icon.size = Vector2(30, 30)
			label(panel, entries[i][1], Vector2(86, 219 + i * 38), 17, WHITE, 395)
		paragraph(panel, "Reach the next floor by riding the central lift to restore health. Numbers on spell icons show mana cost; the enchant ring shows time remaining.", Vector2(36, 546), Vector2(448, 96), 17)
		button(panel, "UNDERSTOOD", Vector2(36, 656), Vector2(448, 44), close_modal, true)
		return
	for i in range(instructions.size()):
		var parts: PackedStringArray = instructions[i].split("|")
		label(panel, parts[0], Vector2(36, 190 + i * 32), 17, TEAL, 205)
		label(panel, parts[1], Vector2(244, 190 + i * 32), 17, WHITE, 260)
	paragraph(panel, "Q enchants your sword for 12 seconds: +80% sword damage. Girl Knight commands fire; Omega commands lightning. Spells can be recast as soon as enough mana returns. Movement and normal sword attacks are free.", Vector2(36, 552), Vector2(448, 100), 17)
	button(panel, "UNDERSTOOD", Vector2(36, 656), Vector2(448, 44), close_modal, true)

func announce(title: String, subtitle: String) -> void:
	banner.text = title
	banner_sub.text = subtitle
	banner_timer = 3.0

func _process(delta: float) -> void:
	menu_root.size = size
	ui_scale = minf(size.x / 960.0, size.y / 600.0) if game.mobile_controls else minf(size.x / 1440.0, size.y / 900.0)
	var extent := size / ui_scale
	game_root.scale = Vector2.ONE * ui_scale
	game_root.size = extent
	modal_root.scale = Vector2.ONE * minf(1.0, minf(size.x / (960.0 if is_journal_open else 620.0), size.y / 800.0))
	modal_root.size = size / modal_root.scale
	layout_anchors(game_root, extent)
	layout_anchors(modal_root, size / modal_root.scale)
	top_gradient.size = Vector2(extent.x, 160 if game.mobile_controls else 210)
	bottom_gradient.size = Vector2(extent.x, 100 if game.mobile_controls else 235)
	bottom_gradient.position.y = extent.y - bottom_gradient.size.y
	if game.state != "paused":
		hit_timer = maxf(0, hit_timer - delta)
		damage_flash = maxf(0, damage_flash - delta)
		banner_timer = maxf(0, banner_timer - delta)
	if game_root.visible:
		echo_prompt.visible = false
		journal_access.visible = false
		health_text.text = "VITALITY   %03d / %d" % [ceili(game.player.health), ceili(game.player.max_health)]
		var mana_status: String = "READY" if game.player.mana >= game.player.max_mana else ("REPLENISHING" if game.player.mana_regen_delay <= 0 else "MAGIC")
		mana_text.text = "MANA   %03d / %d   ·   %s" % [ceili(game.player.mana), ceili(game.player.max_mana), mana_status]
		score_text.text = "%06d   /   %d XP" % [game.score, game.player.growth.xp]
		growth_access.text = "" if game.mobile_controls else "U  ·  UPGRADES  /  HERO LV %d" % game.player.growth.level
		var ally_str: String = ""
		if is_instance_valid(game.ally_bot):
			if game.ally_bot.is_down:
				ally_str = "ALLY: %s (DOWN)" % game.ally_bot.bot_name
			else:
				ally_str = "ALLY: %s (%d HP)" % [game.ally_bot.bot_name, ceili(game.ally_bot.health)]
		wave_text.text = "FLOOR %02d / 11   ·   %s" % [game.encounter_index + 1, ally_str]
		status_text.text = "DA VINCI BLADE  /  "+("STORM ARTS" if game.player.element()=="lightning" else "EMBER ARTS")
		banner.modulate.a = minf(1, banner_timer * 1.5)
		banner_sub.modulate.a = minf(1, banner_timer * 1.5)
	if is_growth_open and modal_root.visible: refresh_growth()
	queue_redraw()

func _draw() -> void:
	if not game_root.visible:
		return
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * ui_scale)
	var viewport: Vector2 = size / ui_scale
	if game.mobile_controls:
		_draw_mobile_hud(viewport)
		draw_set_transform(Vector2.ZERO)
		return
	var boss: Node = get_tree().get_first_node_in_group("bosses")
	for i in range(11):
		var point := Vector2(viewport.x * 0.5 + (i - 5) * 23, 70)
		var color := GOLD if i >= game.completed_encounters else Color("303844")
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -4), point + Vector2(4, 0), point + Vector2(0, 4), point + Vector2(-4, 0)]), color)
	if is_instance_valid(boss) and not boss.dead:
		var bar_start := Vector2((viewport.x - 650) * 0.5, 158)
		var data: Dictionary = ENCOUNTERS.record(boss.encounter_index)
		var boss_color: Color = data.color
		draw_rect(Rect2(bar_start - Vector2(16, 44), Vector2(682, 68)), Color(0.03, 0.035, 0.055, 0.86))
		draw_string(title_font, bar_start + Vector2(0, -12), "FLOOR %02d  ·  %s  /  PHASE %d" % [game.encounter_index + 1, data.name, boss.phase], HORIZONTAL_ALIGNMENT_LEFT, 530, 22, boss_color)
		draw_string(title_font, bar_start + Vector2(538, -12), "%d / %d" % [ceili(boss.health), ceili(boss.max_health)], HORIZONTAL_ALIGNMENT_RIGHT, 112, 18, WHITE)
		draw_rect(Rect2(bar_start, Vector2(650, 7)), Color("303544"))
		draw_rect(Rect2(bar_start, Vector2(650 * boss.health / boss.max_health, 7)), boss_color)
		for fraction in [0.33, 0.66]:
			draw_line(bar_start + Vector2(650 * fraction, 0), bar_start + Vector2(650 * fraction, 7), INK, 2)
	var vitality_y: float = 150 if game.mobile_controls else viewport.y - 116
	var mana_y: float = 210 if game.mobile_controls else viewport.y - 57
	draw_rect(Rect2(40, vitality_y, 290, 8), Color("303544"))
	draw_rect(Rect2(40, vitality_y, 290 * game.player.health / game.player.max_health, 8), Color("dfb391") if game.player.health > 40 else Color("ff664c"))
	draw_rect(Rect2(40, mana_y, 290, 5), Color("303544"))
	draw_rect(Rect2(40, mana_y, 290 * game.player.mana / game.player.max_mana, 5), Color("a1bfff"))
	var ally = game.get("ally_bot")
	if is_instance_valid(ally):
		var ally_y: float = mana_y + 18
		var ally_hp_ratio: float = clampf(ally.health / ally.max_health, 0.0, 1.0)
		draw_string(title_font, Vector2(40, ally_y - 2), "ALLY: %s   %d / %d" % [ally.bot_name, ceili(ally.health), ceili(ally.max_health)], HORIZONTAL_ALIGNMENT_LEFT, 290, 14, Color("8bedd6") if not ally.is_down else Color("ff664c"))
		draw_rect(Rect2(40, ally_y + 12, 290, 6), Color("303544"))
		draw_rect(Rect2(40, ally_y + 12, 290 * ally_hp_ratio, 6), Color("50e0ff") if not ally.is_down else Color("ff4444"))
	var target: Vector3 = game.objective_position() - game.player.position
	var distance := target.length()
	var objective: String = game.objective_text()
	draw_string(title_font, Vector2(viewport.x * 0.5 - 300, 96), "%s   ·   %dm" % [objective, roundi(distance)], HORIZONTAL_ALIGNMENT_CENTER, 600, 15, MUTED)
	var status_str := "ELEVEN-FLOOR BOSS TOWER   ·   CENTRAL LIFT"
	draw_string(title_font, Vector2(viewport.x * 0.5 - 350, 125), status_str, HORIZONTAL_ALIGNMENT_CENTER, 700, 14, GOLD)
	var direction_angle: float = atan2(-target.x, -target.z) - game.player.yaw
	var nav_pos := Vector2(viewport.x * 0.5 - clampf(sin(direction_angle) * 240, -240, 240), 105)
	draw_circle(nav_pos, 3, GOLD)
	var center: Vector2 = viewport * 0.5
	if game.state == "playing":
		draw_circle(center, 2, GOLD)
		draw_arc(center, 8, 0, TAU, 24, Color(0.95, 0.87, 0.75, 0.5), 1, true)
		if hit_timer > 0:
			for direction in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(center + direction * 9, center + direction * 16, GOLD if critical_hit else WHITE, 2, true)
	if not game.mobile_controls:
		var abilities := [["LMB", "SWORD", 0.0], ["RMB", game.player.power_label("ranged"), 12.0], ["Q", "ENCHANT", 26.0], ["R", game.player.power_label("ultimate"), 70.0]]
		for i in range(abilities.size()):
			var entry: Array = abilities[i]
			var pos := Vector2(viewport.x - 520 + i * 123, viewport.y - 142)
			draw_rect(Rect2(pos, Vector2(113, 83)), Color(0.04, 0.045, 0.07, 0.88))
			draw_rect(Rect2(pos, Vector2(113, 83)), Color("534952"), false, 1)
			draw_string(title_font, pos + Vector2(12, 24), entry[0], HORIZONTAL_ALIGNMENT_LEFT, 89, 23, GOLD)
			draw_string(title_font, pos + Vector2(8, 48), entry[1], HORIZONTAL_ALIGNMENT_LEFT, 103, 13 if str(entry[1]).length()>10 else 16, WHITE)
			var ready: bool = game.player.mana >= entry[2]
			var status: String = "FREE" if i==0 else ("%d MANA" % int(entry[2]) if ready else "NEED %d" % ceili(entry[2]-game.player.mana))
			if i==2 and game.player.enchantment_time>0: status = "ACTIVE %.1fs" % game.player.enchantment_time
			draw_string(title_font, pos + Vector2(8, 69), status, HORIZONTAL_ALIGNMENT_LEFT, 103, 13, game.player.element_color() if ready else MUTED)
		var dodge_ready: bool = game.player.dash_cooldown <= 0
		draw_string(title_font, Vector2(40, viewport.y - 181), "EVADE READY" if dodge_ready else "EVADE  %.1fs" % game.player.dash_cooldown, HORIZONTAL_ALIGNMENT_LEFT, 300, 14, GOLD if dodge_ready else MUTED)
	var radar := Vector2(viewport.x - 97, 225 if game.mobile_controls else 172)
	draw_circle(radar, 54, Color(0.03, 0.035, 0.055, 0.7))
	draw_arc(radar, 54, 0, TAU, 48, Color("62616d"), 1, true)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = enemy.global_position - game.player.global_position
		if absf(offset.y) > 5.0: continue
		var point := Vector2(offset.x, offset.z) * 1.15
		if point.length() < 50:
			draw_circle(radar + point, 4 if enemy.is_boss else 2.3, GOLD)
	var objective_point := Vector2(target.x, target.z).limit_length(42.0)
	draw_arc(radar + objective_point, 4, 0, TAU, 12, TEAL, 1.5, true)
	var forward := Vector2(-sin(game.player.yaw), -cos(game.player.yaw))
	var side := forward.orthogonal()
	draw_colored_polygon(PackedVector2Array([radar + forward * 7, radar - forward * 4 + side * 4, radar - forward * 4 - side * 4]), WHITE)
	if game.combo > 1:
		draw_string(title_font, Vector2(viewport.x - 161, 246), "%dx CHAIN" % game.combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, GOLD)
	if damage_flash > 0:
		for i in range(8):
			draw_rect(Rect2(i * 8, i * 8, viewport.x - i * 16, viewport.y - i * 16), Color(0.8, 0.15, 0.08, damage_flash * 0.24 * (1 - float(i) / 8)), false, 8)
	draw_set_transform(Vector2.ZERO)

func _draw_mobile_hud(viewport: Vector2) -> void:
	var hero: CharacterBody3D = game.player
	var pale := Color("ebeff1")
	var quiet := Color("a0abb6")
	var center_x := viewport.x * 0.5
	draw_style_box(style(Color(0.025, 0.035, 0.05, 0.62)), Rect2(20, 20, 207, 95))
	draw_string(title_font, Vector2(32, 41), "LV %02d  ·  %s" % [hero.growth.level, "EMBER" if hero.element() == "fire" else "STORM"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, pale)
	draw_string(title_font, Vector2(32, 64), "%d / %d" % [ceili(hero.health), ceili(hero.max_health)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, pale)
	draw_rect(Rect2(32, 72, 182, 5), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(32, 72, 182 * clampf(hero.health / hero.max_health, 0, 1), 5), Color("a8deb8") if hero.health > hero.max_health * 0.25 else Color("ff7769"))
	draw_string(title_font, Vector2(32, 99), "%d / %d" % [ceili(hero.mana), ceili(hero.max_mana)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("acd4f7"))
	draw_rect(Rect2(105, 93, 109, 3), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(105, 93, 109 * clampf(hero.mana / hero.max_mana, 0, 1), 3), Color("85bbeb"))
	if is_instance_valid(game.ally_bot):
		var ally: CharacterBody3D = game.ally_bot
		draw_string(title_font, Vector2(32, 139), "PARTNER  ·  " + ("RECOVERING" if ally.is_down else str(ceili(ally.health))), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, quiet)
		draw_rect(Rect2(32, 146, 182, 3), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(32, 146, 182 * clampf(ally.health / ally.max_health, 0, 1), 3), Color("8bd6ce"))
	draw_string(title_font, Vector2(center_x - 62, 46), "FLOOR %02d / 11" % (game.encounter_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, GOLD)
	for n in 11:
		var point := Vector2(center_x - 65 + n * 13, 62)
		draw_circle(point, 2.5, GOLD if n >= game.completed_encounters else Color(1, 1, 1, 0.15))
	var nearest: CharacterBody3D
	var nearest_distance := 55.0
	var radar := Vector2(viewport.x - 142, 86)
	draw_circle(radar, 42, Color(0.025, 0.035, 0.05, 0.5))
	draw_arc(radar, 42, 0, TAU, 48, Color(1, 1, 1, 0.22), 1, true)
	draw_line(radar - Vector2(36, 0), radar + Vector2(36, 0), Color(1, 1, 1, 0.08), 1)
	draw_line(radar - Vector2(0, 36), radar + Vector2(0, 36), Color(1, 1, 1, 0.08), 1)
	for foe in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = foe.global_position - hero.global_position
		if foe.is_boss and offset.length() < nearest_distance:
			nearest = foe
			nearest_distance = offset.length()
		var point := Vector2(offset.x, offset.z).rotated(hero.yaw) * 0.7
		if point.length() < 37:
			draw_circle(radar + point, 3 if foe.is_boss else 1.5, Color("f1b083"))
	draw_colored_polygon(PackedVector2Array([radar + Vector2(0, -6), radar + Vector2(-4, 4), radar + Vector2(4, 4)]), pale)
	if is_instance_valid(nearest):
		var left := center_x - 150
		draw_string(title_font, Vector2(left, 94), ENCOUNTERS.NAMES[nearest.encounter_index], HORIZONTAL_ALIGNMENT_LEFT, 300, 15, GOLD)
		draw_rect(Rect2(left, 103, 300, 4), Color(1, 1, 1, 0.14))
		draw_rect(Rect2(left, 103, 300 * clampf(nearest.health / nearest.max_health, 0, 1), 4), Color("d6a584"))
	var crosshair := viewport * 0.5
	draw_circle(crosshair, 1.5, pale)
	draw_arc(crosshair, 7, 0, TAU, 24, Color(1, 1, 1, 0.4), 1, true)
	if hit_timer > 0:
		for direction in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(crosshair + direction * 8, crosshair + direction * 14, GOLD if critical_hit else pale, 2, true)
	if damage_flash > 0:
		draw_rect(Rect2(Vector2(3, 3), viewport - Vector2(6, 6)), Color(0.9, 0.2, 0.12, damage_flash * 0.8), false, 6)

func gradient_overlay(parent: Control, horizontal: bool) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.45, 1])
	gradient.colors = PackedColorArray([Color(0.025, 0.065, 0.085, 0.98 if horizontal else 0.9), Color(0.025, 0.065, 0.085, 0.92 if horizontal else 0.45), Color(0.025, 0.065, 0.085, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 64
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(1, 0) if horizontal else Vector2(0, 1)
	var rect := TextureRect.new()
	parent.add_child(rect)
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.z_index = -1
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func layout_anchors(node: Node, extent: Vector2) -> void:
	for child in node.get_children():
		if child is Control:
			if child.has_meta("layout_anchor"):
				if not child.has_meta("layout_offset"):
					child.set_meta("layout_offset", child.position)
				child.position = child.get_meta("layout_offset") + extent * child.get_meta("layout_anchor")
			layout_anchors(child, extent)

func show_world() -> void:
	is_growth_open = false
	is_journal_open = false
	menu_root.hide()
	game_root.hide()
	modal_root.hide()
	world_root.show()
	queue_redraw()

func world_notice(message: String) -> void:
	world_root.notify(message)

func show_story_dialogue(page_index: int = 0) -> void:
	var stage: String = game.progress.current_world().get("quest", "unmet")
	var pages: Array[String] = game.STORY.dialogue(stage, game.chronicle(), game.selected_skin)
	if game.mobile_controls:
		for index in pages.size():
			pages[index] = pages[index].replace("Read them with T; keep them in your journal with J.", "Tap READ ECHO at a stand, then open JOURNAL to compare the evidence.")
	page_index = clampi(page_index, 0, pages.size() - 1)
	var panel: Control = modal("DAWN RESTORED" if stage == "healed" else "ELDER ORIN", "THE BORROWED DAWN  /  %d OF %d" % [page_index + 1, pages.size()], 735)
	var text: RichTextLabel = paragraph(panel, pages[page_index], Vector2(36, 188), Vector2(448, 342), 22)
	text.name = "StoryDialogueBody"
	text.scroll_active = true
	text.mouse_filter = Control.MOUSE_FILTER_STOP
	if page_index > 0:
		button(panel, "PREVIOUS PAGE", Vector2(36, 534), Vector2(210, 28), func() -> void: show_story_dialogue(page_index - 1)).add_theme_font_size_override("font_size", 16)
	if not game.progress.error.is_empty():
		label(panel, game.progress.error, Vector2(36, 704), 14, GOLD, 448)
	if page_index < pages.size() - 1:
		button(panel, "KEEP LISTENING", Vector2(36, 579), Vector2(448, 52), func() -> void: show_story_dialogue(page_index + 1), true).grab_focus()
		button(panel, "LEAVE FOR NOW", Vector2(36, 646), Vector2(448, 43), game.close_story_dialogue)
	elif stage == "unmet":
		button(panel, "I WILL HELP", Vector2(36, 568), Vector2(448, 52), game.accept_quest, true).grab_focus()
		button(panel, "LET ME LOOK AROUND", Vector2(36, 637), Vector2(448, 43), game.close_story_dialogue)
	elif stage == "elixir":
		button(panel, "SPEAK THEIR NAMES" if game.STORY.truth_known(game.chronicle()) else "GIVE MOONWELL ELIXIR", Vector2(36, 568), Vector2(448, 52), game.deliver_elixir, true).grab_focus()
		button(panel, "NOT YET", Vector2(36, 637), Vector2(448, 43), game.close_story_dialogue)
	else:
		button(panel, "CONTINUE", Vector2(36, 611), Vector2(448, 57), game.close_story_dialogue, true).grab_focus()

func confirm_delete_world(id: int) -> void:
	var world_name := ""
	for world in game.progress.worlds:
		if world.id == id:
			world_name = str(world.name)
	if world_name.is_empty():
		return
	var panel: Control = modal("DELETE WORLD?", "This removes its story and level progress.", 570)
	paragraph(panel, 'Delete "' + world_name + '"?\n\nYour shared coins, characters and upgrades will remain. This world cannot be restored from this menu.', Vector2(36, 196), Vector2(448, 185), 23)
	button(panel, "CANCEL", Vector2(36, 409), Vector2(448, 50), func() -> void: modal_root.hide(), true).grab_focus()
	button(panel, "DELETE THIS WORLD", Vector2(36, 479), Vector2(448, 48), func() -> void:
		game.progress.delete_world(id)
		modal_root.hide()
		menu_root.open_page("worlds")
	)

func paragraph(parent: Control, content: String, pos: Vector2, dimensions: Vector2, font_size: int) -> RichTextLabel:
	var node := RichTextLabel.new()
	node.position = pos
	node.size = dimensions
	node.scroll_active = false
	node.fit_content = false
	node.bbcode_enabled = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("normal_font", title_font)
	node.add_theme_font_size_override("normal_font_size", font_size)
	node.add_theme_color_override("default_color", WHITE)
	parent.add_child(node)
	node.text = content
	return node

func show_next_level() -> void:
	var panel: Control = modal("ELIXIR RECOVERED", "Eleven floors cleared. The healing potion is yours.", 650)
	paragraph(panel, "Next Level — Under Construction", Vector2(36, 212), Vector2(448, 114), 36)
	paragraph(panel, "The terrace's Moonwell Elixir is safe. Return to Elder Orin to heal your people, or keep exploring the tower.", Vector2(36, 338), Vector2(448, 100), 21)
	button(panel, "RETURN TO THE CATHEDRAL", Vector2(36, 470), Vector2(448, 55), game.leave_next_portal, true).grab_focus()
	button(panel, "RETURN TO ORIN", Vector2(36, 548), Vector2(448, 48), game.return_to_courtyard)
