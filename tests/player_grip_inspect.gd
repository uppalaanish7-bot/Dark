extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for id in ["female", "omega"]:
		var model: Node3D = load("res://assets/provided/"+id+".glb").instantiate()
		root.add_child(model)
		for sk in model.find_children("*", "Skeleton3D", true, false):
			print("RIG ",id," ",model.get_path_to(sk)," basis ",sk.global_basis)
			for i in sk.get_bone_count():
				print(i," ",sk.get_bone_name(i)," p=",sk.get_bone_parent(i)," origin=",sk.to_global(sk.get_bone_global_rest(i).origin)," basis=",sk.get_bone_global_rest(i).basis)
		model.free()
	quit()
