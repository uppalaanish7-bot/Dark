extends SceneTree
const VISUAL=preload("res://scripts/provided_visual.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for id in ["subboss_3","subboss_4","subboss_5","subboss_6","soldier_4","soldier_6","soldier_8","soldier_9"]:
		var source:=VISUAL.new()
		source.asset_id=id
		root.add_child(source)
		for n in 36:
			source.set_motion_state(Vector3(0,0,-3.8),true,0,0,false,false)
			source.tick(1.0/30,3.8,true)
		source.action("Ice_Cleave",2.0)
		for n in 17: source.tick(1.0/30,0,true)
		var report:Array=[]
		for part in source.find_children("*","MeshInstance3D",true,false):
			for surface in part.mesh.get_surface_count():
				var arrays:Array=part.mesh.surface_get_arrays(surface)
				var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var points:Array=[]
				var posed_points:Array=[]
				var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
				var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
				if bones.is_empty(): continue
				for v in vertices.size():
					var point:Vector3=vertices[v]
					points.append([point.x,point.y,point.z])
					var posed:=Vector3.ZERO
					for k in 4:
						var bone:int=bones[v*4+k]
						posed+=(source.skeleton.get_bone_global_pose(bone)*part.skin.get_bind_pose(bone)*point)*weights[v*4+k]
					posed_points.append([posed.x,posed.y,posed.z])
				report.append({"points":points,"posed":posed_points,"bones":Array(bones),"weights":Array(weights),"indices":Array(arrays[Mesh.ARRAY_INDEX])})
		var output:=FileAccess.open("res://art/asset_review/"+id+"_geometry.json",FileAccess.WRITE)
		output.store_string(JSON.stringify(report))
		source.free()
	quit()
