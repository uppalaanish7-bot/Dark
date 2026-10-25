extends SceneTree
func _initialize() -> void: call_deferred("run")
func find_root(parents: PackedInt32Array, index: int) -> int:
	while parents[index] != index: index=parents[index]
	return index
func run() -> void:
	var actor: Node3D = load("res://assets/provided/female.glb").instantiate()
	root.add_child(actor)
	var mesh: MeshInstance3D = actor.find_children("*","MeshInstance3D",true,false)[0]
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var parents := PackedInt32Array()
	var weld := {}
	for n in points.size():
		var key := str(points[n].snapped(Vector3.ONE*0.00001))
		parents.append(weld[key] if weld.has(key) else n)
		weld[key]=parents[n]
	for n in range(0,indices.size(),3):
		for k in 3:
			var first := indices[n+k]
			var second := indices[n+(k+1)%3]
			if points[first].y>0.98 or points[second].y>0.98: continue
			parents[find_root(parents,second)]=find_root(parents,first)
	var components := {}
	for n in points.size():
		var group := find_root(parents,n)
		if not components.has(group): components[group]=[0,Vector3.INF,-Vector3.INF,0]
		components[group][0]+=1
		components[group][1]=components[group][1].min(points[n])
		components[group][2]=components[group][2].max(points[n])
		if points[n].z< -0.12 and points[n].y < 0.98: components[group][3]+=1
	for key in components:
		if components[key][0]>10 or components[key][3]>0: print("COMPONENT ",key," ",components[key])
	actor.free()
	quit()
