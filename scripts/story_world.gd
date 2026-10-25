extends Node3D
## A separate exploration scene. Arena layout and encounter rules stay untouched.
const ART = preload("res://scripts/visuals.gd")
const BUILDING_SCENE = preload("res://assets/buildings/hollow_spire.glb")
const FLOORS := 10
const BUILDING_ORIGIN := Vector3(0, 0, -50)
const SPAWN := Vector3(0, 0.1, 170)
const ELDER_POS := Vector3(-8, 0, 157)
const DOOR_POS := Vector3(0, 0, -9.8)
const WORLD_BOUNDS := Rect2(-224, -244, 448, 488)
const GROUND_SHADER = preload("res://shaders/spire_grounds.gdshader")
var game: Node3D
var elder: Node3D
var villagers: Array[Node3D] = []
var portal: Area3D
var portal_surface: MeshInstance3D
var portal_rings: Array[MeshInstance3D] = []
var bottle: Node3D
var elapsed := 0.0
var doorway_cooldown := 0.0
var sick_material: StandardMaterial3D
var _batches: Dictionary = {}
var _prop_meshes: Dictionary = {}
var _ground_body: StaticBody3D
var _stone: StandardMaterial3D
var _edge: StandardMaterial3D
var _dark: StandardMaterial3D
var _brass: StandardMaterial3D
var _bark: StandardMaterial3D
var _flame: StandardMaterial3D

func _ready() -> void:
	name = "HollowSpire"
	_stone = ART.material(Color("454642"), 0.05)
	_edge = ART.material(Color("77766b"), 0.12)
	_dark = ART.material(Color("282e2d"), 0.08)
	_brass = ART.material(Color("957246"), 0.6)
	_bark = ART.material(Color("34352e"), 0.0)
	_flame = ART.material(Color("fca956"), 0.0, 0.2)
	_flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mana := ART.material(Color("9d86da"), 0.15, 0.22)
	sick_material = ART.material(Color("9a67c7"), 0, 0.4)
	_ground_body = StaticBody3D.new()
	_ground_body.name = "EstateGroundAndProps"
	_ground_body.collision_layer = 1
	_ground_body.collision_mask = 0
	add_child(_ground_body)
	build_grounds()
	build_building()
	build_entrance_approach()
	build_portal(_edge, mana)
	build_gardens()
	build_refuge()
	build_people()
	flush_props()
	create_environment()

func get_play_bounds() -> Rect2:
	return WORLD_BOUNDS

func contains_player_position(pos: Vector3) -> bool:
	return WORLD_BOUNDS.has_point(Vector2(pos.x, pos.z))

func safe_spawn_position() -> Vector3:
	return SPAWN

func build_grounds() -> void:
	var ground := ShaderMaterial.new()
	ground.shader = GROUND_SHADER
	# One continuous collider supports every reachable point, including paths,
	# vegetation, the old save positions, and the tower's portal vestibule.
	prop_collision(Vector3(0, -0.75, 0), Vector3(460, 1.5, 500))
	# Render patches meet at their edges. The tower has its own y=0 vestibule
	# floor, so no second coplanar visual is placed under that imported surface.
	ART.box(self, Vector3(0, -0.5, 120), Vector3(460, 1, 260), ground)
	ART.box(self, Vector3(0, -0.5, -170), Vector3(460, 1, 160), ground)
	for side in [-1.0, 1.0]:
		ART.box(self, Vector3(side * 155, -0.5, -50), Vector3(150, 1, 80), ground)
	# Distant land is below the guarded estate, so there is no floating tabletop.
	ART.box(self, Vector3(0, -3.5, -15), Vector3(1400, 3, 1400), ART.material(Color("172a2c")))
	for side in [-1.0, 1.0]:
		prop_box(Vector3(side * 227, 4.5, 0), Vector3(4, 9, 498), _dark, true)
		prop_box(Vector3(0, 4.5, side * 247), Vector3(450, 9, 4), _dark, true)
		prop_box(Vector3(side * 227, 9.2, 0), Vector3(4.8, 0.4, 498), _edge)
		prop_box(Vector3(0, 9.2, side * 247), Vector3(455, 0.4, 4.8), _edge)
		for z in range(-225, 226, 45):
			prop_box(Vector3(side * 226.5, 5.2, z), Vector3(2.8, 10.4, 6), _stone)
			prop_box(Vector3(side * 226.5, 10.6, z), Vector3(3.4, 0.4, 6.5), _edge)
		for x in range(-202, 203, 45):
			prop_box(Vector3(x, 5.2, side * 246.5), Vector3(6, 10.4, 2.8), _stone)
			prop_box(Vector3(x, 10.6, side * 246.5), Vector3(6.5, 0.4, 3.4), _edge)
		for depth in [-1.0, 1.0]:
			prop_box(Vector3(side * 233, 9, depth * 253), Vector3(16, 18, 16), _stone)
			prop_box(Vector3(side * 233, 18.3, depth * 253), Vector3(18, 0.6, 18), _edge)
	# Restrained edge inlays mark the direct route; all paving is flush.
	for side in [-1.0, 1.0]:
		prop_box(Vector3(side * 9.5, 0.017, 101), Vector3(0.12, 0.025, 228), _brass)
		for z in [8.0, 43.0, 119.0, 151.0, 191.0]:
			estate_lantern(Vector3(side * 13, 0, z))
		for z in [-104.0, -50.0, 0.0, 84.0, 150.0, 205.0]:
			estate_lantern(Vector3(side * 119, 0, z))
	var bronze := ART.material(Color("a89670"), 0.6, 0.05)
	for z in [84.0, 168.0]:
		var radius: float = 27.5 if z < 100 else 25.5
		ART.ring(self, Vector3(0, 0.035, z), radius, 0.045, bronze)
		ART.ring(self, Vector3(0, 0.034, z), radius - 1.3, 0.022, bronze)
	# Distant angular hills anchor the fortified estate in a landscape.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11478
	for i in range(34):
		var angle: float = TAU * float(i) / 34.0
		var radius: float = rng.randf_range(460, 640)
		var height: float = rng.randf_range(32, 108)
		prop_rock(Vector3(sin(angle) * radius, height * 0.1 - 10, cos(angle) * radius), Vector3(rng.randf_range(70, 130), height, rng.randf_range(65, 115)), _dark, rng.randf() * TAU)

func build_entrance_approach() -> void:
	# The original small doorway remains the usable threshold. A monumental
	# blind arch frames it at the scale of the fortress without narrowing it.
	for side in [-1.0, 1.0]:
		var base := Vector3(side * 8.2, 0, -6.3)
		prop_box(base + Vector3.UP * 0.55, Vector3(4.5, 1.1, 6.6), _dark, true)
		prop_box(base + Vector3.UP * 9.1, Vector3(2.9, 17.1, 3.2), _stone, true)
		prop_box(base + Vector3.UP * 17.7, Vector3(3.7, 0.7, 4.0), _edge)
		prop_box(base + Vector3(0, 9, 1.67), Vector3(0.2, 12, 0.08), _brass)
		for z in [-26.0, -69.0]:
			var root_point := Vector3(side * 93, 0, z)
			prop_box(root_point + Vector3.UP * 4, Vector3(6, 8, 10), _stone, true)
			prop_box(root_point + Vector3.UP * 8.2, Vector3(6.7, 0.4, 10.7), _edge)
			prop_beam(root_point + Vector3.UP * 8, Vector3(side * 79.2, 60, z), 3.6, 5.5, _stone)
			prop_beam(root_point + Vector3(0, 8, 2.83), Vector3(side * 79.2, 60, z + 2.83), 0.3, 0.15, _edge)
		prop_box(Vector3(side * 22, 0.6, 1), Vector3(5.5, 1.2, 5.5), _dark, true)
		prop_box(Vector3(side * 22, 6.5, 1), Vector3(1.5, 11, 1.5), _stone, true)
		prop_box(Vector3(side * 22, 6.6, 1.78), Vector3(0.13, 8.5, 0.06), _brass)
		prop_rock(Vector3(side * 22, 12.5, 1), Vector3(1.5, 2, 1.5), _brass, 0)
	for i in range(18):
		var a0: float = float(i) / 18.0
		var a1: float = float(i + 1) / 18.0
		var a := Vector3(lerpf(-8.2, 8.2, a0), 17.5 + pow(sin(a0 * PI), 0.72) * 10.0, -6.3)
		var b := Vector3(lerpf(-8.2, 8.2, a1), 17.5 + pow(sin(a1 * PI), 0.72) * 10.0, -6.3)
		prop_beam(a, b, 1.9, 3.2, _stone)
	var medallion := ART.ring(self, Vector3(0, 17.6, -4.8), 3.1, 0.12, _brass)
	medallion.rotation.x = PI * 0.5
	var seal: MeshInstance3D = ART.box(self, Vector3(0, 17.6, -4.7), Vector3(0.8, 0.8, 0.22), _flame)
	seal.rotation.z = PI * 0.25
	# Gate labels sit above head height and never form a collision lip.
	var title := ART.text3d(self, "T H E   H O L L O W   S P I R E", Vector3(0, 11.5, -4.7), 74)
	title.pixel_size = 0.014
	title.modulate = Color("d9bd91")
	for side in [-1.0, 1.0]:
		var light := SpotLight3D.new()
		add_child(light)
		light.position = Vector3(side * 50, 4, 15)
		light.look_at(Vector3(side * 45, 63, -12))
		light.light_color = Color("ffc58b")
		light.light_energy = 42.0
		light.spot_range = 118
		light.spot_angle = 26
		light.spot_attenuation = 1.0
		light.shadow_enabled = false
	var gate_light := OmniLight3D.new()
	add_child(gate_light)
	gate_light.position = Vector3(0, 10, 0)
	gate_light.light_color = Color("ffc17a")
	gate_light.light_energy = 14.0
	gate_light.omni_range = 28
	gate_light.shadow_enabled = false

func build_gardens() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4832
	var moss := ART.material(Color("263e34"), 0.0)
	var slate := ART.material(Color("454d51"), 0.0)
	for side in [-1.0, 1.0]:
		for z in [48.0, 113.0, 180.0]:
			# Long garden edges face away from the central route, with broad gaps.
			for x in [31.0, 83.0]:
				prop_box(Vector3(side * x, 0.38, z), Vector3(0.65, 0.76, 34), _stone, true)
				prop_box(Vector3(side * x, 0.82, z), Vector3(0.95, 0.14, 34.3), _edge)
			for offset in [-15.0, 15.0]:
				prop_box(Vector3(side * 57, 0.31, z + offset), Vector3(16, 0.62, 0.7), _stone, true)
			for j in range(7):
				var at := Vector3(side * rng.randf_range(39, 77), 0, z + rng.randf_range(-11, 11))
				prop_rock(at + Vector3.UP * 0.25, Vector3(rng.randf_range(1.4, 3.4), rng.randf_range(0.6, 1.1), rng.randf_range(1.2, 2.6)), moss, rng.randf() * TAU)
			for dx in [42.0, 71.0]:
				estate_tree(Vector3(side * dx, 0, z), rng)
			# Benches have explicit, generous collision footprints, never scattered
			# across the path where fast movement would catch an invisible corner.
			prop_box(Vector3(side * 22, 0.72, z + 3), Vector3(1.9, 0.28, 6), slate, true)
			for dz in [-2.1, 2.1]:
				prop_box(Vector3(side * 22, 0.33, z + 3 + dz), Vector3(1.2, 0.65, 0.55), _dark)
		for z in [-135.0, -93.0, 7.0, 64.0, 139.0, 210.0]:
			estate_tree(Vector3(side * rng.randf_range(161, 195), 0, z), rng)
		# Quiet memorial courts, outside the straight approach and side paths.
		for row in range(4):
			for column in range(4):
				var at := Vector3(side * (139 + column * 12), 0, 35 + row * 17)
				prop_box(at + Vector3.UP * 0.32, Vector3(3.1, 0.64, 6.4), _dark, true)
				prop_box(at + Vector3(0, 1.65, -2.4), Vector3(1.45, 2.7, 0.6), _stone, true)
				prop_box(at + Vector3(0, 2.55, -2.02), Vector3(0.7, 0.12, 0.06), _brass)
		for z in [-143.0, 169.0]:
			for x in [143.0, 182.0]:
				prop_box(Vector3(side * x, 5.0, z), Vector3(3.4, 10, 3.4), _stone, true)
				prop_box(Vector3(side * x, 10.4, z), Vector3(4.2, 0.8, 4.2), _edge)
			prop_box(Vector3(side * 162.5, 10.5, z), Vector3(43, 1.6, 3.8), _stone)
			prop_box(Vector3(side * 162.5, 11.4, z), Vector3(44, 0.3, 4.1), _edge)

func build_refuge() -> void:
	# The camp is placed at the arrival end, where the whole tower is readable.
	var canvas := ART.material(Color("504449"), 0.0)
	canvas.cull_mode = BaseMaterial3D.CULL_DISABLED
	for z in [151.0, 166.0]:
		for dx in [-5.0, 5.0]:
			prop_cylinder(Vector3(-35 + dx, 2, z), 0.13, 4.0, _bark)
		prop_box(Vector3(-35, 3.55, z), Vector3(10.7, 0.12, 8), canvas, false, Vector3(0, 0, 0.11))
		prop_box(Vector3(-35, 1.9, z - 3.6), Vector3(10.5, 3.4, 0.1), canvas)
	for at in [Vector3(-23, 0, 155), Vector3(-21, 0, 165), Vector3(-45, 0, 161)]:
		prop_box(at + Vector3.UP * 0.45, Vector3(1.2, 0.9, 1.1), _bark, true)
		prop_box(at + Vector3.UP * 0.91, Vector3(1.3, 0.09, 1.2), _edge)
	var camp_light := OmniLight3D.new()
	camp_light.position = Vector3(-15, 5, 158)
	camp_light.light_color = Color("ffcb97")
	camp_light.light_energy = 2.0
	camp_light.omni_range = 28
	camp_light.shadow_enabled = false
	add_child(camp_light)

func estate_lantern(at: Vector3) -> void:
	prop_box(at + Vector3.UP * 0.25, Vector3(1.1, 0.5, 1.1), _dark)
	prop_cylinder(at + Vector3.UP * 1.6, 0.13, 2.5, _brass)
	prop_box(at + Vector3.UP * 3.05, Vector3(0.75, 0.9, 0.75), _dark)
	prop_box(at + Vector3.UP * 3.05, Vector3(0.52, 0.65, 0.79), _flame)
	prop_box(at + Vector3.UP * 3.57, Vector3(0.96, 0.12, 0.96), _edge)

func estate_tree(at: Vector3, rng: RandomNumberGenerator) -> void:
	var height: float = rng.randf_range(10, 16)
	prop_cylinder(at + Vector3.UP * height * 0.5, 0.52, height, _bark)
	prop_collision(at + Vector3.UP * 3, Vector3(1.2, 6, 1.2))
	for j in range(7):
		var angle: float = rng.randf() * TAU
		var origin := at + Vector3.UP * (height * (0.44 + j * 0.055))
		var tip := origin + Vector3(sin(angle) * rng.randf_range(2.8, 5.8), rng.randf_range(2.0, 4.4), cos(angle) * rng.randf_range(2.8, 5.8))
		prop_beam(origin, tip, 0.22 if j < 4 else 0.13, 0.22 if j < 4 else 0.13, _bark)
		prop_beam(tip, tip + Vector3(sin(angle + 0.65) * 1.8, 1.7, cos(angle + 0.65) * 1.8), 0.10, 0.10, _bark)

func prop_collision(at: Vector3, dimensions: Vector3) -> void:
	building_collision(_ground_body, "EstateSolid", at, dimensions)

func prop_box(at: Vector3, dimensions: Vector3, mat: Material, solid: bool = false, angles := Vector3.ZERO) -> void:
	if not _prop_meshes.has("box"):
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		_prop_meshes["box"] = mesh
	prop_batch("box", Transform3D(Basis.from_euler(angles) * Basis.from_scale(dimensions), at), mat)
	if solid:
		prop_collision(at, dimensions)

func prop_cylinder(at: Vector3, radius: float, height: float, mat: Material) -> void:
	if not _prop_meshes.has("cylinder"):
		var mesh := CylinderMesh.new()
		mesh.height = 1
		mesh.top_radius = 0.37
		mesh.bottom_radius = 0.5
		mesh.radial_segments = 12
		_prop_meshes["cylinder"] = mesh
	prop_batch("cylinder", Transform3D(Basis.from_scale(Vector3(radius * 2, height, radius * 2)), at), mat)

func prop_rock(at: Vector3, dimensions: Vector3, mat: Material, yaw: float) -> void:
	if not _prop_meshes.has("rock"):
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1
		mesh.radial_segments = 7
		mesh.rings = 3
		_prop_meshes["rock"] = mesh
	prop_batch("rock", Transform3D(Basis.from_euler(Vector3(0.11, yaw, 0.17)) * Basis.from_scale(dimensions), at), mat)

func prop_beam(a: Vector3, b: Vector3, width: float, depth: float, mat: Material) -> void:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.94 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	if not _prop_meshes.has("box"):
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		_prop_meshes["box"] = mesh
	prop_batch("box", Transform3D(Basis(x * width, y * a.distance_to(b), z * depth), (a + b) * 0.5), mat)

func prop_batch(kind: String, transform: Transform3D, mat: Material) -> void:
	var chunk := Vector2i(floori(transform.origin.x / 90), floori(transform.origin.z / 100))
	var key: String = "%s_%d_%s" % [kind, mat.get_instance_id(), chunk]
	if not _batches.has(key):
		_batches[key] = {"mesh": _prop_meshes[kind], "material": mat, "transforms": []}
	_batches[key].transforms.append(transform)

func flush_props() -> void:
	for key in _batches:
		var data: Dictionary = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = data.mesh
		mm.instance_count = data.transforms.size()
		for i in range(data.transforms.size()):
			mm.set_instance_transform(i, data.transforms[i])
		var mesh := MultiMeshInstance3D.new()
		mesh.name = "EstateArchitecture"
		mesh.multimesh = mm
		mesh.material_override = data.material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
	_batches.clear()

func build_building() -> void:
	# The 160 x 150 x 80 m basalt model faces +Z. Its local z=40
	# vestibule mouth stays on the courtyard's existing z=-10 threshold.
	var building := BUILDING_SCENE.instantiate() as Node3D
	building.name = "Building"
	building.position = BUILDING_ORIGIN
	add_child(building)
	# Solid boxes follow the authored masses, setbacks and piers without
	# making the carved facade's decorative triangles part of the physics mesh.
	var shell := StaticBody3D.new()
	shell.name = "BuildingShell"
	shell.collision_layer = 1
	shell.collision_mask = 0
	building.add_child(shell)
	building_collision(shell, "MainMassAndVestibuleRear", Vector3(0, 54, -2), Vector3(156, 108, 72))
	building_collision(shell, "FacadeAboveEntrance", Vector3(0, 56.25, 36), Vector3(156, 103.5, 4))
	for side in [-1.0, 1.0]:
		var label := "West" if side < 0 else "East"
		building_collision(shell, label + "GroundWing", Vector3(side * 40.1, 2.25, 36), Vector3(75.8, 4.5, 4))
		building_collision(shell, label + "VestibuleWall", Vector3(side * 3.95, 3.75, 39), Vector3(3.5, 7.5, 2))
	building_collision(shell, "VestibuleCeiling", Vector3(0, 6, 39), Vector3(4.4, 3, 2))
	building_collision(shell, "VestibuleFloor", Vector3(0, -0.5, 37), Vector3(4.4, 1, 6))
	building_collision(shell, "UpperTower", Vector3(0, 123, 0), Vector3(75, 30, 68))
	# Front and rear buttresses establish the full 80 m depth; the side
	# buttresses establish the full 160 m width.
	for side in [-1.0, 1.0]:
		for x in [-76.5, -59.0, -43.0, -27.0, -11.0, 11.0, 27.0, 43.0, 59.0, 76.5]:
			var width := 7.0 if absf(x) > 70 else (5.6 if absf(x) == 11 else 4.8)
			building_collision(shell, "LowerPier_%s_%s" % [side, x], Vector3(x, 54, side * 38.4), Vector3(width, 108, 3.2))
		for z in [-27.0, -10.0, 10.0, 27.0]:
			building_collision(shell, "SidePier_%s_%s" % [side, z], Vector3(side * 79, 54, z), Vector3(2, 108, 5.2))
		for x in [-27.0, -11.0, 11.0, 27.0]:
			var width := 5.6 if absf(x) == 11 else 4.8
			building_collision(shell, "UpperPier_%s_%s" % [side, x], Vector3(x, 123, side * 34.4), Vector3(width, 30, 3.2))
		for x in [47.0, 63.0, 76.0]:
			for z in [-34.0, 34.0]:
				building_collision(shell, "BastionCrown_%s_%s_%s" % [side, x, z], Vector3(side * x, 109.5, z), Vector3(5, 3, 8))
		for z in [-23.0, 23.0]:
			building_collision(shell, "CrownPier_%s_%s" % [side, z], Vector3(side * 24.5, 144, z), Vector3(7, 12, 9))
			building_collision(shell, "CrownCap_%s_%s" % [side, z], Vector3(side * 24.5, 149.4, z), Vector3(7.8, 1.2, 9.8))
	building_collision(shell, "CrownBase", Vector3(0, 142.5, 0), Vector3(40, 9, 50))
	building_collision(shell, "CrownLedge", Vector3(0, 147.55, 0), Vector3(33, 1.1, 44))
	building_collision(shell, "CrownTop", Vector3(0, 148.6, 0), Vector3(27, 1, 38))
	for x in [-9.0, 0.0, 9.0]:
		building_collision(shell, "RoofRidge_%s" % x, Vector3(x, 149.55, 0), Vector3(3.8, 0.9, 35))
	build_shadow_proxy(building, shell)

func build_shadow_proxy(building: Node3D, shell: StaticBody3D) -> void:
	# The closed structural masses cast the tower's shadows. Repeating relief
	# blocks need not be rendered in all four cascades; their tiny overlapping
	# shadow edges otherwise shimmer at courtyard viewing distances.
	var visuals := building.find_children("*", "MeshInstance3D", true, false)
	for visual in visuals:
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mm.mesh = box
	mm.instance_count = shell.get_child_count()
	for i in range(shell.get_child_count()):
		var collider := shell.get_child(i) as CollisionShape3D
		var shape := collider.shape as BoxShape3D
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(shape.size), collider.position))
	var proxy := MultiMeshInstance3D.new()
	proxy.name = "TowerStructuralShadows"
	proxy.multimesh = mm
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	building.add_child(proxy)

func building_collision(parent: StaticBody3D, part: String, pos: Vector3, size: Vector3) -> void:
	var collider := CollisionShape3D.new()
	collider.name = part
	collider.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	parent.add_child(collider)

func build_portal(trim: Material, mana: Material) -> void:
	for side in [-1.0, 1.0]:
		ART.box(self, Vector3(side * 2.25, 2.1, -9.5), Vector3(0.55, 4.2, 0.9), trim, true)
		# Door leaves stand open, making the threshold clearly walkable.
		var leaf := ART.box(self, Vector3(side * 2.8, 1.6, -8.9), Vector3(1.55, 3.2, 0.16), trim)
		leaf.rotation.y = side * 1.15
	ART.box(self, Vector3(0, 4.3, -9.5), Vector3(5.0, 0.6, 1.0), trim, true)
	var veil: StandardMaterial3D = mana.duplicate()
	veil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	veil.albedo_color.a = 0.42
	portal_surface = ART.box(self, Vector3(0, 1.75, -9.55), Vector3(3.85, 3.4, 0.055), veil)
	for radius in [1.1, 1.65]:
		var ring := ART.ring(self, Vector3(0, 1.85, -9.45), radius, 0.035, mana)
		ring.rotation.x = PI / 2
		portal_rings.append(ring)
	var sign := ART.text3d(self, "THE HOLLOW SPIRE", Vector3(0, 5.1, -9.35), 43)
	sign.modulate = Color("c9b0f9")
	portal = Area3D.new()
	portal.name = "ArenaDoorway"
	portal.collision_layer = 0
	portal.collision_mask = 2
	add_child(portal)
	portal.position = DOOR_POS + Vector3.UP * 1.65
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.7, 3.3, 1.4)
	collider.shape = shape
	portal.add_child(collider)
	portal.body_entered.connect(func(body: Node3D) -> void:
		if body == game.player and game.state == "world" and doorway_cooldown <= 0:
			game.call_deferred("enter_portal")
	)
	var glow := OmniLight3D.new()
	add_child(glow)
	glow.position = Vector3(0, 2, -7)
	glow.light_color = Color("ab87ff")
	glow.light_energy = 1.25
	glow.omni_range = 10

func dead_tree(pos: Vector3, mat: Material, rng: RandomNumberGenerator) -> void:
	var trunk := ART.cylinder(self, pos + Vector3.UP * 3.0, 0.4, 6.0, mat, true, 0.16)
	trunk.rotation.z = rng.randf_range(-0.14, 0.14)
	for i in range(5):
		var branch := ART.cylinder(self, pos + Vector3(rng.randf_range(-1, 1), 3 + i * 0.45, 0), 0.14, 2.5, mat, false, 0.015)
		branch.rotation = Vector3(rng.randf_range(-0.8, 0.8), rng.randf() * TAU, (-1 if i % 2 == 0 else 1) * 0.9)

func lantern(pos: Vector3, metal: Material, flame: Material) -> void:
	ART.cylinder(self, pos + Vector3.UP * 1.0, 0.08, 2.0, metal)
	ART.box(self, pos + Vector3.UP * 2.0, Vector3(0.38, 0.52, 0.38), metal)
	ART.box(self, pos + Vector3.UP * 2.02, Vector3(0.26, 0.32, 0.40), flame)
	var light := OmniLight3D.new()
	add_child(light)
	light.position = pos + Vector3.UP * 2.2
	light.light_color = Color("ffc796")
	light.light_energy = 0.85
	light.omni_range = 6

func sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	var node := MeshInstance3D.new()
	parent.add_child(node)
	node.position = pos
	node.mesh = mesh
	node.material_override = mat
	return node

func build_people() -> void:
	var skin := ART.material(Color("b59780"))
	var robe := ART.material(Color("685849"))
	var hair := ART.material(Color("d2d6ce"))
	var wood := ART.material(Color("3d3030"))
	elder = Node3D.new()
	elder.name = "ElderOrin"
	add_child(elder)
	elder.position = ELDER_POS
	ART.cylinder(elder, Vector3(0, 0.7, 0), 0.36, 1.3, robe, false, 0.22)
	sphere(elder, Vector3(0, 1.58, 0), 0.23, skin)
	sphere(elder, Vector3(0, 1.69, -0.04), 0.225, hair)
	ART.cylinder(elder, Vector3(0, 1.32, 0.19), 0.03, 0.5, hair, false, 0.18)
	for side in [-1.0, 1.0]:
		sphere(elder, Vector3(side * 0.082, 1.61, 0.203), 0.023, wood)
		var arm := ART.cylinder(elder, Vector3(side * 0.33, 1.0, 0.04), 0.095, 0.64, robe)
		arm.rotation.z = side * 0.2
		sphere(elder, Vector3(side * 0.4, 0.72, 0.08), 0.10, skin)
	ART.cylinder(elder, Vector3(0.48, 0.9, 0.13), 0.035, 1.8, wood)
	var nameplate := ART.text3d(elder, "ELDER ORIN", Vector3(0, 2.05, 0), 23)
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.modulate = Color("ffe0ab")
	for i in range(3):
		var villager := Node3D.new()
		villager.name = "Villager%d" % i
		add_child(villager)
		villager.position = ELDER_POS + Vector3(-7.5 - i * 2.0, 0.1, (i % 2) * 2.3)
		ART.box(villager, Vector3(0, 0, 0), Vector3(1.2, 0.15, 2.4), robe)
		ART.cylinder(villager, Vector3(0, 0.6, 0), 0.3, 0.9, ART.material(Color("4c6172")), false, 0.2)
		sphere(villager, Vector3(0, 1.18, 0.1), 0.21, skin)
		var aura := ART.ring(villager, Vector3(0, 0.15, 0), 0.7, 0.045, sick_material)
		aura.name = "ManaWound"
		villagers.append(villager)
	bottle = Node3D.new()
	bottle.name = "MoonwellElixir"
	add_child(bottle)
	bottle.position = ELDER_POS + Vector3(1.05, 1.0, 0.2)
	var elixir := ART.material(Color("87ffdf"), 0.4, 1.6)
	sphere(bottle, Vector3.ZERO, 0.18, elixir)
	ART.cylinder(bottle, Vector3(0, 0.22, 0), 0.07, 0.22, elixir)
	ART.cylinder(bottle, Vector3(0, 0.35, 0), 0.08, 0.08, ART.material(Color("edc88c"), 0.4))
	ART.ring(bottle, Vector3.ZERO, 0.23, 0.018, elixir).rotation.x = PI / 2
	bottle.hide()

func refresh_story() -> void:
	var quest: String = game.progress.current_world().get("quest", "unmet")
	bottle.visible = quest in ["elixir", "healed"]
	for villager in villagers:
		villager.get_node("ManaWound").visible = quest != "healed"
		villager.rotation.x = 0.0 if quest == "healed" else 0.18

func near_elder() -> bool:
	return Vector2(game.player.position.x - ELDER_POS.x, game.player.position.z - ELDER_POS.z).length() < 4.3

func create_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("040c20")
	sky_mat.sky_horizon_color = Color("243d5b")
	sky_mat.ground_bottom_color = Color("0c1522")
	sky_mat.ground_horizon_color = Color("243d5b")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("859bc2")
	env.ambient_light_energy = 0.31
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("223a56")
	env.fog_density = 0.00065
	env.fog_sky_affect = 0.25
	world.environment = env
	add_child(world)
	var moonlight := DirectionalLight3D.new()
	add_child(moonlight)
	moonlight.rotation_degrees = Vector3(-38, -32, 0)
	moonlight.light_color = Color("b2cafa")
	moonlight.light_energy = 1.15
	moonlight.shadow_enabled = true
	moonlight.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	moonlight.directional_shadow_max_distance = 380
	moonlight.shadow_bias = 0.12
	moonlight.shadow_normal_bias = 2.0
	sphere(self, Vector3(-150, 205, -260), 12, ART.material(Color("d1d4ef"), 0, 1.0))

func _process(delta: float) -> void:
	elapsed += delta
	doorway_cooldown = maxf(0, doorway_cooldown - delta)
	for ring in portal_rings:
		ring.rotation.z += delta * 0.18
	portal_surface.material_override.albedo_color.a = 0.32 + sin(elapsed * 1.5) * 0.08
	if is_instance_valid(bottle):
		bottle.rotation.y += delta * 0.8
		if is_instance_valid(game.player):
			bottle.position = game.player.position + Vector3(0.55, 1.15, 0) if game.progress.current_world().get("quest", "unmet") == "elixir" else ELDER_POS + Vector3(1.05, 1.0, 0.2)
