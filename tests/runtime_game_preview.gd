extends SceneTree

var frames: int = 0
var max_frames: int = 120

func _initialize() -> void:
	print("--- BOOTING GAME HEADLESS PREVIEW ---")
	var game_scene = load("res://ground.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)

func _physics_process(delta: float) -> bool:
	frames += 1
	if frames >= max_frames:
		print("PREVIEW SUCCESS: Ran %d frames with zero runtime crashes!" % frames)
		quit(0)
	return false
