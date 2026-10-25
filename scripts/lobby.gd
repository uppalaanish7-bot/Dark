extends Control
const DATA = preload("res://scripts/campaign_data.gd")
const WHITE := Color("eef1e5")
const MUTED := Color("9cacac")
const TEAL := Color("8bedd6")
const GOLD := Color("efbe83")
var game: Node3D
var hud: Control
var canvas: Control
var page: Control
var wallet: Label
var footer: Label
var nav_buttons: Dictionary = {}
var section: String = "lobby"
var market_category: String = "CHARACTERS"
var notice: Label
var selected_guardian: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas = Control.new()
	add_child(canvas)
	canvas.size = Vector2(1440, 900)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient: TextureRect = hud.gradient_overlay(canvas, true)
	gradient.size = Vector2(1150, 900)
	var bottom: TextureRect = hud.gradient_overlay(canvas, false)
	bottom.flip_v = true
	bottom.position = Vector2(0, 580)
	bottom.size = Vector2(1440, 320)
	text_at(canvas, "H E R O", 44, 30, 46)
	text_at(canvas, "T H E   H O L L O W   S P I R E", 46, 86, 14, TEAL)
	text_at(canvas, "ELEVEN-FLOOR GAUNTLET", 316, 45, 17, MUTED)
	var balance := panel_at(canvas, Vector2(1124, 32), Vector2(272, 66))
	wallet = text_at(balance, "", 20, 14, 25, GOLD, 234)
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text_at(canvas, "YOUR LOADOUT", 46, 168, 16, TEAL)
	var navigation := [["lobby", "LOBBY"], ["characters", "CHARACTERS"], ["bestiary", "THE ELEVEN"], ["worlds", "MY WORLDS"]]
	for index in range(navigation.size()):
		var key: String = navigation[index][0]
		var nav: Button = hud.button(canvas, navigation[index][1], Vector2(44, 210 + index * 62), Vector2(224, 50), func() -> void: open_page(key))
		nav.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav_buttons[key] = nav
	hud.button(canvas, "SETTINGS", Vector2(44, 728), Vector2(224, 43), hud.show_settings)
	hud.button(canvas, "HOW TO PLAY", Vector2(44, 781), Vector2(224, 43), hud.show_controls)
	footer = text_at(canvas, "OFFLINE  /  SOLO CAMPAIGN", 44, 851, 14, MUTED, 600)
	page = Control.new()
	canvas.add_child(page)
	page.size = canvas.size
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	open_page("lobby")

func _process(_delta: float) -> void:
	var ratio := minf(size.x / 1440.0, size.y / 900.0)
	canvas.scale = Vector2.ONE * ratio
	canvas.position = (size - canvas.size * ratio) * 0.5
	wallet.text = "%s   COINS" % game.progress.coins
	footer.text = game.progress.error if not game.progress.error.is_empty() else "OFFLINE  /  SOLO CAMPAIGN  /  PROGRESS SAVED LOCALLY"
	footer.add_theme_color_override("font_color", GOLD if not game.progress.error.is_empty() else MUTED)

func text_at(parent: Control, value: String, x: float, y: float, font_size: int = 20, color: Color = WHITE, width: float = 700) -> Label:
	return hud.label(parent, value, Vector2(x, y), font_size, color, width)

func panel_at(parent: Control, pos: Vector2, dimensions: Vector2, border: Color = Color("365054")) -> Panel:
	var panel := Panel.new()
	parent.add_child(panel)
	panel.position = pos
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", hud.style(Color(0.035, 0.09, 0.115, 0.96), border))
	return panel

func empty_slot(parent: Control, pos: Vector2, dimensions: Vector2, index: int) -> Panel:
	var slot := panel_at(parent, pos, dimensions, Color("2b4149"))
	slot.set_meta("empty_slot", true)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No item art, names, prices or purchase actions in a reserved slot.
	text_at(slot, "%02d" % index, 12, dimensions.y - 28, 14, Color("667d83"), 40)
	return slot

func open_page(key: String) -> void:
	section = key
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	for nav_key in nav_buttons:
		nav_buttons[nav_key].add_theme_stylebox_override("normal", hud.style(Color("254c4c") if nav_key == key else Color("10252d"), TEAL if nav_key == key else Color("365054")))
	match key:
		"lobby": build_home()
		"characters": build_characters()
		"costumes": build_collection("COSTUMES", DATA.COSTUME_SLOTS)
		"character_skins": build_collection("CHARACTER SKINS", DATA.CHARACTER_SKIN_SLOTS)
		"bestiary": build_bestiary()
		"market": build_market()
		"worlds": build_worlds()

func heading(title: String, subtitle: String) -> Control:
	var body := panel_at(page, Vector2(300, 140), Vector2(1096, 686))
	text_at(body, title, 30, 20, 40)
	text_at(body, subtitle, 32, 76, 19, MUTED, 1020)
	return body

func build_home() -> void:
	text_at(page, "THE ELEVEN-FLOOR BOSS TOWER", 316, 166, 17, TEAL)
	text_at(page, "THE HOLLOW\nSPIRE.", 309, 203, 64, WHITE, 620)
	text_at(page, "Eleven guardians. Eleven arena floors. One central lift.\nFight beside your AI partner and earn each ascent.", 316, 375, 23, MUTED, 600)
	var world: Dictionary = game.progress.current_world()
	if world.is_empty():
		text_at(page, "THE LIFT IS READY", 996, 510, 26, GOLD, 400)
		text_at(page, "Create a saved world and begin on floor one.", 996, 563, 21, WHITE, 400)
		hud.button(page, "CREATE / SELECT WORLD   >", Vector2(995, 749), Vector2(401, 75), game.enter_world, true)
		return
	var level: int = world.level
	var mission := panel_at(page, Vector2(995, 388), Vector2(401, 336))
	text_at(mission, "THE HOLLOW SPIRE", 24, 23, 16, TEAL, 350)
	var world_title := text_at(mission, str(world.get("name", "Saved World")), 24, 55, 31, WHITE, 350)
	world_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	world_title.clip_text = true
	text_at(mission, "11-FLOOR GAUNTLET", 24, 112, 17, GOLD, 350)
	text_at(mission, "One Guardian at a Time", 24, 148, 25, WHITE, 350)
	text_at(mission, "Clear every retinue, ride the central lift, and reach Nox on the summit.", 24, 190, 20, MUTED, 350)
	hud.button(mission, "CHANGE WORLD", Vector2(24, 265), Vector2(353, 46), func() -> void: open_page("worlds"))
	var character: int = game.selected_skin
	var rank: int = game.progress.ranks[character]
	var info := panel_at(page, Vector2(316, 685), Vector2(638, 139))
	text_at(info, "HERO   /   %s   /   RANK %d" % [DATA.CHARACTERS[character].name, rank], 24, 17, 27, WHITE, 600)
	text_at(info, DATA.CHARACTERS[character].ability + "  /  PASSIVE", 24, 60, 16, TEAL, 590)
	text_at(info, DATA.ability_text(character, rank), 24, 90, 21, MUTED, 590)
	hud.button(page, "ASCEND THE SPIRE   >", Vector2(995, 749), Vector2(401, 75), game.enter_world, true)

func build_characters() -> void:
	var body := heading("CHARACTERS", "Seraphina, the Ember Vow, commands fire. Omega, the Astral Reliquary, commands lightning. Both wield the Canticle Blade.")
	for i in range(DATA.CHARACTERS.size()):
		var index: int = i
		var rank: int = game.progress.ranks[i]
		var card := panel_at(body, Vector2(30 + i * 522, 128), Vector2(506, 312), TEAL if game.selected_skin == i else Color("365054"))
		card.clip_contents = true
		var portrait := TextureRect.new()
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = load("res://assets/ui/girl_knight_portrait.png" if i == 0 else "res://assets/ui/omega_knight_portrait.png")
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)
		portrait.position = Vector2(236, 8)
		portrait.size = Vector2(258, 296)
		text_at(card, "0%d  /  %s" % [i + 1, DATA.CHARACTERS[i].ability], 16, 28, 17, GOLD, 215)
		text_at(card, "SWORD\n"+("FIRE" if i==0 else "LIGHTNING")+"\nAGILITY", 16, 64, 20, TEAL, 200)
		text_at(card, DATA.CHARACTERS[i].name, 16, 156, 25, WHITE, 218)
		text_at(card, "RANK %d / %d  •  %s" % [rank, DATA.MAX_RANK, "SELECTED" if game.selected_skin == i else "OWNED"], 16, 193, 15, TEAL, 222)
		text_at(card, DATA.CHARACTERS[i].ability, 16, 221, 17, MUTED, 220)
		var select: Button = hud.button(card, "SELECTED" if game.selected_skin == i else "SELECT", Vector2(15, 258), Vector2(220, 40), func() -> void:
			game.select_skin(index)
			open_page("characters")
		)
		select.disabled = game.selected_skin == i
	var selected: int = game.selected_skin
	var current_rank: int = game.progress.ranks[selected]
	text_at(body, DATA.CHARACTERS[selected].ability + "  /  PASSIVE ABILITY", 32, 464, 22, TEAL, 670)
	text_at(body, DATA.CHARACTERS[selected].description, 32, 503, 21, WHITE, 700)
	text_at(body, "NOW   " + DATA.ability_text(selected, current_rank), 32, 544, 22, GOLD, 670)
	var cost := DATA.upgrade_cost(current_rank)
	var maxed: bool = current_rank == DATA.MAX_RANK
	text_at(body, "MAXIMUM RANK REACHED" if maxed else "NEXT   " + DATA.ability_text(selected, current_rank + 1), 32, 579, 19, MUTED, 670)
	var upgrade: Button = hud.button(body, "MAX RANK" if maxed else "UPGRADE  /  %d COINS" % cost, Vector2(736, 493), Vector2(326, 58), func() -> void:
		game.progress.upgrade(selected)
		open_page("characters")
	, true)
	upgrade.disabled = maxed or game.progress.coins < cost
	text_at(body, "" if maxed else ("Ready to upgrade" if game.progress.coins >= cost else "%d more coins needed" % (cost - game.progress.coins)), 739, 568, 18, MUTED, 330)
	text_at(body, "Upgrades strengthen your ability in every world.", 32, 638, 17, MUTED)

func build_collection(title: String, count: int) -> void:
	var body := heading(title, "%02d empty slots  /  Your collection will appear here." % count)
	var columns := 5 if count == 20 else 4
	var width := 195 if count == 20 else 248
	var height := 103 if count == 20 else 202
	for i in range(count):
		empty_slot(body, Vector2(32 + (i % columns) * (width + 14), 137 + (i / columns) * (height + 16)), Vector2(width, height), i + 1)
	text_at(body, "NO ITEMS YET", 32, 627, 18, TEAL)

func build_market() -> void:
	var body := heading("MARKETPLACE", "Earn coins in battle. Future characters, blades and costumes will appear here.")
	var categories := ["CHARACTERS", "BLADES", "COSTUMES"]
	for i in range(categories.size()):
		var category: String = categories[i]
		var tab: Button = hud.button(body, category, Vector2(32 + i * 252, 126), Vector2(236, 43), func() -> void:
			market_category = category
			open_page("market")
		)
		if market_category == category:
			tab.add_theme_stylebox_override("normal", hud.style(Color("254c4c"), TEAL))
	for i in range(20):
		empty_slot(body, Vector2(32 + (i % 5) * 209, 193 + (i / 5) * 99), Vector2(195, 86), i + 1)
	text_at(body, "MARKETPLACE IS EMPTY", 32, 606, 20, TEAL)
	text_at(body, "+10 coins per enemy  /  +100 per guardian  /  +500 for the first level clear", 32, 642, 18, MUTED, 1010)

func build_worlds() -> void:
	var body := heading("MY WORLDS", "Each world saves its own story, XP and hero levels. Character ranks and coins are shared.")
	var scroll := ScrollContainer.new()
	body.add_child(scroll)
	scroll.position = Vector2(32, 128)
	scroll.size = Vector2(300, 328)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	scroll.add_child(list)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	for world in game.progress.worlds:
		var id: int = world.id
		var select: Button = hud.button(list, "%s\n%d / %d COMPLETED" % [world.name, world.completed, DATA.LEVELS.size()], Vector2.ZERO, Vector2(280, 74), func() -> void:
			game.progress.select_world(id)
			open_page("worlds")
		)
		select.custom_minimum_size = Vector2(280, 74)
		select.add_theme_font_size_override("font_size", 19)
		select.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if id == game.progress.active_world:
			select.add_theme_stylebox_override("normal", hud.style(Color("254c4c"), TEAL))
	text_at(body, "CREATE A WORLD", 32, 479, 17, TEAL, 280)
	var input := LineEdit.new()
	body.add_child(input)
	input.position = Vector2(32, 517)
	input.size = Vector2(300, 47)
	input.max_length = 24
	input.placeholder_text = "Name your world"
	input.add_theme_font_size_override("font_size", 20)
	input.add_theme_stylebox_override("normal", hud.style(Color("08191f"), Color("40595b")))
	var create := func() -> void:
		if game.progress.create_world(input.text):
			open_page("worlds")
		else:
			notice.text = game.progress.error
	hud.button(body, "+ CREATE WORLD", Vector2(32, 580), Vector2(300, 47), create)
	input.text_submitted.connect(func(_value: String) -> void: create.call())
	notice = text_at(body, "", 32, 636, 15, GOLD, 325)
	var selected: Dictionary = game.progress.current_world()
	if selected.is_empty():
		text_at(body, "NO WORLDS YET", 374, 260, 34, WHITE, 640)
		text_at(body, "Create a world on the left to begin Hero's story.", 374, 318, 22, MUTED, 640)
		return
	hud.button(body, "DELETE WORLD", Vector2(863, 126), Vector2(191, 41), func() -> void: hud.confirm_delete_world(int(selected.id)))
	var world_title := text_at(body, str(selected.name).to_upper(), 372, 129, 28, WHITE, 475)
	world_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	world_title.clip_text = true
	text_at(body, "CHOOSE YOUR LEVEL", 374, 176, 17, TEAL, 680)
	for i in range(DATA.LEVEL_CAPACITY):
		var level: int = i + 1
		var available: bool = i < DATA.LEVELS.size()
		var unlocked: bool = available and level <= int(selected.completed) + 1
		var caption: String = "COMING LATER"
		if available:
			caption = "COMPLETED" if level <= int(selected.completed) else ("PLAY" if unlocked else "LOCKED")
		var tile: Button = hud.button(body, "%02d\n%s" % [level, caption], Vector2(374 + (i % 5) * 139, 220 + (i / 5) * 103), Vector2(125, 89), func() -> void:
			game.progress.select_level(level)
			open_page("worlds")
		)
		tile.add_theme_font_size_override("font_size", 15)
		tile.disabled = not unlocked
		if selected.level == level:
			tile.add_theme_stylebox_override("normal", hud.style(Color("254c4c"), TEAL))
	var level: int = selected.level
	text_at(body, DATA.LEVELS[level - 1].name, 374, 447, 30, WHITE, 675)
	text_at(body, DATA.LEVELS[level - 1].subtitle, 374, 493, 20, MUTED, 674)
	text_at(body, "Enter the world, then walk through the glowing door.\nThe portal starts the level selected above.", 374, 534, 19, MUTED, 674)
	hud.button(body, "ENTER WORLD   /   LEVEL %02d" % level, Vector2(374, 604), Vector2(680, 54), game.enter_world, true)

func build_bestiary() -> void:
	var body := heading("THE ELEVEN GUARDIANS", "Eleven wardens bound to protect the Moonwell. Each guards a floor of the Hollow Spire.")
	var encounters = preload("res://scripts/encounter_data.gd")
	for i in range(11):
		var index: int = i
		var row: Button = hud.button(body,"%02d   %s" % [i+1,encounters.NAMES[i]],Vector2(30,124+i*45),Vector2(480,41),func() -> void:
			selected_guardian = index
			open_page("bestiary")
		)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size",18)
		if i == selected_guardian:
			row.add_theme_stylebox_override("normal",hud.style(Color("21333b"),encounters.COLORS[i]))
			row.add_theme_color_override("font_color",encounters.COLORS[i])
	var data: Dictionary = encounters.record(selected_guardian)
	var detail := panel_at(body,Vector2(536,124),Vector2(530,491),data.color)
	text_at(detail,"SUB-BOSS" if selected_guardian < 9 else ("GRAND BOSS" if selected_guardian == 9 else "MAIN BOSS"),26,24,17,data.color,475)
	text_at(detail,data.name,24,63,25,WHITE,480)
	text_at(detail,data.title,26,109,20,MUTED,475)
	text_at(detail,str(data.element).to_upper(),24,165,50,data.color,475)
	hud.paragraph(detail,data.description,Vector2(26,246),Vector2(478,118),22)
	hud.paragraph(detail,"Watch the guardian's stance, evade its strike, and counter during recovery. Your dodge and movement cost no mana.",Vector2(26,378),Vector2(478,94),18)
