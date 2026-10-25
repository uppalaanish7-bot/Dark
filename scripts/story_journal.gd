extends RefCounted
## A paused journal: unknown pages hide their text, and theories require evidence.
const STORY = preload("res://scripts/story_data.gd")
var game: Node3D
var hud: Control

func build(section: String, selected: int, notice: String) -> void:
	var evidence: Dictionary = game.chronicle()
	var subtitle := "%d / 11 ECHOES  ·  %d / 3 MYSTERIES  ·  %s" % [evidence.clues.size(), evidence.solved.size(), game.progress.current_world().get("name", "")]
	var panel: Control = hud.modal("THE BORROWED DAWN", subtitle, 790, 900)
	panel.name = "StoryJournal"
	hud.is_journal_open = true
	hud.button(panel, "ECHOES", Vector2(36, 177), Vector2(126, 36), func() -> void: hud.show_journal("echoes", 0), section == "echoes").add_theme_font_size_override("font_size", 18)
	hud.button(panel, "MYSTERIES", Vector2(174, 177), Vector2(126, 36), func() -> void: hud.show_journal("mysteries", 0), section == "mysteries").add_theme_font_size_override("font_size", 18)
	var divider := ColorRect.new()
	panel.add_child(divider)
	divider.position = Vector2(309, 230)
	divider.size = Vector2(1, 443)
	divider.color = Color("34515a")
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if section == "echoes":
		for index in STORY.ECHOES.size():
			var found: bool = index in evidence.clues
			var caption := "%02d  %s" % [index + 1, STORY.ECHOES[index].title.to_upper() if found else "UNRECOVERED ECHO"]
			var item: Button = hud.button(panel, caption, Vector2(36, 230 + index * 36), Vector2(263, 31), func() -> void: hud.show_journal("echoes", index), selected == index)
			item.name = "EchoPage%02d" % index
			item.add_theme_font_size_override("font_size", 15)
			item.clip_text = true
			item.tooltip_text = STORY.location(index)
		hud.label(panel, "Blue copper marks a memory stand.\n20 XP for each new discovery.", Vector2(36, 641), 17, hud.MUTED, 265)
		build_echo(panel, selected, evidence)
	else:
		for index in STORY.MYSTERIES.size():
			var mystery: Dictionary = STORY.MYSTERIES[index]
			var solved: bool = index in evidence.solved
			var caption: String = ("RESOLVED" if solved else "%d / %d ECHOES" % [STORY.evidence_count(evidence, index), mystery.clues.size()]) + "\n" + mystery.title
			var item: Button = hud.button(panel, caption, Vector2(36, 230 + index * 102), Vector2(263, 87), func() -> void: hud.show_journal("mysteries", index), selected == index)
			item.name = "MysteryPage%02d" % index
			item.add_theme_font_size_override("font_size", 17)
		body(panel, "Find every clue, then choose.\nWrong theories cost nothing.\nRewards are granted once.", Vector2(36, 558), Vector2(263, 116), 18)
		build_mystery(panel, selected, evidence)
	var feedback: Label = hud.label(panel, notice, Vector2(36, 685), 17, hud.GOLD, 828)
	feedback.name = "JournalFeedback"
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.size.y = 43
	hud.button(panel, "RETURN TO THE WORLD" if game.mobile_controls else "RETURN TO THE WORLD  /  J OR ESC", Vector2(36, 735), Vector2(828, 42), game.resume, true).grab_focus()

func body(parent: Control, content: String, at: Vector2, extent: Vector2, font_size: int = 21) -> RichTextLabel:
	var text: RichTextLabel = hud.paragraph(parent, content, at, extent, font_size)
	text.scroll_active = true
	text.mouse_filter = Control.MOUSE_FILTER_STOP
	text.add_theme_constant_override("line_separation", 3)
	return text

func heading(panel: Control, title: String) -> void:
	var label: Label = hud.label(panel, title, Vector2(330, 268), 31, hud.WHITE, 534)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size.y = 65

func build_echo(panel: Control, index: int, evidence: Dictionary) -> void:
	var found: bool = index in evidence.clues
	var echo: Dictionary = STORY.ECHOES[index]
	hud.label(panel, STORY.location(index) + ("  /  RECORDED" if found else "  /  MISSING"), Vector2(330, 230), 18, hud.TEAL, 534)
	heading(panel, echo.title if found else "A memory still missing")
	var content: String = echo.source + "\n\n" + echo.text if found else "Mara hid a blue-copper memory stand in this chamber. The words remain unknown until you find it.\n\nLook for the blue MEMORY ECHO sign above the room's door. Approach the glowing stand and press T, or tap READ ECHO.\n\nYou can track its position while you are on this floor. Echoes are optional; the floor key and guardian still control the stairs."
	if game.mobile_controls: content = content.replace("press T, or tap READ ECHO", "tap READ ECHO")
	var text := body(panel, content, Vector2(330, 339), Vector2(534, 282), 21)
	text.name = "EchoBody"
	if found:
		var mystery_index := 0 if index < 3 else (1 if index < 7 else 2)
		hud.button(panel, "COMPARE THE EVIDENCE", Vector2(330, 635), Vector2(534, 41), func() -> void: hud.show_journal("mysteries", mystery_index))
	else:
		var track: Button = hud.button(panel, "TRACK THIS ECHO", Vector2(330, 635), Vector2(534, 41), func() -> void: game.track_echo(index))
		track.name = "TrackEcho"
		track.disabled = not game.can_track_echo(index)
		track.tooltip_text = "Visit this floor to track its echo." if track.disabled else "Replace the compass objective with this echo's position."

func build_mystery(panel: Control, index: int, evidence: Dictionary) -> void:
	var mystery: Dictionary = STORY.MYSTERIES[index]
	var solved: bool = index in evidence.solved
	var ready: bool = STORY.can_solve(evidence, index)
	hud.label(panel, ("RESOLVED" if solved else "EVIDENCE %d / %d" % [STORY.evidence_count(evidence, index), mystery.clues.size()]) + "  /  %d XP" % mystery.xp, Vector2(330, 230), 18, hud.TEAL, 534)
	heading(panel, mystery.title)
	if solved:
		body(panel, mystery.resolution + ("\n\nAll three mysteries are resolved. Return to Orin with the elixir, or speak to him again if Greywake is already healed." if STORY.truth_known(evidence) else "\n\nYour conclusion is saved. Orin may have more to say about what you found."), Vector2(330, 339), Vector2(534, 334))
	elif not ready:
		var content: String = mystery.question + "\n\nEVIDENCE TO FIND\n"
		for clue in mystery.clues:
			content += "\n" + ("Recorded: " + STORY.ECHOES[clue].title if clue in evidence.clues else "Missing: " + STORY.location(clue))
		content += "\n\nRecover every listed echo to compare the theories."
		body(panel, content, Vector2(330, 339), Vector2(534, 334))
	else:
		body(panel, mystery.question, Vector2(330, 339), Vector2(534, 107))
		for answer in mystery.options.size():
			var choice: Button = hud.button(panel, mystery.options[answer], Vector2(330, 464 + answer * 63), Vector2(534, 49), func() -> void:
				var notice: String = game.solve_mystery(index, answer)
				hud.show_journal("mysteries", index, notice)
			)
			choice.name = "Theory%d" % answer
			choice.add_theme_font_size_override("font_size", 21)
