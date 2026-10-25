extends "res://scripts/arena.gd"
## HERO: The Hollow Spire — one shared arena layout repeated across eleven floors.
## The center shaft contains the lift; inactive floor rendering and collision are culled.

const ENCOUNTERS = preload("res://scripts/encounter_data.gd")
const LAYOUT = preload("res://scripts/tower_layout.gd")

const ARENA_SIZE: float = 280.0
const ARENA_HALF: float = 140.0
const PLAY_HALF: float = 138.0
const FLOOR_COUNT: int = 11
const FLOOR_HEIGHT: float = LAYOUT.FLOOR_HEIGHT
const PILLAR_HEIGHT: float = FLOOR_HEIGHT * (FLOOR_COUNT - 1) + 4.0
const PILLAR_RADIUS: float = 1.35

var central_pillar: Node3D
var pillar_body: StaticBody3D
var pillar_beacon: OmniLight3D
var _floor_grid := AStarGrid2D.new()
var stage_index: int = 0
var stage_radius: float = 138.0
var stage_ring: MeshInstance3D
var elevator_car: Node3D
var elevator_trim_material: StandardMaterial3D
var elevator_active: bool = false
var elevator_ride_seconds: float = 2.7
var _elevator_riders: Array[CharacterBody3D] = []
var _floor_visual_roots: Array[Node3D] = []
var _floor_bodies: Array[StaticBody3D] = []

# Compatibility stubs for legacy scripts
var _room_doors: Array[Dictionary] = []
var _key_nodes: Array[Node3D] = []
var _floor_roots: Array[Node3D] = []
var _echoes: Array[Dictionary] = []
var _floor_keys: Dictionary = {}
var _potion_collected: bool = false
var potion_position := Vector3(0, 0.12, 0)
var terrace_position := Vector3(0, 0.12, 0)

func _ready() -> void:
	name = "BattleRoyaleArena"
	spawn_position = Vector3(0, 0.12, 95)
	exit_position = Vector3(0, 0.12, -95)

	# 11 perimeter encounter positions
	encounter_positions.clear()
	for i in range(11):
		var angle: float = (TAU * float(i) / 11.0) - PI * 0.5
		var radius: float = 85.0 + ((i % 3) - 1) * 10.0
		encounter_positions.append(Vector3(cos(angle) * radius, 0.12, sin(angle) * radius))

	_body = StaticBody3D.new()
	_body.name = "ArenaStaticCollision"
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)

	_create_materials()
	_build_open_arena()
	_build_stage_ring()
	_build_central_time_pillar()
	_build_perimeter_energy_barrier()
	_build_braziers_and_lighting()
	_setup_sky_environment()
	_build_elevator_car()
	_build_tower_floors()
	build_grid()

func get_play_bounds() -> Rect2:
	return Rect2(-PLAY_HALF, -PLAY_HALF, PLAY_HALF * 2.0, PLAY_HALF * 2.0)

func set_stage(index: int) -> void:
	stage_index = clampi(index, 0, FLOOR_COUNT - 1)
	stage_radius = 132.0
	if is_instance_valid(stage_ring):
		var torus := TorusMesh.new()
		torus.inner_radius = maxf(0.1, stage_radius - 0.28)
		torus.outer_radius = stage_radius + 0.28
		torus.rings = 4
		torus.ring_segments = 96
		stage_ring.mesh = torus
		stage_ring.position.y = float(stage_index) * FLOOR_HEIGHT + 0.06
	_update_floor_presentation()
	if is_instance_valid(pillar_beacon):
		pillar_beacon.position.y = float(stage_index) * FLOOR_HEIGHT + 4.0

func _update_floor_presentation() -> void:
	var lift_in_motion: bool = elevator_active or not _elevator_riders.is_empty()
	for floor_index in range(_floor_visual_roots.size()):
		var floor_is_active: bool = floor_index == stage_index
		var floor_is_landing: bool = lift_in_motion and floor_index == stage_index + 1
		var floor_enabled: bool = floor_is_active or floor_is_landing
		_floor_visual_roots[floor_index].visible = floor_enabled
		if floor_index < _floor_bodies.size() and is_instance_valid(_floor_bodies[floor_index]):
			_floor_bodies[floor_index].collision_layer = 1 if floor_enabled else 0
		for light in _floor_visual_roots[floor_index].find_children("*", "OmniLight3D", false, false):
			light.visible = floor_is_active

func activate_elevator(floor_index: int) -> void:
	if floor_index != stage_index or floor_index >= FLOOR_COUNT - 1 or not is_instance_valid(elevator_car):
		return
	elevator_active = true
	_update_floor_presentation()
	if is_instance_valid(elevator_trim_material):
		elevator_trim_material.albedo_color = Color("f4d079")
		elevator_trim_material.emission = Color("f4a943")
		elevator_trim_material.emission_energy_multiplier = 2.2

func player_is_on_elevator(body: CharacterBody3D) -> bool:
	if not elevator_active or not is_instance_valid(body) or body.is_queued_for_deletion():
		return false
	var floor_y: float = float(stage_index) * FLOOR_HEIGHT
	var local_position: Vector3 = elevator_car.to_local(body.global_position)
	return absf(local_position.x) <= 6.7 and absf(local_position.z) <= 6.7 and absf(local_position.y) <= 2.2 and absf(body.global_position.y - floor_y) <= 2.2

func ride_elevator_to_floor(target_floor: int, riders: Array[CharacterBody3D]) -> bool:
	if not elevator_active or target_floor != stage_index + 1 or target_floor >= FLOOR_COUNT or not is_instance_valid(elevator_car):
		return false
	elevator_active = false
	_elevator_riders.clear()
	for rider in riders:
		if not is_instance_valid(rider) or rider.is_queued_for_deletion():
			continue
		rider.reparent(elevator_car, true)
		rider.set_physics_process(false)
		_elevator_riders.append(rider)
	if _elevator_riders.is_empty():
		return false
	_update_floor_presentation()
	var destination_y: float = float(target_floor) * FLOOR_HEIGHT
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(elevator_car, "position:y", destination_y, elevator_ride_seconds)
	tween.tween_callback(func() -> void:
		var destination: Node = get_parent()
		for rider_index in range(_elevator_riders.size()):
			var rider: CharacterBody3D = _elevator_riders[rider_index]
			if not is_instance_valid(rider) or rider.is_queued_for_deletion():
				continue
			rider.reparent(destination, true)
			rider.set_physics_process(true)
			rider.velocity = Vector3.ZERO
			rider.position = Vector3(0.0 if rider_index == 0 else 2.4, destination_y + 0.12, 9.0 + rider_index * 2.0)
		_elevator_riders.clear()
		set_stage(target_floor)
		if is_instance_valid(destination) and destination.has_method("on_lift_arrived"):
			destination.on_lift_arrived(target_floor)
	)
	return true

func _build_elevator_car() -> void:
	elevator_car = Node3D.new()
	elevator_car.name = "CentralElevatorCar"
	elevator_car.position.y = 0.0
	add_child(elevator_car)
	var car_body := StaticBody3D.new()
	car_body.name = "ElevatorPlatformCollision"
	car_body.collision_layer = 1
	car_body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(14.0, 0.58, 14.0)
	collision.shape = shape
	collision.position.y = -0.29
	car_body.add_child(collision)
	elevator_car.add_child(car_body)
	var platform := MeshInstance3D.new()
	platform.name = "ElevatorPlatform"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(14.0, 0.58, 14.0)
	platform.mesh = mesh
	platform.position.y = -0.29
	var platform_material := StandardMaterial3D.new()
	platform_material.albedo_color = Color("252d39")
	platform_material.roughness = 0.52
	platform_material.metallic = 0.24
	platform.material_override = platform_material
	platform.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elevator_car.add_child(platform)
	elevator_trim_material = StandardMaterial3D.new()
	elevator_trim_material.albedo_color = Color("384353")
	elevator_trim_material.emission_enabled = true
	elevator_trim_material.emission = Color("345477")
	elevator_trim_material.emission_energy_multiplier = 0.55
	elevator_trim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for edge in range(4):
		var trim := MeshInstance3D.new()
		var trim_mesh := BoxMesh.new()
		trim_mesh.size = Vector3(13.6, 0.06, 0.14) if edge % 2 == 0 else Vector3(0.14, 0.06, 13.6)
		trim.mesh = trim_mesh
		trim.position = Vector3(0.0, 0.025, -6.75 if edge == 0 else (6.75 if edge == 1 else 0.0)) if edge < 2 else Vector3(-6.75 if edge == 2 else 6.75, 0.025, 0.0)
		trim.material_override = elevator_trim_material
		trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elevator_car.add_child(trim)

func _build_tower_floors() -> void:
	var original_visuals: Array[Node3D] = []
	for child in get_children():
		if child == stage_ring or child == central_pillar or child == elevator_car:
			continue
		if child is MeshInstance3D or child is OmniLight3D:
			original_visuals.append(child as Node3D)
	var base_floor := Node3D.new()
	base_floor.name = "ArenaFloor01"
	add_child(base_floor)
	for visual in original_visuals:
		visual.reparent(base_floor, true)
	_floor_visual_roots.append(base_floor)
	_floor_bodies.append(_body)
	for floor_index in range(1, FLOOR_COUNT):
		var floor_y: float = float(floor_index) * FLOOR_HEIGHT
		var visual_root := Node3D.new()
		visual_root.name = "ArenaFloor%02d" % (floor_index + 1)
		visual_root.position.y = floor_y
		add_child(visual_root)
		for visual in original_visuals:
			var copy: Node3D = visual.duplicate() as Node3D
			if copy != null:
				visual_root.add_child(copy)
		_floor_visual_roots.append(visual_root)
		var floor_body := StaticBody3D.new()
		floor_body.name = "ArenaFloor%02dCollision" % (floor_index + 1)
		floor_body.position.y = floor_y
		floor_body.collision_layer = 1
		floor_body.collision_mask = 0
		for shape_node in _body.get_children():
			floor_body.add_child(shape_node.duplicate())
		add_child(floor_body)
		_floor_bodies.append(floor_body)
	set_stage(0)

func mark_stage_complete(index: int) -> void:
	if not cleared_encounters.has(index):
		cleared_encounters.append(index)

func clamp_to_stage(pos: Vector3, margin: float = 1.0) -> Vector3:
	var flat := Vector2(pos.x, pos.z)
	var limit := maxf(4.0, stage_radius - margin)
	if flat.length() > limit:
		flat = flat.normalized() * limit
		pos.x = flat.x
		pos.z = flat.y
	return pos

func _build_stage_ring() -> void:
	stage_ring = MeshInstance3D.new()
	stage_ring.name = "StageBoundaryRing"
	stage_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ff9d4d")
	material.emission_enabled = true
	material.emission = Color("ff632e")
	material.emission_energy_multiplier = 1.8
	stage_ring.material_override = material
	add_child(stage_ring)
	set_stage(0)

func _build_open_arena() -> void:
	# Solid flat floor collider
	var shaft_clearance: float = 7.1
	var panel_span: float = ARENA_HALF - shaft_clearance
	var panel_offset: float = (ARENA_HALF + shaft_clearance) * 0.5
	_add_floor_panel(Vector3(0.0, -0.5, -panel_offset), Vector3(ARENA_SIZE, 1.0, panel_span))
	_add_floor_panel(Vector3(0.0, -0.5, panel_offset), Vector3(ARENA_SIZE, 1.0, panel_span))
	_add_floor_panel(Vector3(-panel_offset, -0.5, 0.0), Vector3(panel_span, 1.0, shaft_clearance * 2.0))
	_add_floor_panel(Vector3(panel_offset, -0.5, 0.0), Vector3(panel_span, 1.0, shaft_clearance * 2.0))

	# Match the collision panels so the center stays visibly open around the lift.
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("151c26")
	floor_mat.roughness = 0.68
	floor_mat.metallic = 0.12
	floor_mat.metallic_specular = 0.2
	for panel in [
		[Vector3(0.0, -0.4, -panel_offset), Vector3(ARENA_SIZE, 0.8, panel_span)],
		[Vector3(0.0, -0.4, panel_offset), Vector3(ARENA_SIZE, 0.8, panel_span)],
		[Vector3(-panel_offset, -0.4, 0.0), Vector3(panel_span, 0.8, shaft_clearance * 2.0)],
		[Vector3(panel_offset, -0.4, 0.0), Vector3(panel_span, 0.8, shaft_clearance * 2.0)]
	]:
		var floor_panel := MeshInstance3D.new()
		floor_panel.name = "ArenaFloorPanel"
		var panel_mesh := BoxMesh.new()
		panel_mesh.size = panel[1]
		floor_panel.mesh = panel_mesh
		floor_panel.position = panel[0]
		floor_panel.material_override = floor_mat
		floor_panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(floor_panel)

	# Inner circular combat dais / Tournament of Power platform (r = 48m)
	var dais := MeshInstance3D.new()
	var dais_mesh := CylinderMesh.new()
	dais_mesh.top_radius = 48.0
	dais_mesh.bottom_radius = 49.0
	dais_mesh.height = 0.04
	dais_mesh.radial_segments = 48
	dais.mesh = dais_mesh
	dais.position = Vector3(0.0, 0.02, 0.0)

	var dais_mat := StandardMaterial3D.new()
	dais_mat.albedo_color = Color("222b38")
	dais_mat.roughness = 0.62
	dais_mat.metallic = 0.18
	dais_mat.metallic_specular = 0.25
	dais.material_override = dais_mat
	dais.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dais)

	# Combat stage ring markings (unshaded for 100% mobile GPU performance)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color("e5a044")
	ring_mat.emission_enabled = true
	ring_mat.emission = Color("e5a044")
	ring_mat.emission_energy_multiplier = 0.95
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for r in [35.0, 75.0, 115.0]:
		var stage_ring := ART.ring(self, Vector3(0.0, 0.05, 0.0), r, 0.35, ring_mat)
		stage_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Inlaid radial alignment lines along cardinal axes for mobile touch orientation
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var axis_inlay := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.32, 0.02, 107.0)
		axis_inlay.mesh = box
		axis_inlay.position = Vector3(sin(angle) * 61.5, 0.045, cos(angle) * 61.5)
		axis_inlay.rotation.y = angle
		axis_inlay.material_override = ring_mat
		axis_inlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(axis_inlay)

func _add_floor_panel(at: Vector3, size: Vector3) -> void:
	var floor_col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	floor_col.shape = box_shape
	floor_col.position = at
	_body.add_child(floor_col)

func _build_central_time_pillar() -> void:
	central_pillar = Node3D.new()
	central_pillar.name = "CentralTimePillar"
	central_pillar.position = Vector3.ZERO
	add_child(central_pillar)

	# Static collision for the pillar
	pillar_body = StaticBody3D.new()
	pillar_body.name = "PillarCollision"
	pillar_body.collision_layer = 1
	pillar_body.collision_mask = 0
	central_pillar.add_child(pillar_body)

	var col := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = PILLAR_RADIUS
	cylinder.height = PILLAR_HEIGHT
	col.shape = cylinder
	col.position = Vector3(0.0, PILLAR_HEIGHT * 0.5, 0.0)
	pillar_body.add_child(col)

	# Main Pillar Mesh
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = PILLAR_RADIUS
	shaft_mesh.bottom_radius = PILLAR_RADIUS * 1.08
	shaft_mesh.height = PILLAR_HEIGHT
	shaft_mesh.radial_segments = 28
	shaft.mesh = shaft_mesh
	shaft.position = Vector3(0.0, PILLAR_HEIGHT * 0.5, 0.0)

	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color("28323f")
	pillar_mat.roughness = 0.6
	pillar_mat.metallic = 0.28
	shaft.material_override = pillar_mat
	central_pillar.add_child(shaft)

	# Ornamental top capital
	var capital := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = PILLAR_RADIUS * 1.25
	cap_mesh.bottom_radius = PILLAR_RADIUS * 0.95
	cap_mesh.height = 2.4
	cap_mesh.radial_segments = 28
	capital.mesh = cap_mesh
	capital.position = Vector3(0.0, PILLAR_HEIGHT + 1.2, 0.0)

	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color("d4af5d")
	gold_mat.metallic = 0.78
	gold_mat.roughness = 0.28
	gold_mat.emission_enabled = true
	gold_mat.emission = Color("efc87d")
	gold_mat.emission_energy_multiplier = 0.35
	capital.material_override = gold_mat
	central_pillar.add_child(capital)

	# Glowing rune bands along the shaft (unshaded, zero dynamic lighting cost)
	var rune_mat := StandardMaterial3D.new()
	rune_mat.albedo_color = Color("ffe088")
	rune_mat.emission_enabled = true
	rune_mat.emission = Color("ffe088")
	rune_mat.emission_energy_multiplier = 2.2
	rune_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for floor_index in range(FLOOR_COUNT):
		for floor_offset in [4.0, 9.0, 14.0]:
			var rune_ring := ART.ring(central_pillar, Vector3(0.0, float(floor_index) * FLOOR_HEIGHT + floor_offset, 0.0), PILLAR_RADIUS + 0.12, 0.22, rune_mat)
			rune_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Monumental Top Beacon Light
	pillar_beacon = OmniLight3D.new()
	pillar_beacon.position = Vector3(0.0, PILLAR_HEIGHT + 2.8, 0.0)
	pillar_beacon.light_color = Color("ffe088")
	pillar_beacon.light_energy = 3.6
	pillar_beacon.omni_range = 42.0
	pillar_beacon.omni_attenuation = 1.4
	pillar_beacon.shadow_enabled = false
	central_pillar.add_child(pillar_beacon)

	# Vertical Sky Beam
	var beam := MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 1.2
	beam_mesh.bottom_radius = 2.4
	beam_mesh.height = PILLAR_HEIGHT + 140.0
	beam_mesh.radial_segments = 16
	beam.mesh = beam_mesh
	beam.position = Vector3(0.0, PILLAR_HEIGHT + 70.0, 0.0)

	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(1.0, 0.88, 0.5, 0.25)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.emission_enabled = true
	beam_mat.emission = Color("ffdd77")
	beam_mat.emission_energy_multiplier = 1.8
	beam.material_override = beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	central_pillar.add_child(beam)

## Legacy compatibility hook; the central shaft remains fixed for the lift.
func set_pillar_time_ratio(ratio: float) -> void:
	# Kept for older callers; the core now stays fixed as the tower lift shaft.
	pass

func _build_perimeter_energy_barrier() -> void:
	# 4 perimeter boundary curb colliders
	var wall_height: float = 12.0
	var wall_thickness: float = 4.0

	var offsets := [
		Vector3(0.0, wall_height * 0.5, ARENA_HALF),
		Vector3(0.0, wall_height * 0.5, -ARENA_HALF),
		Vector3(ARENA_HALF, wall_height * 0.5, 0.0),
		Vector3(-ARENA_HALF, wall_height * 0.5, 0.0)
	]
	var sizes := [
		Vector3(ARENA_SIZE, wall_height, wall_thickness),
		Vector3(ARENA_SIZE, wall_height, wall_thickness),
		Vector3(wall_thickness, wall_height, ARENA_SIZE),
		Vector3(wall_thickness, wall_height, ARENA_SIZE)
	]

	var barrier_mat := StandardMaterial3D.new()
	barrier_mat.albedo_color = Color(0.2, 0.68, 1.0, 0.28)
	barrier_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	barrier_mat.emission_enabled = true
	barrier_mat.emission = Color("38a0ff")
	barrier_mat.emission_energy_multiplier = 1.25
	barrier_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color("70c8ff")
	rim_mat.emission_enabled = true
	rim_mat.emission = Color("70c8ff")
	rim_mat.emission_energy_multiplier = 2.0
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for i in range(4):
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = sizes[i]
		col.shape = shape
		col.position = offsets[i]
		_body.add_child(col)

		var mesh_inst := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = sizes[i]
		mesh_inst.mesh = box_mesh
		mesh_inst.position = offsets[i]
		mesh_inst.material_override = barrier_mat
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_inst)

		# Glowing top rim for clear arena perimeter framing against night sky
		var rim := MeshInstance3D.new()
		var rim_mesh := BoxMesh.new()
		var is_ew := i < 2
		rim_mesh.size = Vector3(ARENA_SIZE if is_ew else 0.5, 0.4, 0.5 if is_ew else ARENA_SIZE)
		rim.mesh = rim_mesh
		rim.position = Vector3(offsets[i].x, wall_height, offsets[i].z)
		rim.material_override = rim_mat
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rim)

func _build_braziers_and_lighting() -> void:
	var brazier_mat := StandardMaterial3D.new()
	brazier_mat.albedo_color = Color("252b36")
	brazier_mat.metallic = 0.5
	brazier_mat.roughness = 0.55

	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color("ff8c3b")
	flame_mat.emission_enabled = true
	flame_mat.emission = Color("ff7a24")
	flame_mat.emission_energy_multiplier = 3.2
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# 16 perimeter braziers along outer ring (r = 125m) with unshaded flames (zero light-calculation cost)
	for i in range(16):
		var angle: float = TAU * float(i) / 16.0
		var pos := Vector3(cos(angle) * 125.0, 0.0, sin(angle) * 125.0)

		var plinth := MeshInstance3D.new()
		var plinth_mesh := CylinderMesh.new()
		plinth_mesh.top_radius = 1.2
		plinth_mesh.bottom_radius = 1.5
		plinth_mesh.height = 3.2
		plinth_mesh.radial_segments = 16
		plinth.mesh = plinth_mesh
		plinth.position = pos + Vector3(0.0, 1.6, 0.0)
		plinth.material_override = brazier_mat
		plinth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(plinth)

		var flame := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.75
		sphere.height = 1.5
		sphere.radial_segments = 12
		sphere.rings = 6
		flame.mesh = sphere
		flame.position = pos + Vector3(0.0, 3.6, 0.0)
		flame.material_override = flame_mat
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame)

	# Mobile-optimized perimeter illumination:
	# 4 wide cardinal fill lights instead of 16 individual overlapping omni lights.
	# Prevents mobile GLES3 / GL Compatibility forward-renderer light limit overflow (< 8 lights per cluster).
	for i in range(4):
		var angle: float = PI * 0.5 * float(i)
		var light_pos := Vector3(cos(angle) * 105.0, 5.0, sin(angle) * 105.0)
		var fill := OmniLight3D.new()
		fill.name = "PerimeterFill%d" % i
		fill.position = light_pos
		fill.light_color = Color("ffa050")
		fill.light_energy = 1.6
		fill.omni_range = 45.0
		fill.omni_attenuation = 1.3
		fill.shadow_enabled = false
		add_child(fill)

func _setup_sky_environment() -> void:
	_create_environment()

	# Clean up redundant old cathedral interior lights from parent arena.gd to conserve mobile light slots
	for light in _court_lights:
		if is_instance_valid(light):
			if light.get_parent() == self:
				remove_child(light)
			light.queue_free()
	_court_lights.clear()

	var old_entry := get_node_or_null("EntryEmberWash")
	if is_instance_valid(old_entry):
		remove_child(old_entry)
		old_entry.queue_free()

	# Optimize Directional Key Light (ClerestoryMoonlight) for mobile performance & crisp contrast
	var moon: DirectionalLight3D = get_node_or_null("ClerestoryMoonlight")
	if is_instance_valid(moon):
		moon.light_color = Color("d8e6f8")
		moon.light_energy = 1.15
		moon.rotation_degrees = Vector3(-52, -35, 0)
		moon.shadow_enabled = true
		moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		moon.directional_shadow_max_distance = 60.0
		moon.directional_shadow_blend_splits = false
		moon.shadow_bias = 0.05
		moon.shadow_normal_bias = 0.8

	# Warm ambient bounce light
	var fill: DirectionalLight3D = get_node_or_null("WarmStoneBounce")
	if is_instance_valid(fill):
		fill.light_color = Color("bf9474")
		fill.light_energy = 0.32
		fill.shadow_enabled = false

	# Atmosphere & sky environment tuned for OLED/LCD mobile screens
	if is_instance_valid(world_environment) and is_instance_valid(world_environment.environment):
		var env := world_environment.environment
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 0.55
		env.ambient_light_color = Color("6b829e")
		env.ambient_light_energy = 0.78
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 1.08
		env.fog_enabled = true
		env.fog_light_color = Color("1a2536")
		env.fog_density = 0.0022
		env.fog_sky_affect = 0.85

		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color("0d1726")
		sky_mat.sky_horizon_color = Color("385072")
		sky_mat.ground_bottom_color = Color("0c121c")
		sky_mat.ground_horizon_color = Color("202c3d")
		sky_mat.sky_curve = 0.16
		sky_mat.sun_angle_max = 2.5

		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.sky = sky

func build_grid() -> void:
	# Flat navigation grid covering 280m x 280m (cell size 3.0m)
	_floor_grid.region = Rect2i(-47, -47, 95, 95)
	_floor_grid.cell_size = Vector2(3.0, 3.0)
	_floor_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_floor_grid.update()

	# Keep pursuit paths out of the open lift shaft. The moving car remains safe
	# for its riders, while floor enemies route around the platform edge.
	for x in range(-2, 3):
		for z in range(-2, 3):
			_floor_grid.set_point_solid(Vector2i(x, z))

func is_walkable(pos: Vector3) -> bool:
	if not get_play_bounds().has_point(Vector2(pos.x, pos.z)):
		return false
	if Vector2(pos.x, pos.z).length() > stage_radius:
		return false
	# The square floor opening surrounds the central shaft and lift platform.
	if absf(pos.x) < 7.2 and absf(pos.z) < 7.2:
		return false
	return true

func nearest_open(pos: Vector3) -> Vector2i:
	var cell := Vector2i(clampi(roundi(pos.x / 3.0), -46, 47), clampi(roundi(pos.z / 3.0), -46, 47))
	if not _floor_grid.is_point_solid(cell):
		return cell
	for radius in range(1, 8):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var candidate := cell + Vector2i(x, z)
				if _floor_grid.is_in_boundsv(candidate) and not _floor_grid.is_point_solid(candidate):
					return candidate
	return cell

func route(from: Vector3, to: Vector3) -> PackedVector2Array:
	var start_cell := nearest_open(from)
	var end_cell := nearest_open(to)
	var cell_path := _floor_grid.get_point_path(start_cell, end_cell)
	if cell_path.size() > 1:
		var result := PackedVector2Array()
		for pt in cell_path:
			result.append(Vector2(pt.x, pt.y))
		return result
	return PackedVector2Array([Vector2(from.x, from.z), Vector2(to.x, to.z)])

# API Compatibility methods for existing systems & tests
func floor_for_position(_pos: Vector3) -> int:
	return LAYOUT.floor_for_position(_pos)

func floor_unlocked(_index: int) -> bool:
	return true

func stair_waypoint(pos: Vector3, _target_floor: int) -> Vector3:
	return pos

func floor_spawn(_floor: int) -> Vector3:
	return LAYOUT.floor_spawn(_floor)

func set_encounter(floor_idx: int, _active: bool = true) -> void:
	active_encounter = floor_idx

func mark_encounter_complete(floor_idx: int) -> void:
	if not cleared_encounters.has(floor_idx):
		cleared_encounters.append(floor_idx)

func set_floor_key_collected(_floor_idx: int, _collected: bool = true) -> void:
	pass

func set_potion_collected(_collected: bool = true) -> void:
	_potion_collected = _collected

func reset_progress() -> void:
	cleared_encounters.clear()
	elevator_active = false
	_elevator_riders.clear()
	if is_instance_valid(elevator_car):
		elevator_car.position.y = 0.0
	if is_instance_valid(elevator_trim_material):
		elevator_trim_material.albedo_color = Color("384353")
		elevator_trim_material.emission = Color("345477")
		elevator_trim_material.emission_energy_multiplier = 0.55
	set_stage(0)

func reveal_portal() -> Node3D:
	return null

func update_floor_visibility(_pos: Vector3) -> void:
	pass

func refresh_echoes(_clues: Array) -> void:
	pass

func _physics_process(_delta: float) -> void:
	pass

func _process(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(pillar_beacon):
		pillar_beacon.light_energy = 3.6 + sin(elapsed * 3.0) * 0.4
