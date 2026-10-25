extends Node3D
## Delayed friendly sky magic; only enemy-group actors ever receive damage.
const ART = preload("res://scripts/visuals.gd")
const FLAME = preload("res://scripts/flame_effect.gd")
var game: Node3D
var caster: Node3D
var element: String = "fire"
var age: float = 0.0
var session: int = -1
var impacted: bool = false
var meteor: Node3D
var warning: Node3D
var strike_positions: Array[Vector3] = []
var _echo: int = 0

func _ready() -> void:
	add_to_group("player_sky_spells")
	session = game.session_id
	var tint := Color("ff8844") if element=="fire" else Color("83daff")
	warning = ART.ring(self,Vector3(0,0.09,0),11.0 if element=="fire" else 4.0,0.055,game.fx.luminous(tint,0.75))
	if element=="fire":
		meteor = Node3D.new()
		add_child(meteor)
		var core := SphereMesh.new()
		core.radius = 1.15
		core.height = 2.3
		core.radial_segments = 9
		core.rings = 5
		var rock := MeshInstance3D.new()
		rock.mesh = core
		rock.material_override = ART.material(Color("412318"),0.25,0.35)
		meteor.add_child(rock)
		for i in 5:
			var fire := FLAME.new()
			fire.height = 4.8 + i*0.35
			fire.width = 1.1
			fire.duration = 0
			fire.position = Vector3(sin(i*TAU/5.0)*0.8,-0.7,cos(i*TAU/5.0)*0.8)
			meteor.add_child(fire)
		meteor.position = Vector3(-9,34,2)
	else:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if valid_target(enemy):
				strike_positions.append(enemy.global_position)
		for point in strike_positions:
			game.fx.ring(point,1.6,tint,0.65)

func valid_target(enemy: Node) -> bool:
	return is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.is_in_group("enemies") and not enemy.dead and enemy.global_position.distance_to(global_position)<85.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or game.session_id!=session or not is_instance_valid(caster):
		queue_free()
		return
	if game.state!="playing":
		if game.state in ["menu","world","dead","victory","construction"]: queue_free()
		return
	age += delta
	if is_instance_valid(meteor):
		var t: float = clampf(age/0.8,0,1)
		meteor.position = Vector3(-9,34,2).lerp(Vector3(0,1.0,0),t*t)
		meteor.rotation += Vector3(1.8,0.5,0.7)*delta
	if not impacted and age>=0.8:
		impact()
	if element=="lightning" and impacted and _echo<2 and age>1.0+_echo*0.19:
		_echo += 1
		for point in strike_positions:
			game.fx.lightning_arc(point+Vector3(randf_range(-2,2),26,randf_range(-2,2)),point+Vector3.UP*0.4,0.2)
	if age>1.65: queue_free()

func impact() -> void:
	if impacted: return
	impacted = true
	if is_instance_valid(meteor): meteor.queue_free()
	if is_instance_valid(warning): warning.queue_free()
	var tint := Color("ff8844") if element=="fire" else Color("83daff")
	if element=="fire":
		game.fx.ring(global_position,11,tint,0.7)
		game.fx.ring(global_position,7,Color("ffdf94"),0.5)
		game.fx.pillar(global_position,tint,15,2.3)
		game.fx.burst(global_position+Vector3.UP*1.2,tint,50)
		game.fx.flash(global_position+Vector3.UP*3,tint,5)
	else:
		strike_positions.clear()
	var accepted: bool = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not valid_target(enemy): continue
		var offset: Vector3 = enemy.global_position-global_position
		if element=="fire" and (Vector2(offset.x,offset.z).length()>11.0 or absf(offset.y)>7): continue
		# Keep walls and the court's own ward meaningful for both power sets.
		var source: Vector3 = global_position+Vector3.UP*1.2 if element=="fire" else caster.global_position+Vector3.UP*1.2
		var query := PhysicsRayQueryParameters3D.create(source,enemy.global_position+Vector3.UP*1.2,1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		var point: Vector3 = enemy.global_position
		if element=="lightning":
			strike_positions.append(point)
			game.fx.lightning_arc(point+Vector3(2,30,-1),point+Vector3.UP*0.3,0.45)
			game.fx.ring(point,2.5,tint,0.45)
			game.fx.burst(point+Vector3.UP,tint,20)
		var amount: float = 320.0 if element=="fire" else 240.0
		if caster.has_method("damage_multiplier"): amount *= caster.damage_multiplier()
		var push_direction := Vector3(enemy.global_position.x-caster.global_position.x,0,enemy.global_position.z-caster.global_position.z).normalized()
		if enemy.take_damage(amount,true,push_direction):
			game.fx.number(point+Vector3.UP*2,ceili(amount),true)
			accepted = true
	if element=="lightning":
		for i in 6:
			var point := global_position+Vector3(sin(i*TAU/6.0)*6,0,cos(i*TAU/6.0)*6)
			game.fx.lightning_arc(point+Vector3(1,27,1),point,0.3)
		game.fx.ring(global_position,14,tint,0.6)
	if accepted: game.register_hit(true)
	# Friendly spells can be cast by the ally, which has no camera of its own.
	if is_instance_valid(game.player):
		game.player.shake = maxf(game.player.shake,0.24)
	game.sound.play("meteor" if element=="fire" else "thunder",-1)
