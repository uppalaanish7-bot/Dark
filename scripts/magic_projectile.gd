extends Node3D
## Swept rays stop fast firebolts at walls and characters before the next position.
const ART = preload("res://scripts/visuals.gd")
const ELEMENT_VFX = preload("res://scripts/elemental_vfx.gd")
var game: Node3D
var caster: Node3D
var friendly: bool = false
var direction := Vector3.FORWARD
var speed: float = 17.0
var damage: float = 18.0
var color := Color("ff8953")
var lifetime: float = 5.0
var radius: float = 0.17
var element: String = "fire"
var splash: float = 0.0
var session: int = -1

func _ready() -> void:
	add_to_group("magic_projectiles")
	session = game.session_id
	direction = direction.normalized()
	var visual := ELEMENT_VFX.new()
	visual.element = element
	visual.color = color
	visual.radius = radius
	add_child(visual)
	visual.global_basis = Basis.looking_at(direction,Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or game.session_id != session:
		queue_free()
		return
	if not friendly and (not is_instance_valid(caster) or caster.is_queued_for_deletion() or caster.dead or not caster.is_in_group("enemies")):
		queue_free()
		return
	if game.state != "playing":
		if game.state in ["dead", "victory", "world", "menu"]:
			queue_free()
		return
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	var next: Vector3 = global_position + direction * delta * speed
	var exclusions: Array[RID] = []
	if is_instance_valid(caster) and caster is CollisionObject3D:
		exclusions.append(caster.get_rid())
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 5 if friendly else 3, exclusions)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		impact(hit.position, hit.collider)
		return
	global_position = next

func impact(pos: Vector3, target: Object) -> void:
	if friendly:
		if is_instance_valid(target) and target.has_method("take_damage"):
			if target.take_damage(damage, false):
				game.fx.number(pos + Vector3.UP * 0.2, ceili(damage))
				game.register_hit(false)
		if splash > 0:
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.is_in_group("enemies") or enemy == target or enemy.dead or enemy.global_position.distance_to(pos) > splash:
					continue
				var query := PhysicsRayQueryParameters3D.create(pos, enemy.global_position + Vector3.UP, 1)
				if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
					if enemy.take_damage(damage * 0.55):
						game.fx.number(enemy.global_position + Vector3.UP, ceili(damage * 0.55))
	elif is_instance_valid(target) and target.has_method("receive_damage"):
		target.receive_damage(damage, pos)
	if not friendly and splash > 0.0:
		var splash_targets: Array[CharacterBody3D] = []
		if is_instance_valid(game.player):
			splash_targets.append(game.player)
		var ally: CharacterBody3D = game.get("ally_bot")
		if is_instance_valid(ally) and not ally.is_down:
			splash_targets.append(ally)
		for victim in splash_targets:
			if not is_instance_valid(victim) or victim == target or victim.global_position.distance_to(pos) > splash:
				continue
			victim.receive_damage(damage * 0.6, pos)
	game.fx.burst(pos, color, 14)
	var impact_visual := ELEMENT_VFX.new()
	impact_visual.element = element
	impact_visual.mode = "impact"
	impact_visual.extent = 0.65 if friendly else 0.4
	impact_visual.color = color
	impact_visual.duration = 0.5
	game.fx.add_child(impact_visual)
	impact_visual.global_position = pos
	game.sound.play("magic_hit", -7)
	queue_free()
