extends Node3D
## A committed cast becomes an elemental damage region, without ground previews.
const ELEMENT_VFX = preload("res://scripts/elemental_vfx.gd")
const ART = preload("res://scripts/visuals.gd")
var game: Node3D
var caster: Node3D
var kind: String = "disk"
var element: String = "fire"
var push_strength: float = 0.0
var pull_strength: float = 0.0
var slow_multiplier: float = 1.0
var slow_seconds: float = 0.0
var color := Color("ff8055")
var radius: float = 3.0
var width: float = 0.8
var length: float = 12.0
var facing: float = 0.0
var warning_time: float = 0.9
var active_time: float = 0.4
var damage: float = 24.0
var jumpable: bool = false
var age: float = 0.0
var active: bool = false
var damage_timer: float = 0.0
var current_radius: float = 0.0
var telegraph_style: String = ""
var warning_visual: Node3D
var session: int = -1
var cast_serial: int = -1

func _ready() -> void:
	add_to_group("combat_hazards")
	session = game.session_id
	cast_serial = caster.attack_serial
	global_position.y = maxf(0.08, global_position.y + 0.08)
	rotation.y = facing
	# The final boss's beam gets a slim ground warning with a dark center and
	# bright edges. Other attacks retain the existing clean, low-cost telegraph.
	match telegraph_style:
		"black_beam":
			build_black_beam_warning()
		"kamehameha":
			build_kamehameha_warning()
		"spirit_bomb":
			build_spirit_bomb_warning()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or game.session_id != session or not is_instance_valid(caster) or caster.is_queued_for_deletion() or caster.dead or not caster.is_in_group("enemies"):
		queue_free()
		return
	if not caster.is_boss and not active and caster.attack_serial != cast_serial:
		queue_free()
		return
	if game.state != "playing":
		if game.state in ["dead", "victory", "world", "menu"]:
			queue_free()
		return
	age += delta
	damage_timer = maxf(0, damage_timer - delta)
	if not active:
		if is_instance_valid(warning_visual):
			var pulse: float = 0.72 + 0.28 * sin(age * 12.0)
			warning_visual.scale.y = pulse
		if age >= warning_time:
			activate()
	else:
		var progress: float = clampf((age - warning_time) / active_time, 0, 1)
		if kind == "wave":
			current_radius = lerpf(0.8, radius, progress)
		var targets: Array[CharacterBody3D] = []
		if is_instance_valid(game.player):
			targets.append(game.player)
		var ally: CharacterBody3D = game.get("ally_bot")
		if is_instance_valid(ally) and not ally.is_down:
			targets.append(ally)

		var hit_anyone := false
		for t in targets:
			if pull_strength > 0 and entity_inside(t) and t.has_method("apply_combat_force"):
				var toward: Vector3 = global_position - t.global_position
				toward.y = 0
				if toward.length() > 0.5:
					t.apply_combat_force(toward.normalized() * pull_strength * delta)
			if damage_timer <= 0 and entity_inside(t):
				hit_anyone = true
				t.receive_damage(damage, global_position)
				if push_strength > 0 and t.has_method("apply_combat_force"):
					var away: Vector3 = t.global_position - global_position
					away.y = 0
					t.apply_combat_force(away.normalized() * push_strength if away.length() > 0.1 else -global_basis.z * push_strength)
				if slow_seconds > 0 and t.has_method("apply_slow"):
					t.apply_slow(slow_multiplier, slow_seconds)
		if damage_timer <= 0 and hit_anyone:
			damage_timer = 0.75
		if age >= warning_time + active_time:
			queue_free()

func activate() -> void:
	active = true
	if is_instance_valid(warning_visual):
		warning_visual.queue_free()
		warning_visual = null
	if telegraph_style == "kamehameha":
		build_kamehameha_beam()
	else:
		var visual := ELEMENT_VFX.new()
		visual.element = element
		visual.mode = kind
		visual.extent = width if kind == "line" else radius
		visual.length = length
		visual.color = color
		visual.duration = active_time
		add_child(visual)
		if kind == "wave":
			visual.scale = Vector3.ONE * 0.04
			var expansion := visual.create_tween()
			expansion.tween_property(visual,"scale",Vector3.ONE,active_time)
	game.sound.play("eruption", -7)

func build_kamehameha_warning() -> void:
	warning_visual = Node3D.new()
	warning_visual.name = "KamehamehaWarning"
	add_child(warning_visual)
	var lane_material := StandardMaterial3D.new()
	lane_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lane_material.albedo_color = Color("103958")
	var edge_material := StandardMaterial3D.new()
	edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_material.albedo_color = Color("70e8ff")
	edge_material.emission_enabled = true
	edge_material.emission = Color("28bfff")
	edge_material.emission_energy_multiplier = 2.4
	for edge in 3:
		var stripe := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width * (1.6 if edge == 0 else 0.16), 0.05, length)
		stripe.mesh = mesh
		stripe.position = Vector3(0.0 if edge == 0 else (-width * 0.82 if edge == 1 else width * 0.82), 0.12 + edge * 0.015, -length * 0.5)
		stripe.material_override = lane_material if edge == 0 else edge_material
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		warning_visual.add_child(stripe)

func build_spirit_bomb_warning() -> void:
	warning_visual = Node3D.new()
	warning_visual.name = "SpiritBombTargetWarning"
	add_child(warning_visual)
	var marker_material := StandardMaterial3D.new()
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.albedo_color = Color(0.24, 0.82, 1.0, 0.76)
	marker_material.emission_enabled = true
	marker_material.emission = Color("36cfff")
	marker_material.emission_energy_multiplier = 2.0
	ART.ring(warning_visual, Vector3(0.0, 0.10, 0.0), radius, 0.34, marker_material)
	ART.ring(warning_visual, Vector3(0.0, 0.12, 0.0), radius * 0.24, 0.20, marker_material)

func build_kamehameha_beam() -> void:
	var beam := Node3D.new()
	beam.name = "KamehamehaBeam"
	for layer in [
		[width * 2.4, 2.2, Color("167bff"), 0.42, 2.2],
		[width * 1.45, 1.35, Color("35cfff"), 0.72, 3.2],
		[width * 0.52, 0.78, Color("efffff"), 0.96, 4.2]
	]:
		var strip := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(float(layer[0]), float(layer[1]), length)
		strip.mesh = mesh
		strip.position = Vector3(0.0, 1.45, -length * 0.5)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var tint: Color = layer[2]
		tint.a = float(layer[3])
		material.albedo_color = tint
		material.emission_enabled = true
		material.emission = layer[2]
		material.emission_energy_multiplier = float(layer[4])
		strip.material_override = material
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.add_child(strip)
	add_child(beam)
	beam.scale.z = 0.16
	var grow := beam.create_tween()
	grow.tween_property(beam, "scale:z", 1.0, 0.14)

func build_black_beam_warning() -> void:
	warning_visual = Node3D.new()
	warning_visual.name = "BlackBeamWarning"
	add_child(warning_visual)
	var dark_material := StandardMaterial3D.new()
	dark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark_material.albedo_color = Color("100d1a")
	var edge_material := StandardMaterial3D.new()
	edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_material.albedo_color = Color("d16cff")
	edge_material.emission_enabled = true
	edge_material.emission = Color("ae4bff")
	edge_material.emission_energy_multiplier = 1.7
	for edge in 3:
		var stripe := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width * (1.25 if edge == 0 else 0.18), 0.035, length)
		stripe.mesh = mesh
		stripe.position = Vector3(0.0 if edge == 0 else (-width * 0.72 if edge == 1 else width * 0.72), 0.10 + edge * 0.012, -length * 0.5)
		stripe.material_override = dark_material if edge == 0 else edge_material
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		warning_visual.add_child(stripe)

func entity_inside(target: CharacterBody3D) -> bool:
	if not is_instance_valid(target):
		return false
	var offset: Vector3 = target.global_position - global_position
	if (jumpable and offset.y > width + 0.25) or absf(offset.y) > 5.0:
		return false
	var flat := Vector2(offset.x, offset.z)
	var inside: bool
	if kind == "line":
		var local: Vector3 = global_basis.inverse() * offset
		inside = absf(local.x) <= width + 0.3 and local.z <= 0.3 and local.z >= -length - 0.3
	elif kind == "wave":
		inside = absf(flat.length() - current_radius) <= width + 0.3
	else:
		inside = flat.length() <= radius + 0.3
	if not inside:
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.7, target.global_position + Vector3.UP * 0.7, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func player_inside() -> bool:
	return entity_inside(game.player)
