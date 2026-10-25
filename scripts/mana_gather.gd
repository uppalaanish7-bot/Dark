extends Node3D
## Mana streams converge on the raised blade, following its actual animation.
var caster: Node3D
var color := Color("ffb86b")
var duration: float = 0.84
var age: float = 0.0
var motes: Array[MeshInstance3D] = []
var material: StandardMaterial3D
var halo: MeshInstance3D

func _ready() -> void:
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color.lightened(0.2)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	mesh.radial_segments = 6
	mesh.rings = 3
	for i in 28:
		var mote := MeshInstance3D.new()
		mote.mesh = mesh
		mote.material_override = material
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mote)
		motes.append(mote)
	halo = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.13
	ring.outer_radius = 0.16
	ring.rings = 24
	ring.ring_segments = 6
	halo.mesh = ring
	halo.material_override = material
	add_child(halo)

func _process(delta: float) -> void:
	if not is_instance_valid(caster) or not is_instance_valid(caster.visual) or caster.attack_kind != "ultimate":
		queue_free()
		return
	age += delta
	if age >= duration:
		queue_free()
		return
	var tip: Vector3 = caster.visual.muzzle.global_position
	var origin: Vector3 = caster.global_position + Vector3.UP * 1.25
	var charge := clampf(age / duration, 0, 1)
	for i in motes.size():
		var phase := fposmod(charge * 1.7 + float(i) / motes.size(), 1.0)
		var angle := float(i) * 2.39996 + age * 2.2
		var outward := Vector3(cos(angle) * 1.55, sin(angle * 0.72) * 0.65 + 0.4, sin(angle) * 1.55)
		motes[i].global_position = (origin + outward).lerp(tip, phase * phase)
		motes[i].scale = Vector3.ONE * sin(phase * PI) * lerpf(0.6, 1.4, charge)
	halo.global_transform = caster.visual.weapon.global_transform
	halo.global_position = tip
	halo.rotate_object_local(Vector3.UP, age * 4.0)
	halo.scale *= lerpf(0.65, 1.5, charge)
