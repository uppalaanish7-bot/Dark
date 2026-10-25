extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for identity in ["soldier_1","subboss_7"]:
		var actor: Node3D = load("res://assets/provided/"+identity+".glb").instantiate()
		root.add_child(actor)
		for sk in actor.find_children("*","Skeleton3D",true,false):
			sk.reset_bone_poses()
			for b in sk.get_bone_count():
				var n: String=sk.get_bone_name(b)
				if identity=="subboss_7" and b in range(24,52): print(identity," BONE ",b," ",n," ",sk.to_global(sk.get_bone_global_rest(b).origin)," basis=",sk.global_basis*sk.get_bone_global_rest(b).basis)
		for mesh in actor.find_children("*","MeshInstance3D",true,false):
			var sk: Skeleton3D = mesh.get_node_or_null(mesh.skeleton)
			var lo := Vector3(INF,INF,INF)
			var hi := Vector3(-INF,-INF,-INF)
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array=mesh.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
				for n in points.size():
					var p := points[n]
					if sk and mesh.skin and not bones.is_empty():
						p=Vector3.ZERO
						for k in 4:
							var bind: int=bones[n*4+k]
							var bone:int=mesh.skin.get_bind_bone(bind)
							if bone<0: bone=sk.find_bone(mesh.skin.get_bind_name(bind))
							p += (sk.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind)*points[n])*weights[n*4+k]
						p=sk.to_global(p)
					else: p=mesh.to_global(p)
					lo=lo.min(p)
					hi=hi.max(p)
			if "sword" in mesh.name or mesh.name=="Object_193": print(identity," MESH ",actor.get_path_to(mesh)," ",lo," ",hi," skin=",mesh.skin," transform=",mesh.global_transform," local=",mesh.mesh.get_aabb()," material=",mesh.mesh.surface_get_material(0).resource_name)
		actor.free()
	quit()
