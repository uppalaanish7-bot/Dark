extends Node3D
const ART = preload("res://scripts/visuals.gd")
const FLAME = preload("res://scripts/flame_effect.gd")
const LIGHTNING = preload("res://scripts/lightning_effect.gd")
const FLAME_SHADER = preload("res://shaders/living_flame.gdshader")
var spark_mesh: SphereMesh

func _init() -> void:
	# Shared immutable geometry avoids rebuilding a mesh for each impact burst.
	spark_mesh = SphereMesh.new()
	spark_mesh.radial_segments = 6
	spark_mesh.rings = 3

func luminous(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = ART.material(color, 0, 2.4)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = alpha
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func tracer(start: Vector3, end: Vector3, color: Color) -> void:
	var distance: float = start.distance_to(end)
	if distance < 0.01:
		return
	var beam: MeshInstance3D = ART.box(self, (start + end) * 0.5, Vector3(0.045, 0.045, distance), luminous(color))
	beam.look_at(end, Vector3.UP if absf((end - start).normalized().y) < 0.99 else Vector3.RIGHT)
	var tween := create_tween()
	tween.tween_property(beam, "scale", Vector3(0.01, 0.01, 1), 0.17)
	tween.tween_callback(beam.queue_free)

func burst(pos: Vector3, color: Color, count: int = 10) -> void:
	var particles := CPUParticles3D.new()
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	particles.global_position = pos
	particles.amount = clampi(count, 3, 50)
	particles.one_shot = true
	particles.explosiveness = 1
	particles.lifetime = 0.52
	particles.direction = Vector3.UP
	particles.spread = 170
	particles.initial_velocity_min = 1.3
	particles.initial_velocity_max = 5.2
	particles.gravity = Vector3(0, -4, 0)
	particles.scale_amount_min = 0.018
	particles.scale_amount_max = 0.075
	var gradient := Gradient.new()
	gradient.set_color(0, color.lightened(0.4))
	gradient.set_color(1, Color(color, 0))
	particles.color_ramp = gradient
	particles.mesh = spark_mesh
	particles.material_override = luminous(color)
	particles.emitting = true
	get_tree().create_timer(0.75, false).timeout.connect(particles.queue_free)

func ring(pos: Vector3, radius: float, color: Color, duration: float = 0.5) -> void:
	var material: StandardMaterial3D = luminous(color, 0.9)
	var visual: MeshInstance3D = ART.ring(self, pos + Vector3.UP * 0.09, radius, 0.04, material)
	visual.scale = Vector3.ONE * 0.12
	var tween := create_tween().set_parallel()
	tween.tween_property(visual, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(visual.queue_free)

func slash(pos: Vector3, facing: float, color: Color, radius: float = 2.5, heavy: bool = false) -> void:
	if color.r > 0.9 and color.g < 0.72 and heavy:
		fire_slash(pos, facing, radius)
		return
	var geometry := ImmediateMesh.new()
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 24
	for i in range(segments):
		var a: float = -1.45 + float(i) / segments * 2.9
		var b: float = -1.45 + float(i + 1) / segments * 2.9
		var inner_a := Vector3(sin(a), 0, -cos(a)) * radius * 0.78
		var outer_a := Vector3(sin(a), 0, -cos(a)) * radius
		var inner_b := Vector3(sin(b), 0, -cos(b)) * radius * 0.78
		var outer_b := Vector3(sin(b), 0, -cos(b)) * radius
		for vertex in [inner_a, outer_a, outer_b, inner_a, outer_b, inner_b]:
			geometry.surface_add_vertex(vertex)
	geometry.surface_end()
	var visual := MeshInstance3D.new()
	visual.mesh = geometry
	var material: StandardMaterial3D = luminous(color, 0.88)
	visual.material_override = material
	add_child(visual)
	visual.global_position = pos
	visual.rotation = Vector3(-0.18 if heavy else 0.13, facing, -0.2 if heavy else 0.15)
	var tween := create_tween().set_parallel()
	tween.tween_property(visual, "rotation:y", facing + 0.32, 0.24)
	tween.tween_property(visual, "scale", Vector3.ONE * 1.15, 0.24)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.28)
	tween.chain().tween_callback(visual.queue_free)

func ignite_blade(weapon: Node3D, duration: float = 1.3) -> void:
	if not is_instance_valid(weapon): return
	var existing := weapon.get_node_or_null("LivingBladeFire")
	if existing != null:
		existing.age = 0
		existing.duration = duration
		return
	var fire := FLAME.new()
	fire.name = "LivingBladeFire"
	fire.height = 1.55
	fire.width = 0.58
	fire.duration = duration
	fire.blade = true
	fire.position.y = 0.12
	weapon.add_child(fire)

func enchant_blade(weapon: Node3D, element: String, duration: float) -> void:
	if not is_instance_valid(weapon): return
	var unwanted := weapon.get_node_or_null("LivingBladeLightning" if element=="fire" else "LivingBladeFire")
	if unwanted != null:
		weapon.remove_child(unwanted)
		unwanted.queue_free()
	if element=="fire":
		var fire := weapon.get_node_or_null("LivingBladeFire")
		if fire != null: fire.duration = fire.age+duration
		else: ignite_blade(weapon,duration)
		return
	var existing := weapon.get_node_or_null("LivingBladeLightning")
	if existing != null:
		existing.duration = existing.age+duration
		return
	var arc := LIGHTNING.new()
	arc.name = "LivingBladeLightning"
	arc.blade = true
	arc.end = Vector3(0,1.48,0)
	arc.position.y = 0.13
	arc.duration = duration
	weapon.add_child(arc)

func lightning_arc(from: Vector3, to: Vector3, duration: float = 0.3) -> void:
	if from.distance_squared_to(to)<0.001: return
	var arc := LIGHTNING.new()
	arc.end = to-from
	arc.duration = duration
	add_child(arc)
	arc.global_position = from

func fire_slash(pos: Vector3, facing: float, radius: float) -> void:
	# A curved wall of flame follows the sword arc; several tongues break its edge.
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos - Vector3.UP * 0.55
	root.rotation.y = facing
	var geometry := ImmediateMesh.new()
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 40:
		var a: float = -1.45 + i / 40.0 * 2.9
		var b: float = -1.45 + (i+1) / 40.0 * 2.9
		var low_a := Vector3(sin(a)*radius, 0, -cos(a)*radius)
		var low_b := Vector3(sin(b)*radius, 0, -cos(b)*radius)
		var high_a := low_a + Vector3.UP * (1.45 + 0.25*sin(a*4))
		var high_b := low_b + Vector3.UP * (1.45 + 0.25*sin(b*4))
		var vertices := [low_a, low_b, high_b, low_a, high_b, high_a]
		var uvs := [Vector2(i/40.0,1), Vector2((i+1)/40.0,1), Vector2((i+1)/40.0,0), Vector2(i/40.0,1), Vector2((i+1)/40.0,0), Vector2(i/40.0,0)]
		for j in 6:
			geometry.surface_set_uv(uvs[j])
			geometry.surface_add_vertex(vertices[j])
	geometry.surface_end()
	var ribbon := MeshInstance3D.new()
	ribbon.mesh = geometry
	var mat := ShaderMaterial.new()
	mat.shader = FLAME_SHADER
	mat.set_shader_parameter("seed", randf()*8.0)
	mat.set_shader_parameter("ribbon", true)
	ribbon.material_override = mat
	root.add_child(ribbon)
	for i in 5:
		var angle: float = -1.25 + i / 4.0 * 2.5
		var fire := FLAME.new()
		fire.height = 0.65 + 0.2 * sin(i * 2.1)
		fire.width = 0.7
		fire.duration = 0.52
		fire.position = Vector3(sin(angle)*radius, 0, -cos(angle)*radius)
		root.add_child(fire)
	root.scale = Vector3.ONE * 0.64
	var tween := create_tween().set_parallel()
	tween.tween_property(root, "scale", Vector3.ONE * 1.06, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "rotation:y", facing + 0.3, 0.45)
	tween.tween_method(func(value: float) -> void: mat.set_shader_parameter("intensity", value), 1.0, 0.0, 0.5)
	tween.chain().tween_callback(root.queue_free)

func pillar(pos: Vector3, color: Color, height: float = 9.0, radius: float = 0.65) -> void:
	if color.r > 0.85 and color.r > color.g:
		for i in 5:
			var fire := FLAME.new()
			fire.height = height * (1.0-absf(i-2)*0.16)
			fire.width = radius * 2.1
			fire.duration = 0.95
			add_child(fire)
			fire.global_position = pos + Vector3((i-2)*radius*0.72,0,sin(i*2)*radius*0.5)
			fire.rotation.z = (i-2)*-0.16
		burst(pos + Vector3.UP,color,40)
		return
	var material: StandardMaterial3D = luminous(color, 0.75)
	var visual: MeshInstance3D = ART.cylinder(self, pos + Vector3.UP * height * 0.5, radius, height, material, false, radius * 0.1)
	var tween := create_tween().set_parallel()
	tween.tween_property(visual, "scale:x", 0.03, 0.55)
	tween.tween_property(visual, "scale:z", 0.03, 0.55)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.6)
	tween.chain().tween_callback(visual.queue_free)
	burst(pos + Vector3.UP * 0.4, color, 18)

func flash(pos: Vector3, color: Color, strength: float = 2.0) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = strength
	light.omni_range = 7
	light.shadow_enabled = false
	add_child(light)
	light.global_position = pos
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.22)
	tween.tween_callback(light.queue_free)

func number(pos: Vector3, amount: int, critical: bool = false) -> void:
	var label := Label3D.new()
	label.text = str(amount) + ("!" if critical else "")
	label.font_size = 48 if critical else 33
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color("ffcf85") if critical else Color("fff2d6")
	label.outline_modulate = Color("15202c")
	add_child(label)
	label.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0, 0)
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", pos.y + 1.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.15)
	tween.chain().tween_callback(label.queue_free)
