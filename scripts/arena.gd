extends Node3D
## The Cathedral of Cinders. Broad, collision-safe floors under a 112 m vault.
## Static architectural pieces share MultiMeshes to keep the nave affordable on
## the Compatibility renderer. Only the current court receives dynamic lights.
const ART = preload("res://scripts/visuals.gd")
const FLOOR_SHADER = preload("res://shaders/citadel_floor.gdshader")
const COURT_SHADER = preload("res://shaders/citadel_court.gdshader")
const PORTAL_SHADER = preload("res://shaders/citadel_portal.gdshader")
const SHAFT_SHADER = preload("res://shaders/citadel_lightshaft.gdshader")
const CELL_SIZE: float = 3.0
const GRID_MIN := Vector2i(-51, -77)
const GRID_SIZE := Vector2i(103, 155)
const COURT_COLORS = preload("res://scripts/encounter_data.gd").COLORS
const COURT_NUMERALS: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]

@export var encounter_positions: Array[Vector3] = [
	Vector3(-44, 0.12, 145), Vector3(44, 0.12, 114),
	Vector3(-44, 0.12, 83), Vector3(44, 0.12, 52),
	Vector3(-44, 0.12, 21), Vector3(44, 0.12, -10),
	Vector3(-44, 0.12, -41), Vector3(44, 0.12, -72),
	Vector3(0, 0.12, -107), Vector3(0, 0.12, -150),
	Vector3(0, 0.12, -194)
]
@export var spawn_position := Vector3(0, 0.12, 190)
@export var exit_position := Vector3(0, 0.12, -222)
var portal_position: Vector3:
	get:
		return exit_position
var grid := AStarGrid2D.new()
var obstacles: Array[Rect2] = []
var elapsed: float = 0.0
var active_encounter: int = -1
var portal: Node3D
var portal_active: bool = false
var world_environment: WorldEnvironment
var court_materials: Array[StandardMaterial3D] = []
var court_beacons: Array[Node3D] = []
var court_labels: Array[Label3D] = []
var cleared_encounters: Array[int] = []
var _portal_rings: Array[Node3D] = []
var _court_lights: Array[OmniLight3D] = []
var _embers: CPUParticles3D
var _portal_light: OmniLight3D
var _portal_sparks: CPUParticles3D
var _active_beam: MeshInstance3D
var _active_beam_mat: ShaderMaterial
var _batches: Dictionary = {}
var _meshes: Dictionary = {}
var _body: StaticBody3D
var _stone: StandardMaterial3D
var _dark: StandardMaterial3D
var _edge: StandardMaterial3D
var _gold: StandardMaterial3D
var _moon: StandardMaterial3D
var _ember: StandardMaterial3D
var _velvet: StandardMaterial3D
var _portal_tween: Tween

func _ready() -> void:
	name = "CathedralOfCinders"
	_body = StaticBody3D.new()
	_body.name = "CathedralCollision"
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	_create_materials()
	_build_shell()
	_build_colonnades()
	_build_floor_detail()
	for index in range(encounter_positions.size()):
		_build_court(index)
	_build_sanctum()
	_build_chandeliers()
	_flush_batches()
	_create_environment()
	_create_atmosphere()
	_create_portal()
	build_grid()

func _create_materials() -> void:
	_stone = ART.material(Color("343e49"), 0.06)
	_dark = ART.material(Color("171e2b"), 0.22)
	_edge = ART.material(Color("59616a"), 0.18)
	_gold = ART.material(Color("8a623a"), 0.65)
	_moon = ART.material(Color("6095b3"), 0.15, 1.1)
	_ember = ART.material(Color("ff7b24"), 0.1, 0.35)
	_ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_velvet = ART.material(Color("3e1e30"), 0.03)
	var noise := FastNoiseLite.new()
	noise.seed = 4917
	noise.frequency = 0.065
	noise.fractal_octaves = 3
	var grain := NoiseTexture2D.new()
	grain.width = 128
	grain.height = 128
	grain.noise = noise
	grain.seamless = true
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.55, 0.58, 0.65), Color(0.94, 0.94, 0.96)])
	grain.color_ramp = ramp
	for mat in [_stone, _dark, _edge]:
		mat.albedo_texture = grain
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * 0.18

func _build_shell() -> void:
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = FLOOR_SHADER
	_box(Vector3(0, -0.7, 0), Vector3(320, 1.4, 480), floor_mat)
	_collision_box(Vector3(0, -0.7, 0), Vector3(320, 1.4, 480), false)
	# Complete walls and a remote vault make this a true, enclosed interior.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 158, 57, 0), Vector3(4, 114, 480), _dark)
		_collision_box(Vector3(side * 158, 57, 0), Vector3(4, 114, 480), false)
		_box(Vector3(0, 57, side * 238), Vector3(320, 114, 4), _dark)
		_collision_box(Vector3(0, 57, side * 238), Vector3(320, 114, 4), false)
		_box(Vector3(side * 155.4, 1.0, 0), Vector3(1.3, 2, 475), _stone)
		_box(Vector3(side * 155.1, 2.05, 0), Vector3(1.5, 0.16, 475), _gold)
		for z in range(-210, 211, 60):
			_box(Vector3(side * 155.0, 32, z), Vector3(1.5, 57, 24), _stone)
			_box(Vector3(side * 154.1, 31, z), Vector3(0.5, 44, 15), _dark)
			# A pale slit high above the player is the source of the moon wash.
			_box(Vector3(side * 153.6, 53, z), Vector3(0.1, 21, 2.0), _moon)
			_box(Vector3(side * 153.4, 53, z), Vector3(0.1, 0.2, 2.2), _gold)
			_box(Vector3(side * 153.4, 47, z), Vector3(0.1, 0.2, 2.2), _gold)
			_box(Vector3(side * 153.4, 59, z), Vector3(0.1, 0.2, 2.2), _gold)
	_box(Vector3(0, 117, 0), Vector3(320, 4, 480), _dark)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 119, 71, 0), Vector3(78, 2.2, 477), _stone)
		_box(Vector3(side * 86, 70, 0), Vector3(3.6, 3.6, 477), _edge)
		_box(Vector3(side * 86, 72.1, 0), Vector3(3.8, 0.3, 477), _gold)
	# Entry threshold, with broad clear space between its doors.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 21, 15, 232), Vector3(4.0, 30, 6), _stone)
		_box(Vector3(side * 21, 0.8, 229), Vector3(5.4, 1.6, 7), _edge)
		_box(Vector3(side * 12, 14, 235.2), Vector3(16, 28, 1.1), _velvet)
		_box(Vector3(side * 12, 14, 234.5), Vector3(0.45, 23, 0.15), _gold)
	var entry := ART.text3d(self, "C A T H E D R A L   O F   C I N D E R S", Vector3(0, 24, 233.8), 140)
	entry.rotation.y = PI
	entry.modulate = Color("d9b67c")
	entry.pixel_size = 0.015

func _build_colonnades() -> void:
	for side in [-1.0, 1.0]:
		for z in range(-210, 211, 60):
			var at := Vector3(side * 86, 0, z)
			_pier(at, 70.0, 1.0)
			_pier(Vector3(side * 137, 0, z), 68.0, 0.66)
			# Side-aisle ribs and monumental triangular buttresses.
			_arch(Vector3(side * 111.5, 57, z), 25.5, 13.0, 1.9, _stone)
			_box(at + Vector3(side * -4.0, 33, 0), Vector3(0.4, 17, 7), _velvet)
			_box(at + Vector3(side * -4.3, 39.5, 0), Vector3(0.15, 0.3, 7.4), _gold)
			_box(at + Vector3(side * -4.3, 30, 0), Vector3(0.15, 8, 0.24), _gold)
			_brazier(at + Vector3(-side * 6.5, 0, 8))
			_brazier(at + Vector3(-side * 6.5, 0, -8))
	for z in range(-210, 211, 60):
		_arch(Vector3(0, 69, z), 86.0, 43.0, 2.3, _stone)
		_arch(Vector3(0, 68.8, z + 1.5), 85.0, 42.3, 0.35, _gold)
		_box(Vector3(0, 111, z), Vector3(5, 3, 5), _edge)
	# The long central ridge fades into the fog above the player.
	_box(Vector3(0, 112.8, 0), Vector3(2.3, 2.3, 475), _stone)

func _pier(at: Vector3, height: float, width: float) -> void:
	_box(at + Vector3.UP * 0.5, Vector3(9.6 * width, 1, 9.6 * width), _dark)
	_box(at + Vector3.UP * 1.1, Vector3(8.6 * width, 0.25, 8.6 * width), _gold)
	_box(at + Vector3.UP * 2.0, Vector3(7.7 * width, 1.65, 7.7 * width), _stone)
	_cylinder(at + Vector3.UP * (height * 0.5), 3.7 * width, height - 4, _stone)
	for dx in [-1.0, 1.0]:
		for dz in [-1.0, 1.0]:
			_cylinder(at + Vector3(dx * 2.65 * width, height * 0.5, dz * 2.65 * width), 0.72 * width, height - 4, _edge)
	for y in [4.0, height * 0.4, height - 4.0, height - 1.1]:
		_box(at + Vector3.UP * y, Vector3(8.2 * width, 0.7, 8.2 * width), _dark)
		_box(at + Vector3.UP * (y + 0.44), Vector3(8.6 * width, 0.16, 8.6 * width), _gold)
	_box(at + Vector3.UP * (height - 0.2), Vector3(10.6 * width, 2.0, 10.6 * width), _stone)
	_collision_box(at + Vector3.UP * height * 0.5, Vector3(8.5 * width, height, 8.5 * width))

func _arch(center: Vector3, half_width: float, rise: float, thickness: float, mat: Material) -> void:
	# A pointed arch rather than a low ceiling: its crown is over 110 m up.
	const SEGMENTS: int = 18
	for i in range(SEGMENTS):
		var u0: float = float(i) / SEGMENTS
		var u1: float = float(i + 1) / SEGMENTS
		var a := center + Vector3(lerpf(-half_width, half_width, u0), rise * pow(sin(u0 * PI), 0.74), 0)
		var b := center + Vector3(lerpf(-half_width, half_width, u1), rise * pow(sin(u1 * PI), 0.74), 0)
		_beam(a, b, thickness, thickness * 1.35, mat)

func _build_floor_detail() -> void:
	# Recessed luminous procession rails and widely separated transverse joints.
	for side in [-1.0, 1.0]:
		for z in range(-218, 195, 8):
			_box(Vector3(side * 13.7, 0.024, z), Vector3(0.07, 0.024, 4.0), _gold)
		for z in range(-204, 193, 24):
			_box(Vector3(side * 13.7, 0.029, z), Vector3(0.09, 0.024, 1.4), _ember)
		for x in [78.5, 95.0, 129.0, 147.0]:
			_box(Vector3(side * x, 0.023, 0), Vector3(0.075, 0.02, 471), _gold)
	for z in range(-228, 229, 30):
		_box(Vector3(0, 0.02, z), Vector3(304, 0.02, 0.08), _dark)
	var arrival_mat := ART.material(Color("d4aa6b"), 0.4, 0.25)
	ART.ring(self, spawn_position + Vector3(0, -0.065, 0), 6.0, 0.07, arrival_mat)
	ART.ring(self, spawn_position + Vector3(0, -0.064, 0), 5.4, 0.025, _gold)
	for i in range(8):
		var angle: float = TAU * i / 8
		_box(spawn_position + Vector3(sin(angle) * 5.7, -0.06, cos(angle) * 5.7), Vector3(0.16, 0.025, 0.5), arrival_mat, Vector3(0, angle, 0))

func _build_court(index: int) -> void:
	var center: Vector3 = encounter_positions[index]
	var radius: float = 21.0 if index < 9 else 22.0
	var accent := ART.material(COURT_COLORS[index] * Color(0.34, 0.34, 0.34, 1.0), 0.35, 0.15)
	accent.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	court_materials.append(accent)
	# No raised platforms or lips: the complete arena remains traversable.
	var court_stone := ShaderMaterial.new()
	court_stone.shader = COURT_SHADER
	court_stone.set_shader_parameter("court_center", Vector2(center.x, center.z))
	_cylinder(center + Vector3(0, -0.106, 0), radius + 0.5, 0.022, court_stone)
	ART.ring(self, center + Vector3(0, -0.080, 0), radius, 0.065, accent)
	ART.ring(self, center + Vector3(0, -0.079, 0), radius - 0.75, 0.026, _gold)
	ART.ring(self, center + Vector3(0, -0.076, 0), 5.4, 0.035, accent)
	for i in range(24):
		var angle: float = TAU * i / 24.0
		var at := center + Vector3(sin(angle) * (radius - 1.8), -0.07, cos(angle) * (radius - 1.8))
		_box(at, Vector3(0.1, 0.024, 0.75 if i % 3 == 0 else 0.3), accent, Vector3(0, angle, 0))
	# Each sanctum carries a distinct engraved heraldic geometry.
	var sides: int = 3 + index % 6
	for i in range(sides):
		var a: float = TAU * i / sides + index * 0.3
		var b: float = TAU * ((i + 2) % sides) / sides + index * 0.3
		var first := center + Vector3(sin(a) * 4.4, -0.073, cos(a) * 4.4)
		var second := center + Vector3(sin(b) * 4.4, -0.073, cos(b) * 4.4)
		_beam(first, second, 0.055, 0.028, accent)
	for side in [-1.0, 1.0]:
		var at := center + Vector3(side * (radius + 3.5), -0.12, 0)
		_box(at + Vector3.UP * 0.28, Vector3(2.4, 0.56, 2.4), _edge)
		_box(at + Vector3.UP * 2.6, Vector3(1.1, 4.65, 1.1), _dark)
		_box(at + Vector3.UP * 2.8, Vector3(1.14, 3.7, 0.12), accent)
		_cylinder(at + Vector3.UP * 5.1, 0.9, 1.25, _gold, true)
		_collision_box(at + Vector3.UP * 2.8, Vector3(1.7, 5.6, 1.7))
	var beacon := Node3D.new()
	beacon.name = "Court%02dBeacon" % (index + 1)
	add_child(beacon)
	beacon.position = center + Vector3(0, 9.0, -radius + 2.0)
	var shard: MeshInstance3D = ART.box(beacon, Vector3.ZERO, Vector3(0.6, 0.6, 0.6), accent)
	shard.rotation = Vector3(PI * 0.25, 0, PI * 0.25)
	var orbit: MeshInstance3D = ART.ring(beacon, Vector3.ZERO, 1.4, 0.045, accent)
	orbit.rotation.x = PI * 0.5
	court_beacons.append(beacon)
	var label := ART.text3d(self, COURT_NUMERALS[index], center + Vector3(0, 6.2, -radius + 2.0), 116)
	label.modulate = COURT_COLORS[index] * Color(0.55, 0.55, 0.55, 1.0)
	label.pixel_size = 0.017
	label.no_depth_test = false
	court_labels.append(label)

func _build_sanctum() -> void:
	# A distant eclipse hangs above the final throne. Its architectural silhouette
	# is visible through the haze long before the final encounter is reached.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 29, 22, -232), Vector3(6, 44, 7), _stone)
		_box(Vector3(side * 29, 1.0, -231), Vector3(9, 2, 10), _edge)
		_box(Vector3(side * 29, 21, -227.8), Vector3(0.16, 34, 0.1), _gold)
		for j in range(3):
			var x: float = side * (37.0 + j * 7.0)
			var height: float = 36.0 - j * 6.0
			_beam(Vector3(x, 4, -232), Vector3(x + side * 5, height, -232), 2.0, 4.0, _dark)
			_beam(Vector3(x, 5, -229.9), Vector3(x + side * 5, height - 2, -229.9), 0.2, 0.15, _gold)
	_arch(Vector3(0, 41, -232), 29, 23, 3.0, _stone)
	var eclipse := ART.ring(self, Vector3(0, 43, -231), 12.0, 0.22, _gold)
	eclipse.rotation.x = PI * 0.5
	var aureole := ART.ring(self, Vector3(0, 43, -230.8), 13.4, 0.06, _ember)
	aureole.rotation.x = PI * 0.5
	for i in range(16):
		var angle: float = TAU * i / 16
		var at := Vector3(sin(angle) * 15, 43 + cos(angle) * 15, -231)
		_box(at, Vector3(0.23, 2.1 if i % 2 else 3.7, 0.2), _gold, Vector3(0, 0, -angle))
	for side in [-1.0, 1.0]:
		_brazier(Vector3(side * 11, 0, -228))
	var words := ART.text3d(self, "T H E   L A S T   F L A M E", Vector3(0, 22, -227.7), 148)
	words.modulate = Color("d5af7d")
	words.pixel_size = 0.021

func _build_chandeliers() -> void:
	for z in [176.0, 56.0, -64.0, -184.0]:
		var at := Vector3(0, 36, z)
		var hoop := ART.ring(self, at, 11.0, 0.18, _gold)
		hoop.name = "CrownChandelier"
		ART.ring(self, at + Vector3.UP * 0.5, 10.4, 0.10, _dark)
		for side in [-1.0, 1.0]:
			_beam(at + Vector3(side * 8, 0, 0), at + Vector3(0, 60, 0), 0.09, 0.09, _gold)
			_beam(at + Vector3(0, 0, side * 8), at + Vector3(0, 60, 0), 0.09, 0.09, _gold)
		for i in range(12):
			var angle: float = TAU * i / 12
			var candle := at + Vector3(sin(angle) * 11, 1, cos(angle) * 11)
			_cylinder(candle, 0.25, 2.0, _edge)
			_cylinder(candle + Vector3.UP * 1.3, 0.2, 0.85, _ember, true)
			_beam(at, candle + Vector3.DOWN, 0.1, 0.1, _gold)

func _brazier(at: Vector3) -> void:
	_cylinder(at + Vector3.UP * 0.3, 0.95, 0.6, _dark)
	_cylinder(at + Vector3.UP * 1.6, 0.3, 2.2, _gold)
	_cylinder(at + Vector3.UP * 2.5, 0.9, 0.35, _gold)
	for j in range(3):
		_cylinder(at + Vector3((j - 1) * 0.25, 3.1 + j * 0.13, 0), 0.20, 1.0 + j * 0.18, _ember, true)

func _create_environment() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "CathedralAtmosphere"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("070d18")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8198b8")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.12
	env.fog_enabled = true
	env.fog_light_color = Color("142234")
	env.fog_light_energy = 0.65
	env.fog_density = 0.008
	env.fog_sky_affect = 1.0
	world_environment.environment = env
	add_child(world_environment)
	var moon := DirectionalLight3D.new()
	moon.name = "ClerestoryMoonlight"
	moon.rotation_degrees = Vector3(-56, -31, 0)
	moon.light_color = Color("9ab7d8")
	moon.light_energy = 0.85
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 75
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.shadow_bias = 0.08
	add_child(moon)
	var fill := DirectionalLight3D.new()
	fill.name = "WarmStoneBounce"
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_color = Color("b48970")
	fill.light_energy = 0.26
	fill.shadow_enabled = false
	add_child(fill)
	for i in range(3):
		var light := OmniLight3D.new()
		light.name = "ActiveCourtLight%d" % i
		light.omni_range = 30 if i == 0 else 18
		light.omni_attenuation = 1.2
		light.light_energy = 2.5 if i == 0 else 1.8
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_court_lights.append(light)
	var entry := OmniLight3D.new()
	entry.name = "EntryEmberWash"
	entry.position = spawn_position + Vector3(0, 7, -5)
	entry.omni_range = 35
	entry.light_color = Color("ffc187")
	entry.light_energy = 2.0
	entry.shadow_enabled = false
	add_child(entry)

func _create_atmosphere() -> void:
	# Transparent shafts are sparse, and never rely on unsupported volumetric fog.
	var shaft_mat := ShaderMaterial.new()
	shaft_mat.shader = SHAFT_SHADER
	for z in [140.0, 20.0, -100.0]:
		for side in [-1.0, 1.0]:
			var shaft := MeshInstance3D.new()
			var plane := QuadMesh.new()
			plane.size = Vector2(15, 76)
			shaft.mesh = plane
			shaft.material_override = shaft_mat
			shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shaft.position = Vector3(side * 69, 36, z)
			shaft.rotation = Vector3(0.10, side * 0.5, side * -0.35)
			add_child(shaft)
	_embers = _particles(58, Color("ffbd81"), Vector3(18, 5, 18))
	_embers.name = "CourtEmberMotes"
	_embers.position = spawn_position + Vector3.UP * 3
	_embers.lifetime = 8.0
	_embers.direction = Vector3.UP
	_embers.gravity = Vector3(0.02, 0.04, 0.03)
	_embers.initial_velocity_min = 0.15
	_embers.initial_velocity_max = 0.7
	_active_beam_mat = ShaderMaterial.new()
	_active_beam_mat.shader = SHAFT_SHADER
	_active_beam_mat.set_shader_parameter("shaft_color", Color(0.75, 0.4, 0.18, 0.17))
	_active_beam = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(8, 33)
	_active_beam.mesh = quad
	_active_beam.material_override = _active_beam_mat
	_active_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_active_beam.visible = false
	add_child(_active_beam)

func _particles(amount: int, color: Color, area: Vector3) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 6.0
	particles.preprocess = 2.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = area
	particles.direction = Vector3.UP
	particles.spread = 22
	particles.gravity = Vector3(0, 0.1, 0)
	particles.initial_velocity_min = 0.3
	particles.initial_velocity_max = 1.0
	particles.scale_amount_min = 0.025
	particles.scale_amount_max = 0.075
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 4
	mesh.rings = 2
	particles.mesh = mesh
	var mat := ART.material(color, 0.0, 0.15)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particles.material_override = mat
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	return particles

func _create_portal() -> void:
	portal = Node3D.new()
	portal.name = "NextLevelPortal"
	portal.position = exit_position
	portal.visible = false
	add_child(portal)
	var gold := ART.material(Color("fbb556"), 0.45, 0.18)
	var blue := ART.material(Color("4cbee5"), 0.2, 0.22)
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blue.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring: MeshInstance3D = ART.ring(portal, Vector3(0, 4.8, 0), 4.5, 0.16, gold)
	ring.rotation.x = PI * 0.5
	_portal_rings.append(ring)
	var orbit: MeshInstance3D = ART.ring(portal, Vector3(0, 4.8, 0.15), 4.9, 0.045, blue)
	orbit.rotation.x = PI * 0.5
	_portal_rings.append(orbit)
	for i in range(12):
		var angle: float = TAU * i / 12
		var shard: MeshInstance3D = ART.box(portal, Vector3(sin(angle) * 4.75, 4.8 + cos(angle) * 4.75, 0), Vector3(0.20, 0.54, 0.20), gold)
		shard.rotation.z = -angle
	var surface := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(8.9, 8.9)
	surface.mesh = plane
	surface.position = Vector3(0, 4.8, 0)
	var mat := ShaderMaterial.new()
	mat.shader = PORTAL_SHADER
	surface.material_override = mat
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	portal.add_child(surface)
	ART.ring(portal, Vector3(0, 0.065, 0), 6.2, 0.065, blue)
	var label := ART.text3d(portal, "B E Y O N D   T H E   A S H", Vector3(0, 10.8, 0), 76)
	label.modulate = Color("ffdc9b")
	label.pixel_size = 0.012
	_portal_light = OmniLight3D.new()
	_portal_light.position = Vector3(0, 5, 2)
	_portal_light.light_color = Color("7edbff")
	_portal_light.light_energy = 4.0
	_portal_light.omni_range = 21
	_portal_light.shadow_enabled = false
	portal.add_child(_portal_light)
	_portal_sparks = _particles(88, Color("ffe2a0"), Vector3(4.8, 3.8, 0.9))
	_portal_sparks.reparent(portal, false)
	_portal_sparks.position = Vector3(0, 4.3, 0)
	_portal_sparks.emitting = false
	_portal_sparks.visible = false

func set_encounter(index: int) -> void:
	active_encounter = clampi(index, -1, encounter_positions.size() - 1)
	_refresh_courts()
	if active_encounter < 0:
		return
	var center: Vector3 = encounter_positions[active_encounter]
	var color: Color = COURT_COLORS[active_encounter]
	for i in range(_court_lights.size()):
		var light: OmniLight3D = _court_lights[i]
		light.visible = true
		light.position = center + Vector3(0 if i == 0 else (-17 if i == 1 else 17), 8 if i == 0 else 3, 0)
		light.light_color = Color("ffd4a6") if i == 0 else color
	_embers.position = center + Vector3.UP * 3
	_active_beam.position = center + Vector3(0, 16.5, -18)
	_active_beam.visible = true
	_active_beam_mat.set_shader_parameter("shaft_color", Color(color.r, color.g, color.b, 0.14))

func mark_encounter_complete(index: int) -> void:
	if index >= 0 and index < encounter_positions.size() and not cleared_encounters.has(index):
		cleared_encounters.append(index)
	_refresh_courts()

func _refresh_courts() -> void:
	for i in range(court_materials.size()):
		var active: bool = i == active_encounter
		var complete: bool = cleared_encounters.has(i)
		var color: Color = Color("bfba99") if complete else COURT_COLORS[i]
		var power: float = 0.62 if active else (0.34 if complete else 0.20)
		court_materials[i].albedo_color = Color(color.r * power, color.g * power, color.b * power, 1.0)
		court_materials[i].emission = color
		court_materials[i].emission_energy_multiplier = 0.24 if active else (0.12 if complete else 0.025)
		court_beacons[i].scale = Vector3.ONE * (1.25 if active else 0.7)
		court_beacons[i].visible = not portal_active
		court_labels[i].visible = not portal_active
		court_labels[i].modulate = Color(color.r * power, color.g * power, color.b * power, 1.0)
		court_labels[i].text = "✦" if complete else COURT_NUMERALS[i]
	if active_encounter < 0:
		for light in _court_lights:
			light.visible = false
		if is_instance_valid(_active_beam):
			_active_beam.visible = false

func reveal_portal() -> Node3D:
	if portal_active:
		return portal
	portal_active = true
	active_encounter = -1
	_refresh_courts()
	portal.visible = true
	portal.scale = Vector3.ONE * 0.05
	_portal_sparks.visible = true
	_portal_sparks.emitting = true
	_portal_tween = create_tween()
	_portal_tween.tween_property(portal, "scale", Vector3.ONE, 1.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return portal

func reset_progress() -> void:
	active_encounter = -1
	cleared_encounters.clear()
	portal_active = false
	if is_instance_valid(_portal_tween):
		_portal_tween.kill()
	if is_instance_valid(portal):
		portal.visible = false
		portal.scale = Vector3.ONE
		_portal_sparks.emitting = false
		_portal_sparks.visible = false
	_refresh_courts()
	if is_instance_valid(_embers):
		_embers.position = spawn_position + Vector3.UP * 3

func spawn_point() -> Vector3:
	return spawn_position

func is_walkable(pos: Vector3) -> bool:
	if absf(pos.x) > 153 or absf(pos.z) > 231:
		return false
	var flat := Vector2(pos.x, pos.z)
	for obstacle in obstacles:
		if obstacle.has_point(flat):
			return false
	return true

func build_grid() -> void:
	grid.region = Rect2i(GRID_MIN, GRID_SIZE)
	grid.cell_size = Vector2.ONE * CELL_SIZE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	# Rasterize only footprints rather than scanning every cell against every pier.
	for obstacle in obstacles:
		var first := Vector2i(floori(obstacle.position.x / CELL_SIZE), floori(obstacle.position.y / CELL_SIZE))
		var last := Vector2i(ceili(obstacle.end.x / CELL_SIZE), ceili(obstacle.end.y / CELL_SIZE))
		for x in range(first.x, last.x + 1):
			for z in range(first.y, last.y + 1):
				var cell := Vector2i(x, z)
				if grid.is_in_boundsv(cell) and obstacle.grow(0.7).has_point(Vector2(x, z) * CELL_SIZE):
					grid.set_point_solid(cell)

func nearest_open(pos: Vector3) -> Vector2i:
	var cell := Vector2i(clampi(roundi(pos.x / CELL_SIZE), GRID_MIN.x, GRID_MIN.x + GRID_SIZE.x - 1), clampi(roundi(pos.z / CELL_SIZE), GRID_MIN.y, GRID_MIN.y + GRID_SIZE.y - 1))
	if not grid.is_point_solid(cell):
		return cell
	for radius in range(1, 9):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var candidate: Vector2i = cell + Vector2i(x, z)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate):
					return candidate
	return Vector2i(0, 63)

func route(from: Vector3, to: Vector3) -> PackedVector2Array:
	return grid.get_point_path(nearest_open(from), nearest_open(to))

func _box(at: Vector3, size: Vector3, mat: Material, rotation := Vector3.ZERO) -> void:
	if not _meshes.has("box"):
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		_meshes["box"] = mesh
	_batch("box", Transform3D(Basis.from_euler(rotation) * Basis.from_scale(size), at), mat)

func _cylinder(at: Vector3, radius: float, height: float, mat: Material, cone: bool = false) -> void:
	var key: String = "cone" if cone else "cylinder"
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = 0.5
		mesh.top_radius = 0.02 if cone else 0.5
		mesh.height = 1.0
		mesh.radial_segments = 16 if cone else 24
		_meshes[key] = mesh
	_batch(key, Transform3D(Basis.from_scale(Vector3(radius * 2, height, radius * 2)), at), mat)

func _beam(a: Vector3, b: Vector3, thickness: float, depth: float, mat: Material) -> void:
	var y_axis: Vector3 = (b - a).normalized()
	if y_axis.length_squared() < 0.5:
		return
	var helper: Vector3 = Vector3.FORWARD if absf(y_axis.z) < 0.95 else Vector3.RIGHT
	var x_axis: Vector3 = y_axis.cross(helper).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	if not _meshes.has("box"):
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		_meshes["box"] = mesh
	_batch("box", Transform3D(Basis(x_axis * thickness, y_axis * a.distance_to(b), z_axis * depth), (a + b) * 0.5), mat)

func _batch(kind: String, transform: Transform3D, mat: Material) -> void:
	# Spatial chunks retain frustum culling in a room hundreds of metres long.
	var chunk: int = floori((transform.origin.z + 240) / 90.0)
	var key: String = "%s_%s_%s" % [kind, mat.get_instance_id(), chunk]
	if not _batches.has(key):
		_batches[key] = {"mesh": _meshes[kind], "material": mat, "transforms": []}
	_batches[key].transforms.append(transform)

func _flush_batches() -> void:
	for key in _batches:
		var data: Dictionary = _batches[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = data.mesh
		multimesh.instance_count = data.transforms.size()
		for i in range(data.transforms.size()):
			multimesh.set_instance_transform(i, data.transforms[i])
		var visual := MultiMeshInstance3D.new()
		visual.name = "Architecture_" + str(key)
		visual.multimesh = multimesh
		visual.material_override = data.material
		# Most of the hall is lit by baked-looking ambient moonlight; keeping its
		# enormous roof out of dynamic shadow maps preserves a visible interior.
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var visual_parent: Node = data.get("parent", self)
		visual_parent.add_child(visual)
	_batches.clear()

func _collision_box(at: Vector3, size: Vector3, navigational: bool = true) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = at
	_body.add_child(collision)
	if navigational:
		obstacles.append(Rect2(at.x - size.x * 0.5 - 0.8, at.z - size.z * 0.5 - 0.8, size.x + 1.6, size.z + 1.6))

func _process(delta: float) -> void:
	elapsed += delta
	for i in range(court_beacons.size()):
		var beacon: Node3D = court_beacons[i]
		beacon.position.y = encounter_positions[i].y + 9.0 + sin(elapsed * 0.8 + i) * 0.22
		beacon.rotation.y += delta * (0.25 if i == active_encounter else 0.09)
	if portal_active:
		_portal_rings[0].rotation.y = sin(elapsed * 0.6) * 0.12
		_portal_rings[1].rotation.y = -sin(elapsed * 0.6) * 0.18
		_portal_light.light_energy = 4.0 + sin(elapsed * 2) * 0.4
	if active_encounter >= 0:
		_court_lights[1].light_energy = 1.8 + sin(elapsed * 3.7) * 0.13
		_court_lights[2].light_energy = 1.8 + sin(elapsed * 4.1) * 0.15
