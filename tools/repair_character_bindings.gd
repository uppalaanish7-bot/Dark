extends SceneTree
## Preserve source meshes/materials while repairing rest-space placement and
## a small number of skirt vertices assigned to the Girl Knight's arms.
func _initialize() -> void: call_deferred("run")
func own(node: Node, parent: Node) -> void:
	for child in node.get_children():
		child.owner=parent
		own(child,parent)
func save_scene(scene: Node3D, identity: String) -> void:
	own(scene,scene)
	var packed := PackedScene.new()
	packed.pack(scene)
	var err := ResourceSaver.save(packed,"res://assets/sculpt_motion/"+identity+".scn")
	print("CHARACTER_BINDING_REPAIRED ",identity," status=",err)
	scene.free()
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/sculpt_motion")
	var requested := OS.get_cmdline_user_args()
	if requested.is_empty() or "female" in requested: repair_female()
	if requested.is_empty() or "subboss_1" in requested: repair_stelae()
	quit()

func component_root(parents: PackedInt32Array, index: int) -> int:
	while parents[index] != index: index = parents[index]
	return index

func cape_vertices(points: PackedVector3Array, indices: PackedInt32Array) -> PackedByteArray:
	# The hanging cape is a separate connected region below the belt. A
	# distance-only bind assigned its upper half to the thighs. Weld UV seams
	# for this connectivity test, then seed the known rear hem below the belt.
	var parents := PackedInt32Array()
	var welded := {}
	for n in points.size():
		var key := str(points[n].snapped(Vector3.ONE * 0.00001))
		parents.append(welded[key] if welded.has(key) else n)
		welded[key] = parents[n]
	for n in range(0, indices.size(), 3):
		for k in 3:
			var first := indices[n+k]
			var second := indices[n+(k+1)%3]
			if points[first].y > 0.98 or points[second].y > 0.98: continue
			parents[component_root(parents, second)] = component_root(parents, first)
	var regions := {}
	for n in points.size():
		if points[n].z < -0.12 and points[n].y < 0.98: regions[component_root(parents,n)] = true
	var mask := PackedByteArray()
	mask.resize(points.size())
	for n in points.size(): mask[n] = 1 if regions.has(component_root(parents,n)) else 0
	return mask

func repair_female() -> void:
	var source: Node3D=load("res://assets/provided/female.glb").instantiate()
	root.add_child(source)
	var rig: Skeleton3D=source.find_children("*","Skeleton3D",true,false)[0]
	rig.reset_bone_poses()
	var cape := rig.find_bone("cape")
	var previous := cape
	for spec in [["cape_mid", Vector3(0,0.67,-0.115)], ["cape_tip", Vector3(0,0.36,-0.17)]]:
		rig.add_bone(spec[0])
		var index := rig.find_bone(spec[0])
		var desired := Transform3D(rig.get_bone_global_rest(cape).basis, spec[1])
		rig.set_bone_parent(index, previous)
		rig.set_bone_rest(index, rig.get_bone_global_rest(previous).affine_inverse() * desired)
		previous = index
	rig.reset_bone_poses()
	var repaired := 0
	var cloth_repaired := 0
	for instance in source.find_children("*","MeshInstance3D",true,false):
		instance.skin = instance.skin.duplicate()
		var binds := {}
		for bind in instance.skin.get_bind_count():
			var name: String = instance.skin.get_bind_name(bind)
			if name.is_empty(): name=rig.get_bone_name(instance.skin.get_bind_bone(bind))
			binds[name] = bind
		for name in ["cape_mid","cape_tip"]:
			binds[name] = instance.skin.get_bind_count()
			instance.skin.add_named_bind(name, rig.get_bone_global_rest(rig.find_bone(name)).affine_inverse())
		var result := ArrayMesh.new()
		for surface in instance.mesh.get_surface_count():
			var arrays: Array=instance.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var cloth := cape_vertices(points, arrays[Mesh.ARRAY_INDEX])
			for n in points.size():
				var p: Vector3=instance.to_global(points[n])
				if cloth[n] != 0:
					var upper: String = "cape" if p.y >= 0.67 else "cape_mid"
					var lower: String = "cape_mid" if p.y >= 0.67 else "cape_tip"
					var blend := smoothstep(0.67,1.05,p.y) if p.y >= 0.67 else smoothstep(0.36,0.67,p.y)
					bones[n*4] = binds[upper]
					bones[n*4+1] = binds[lower]
					weights[n*4] = blend
					weights[n*4+1] = 1.0-blend
					weights[n*4+2] = 0.0
					weights[n*4+3] = 0.0
					cloth_repaired += 1
					continue
				if p.y>1.10 or absf(p.x)>0.43: continue
				var affected := false
				for k in 4:
					var bind: int=bones[n*4+k]
					var bone: int=instance.skin.get_bind_bone(bind)
					if bone<0: bone=rig.find_bone(instance.skin.get_bind_name(bind))
					var name := rig.get_bone_name(bone)
					if "arm" in name or "hand" in name:
						bones[n*4+k]=binds["cape" if p.z < -0.065 else "pelvis"]
						affected=true
				if affected: repaired+=1
			arrays[Mesh.ARRAY_BONES]=bones
			arrays[Mesh.ARRAY_WEIGHTS]=weights
			arrays[Mesh.ARRAY_TANGENT]=null
			for custom in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]: arrays[custom]=null
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			result.surface_set_material(surface,instance.mesh.surface_get_material(surface))
		instance.mesh=result
	print("GIRL_SKIRT_REPAIRED_VERTICES ",repaired)
	print("GIRL_CAPE_REBOUND_VERTICES ",cloth_repaired," bones=",rig.get_bone_count())
	save_scene(source,"female")
func repair_stelae() -> void:
	var source: Node3D=load("res://assets/provided/subboss_1.glb").instantiate()
	root.add_child(source)
	var rigs:=source.find_children("*","Skeleton3D",true,false)
	var body: Skeleton3D=rigs[0]
	var prop: Skeleton3D=rigs[1]
	if body.get_bone_count()<prop.get_bone_count():
		var swap:=body
		body=prop
		prop=swap
	body.reset_bone_poses()
	prop.reset_bone_poses()
	# The source exporter used an animated pose for normalization, leaving
	# the neutral body below the ground. Normalize its actual rest mesh.
	var low:=Vector3(INF,INF,INF)
	var high:=Vector3(-INF,-INF,-INF)
	for mesh in body.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var a: Array=mesh.mesh.surface_get_arrays(surface)
			var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
			for n in v.size():
				var p:=posed_vertex(mesh,body,a,n)
				low=low.min(p)
				high=high.max(p)
	var factor:=2.1/(high.y-low.y)
	var offset:=Vector3(-(high.x+low.x)*0.5,-low.y,-(high.z+low.z)*0.5)*factor
	body.global_transform=Transform3D(body.global_basis*factor,body.global_position*factor+offset)
	# The original sword has an independent one-bone rig and floated above
	# the actor. Bake only this rigid prop into rest space and attach its hilt
	# to the actual hand, retaining the sword geometry and texture atlas.
	var hand:=body.find_bone("QuickRigCharacter_RightHand_019")
	var attachment:=BoneAttachment3D.new()
	attachment.name="StelaeSwordGrip"
	attachment.bone_name=body.get_bone_name(hand)
	body.add_child(attachment)
	var hand_rest:=body.get_bone_global_rest(hand)
	var forearm:=body.find_bone("QuickRigCharacter_RightForeArm_018")
	var fingers: Vector3=(body.global_basis*(hand_rest.origin-body.get_bone_global_rest(forearm).origin)).normalized()
	var blade: Vector3=(Vector3.BACK-fingers*Vector3.BACK.dot(fingers)).normalized()
	var face:=(-fingers).cross(blade).normalized()
	var grip_basis:=Basis(blade.cross(face),blade,face)
	var rigid:=Node3D.new()
	rigid.name="AuthoredSword"
	attachment.add_child(rigid)
	var hand_world: Basis=(body.global_basis*hand_rest.basis).orthonormalized()
	rigid.basis=(body.global_basis*hand_rest.basis).inverse()*grip_basis
	rigid.position=hand_rest.basis.inverse()*(body.global_basis.inverse()*(fingers*0.07))
	var sword_grip:=Vector3(-0.131576,-0.38,-0.859013)
	for instance in prop.find_children("*","MeshInstance3D",true,false):
		var result:=ArrayMesh.new()
		for surface in instance.mesh.get_surface_count():
			var arrays: Array=instance.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			for n in points.size():
				points[n]=(posed_vertex(instance,prop,arrays,n)-sword_grip)*0.83
				if n<normals.size(): normals[n]=(prop.global_basis*normals[n]).normalized()
			arrays[Mesh.ARRAY_VERTEX]=points
			arrays[Mesh.ARRAY_NORMAL]=normals
			arrays[Mesh.ARRAY_BONES]=null
			arrays[Mesh.ARRAY_WEIGHTS]=null
			arrays[Mesh.ARRAY_TANGENT]=null
			for custom in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]: arrays[custom]=null
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			result.surface_set_material(surface,instance.mesh.surface_get_material(surface))
		var baked:=MeshInstance3D.new()
		baked.mesh=result
		rigid.add_child(baked)
	prop.free()
	save_scene(source,"subboss_1")
func posed_vertex(mesh: MeshInstance3D, sk: Skeleton3D, arrays: Array, n: int) -> Vector3:
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var p:=Vector3.ZERO
	for k in 4:
		var bind: int=bones[n*4+k]
		var bone: int=mesh.skin.get_bind_bone(bind)
		if bone<0: bone=sk.find_bone(mesh.skin.get_bind_name(bind))
		p+=(sk.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind)*points[n])*weights[n*4+k]
	return sk.to_global(p)
