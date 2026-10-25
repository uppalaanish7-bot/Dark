extends Node3D
## A branching, flickering arc. Geometry is reused while its jagged path changes.
var end := Vector3(0, 10, 0)
var duration: float = 0.35
var blade: bool = false
var illuminate: bool = true
var age: float = 0.0
var _refresh: float = 0.0
var _mesh := ImmediateMesh.new()
var _material: StandardMaterial3D
var _glow: OmniLight3D

func _ready() -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = _mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color("c5f6ff")
	_material.emission_enabled = true
	_material.emission = Color("79baff")
	_material.emission_energy_multiplier = 3.5
	instance.material_override = _material
	add_child(instance)
	_glow = OmniLight3D.new()
	_glow.light_color = Color("77cfff")
	_glow.light_energy = 2.0
	_glow.omni_range = 3.5 if blade else 5.5
	_glow.position = end*0.5
	_glow.shadow_enabled = false
	_glow.visible = illuminate
	add_child(_glow)
	_rebuild()

func ribbon(a: Vector3, b: Vector3, width: float) -> void:
	var tangent := (b-a).normalized()
	var side := tangent.cross(Vector3.UP if absf(tangent.y)<0.9 else Vector3.RIGHT).normalized()*width
	var normal := tangent.cross(side).normalized()*width
	for offset in [side, normal]:
		for point in [a-offset, a+offset, b+offset, a-offset, b+offset, b-offset]:
			_mesh.surface_add_vertex(point)

func _rebuild() -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var distance: float = end.length()
	var steps: int = clampi(ceili(distance*1.7), 9, 55)
	var tangent := end.normalized()
	var side := tangent.cross(Vector3.UP if absf(tangent.y)<0.9 else Vector3.RIGHT).normalized()
	var crosswise := tangent.cross(side).normalized()
	for strand in (3 if blade else 2):
		var previous := Vector3.ZERO
		for i in range(1, steps+1):
			var t: float = float(i)/steps
			var jitter: float = (0.09 if blade else 0.35)*sin(PI*t)
			var point := end*t + side*randf_range(-jitter,jitter) + crosswise*randf_range(-jitter,jitter)
			ribbon(previous,point,0.012 if blade else (0.035 if strand==0 else 0.018))
			if i%4==0:
				var branch := point + side*randf_range(-1.0,1.0)*(0.25 if blade else 1.2) - tangent*(0.18 if blade else 0.7)
				ribbon(point,branch,0.007 if blade else 0.013)
			previous = point
	_mesh.surface_end()

func _process(delta: float) -> void:
	age += delta
	_refresh -= delta
	if _refresh<=0:
		_refresh = 0.045 if blade else 0.055
		_rebuild()
	var fade: float = minf(1.0,maxf(0,(duration-age)/0.15)) if duration>0 else 1.0
	_material.albedo_color.a = fade*(0.7+0.3*absf(sin(age*63)))
	_glow.light_energy = fade*(1.8+sin(age*49)*0.5)
	if duration>0 and age>=duration: queue_free()
