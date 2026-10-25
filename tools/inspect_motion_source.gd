extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene: Node3D = load("res://Godot/AnimationLibrary_Godot_Standard.glb").instantiate()
	root.add_child(scene)
	for ap in scene.find_children("*", "AnimationPlayer", true, false):
		for clip in ap.get_animation_list():
			var animation: Animation = ap.get_animation(clip)
			print("CLIP ",clip," ",animation.length," tracks=",animation.get_track_count())
	for sk in scene.find_children("*", "Skeleton3D", true, false):
		print("SKELETON ",scene.get_path_to(sk)," basis ",sk.global_basis)
		for i in sk.get_bone_count():
			print("BONE ",i," ",sk.get_bone_name(i)," ",sk.get_bone_global_rest(i).origin)
	quit()
