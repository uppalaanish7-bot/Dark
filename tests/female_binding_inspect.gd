extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for path in ["res://assets/provided/female.glb", "res://assets/sculpt_motion/female.scn"]:
		var actor: Node3D = load(path).instantiate()
		root.add_child(actor)
		var sk: Skeleton3D = actor.find_children("*","Skeleton3D",true,false)[0]
		sk.reset_bone_poses()
		print("SOURCE ",path," transform=",sk.global_transform)
		for i in sk.get_bone_count(): print("BONE ",i," ",sk.get_bone_name(i)," parent=",sk.get_bone_parent(i)," rest=",sk.get_bone_global_rest(i))
		for mesh in sk.find_children("*","MeshInstance3D",true,false):
			print("MESH ",mesh.name," surfaces=",mesh.mesh.get_surface_count()," binds=",mesh.skin.get_bind_count())
			for bind in mesh.skin.get_bind_count(): print("BIND ",bind," bone=",mesh.skin.get_bind_bone(bind)," name=",mesh.skin.get_bind_name(bind))
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var count := 0
				var low := Vector3.INF
				var high := -Vector3.INF
				var bone_bounds := {}
				for n in points.size():
					var p: Vector3 = mesh.to_global(points[n])
					low=low.min(p);high=high.max(p)
					for k in 4:
						if weights[n*4+k] < 0.05: continue
						var key: String = mesh.skin.get_bind_name(bones[n*4+k])
						if not bone_bounds.has(key): bone_bounds[key] = [Vector3.INF,-Vector3.INF,0]
						bone_bounds[key][0]=bone_bounds[key][0].min(p)
						bone_bounds[key][1]=bone_bounds[key][1].max(p)
						bone_bounds[key][2]+=1
					if p.y<1.3 and absf(p.x)<0.45:
						for k in 4:
							if weights[n*4+k]<0.01: continue
							var b: int = mesh.skin.get_bind_bone(bones[n*4+k])
							if b<0: b=sk.find_bone(mesh.skin.get_bind_name(bones[n*4+k]))
							if "arm" in sk.get_bone_name(b) or "hand" in sk.get_bone_name(b): count+=1
				print("SURFACE ",surface," material=",mesh.mesh.surface_get_material(surface).resource_name," vertices=",points.size()," body_arm_influences=",count," bounds=",low," ",high)
				print("REGIONS ",bone_bounds)
		actor.free()
	quit()
