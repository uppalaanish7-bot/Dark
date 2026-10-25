extends Node3D
## Crossed, animated flame sheets follow the real blade; embers retain world motion.
const FLAME = preload("res://shaders/living_flame.gdshader")
var height: float = 1.65
var width: float = 0.5
var duration: float = 1.3
var age: float = 0.0
var blade: bool = false
var materials: Array[ShaderMaterial] = []
var embers: CPUParticles3D
var glow: OmniLight3D

func _ready() -> void:
	for i in 3:
		var sheet := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(width, height)
		sheet.mesh = quad
		sheet.position.y = height * 0.5
		sheet.rotation.y = i * PI / 3.0
		var mat := ShaderMaterial.new()
		mat.shader = FLAME
		mat.set_shader_parameter("seed", i * 5.7 + randf()*2.0)
		sheet.material_override = mat
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		materials.append(mat)
		add_child(sheet)
	embers = CPUParticles3D.new()
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	embers.amount = 22 if blade else 12
	embers.lifetime = 0.45
	embers.local_coords = false
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(width*0.14, height*0.43, width*0.14)
	embers.position.y = height * 0.5
	embers.direction = Vector3.UP
	embers.spread = 28
	embers.initial_velocity_min = 0.6
	embers.initial_velocity_max = 2.4
	embers.gravity = Vector3(0, 1.0, 0)
	embers.scale_amount_min = 0.013
	embers.scale_amount_max = 0.035
	var spark := SphereMesh.new()
	spark.radial_segments = 4
	spark.rings = 2
	embers.mesh = spark
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color("ff8234")
	embers.material_override = mat
	var ramp := Gradient.new()
	ramp.set_color(0, Color("ffda73"))
	ramp.set_color(1, Color(0.8,0.1,0.01,0))
	embers.color_ramp = ramp
	add_child(embers)
	if blade:
		glow = OmniLight3D.new()
		glow.light_color = Color("ff742c")
		glow.light_energy = 2.0
		glow.omni_range = 4.0
		glow.shadow_enabled = false
		glow.position.y = height * 0.55
		add_child(glow)

func _process(delta: float) -> void:
	age += delta
	var fade: float = 1.0 if duration <= 0 else minf(1.0, maxf(0, (duration-age)/0.3))
	for mat in materials:
		mat.set_shader_parameter("intensity", fade * (0.91+sin(age*21.0)*0.09))
	if is_instance_valid(glow): glow.light_energy = fade * (1.9+sin(age*25.0)*0.3)
	if duration > 0 and age > duration:
		queue_free()
