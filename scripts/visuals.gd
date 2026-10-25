extends RefCounted
## Small, shared geometry helpers. All arena art is built from native Godot meshes.
static func material(color: Color, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.72
	if glow > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = mat
	parent.add_child(visual)
	visual.position = pos
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		visual.add_child(body)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
	return visual

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, solid: bool = false, top: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 32
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = mat
	parent.add_child(visual)
	visual.position = pos
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		visual.add_child(body)
		var collider := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collider.shape = shape
		body.add_child(collider)
	return visual

static func ring(parent: Node3D, pos: Vector3, radius: float, thickness: float, mat: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 48
	mesh.ring_segments = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	node.position = pos
	return node

static func text3d(parent: Node3D, content: String, pos: Vector3, font_size: int = 72) -> Label3D:
	var label := Label3D.new()
	label.text = content
	label.font_size = font_size
	label.pixel_size = 0.012
	label.modulate = Color("dbdacb")
	label.outline_size = 0
	parent.add_child(label)
	label.position = pos
	return label
