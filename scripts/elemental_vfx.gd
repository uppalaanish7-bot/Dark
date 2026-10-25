extends Node3D
## Distinct silhouettes and motion for each element. Visuals never own damage.
const ART = preload("res://scripts/visuals.gd")
const FLAME = preload("res://scripts/flame_effect.gd")
const FLOW = preload("res://shaders/elemental_flow.gdshader")
const LIGHTNING = preload("res://scripts/lightning_effect.gd")
var element: String = "fire"
var mode: String = "bolt"
var color := Color("ff792e")
var radius: float = 0.2
var extent: float = 3.0
var length: float = 12.0
var duration: float = 0.7
var age: float = 0.0
var spinning: Array[Node3D] = []
var flowing: Array[ShaderMaterial] = []
var formations: Array[Node3D] = []
var formation_scale: Array[Vector3] = []

func _ready() -> void:
	if mode == "bolt":
		build_bolt()
	else:
		build_region()
		for child in get_children():
			if child is Node3D:
				formations.append(child)
				formation_scale.append(child.scale)

func solid(tint: Color, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = ART.material(tint, metal, glow)
	mat.roughness = 0.55
	return mat

func flow(tint: Color, strength: float = 0.6, rate: float = 2.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FLOW
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("opacity", strength)
	mat.set_shader_parameter("speed", rate)
	flowing.append(mat)
	return mat

func sphere(at: Vector3, scale_value: Vector3, mat: Material, facets: int = 12) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = facets
	mesh.rings = 4
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.scale = scale_value
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func flame(at: Vector3, height_value: float, width_value: float, lifetime: float = -1.0) -> Node3D:
	var fire := FLAME.new()
	fire.position = at
	fire.height = height_value
	fire.width = width_value
	fire.duration = lifetime
	add_child(fire)
	return fire

func crystal(at: Vector3, size_value: float, mat: Material) -> Node3D:
	var node := Node3D.new()
	add_child(node)
	node.position = at
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0
	mesh.bottom_radius = size_value * 0.27
	mesh.height = size_value
	mesh.radial_segments = 5
	var shard := MeshInstance3D.new()
	shard.mesh = mesh
	shard.material_override = mat
	shard.position.y = size_value * 0.5
	node.add_child(shard)
	return node

func streak(from: Vector3, to: Vector3, thickness: float, mat: Material) -> MeshInstance3D:
	var node := ART.box(self, (from+to)*0.5, Vector3(thickness, thickness, from.distance_to(to)), mat)
	node.look_at(to_global(to), Vector3.UP if absf((to-from).normalized().y) < 0.95 else Vector3.RIGHT)
	return node

func orbit(at: Vector3, size_value: float, mat: Material, tilt: Vector3) -> MeshInstance3D:
	var node: MeshInstance3D = ART.ring(self, at, size_value, size_value*0.035, mat)
	node.rotation = tilt
	spinning.append(node)
	return node

func trail(tint: Color, amount: int = 12, shard: bool = false) -> void:
	var particles := CPUParticles3D.new()
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.amount = amount
	particles.lifetime = 0.35
	particles.local_coords = false
	particles.direction = Vector3.BACK
	particles.spread = 17
	particles.initial_velocity_min = 0.8
	particles.initial_velocity_max = 2.6
	particles.gravity = Vector3(0,0.25,0)
	particles.scale_amount_min = 0.02
	particles.scale_amount_max = 0.06
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.5,2.0,0.5) if shard else Vector3(1,1,1)
	particles.mesh = mesh
	var particle_material := solid(Color.WHITE, 0, 1.0)
	particle_material.vertex_color_use_as_albedo = true
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = particle_material
	var ramp := Gradient.new()
	ramp.set_color(0,tint)
	ramp.set_color(1,Color(tint,0))
	particles.color_ramp = ramp
	add_child(particles)

func build_bolt() -> void:
	var r: float = maxf(radius,0.16)
	match element:
		"fire":
			var plume := flame(Vector3(0,0,-r), r*8.0, r*3.1)
			plume.rotation.x = PI/2
		"lava":
			sphere(Vector3.ZERO,Vector3.ONE*r*1.3,solid(Color("321a16"),0,0.1),6)
			var plume := flame(Vector3.ZERO,r*7.0,r*3.5)
			plume.rotation.x = PI/2
		"stone":
			var rock := sphere(Vector3.ZERO,Vector3(r*1.5,r,r*1.7),solid(Color("817c6d")),5)
			spinning.append(rock)
			trail(Color("b9ad92"),8,true)
		"water":
			sphere(Vector3.ZERO,Vector3(r*1.25,r*0.75,r*4.4),flow(Color("52cffa"),0.82,2.5))
			for i in 3:
				orbit(Vector3(0,0,i*r*1.8),r*(1.4-i*0.2),flow(Color("b8f5ff"),0.8),Vector3(PI/2,0,i))
			trail(Color("b6edff"),12)
		"ice":
			var shard := crystal(Vector3(0,0,r*2.5),r*5.5,solid(Color("a4efff"),0.25,0.4))
			shard.rotation.x = -PI/2
			trail(Color("c5f6ff"),16,true)
		"wind":
			for i in 4:
				orbit(Vector3(0,0,i*r*1.6),r*(0.8+i*0.3),flow(Color("d7e6cf"),0.5,5),Vector3(PI/2,0,i*0.5))
		"lightning":
			var arc := LIGHTNING.new()
			arc.position = Vector3(0,0,-r*4)
			arc.end = Vector3(0,0,r*8)
			arc.duration = -1.0
			arc.illuminate = false
			add_child(arc)
			trail(Color("75e2ff"),8)
		"poison":
			for i in 3:
				sphere(Vector3(sin(i*2.1)*r*0.7,cos(i*2.1)*r*0.7,i*r),Vector3.ONE*r,flow(Color("91dc3e"),0.64,0.9))
			trail(Color("a9cf38"),10)
		"soul":
			for i in 3:
				var wisp := sphere(Vector3(sin(i*2.1)*r,cos(i*2.1)*r,i*r),Vector3(r*0.6,r*0.7,r*4.3),flow(Color("62eebd"),0.8,3))
				spinning.append(wisp)
		"gravity", "stars":
			var core := crystal(Vector3(0,-r*1.7,0),r*3.4,solid(Color("b8b0ff"),0.3,1.1))
			spinning.append(core)
			orbit(Vector3.ZERO,r*2.5,flow(Color("9eacff"),0.7),Vector3(0.7,0,0.2))
			trail(Color("b0c1ff"),10)
		_:
			sphere(Vector3.ZERO,Vector3.ONE*r*1.4,solid(Color("080612")))
			orbit(Vector3.ZERO,r*2.1,flow(Color("dd7eff"),0.85),Vector3(PI/2,0,0))
			orbit(Vector3.ZERO,r*2.7,flow(Color("8141d7"),0.7),Vector3(0.4,0,0.7))

func build_region() -> void:
	var size_value: float = maxf(extent,0.7)
	if mode == "line":
		for i in 6:
			build_column(Vector3(0,0,-length*(i+0.5)/6.0),size_value*0.7,1.0+i%2)
	elif mode == "wave":
		# This crest is the active attack itself; nothing is drawn during windup.
		ART.ring(self,Vector3(0,0.12,0),size_value,0.38,flow(color,0.82,3.5))
		for i in 12:
			var angle: float = i*TAU/12.0
			build_column(Vector3(sin(angle)*size_value,0,cos(angle)*size_value),0.4,0.4)
	elif mode == "pool":
		var disk: MeshInstance3D = ART.cylinder(self,Vector3(0,0.03,0),size_value,0.04,flow(color,0.78,1.0))
		for i in 5:
			var angle: float = i*TAU/5.0
			build_column(Vector3(sin(angle)*size_value*0.5,0,cos(angle)*size_value*0.5),size_value*0.23,0.7)
	elif mode == "impact":
		build_column(Vector3.ZERO,size_value,0.5)
	else:
		build_column(Vector3.ZERO,size_value*0.8,3.0)
		for i in 5:
			var angle: float = i*TAU/5.0
			build_column(Vector3(sin(angle)*size_value*0.55,0,cos(angle)*size_value*0.55),size_value*0.24,1.5)

func build_column(at: Vector3, size_value: float, height_value: float) -> void:
	match element:
		"fire", "lava":
			flame(at,height_value*2.2,size_value*1.5)
			if element == "lava": crystal(at,size_value*0.85,solid(Color("482718"),0,0.2))
		"stone":
			var rock := crystal(at,height_value,solid(Color("837c69")))
			rock.rotation.z = sin(at.x*4.0)*0.18
		"ice":
			var ice := crystal(at,height_value*1.6,solid(Color("a1def4"),0.25,0.24))
			ice.rotation.z = sin(at.z*4.0)*0.2
		"water":
			sphere(at+Vector3.UP*height_value*0.65,Vector3(size_value*0.5,height_value,size_value*0.5),flow(Color("4bc8f4"),0.74,3))
			orbit(at+Vector3.UP*0.15,size_value,flow(Color("dafbff"),0.74),Vector3.ZERO)
		"wind":
			for i in 3:
				orbit(at+Vector3.UP*(i+0.5)*height_value/3.0,size_value*(0.7+i*0.25),flow(Color("d9e9e3"),0.42,5),Vector3(0.14,0,0.1*i))
		"lightning":
			var arc := LIGHTNING.new()
			arc.position = at
			arc.end = Vector3(0,height_value*4.0,0)
			arc.duration = -1.0
			arc.illuminate = false
			add_child(arc)
			orbit(at+Vector3.UP*0.08,size_value,flow(Color("c8f6ff"),0.6,5),Vector3.ZERO)
		"poison":
			sphere(at+Vector3.UP*0.3,Vector3(size_value,height_value*0.55,size_value),flow(Color("84b433"),0.44,0.5))
		"soul":
			sphere(at+Vector3.UP*height_value*0.65,Vector3(size_value*0.5,height_value,size_value*0.5),flow(Color("5adfb1"),0.65,2))
		_:
			orbit(at+Vector3.UP*0.2,size_value,flow(color,0.65),Vector3.ZERO)
			orbit(at+Vector3.UP*height_value*0.4,size_value*0.75,flow(color,0.65),Vector3(1.0,0,0.4))
			if element in ["gravity","stars"]:
				var core := crystal(at+Vector3.UP*height_value*0.4,size_value*0.5,solid(Color("d0d6ff"),0.2,1))
				spinning.append(core)

func _process(delta: float) -> void:
	age += delta
	for node in spinning:
		node.rotation.y += delta*(4.0 if element == "wind" else 1.6)
		node.rotation.z += delta*0.7 if mode == "bolt" else 0.0
	if mode != "bolt" and duration > 0:
		var fade: float = clampf((duration-age)/0.3,0,1)
		var rise: float = 1.0-pow(1.0-clampf(age/0.12,0,1),3)
		for i in formations.size():
			if is_instance_valid(formations[i]) and not formations[i] in spinning:
				formations[i].scale.y = formation_scale[i].y*maxf(0.01,rise)*(0.72+fade*0.28)
		for mat in flowing: mat.set_shader_parameter("opacity",fade*0.65)
		if age >= duration: queue_free()
