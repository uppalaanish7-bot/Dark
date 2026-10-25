extends SceneTree
## Fit articulated region-weighted rigs to the supplied static sculptures.
## Source GLBs and texture maps remain unchanged. Full-body mocap is deliberately
## not applied to these fused armour/cloth meshes: poses are authored per region.
const IDS := ["subboss_2","subboss_3","subboss_4","subboss_5","subboss_6","subboss_8","subboss_9","soldier_2","soldier_3","soldier_4","soldier_5","soldier_6","soldier_7","soldier_8","soldier_9","grand_boss","grand_soldier","main_boss"]
# Preserve the original indices and append elbow/ankle articulation. Identity
# rest bases give every model common X pitch, Y twist and Z lateral axes.
const PARENTS := [-1,0,1,1,1,0,0,5,6,1,1,0,0,3,4,7,8]
const NAMES := ["sculpt_pelvis","sculpt_spine","sculpt_head","sculpt_arm_l","sculpt_arm_r","sculpt_thigh_l","sculpt_thigh_r","sculpt_shin_l","sculpt_shin_r","sculpt_wing_l","sculpt_wing_r","sculpt_hem_l","sculpt_hem_r","sculpt_forearm_l","sculpt_forearm_r","sculpt_foot_l","sculpt_foot_r"]
var report: Array = []

func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/sculpt_motion")
	var selected:PackedStringArray=OS.get_cmdline_user_args()
	for id in IDS:
		if selected.is_empty() or id in selected: bake(id)
	var file := FileAccess.open("res://art/asset_review/sculpt_rigs.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("SCULPT_RIGS_READY ",report.size())
	quit()

func fit(id: String) -> Dictionary:
	var profile := {"hip":0.98,"hip_width":0.16,"knee":0.53,"ankle":0.16,"shoulder":1.59,"shoulder_width":0.28,"head":1.79,"elbow":1.27,"elbow_width":0.36,"wrist":1.02,"wrist_width":0.40,"winged":id in ["subboss_9","soldier_9","grand_boss"],"spectral":id in ["main_boss","grand_soldier"],"cloth":id in ["subboss_4","subboss_5","subboss_6","subboss_8","soldier_2","soldier_3","soldier_4","soldier_5","soldier_6","soldier_7","soldier_8","main_boss","grand_soldier"]}
	if id in ["subboss_3","subboss_8"]:
		profile.merge({"hip":0.93,"hip_width":0.20,"knee":0.49,"ankle":0.14,"shoulder":1.48,"shoulder_width":0.35,"head":1.73,"elbow":1.20,"elbow_width":0.45,"wrist":0.92,"wrist_width":0.51},true)
	if profile.winged:
		profile.merge({"hip":0.88,"hip_width":0.17,"knee":0.47,"ankle":0.14,"shoulder":1.43,"shoulder_width":0.28,"head":1.67,"elbow":1.15,"elbow_width":0.37,"wrist":0.91,"wrist_width":0.43},true)
	if id=="subboss_5": profile.merge({"shoulder":1.56,"shoulder_width":0.31,"head":1.78,"elbow_width":0.41,"wrist_width":0.45},true)
	if id=="subboss_6": profile.merge({"shoulder":1.56,"head":1.79,"wrist":0.96,"wrist_width":0.44},true)
	var sh: float=profile.shoulder
	var sw: float=profile.shoulder_width
	var ew: float=profile.elbow_width
	var el: float=profile.elbow
	var hi: float=profile.hip
	var hw: float=profile.hip_width
	var joints: Array[Vector3] = [Vector3(0,hi,0),Vector3(0,hi+0.25,0),Vector3(0,profile.head,0),Vector3(sw,sh,0),Vector3(-sw,sh,0),Vector3(hw,hi,0),Vector3(-hw,hi,0),Vector3(hw+0.02,profile.knee,0),Vector3(-hw-0.02,profile.knee,0),Vector3(sw,sh,0.12),Vector3(-sw,sh,0.12),Vector3(hw,hi-0.08,0.13),Vector3(-hw,hi-0.08,0.13),Vector3(ew,el,0),Vector3(-ew,el,0),Vector3(hw+0.03,profile.ankle,0),Vector3(-hw-0.03,profile.ankle,0)]
	var wrists: Array[Vector3] = [Vector3(profile.wrist_width,profile.wrist,-0.03),Vector3(-profile.wrist_width,profile.wrist,-0.03)]
	# Several supplied sculptures already have a raised grip.
	if id in ["subboss_4","subboss_5"]:
		joints[13]=Vector3(0.37 if id=="subboss_4" else 0.41,1.27,-0.02)
		wrists[0]=Vector3(0.43 if id=="subboss_4" else 0.45,1.43,-0.13)
	if id=="soldier_9":
		joints[14]=Vector3(-0.44,1.18,0)
		wrists[1]=Vector3(-0.56,1.42,-0.10)
	profile.joints=joints
	profile.wrists=wrists
	profile.cloth=true
	profile.center=Vector3.ZERO
	profile.id=id
	return profile

func fit_center(source: Node3D, facing: Basis, profile: Dictionary) -> Vector3:
	var samples_x: Array[float] = []
	var samples_z: Array[float] = []
	for part in source.find_children("*","MeshInstance3D",true,false):
		var transform: Transform3D=Transform3D(facing,Vector3.ZERO)*source.global_transform.affine_inverse()*part.global_transform
		for surface in part.mesh.get_surface_count():
			var vertices: PackedVector3Array=part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for v in vertices:
				var p: Vector3=transform*v
				if absf(p.x)<0.24 and p.y>profile.head and p.y<profile.head+0.15:
					samples_x.append(p.x)
					samples_z.append(p.z)
	if samples_x.size()<20: return Vector3.ZERO
	samples_x.sort()
	samples_z.sort()
	var low: int=int(samples_x.size()*0.10)
	var high: int=int(samples_x.size()*0.90)
	return Vector3((samples_x[low]+samples_x[high])*0.5,0,(samples_z[low]+samples_z[high])*0.5)

func segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var direction := b-a
	return p.distance_to(a+direction*clampf((p-a).dot(direction)/maxf(direction.length_squared(),0.0001),0,1))

func weights(p: Vector3, profile: Dictionary, surface_arm:float=-1.0) -> Array:
	var source_point := p
	p-=profile.center
	var result: Array[float] = []
	result.resize(NAMES.size())
	result.fill(0.0)
	var joints: Array[Vector3] = profile.joints
	var x: float = absf(p.x)
	var left: bool = p.x>=0
	var side: int = 0 if left else 1
	var shoulder: Vector3 = joints[3+side]
	var elbow: Vector3 = joints[13+side]
	var wrist: Vector3 = profile.wrists[side]
	var torso: float = smoothstep(profile.hip,profile.shoulder-0.15,p.y)
	var head: float = smoothstep(profile.head-0.15,profile.head+0.08,p.y)*(1-smoothstep(0.20,0.38,x))
	# Root feathers follow the back; outer feathers may project forward. This
	# keeps the wing roots separate from the knight's upper arms.
	var wing: float = 0.0
	if profile.winged:
		wing=smoothstep(profile.shoulder_width+0.13,0.79,x)*smoothstep(profile.shoulder-0.08,profile.shoulder+0.17,p.y)
		wing*=maxf(smoothstep(0.48,0.76,x),smoothstep(0.01,0.19,p.z))
	var arm_inner: float=lerpf(profile.wrist_width-0.09,profile.shoulder_width*0.72,smoothstep(profile.wrist+0.08,profile.shoulder-0.08,p.y))
	var arm: float = smoothstep(arm_inner,arm_inner+0.14,x)*smoothstep(profile.hip-0.13,profile.hip+0.09,p.y)*(1-smoothstep(profile.shoulder+0.12,profile.shoulder+0.31,p.y))
	# Capes and back-mounted equipment follow the body. Long handheld parts
	# outside the body silhouette follow their grip instead of the knees.
	var upper_distance: float=segment_distance(p,shoulder,elbow)
	var forearm_distance: float=segment_distance(p,elbow,wrist)
	# The sleeve circumference belongs to its limb, including its rear half.
	# A loose x-only blend leaves half of a sleeve on the torso and stretches
	# it into a sheet during a raised-arm pose.
	var sleeve: float=(1-smoothstep(0.105,0.19,minf(upper_distance,forearm_distance)))*smoothstep(arm_inner-0.035,arm_inner+0.07,x)
	arm=maxf(arm,sleeve)
	if surface_arm>=0.0:
		# A fused weapon can connect the hand topology to a coat or shin. Keep
		# geodesic sleeve weights inside the actual arm's spatial envelope;
		# long equipment is assigned separately below.
		arm=surface_arm*(1-smoothstep(0.22,0.32,minf(upper_distance,forearm_distance)))
		arm*=smoothstep(profile.wrist-0.20,profile.wrist-0.06,p.y)
	arm*=1-smoothstep(0.23,0.40,p.z)
	arm*=1-wing
	var grip_extension: float=0.0
	if x>profile.wrist_width-0.025 and p.y<profile.wrist+0.15:
		grip_extension=smoothstep(profile.wrist_width-0.025,profile.wrist_width+0.14,x)*(1-smoothstep(0.04,0.23,p.z))*smoothstep(profile.wrist-0.28,profile.wrist-0.10,p.y)
	arm=maxf(arm,grip_extension*(1-wing))
	var forearm: float=smoothstep(-0.065,0.105,upper_distance-forearm_distance)
	forearm=maxf(forearm,grip_extension)
	var lower: float=(1-smoothstep(profile.hip-0.19,profile.hip+0.08,p.y))*(1-arm)*(1-wing)
	var cloth: float=0.0
	if profile.cloth:
		# Preserve the fused coat panels as a drape while the exposed legs and
		# boots below them receive independent knee and ankle articulation.
		cloth=smoothstep(0.08,0.24,p.z)*smoothstep(0.22,profile.knee+0.13,p.y)
		cloth=maxf(cloth,(1-smoothstep(0.04,0.13,x))*smoothstep(profile.knee+0.03,profile.hip-0.10,p.y)*0.82)
	result[9+side] = wing
	result[3+side] = arm*(1-forearm)
	result[13+side] = arm*forearm
	if profile.spectral:
		result[11+side] = lower
	else:
		var shin: float = 1-smoothstep(profile.knee-0.055,profile.knee+0.09,p.y)
		var foot: float = 1-smoothstep(profile.ankle-0.025,profile.ankle+0.09,p.y)
		result[15+side] = lower*(1-cloth)*shin*foot
		result[7+side] = lower*(1-cloth)*shin*(1-foot)
		result[5+side] = lower*(1-cloth)*(1-shin)
		result[11+side] = lower*cloth
	var body: float = maxf(0,1-wing-arm-lower)
	result[2] = body*head
	result[1] = body*(1-head)*torso
	result[0] = maxf(0,1-result.reduce(func(a,b):return a+b,0.0))
	# Only explicitly fitted equipment may extend beyond the hand envelope.
	# The old x-only grip rule also caught wide boot toes near the floor and
	# stretched them all the way to a raised forearm during attack windup.
	var attachment: Array=equipment_weights(source_point,profile.id)
	if not attachment.is_empty():
		var amount:float=attachment[1]
		for i in result.size(): result[i]*=1.0-amount
		result[attachment[0]]+=amount
	var order: Array[int] = []
	for i in result.size(): order.append(i)
	order.sort_custom(func(a,b):return result[a]>result[b])
	var total: float = 0
	for i in 4: total+=result[order[i]]
	return [order.slice(0,4),[result[order[0]]/total,result[order[1]]/total,result[order[2]]/total,result[order[3]]/total]]

func equipment_weights(p:Vector3,id:String) -> Array:
	var amount:float=0.0
	var bone:int=0
	if id=="subboss_2":
		bone=14
		amount=(1-smoothstep(-0.285,-0.265,p.z))*(1-smoothstep(-0.23,-0.20,p.x))*(1-smoothstep(1.31,1.35,p.y))
	elif id in ["subboss_8","subboss_9"]:
		bone=13
		var a:=Vector3(0.74,1.18,0.20) if id=="subboss_8" else Vector3(0.74,1.03,0.20)
		var b:=Vector3(-0.65,0.14,-0.82) if id=="subboss_8" else Vector3(-0.60,0.08,-0.66)
		amount=1-smoothstep(0.145,0.175,segment_distance(p,a,b))
		if p.y<0.78: amount*=1-smoothstep(-0.09,-0.055,p.z)
	elif id=="grand_soldier":
		bone=13
		amount=1-smoothstep(0.11,0.145,segment_distance(p,Vector3(0.34,0.99,0.00),Vector3(0.76,0.14,-0.39)))
	elif id=="grand_boss":
		bone=13 if p.x>0 else 14
		var a:=Vector3(0.43,0.95,0.03) if p.x>0 else Vector3(-0.48,0.92,-0.32)
		var b:=Vector3(0.76,0.32,-0.53) if p.x>0 else Vector3(-0.61,0.11,-0.65)
		amount=1-smoothstep(0.12,0.15,segment_distance(p,a,b))
	elif id=="main_boss":
		bone=13
		# Shaft and crescent share one rigid grip, including the end behind the cloak.
		amount=1-smoothstep(0.041,0.053,segment_distance(p,Vector3(-0.77,1.38,0.39),Vector3(0.96,0.84,-0.37)))
		amount*=smoothstep(0.33,0.40,absf(p.x))
		var blade:float=smoothstep(0.33,0.37,p.x)*(1-smoothstep(0.99,1.04,p.y))*smoothstep(0.28,0.32,p.y)
		blade*=1-smoothstep(0.030,0.048,absf(p.z+0.40*p.x))
		amount=maxf(amount,blade)
	elif id=="soldier_9":
		bone=14
		amount=1-smoothstep(0.080,0.11,segment_distance(p,Vector3(-0.63,1.40,-0.39),Vector3(0.16,1.88,0.05)))
		var head:float=(1-smoothstep(0.15,0.18,absf(p.x-0.15)))*smoothstep(1.73,1.77,p.y)
		head*=1-smoothstep(0.14,0.18,absf(p.z-0.02))
		amount=maxf(amount,head)
	elif id=="subboss_4":
		# Upright staff is separated from the cloak in front of the body.
		bone=13
		var edge:float=lerpf(0.60,0.50,smoothstep(1.15,1.50,p.y))
		amount=smoothstep(edge,edge+0.022,p.x)
	elif id=="subboss_5":
		bone=13
		amount=(1-smoothstep(-0.43,-0.38,p.z))*smoothstep(0.24,0.35,p.x)
	elif id=="subboss_3":
		bone=14
		amount=smoothstep(0.50,0.61,-p.x)*(1-smoothstep(-0.31,-0.19,p.z))*(1-smoothstep(0.98,1.10,p.y))
	elif id=="subboss_6":
		# Hand axe and the separate axe carried across the upper back.
		bone=13
		amount=smoothstep(0.35,0.42,p.x)*(1-smoothstep(0.95,1.12,p.y))
		if p.y>1.73 and p.z>0.11: return [1,smoothstep(0.11,0.20,p.z)]
	elif id=="soldier_6":
		bone=14
		# Both exposed ends belong to the same diagonal staff.
		amount=1-smoothstep(-0.29,-0.23,p.x)
		if p.y>1.75 and p.x>0.32 and p.z>0.18: return [14,1.0]
	elif id=="soldier_8":
		# Belt sheath follows the pelvis instead of borrowing knee motion.
		bone=0
		amount=(1-smoothstep(0.055,0.09,segment_distance(p,Vector3(-0.31,0.50,0.01),Vector3(-0.25,1.03,0.10))))
	return [bone,amount] if amount>0.0 else []

func heap_push(heap:Array,entry:Vector2) -> void:
	heap.append(entry)
	var index:int=heap.size()-1
	while index>0:
		var parent:int=(index-1)/2
		if heap[parent].x<=entry.x: break
		heap[index]=heap[parent]
		index=parent
	heap[index]=entry

func heap_pop(heap:Array) -> Vector2:
	var result:Vector2=heap[0]
	var last:Vector2=heap.pop_back()
	if heap.is_empty(): return result
	var index:int=0
	while index*2+1<heap.size():
		var child:int=index*2+1
		if child+1<heap.size() and heap[child+1].x<heap[child].x: child+=1
		if heap[child].x>=last.x: break
		heap[index]=heap[child]
		index=child
	heap[index]=last
	return result

func surface_distances(vertices:PackedVector3Array,adjacency:Array,seeds:Array[Vector3]) -> PackedFloat32Array:
	var distances:=PackedFloat32Array()
	distances.resize(vertices.size())
	distances.fill(INF)
	var heap:Array=[]
	for seed in seeds:
		var best:int=0
		var minimum:float=INF
		for n in vertices.size():
			var distance:float=seed.distance_squared_to(vertices[n])
			if distance<minimum:
				minimum=distance
				best=n
		distances[best]=0.0
		heap_push(heap,Vector2(0.0,best))
	while not heap.is_empty():
		var current:Vector2=heap_pop(heap)
		var index:int=int(current.y)
		if current.x>distances[index]+0.00001: continue
		for neighbor in adjacency[index]:
			var distance:float=current.x+vertices[index].distance_to(vertices[neighbor])
			if distance<distances[neighbor]:
				distances[neighbor]=distance
				heap_push(heap,Vector2(distance,neighbor))
	return distances

func arm_surface_mask(vertices:PackedVector3Array,indices:PackedInt32Array,profile:Dictionary) -> PackedFloat32Array:
	# Spatial regions cannot tell an inner finger from the belt behind it.
	# Surface distance follows the actual connected sleeve, giving its entire
	# circumference one limb influence while blending only at the armpit.
	var adjacency:Array=[]
	adjacency.resize(vertices.size())
	for n in vertices.size(): adjacency[n]=[]
	for n in range(0,indices.size(),3):
		for k in 3:
			var a:int=indices[n+k]
			var b:int=indices[n+(k+1)%3]
			adjacency[a].append(b)
			adjacency[b].append(a)
	var welded:Dictionary={}
	for n in vertices.size():
		var key:Vector3i=Vector3i((vertices[n]*10000.0).round())
		if welded.has(key):
			adjacency[n].append(welded[key])
			adjacency[welded[key]].append(n)
		else: welded[key]=n
	var c:Vector3=profile.center
	var body_seeds:Array[Vector3]=[c+Vector3(0,profile.hip,0),c+Vector3(0,profile.hip+0.24,-0.1),c+Vector3(0,profile.shoulder,-0.1),c+Vector3(0,profile.hip,0.2)]
	var body:=surface_distances(vertices,adjacency,body_seeds)
	var arms:Array=[]
	for side in 2:
		var joints:Array[Vector3]=profile.joints
		var wrist:Vector3=profile.wrists[side]
		var elbow:Vector3=joints[13+side]
		var hand_seeds:Array[Vector3]=[c+wrist,c+elbow,c+wrist.lerp(elbow,0.5)]
		arms.append(surface_distances(vertices,adjacency,hand_seeds))
	var mask:=PackedFloat32Array()
	mask.resize(vertices.size())
	for n in vertices.size():
		var p:Vector3=vertices[n]-c
		var limb:float=arms[0 if p.x>=0 else 1][n]
		var ratio:float=limb/maxf(limb+body[n],0.0001)
		mask[n]=(1.0-smoothstep(0.37,0.61,ratio))*(1.0-smoothstep(profile.shoulder+0.06,profile.shoulder+0.22,p.y))
		if not is_finite(mask[n]): mask[n]=-1.0
	return mask

func detached_sword_mask(vertices:PackedVector3Array,indices:PackedInt32Array) -> PackedByteArray:
	# This source blade is a disconnected island. Flood its actual topology so
	# a nearby boot toe can never be mistaken for part of the sword.
	var adjacency:Array=[]
	adjacency.resize(vertices.size())
	for i in vertices.size(): adjacency[i]=[]
	for i in range(0,indices.size(),3):
		for j in 3:
			var a:int=indices[i+j]
			var b:int=indices[i+(j+1)%3]
			adjacency[a].append(b)
			adjacency[b].append(a)
	var welded:Dictionary={}
	for i in vertices.size():
		var key:=Vector3i((vertices[i]*10000).round())
		if welded.has(key):
			adjacency[i].append(welded[key])
			adjacency[welded[key]].append(i)
		else: welded[key]=i
	var seed:int=0
	var best:float=INF
	for i in vertices.size():
		var distance:float=vertices[i].distance_squared_to(Vector3(-0.43,0.6,-0.40))
		if distance<best:
			best=distance
			seed=i
	var selected:=PackedByteArray()
	selected.resize(vertices.size())
	var queue:Array[int]=[seed]
	selected[seed]=1
	var cursor:int=0
	while cursor<queue.size():
		for neighbor in adjacency[queue[cursor]]:
			if selected[neighbor]==0:
				selected[neighbor]=1
				queue.append(neighbor)
		cursor+=1
	if queue.size()>vertices.size()/4:
		push_error("Detached sword seed selected body topology")
		selected.fill(0)
	return selected

func bake(id: String) -> void:
	var source: Node3D = load("res://assets/provided/"+id+".glb").instantiate()
	root.add_child(source)
	var legacy_angle: float = PI/2 if id in ["main_boss","subboss_2","subboss_6","subboss_8"] else PI
	# Four original exports face sideways. Correct the baked geometry while
	# retaining the outer model rotation expected by provided_visual.gd.
	var angle: float = PI/2 if id in ["main_boss","subboss_2","subboss_4","subboss_5","subboss_6","subboss_8","soldier_3","soldier_4"] else PI
	var facing := Basis(Vector3.UP,angle)
	var profile := fit(id)
	profile.center=fit_center(source,facing,profile)
	var joints: Array[Vector3] = profile.joints.duplicate()
	for i in joints.size(): joints[i]+=profile.center
	var output := Node3D.new()
	output.name = "ArticulatedSculpt"
	root.add_child(output)
	var rig := Skeleton3D.new()
	rig.name = "SculptRig"
	rig.rotation.y = -legacy_angle
	output.add_child(rig)
	rig.owner = output
	rig.set_meta("sculpt_motion",true)
	rig.set_meta("sculpt_rig_version",2)
	rig.set_meta("spectral",profile.spectral)
	rig.set_meta("winged",profile.winged)
	var skin := Skin.new()
	for i in joints.size():
		rig.add_bone(NAMES[i])
		rig.set_bone_parent(i,PARENTS[i])
		rig.set_bone_rest(i,Transform3D(Basis.IDENTITY,joints[i]-(joints[PARENTS[i]] if PARENTS[i]>=0 else Vector3.ZERO)))
		skin.add_bind(i,Transform3D(Basis.IDENTITY,-joints[i]))
	rig.reset_bone_poses()
	var count: int = 0
	var influences: Array[int] = []
	influences.resize(NAMES.size())
	influences.fill(0)
	for source_mesh in source.find_children("*","MeshInstance3D",true,false):
		var transform: Transform3D = Transform3D(facing,Vector3.ZERO)*source.global_transform.affine_inverse()*source_mesh.global_transform
		var mesh := ArrayMesh.new()
		for surface in source_mesh.mesh.get_surface_count():
			var arrays: Array = source_mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for n in vertices.size(): vertices[n]=transform*vertices[n]
			var arm_mask:=arm_surface_mask(vertices,arrays[Mesh.ARRAY_INDEX],profile)
			var sword_mask:=detached_sword_mask(vertices,arrays[Mesh.ARRAY_INDEX]) if id=="subboss_2" else PackedByteArray()
			var bones := PackedInt32Array()
			var influence := PackedFloat32Array()
			bones.resize(vertices.size()*4)
			influence.resize(vertices.size()*4)
			for n in vertices.size():
				if n<normals.size(): normals[n]=(transform.basis.inverse().transposed()*normals[n]).normalized()
				var weighted: Array = weights(vertices[n],profile,arm_mask[n])
				if id=="subboss_2" and sword_mask[n]==1: weighted=[[14,0,0,0],[1.0,0.0,0.0,0.0]]
				for k in 4:
					bones[n*4+k]=weighted[0][k]
					influence[n*4+k]=weighted[1][k]
					if weighted[1][k]>0.15: influences[weighted[0][k]]+=1
			arrays[Mesh.ARRAY_VERTEX]=vertices
			arrays[Mesh.ARRAY_NORMAL]=normals
			arrays[Mesh.ARRAY_TANGENT]=null
			for custom in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_CUSTOM3]: arrays[custom]=null
			arrays[Mesh.ARRAY_BONES]=bones
			arrays[Mesh.ARRAY_WEIGHTS]=influence
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			if mesh.get_surface_count()!=surface+1:
				push_error("Rejected invalid sculpt surface: "+id)
				quit(1)
				return
			mesh.surface_set_material(surface,source_mesh.get_active_material(surface))
			count+=vertices.size()
		var instance := MeshInstance3D.new()
		instance.name = "SculptPart"+str(rig.get_child_count())
		instance.mesh=mesh
		instance.skin=skin
		rig.add_child(instance)
		instance.skeleton=NodePath("..")
		instance.owner=output
	var scene := PackedScene.new()
	scene.pack(output)
	var err := ResourceSaver.save(scene,"res://assets/sculpt_motion/"+id+".scn")
	report.append({"id":id,"bones":joints.size(),"weighted_vertices":count,"spectral":profile.spectral,"facing_degrees":rad_to_deg(angle),"body_center":str(profile.center),"articulated_vertices":influences,"status":err})
	print("SCULPT_RIG ",id," vertices=",count," bones=",joints.size()," center=",profile.center," status=",err)
	source.free()
	output.free()
