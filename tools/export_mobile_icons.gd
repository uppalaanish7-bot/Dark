extends SceneTree

func _initialize() -> void:
	var svg := FileAccess.get_file_as_string("res://assets/hero_icon.svg")
	var icon := Image.new()
	if icon.load_svg_from_string(svg, 1.5) != OK:
		quit(1)
		return
	icon.save_png("res://assets/hero_192.png")
	# Keep the complete emblem inside Android's central adaptive-icon safe area.
	var emblem := Image.new()
	emblem.load_svg_from_string(svg, 2.0)
	var foreground := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	foreground.fill(Color.TRANSPARENT)
	foreground.blit_rect(emblem, Rect2i(0, 0, 256, 256), Vector2i(88, 88))
	foreground.save_png("res://assets/hero_adaptive_foreground.png")
	var background := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	background.fill(Color("111827"))
	background.save_png("res://assets/hero_adaptive_background.png")
	quit()
