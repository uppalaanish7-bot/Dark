extends CharacterBody3D
## AI Partner Bot for Dragon Ball Tournament of Power Battle Royale.
## Fights autonomously alongside the player, using melee combos, spells, blade enchantment, and ultimates.

const CHARACTER = preload("res://scripts/character_visual.gd")
const PROJECTILE = preload("res://scripts/magic_projectile.gd")
const SKY_SPELL = preload("res://scripts/player_sky_spell.gd")

const WALK_SPEED: float = 10.5
const RUN_SPEED: float = 14.5
const FIRE_COLOR := Color("ff9355")
const LIGHTNING_COLOR := Color("81deff")
const MELEE_REACH: float = 3.8

var game: Node3D
var visual: Node3D
var bot_skin_index: int = 1
var max_health: float = 350.0
var health: float = 350.0
var is_down: bool = false
var down_timer: float = 0.0
var dead: bool = false

var is_knocked_down: bool:
	get: return is_down
var revive_timer: float:
	get: return down_timer

var current_target: CharacterBody3D = null
var combo_index: int = 0
var combo_window: float = 0.0
var attack_cooldown: float = 0.0
var ranged_timer: float = 3.5
var enchant_timer: float = 12.0
var ultimate_timer: float = 20.0
var enchantment_time: float = 0.0
var roll_cooldown: float = 0.0
var action_lock: float = 0.0

var light: OmniLight3D
var health_label: Label3D
var bot_name: String = "OMEGA KNIGHT"

func _ready() -> void:
	add_to_group("allies")
	collision_layer = 2
	collision_mask = 5
	floor_snap_length = 0.4
	floor_constant_speed = true
	floor_stop_on_slope = true
	safe_margin = 0.02
	max_slides = 6

	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.85
	collider.shape = shape
	collider.position.y = 0.94
	add_child(collider)

	visual = CHARACTER.new()
	visual.name = "Character"
	add_child(visual)
	set_bot_skin(bot_skin_index)

	light = OmniLight3D.new()
	light.light_color = LIGHTNING_COLOR if bot_skin_index == 1 else FIRE_COLOR
	light.light_energy = 1.4
	light.omni_range = 9.0
	light.position = Vector3(0, 1.3, 0)
	add_child(light)

	health_label = Label3D.new()
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.position.y = 2.3
	health_label.font_size = 20
	health_label.pixel_size = 0.007
	health_label.modulate = Color("8bedd6")
	health_label.outline_size = 4
	health_label.outline_modulate = Color("10111d")
	add_child(health_label)
	update_label()

func set_bot_skin(skin_idx: int) -> void:
	bot_skin_index = posmod(skin_idx, 2)
	bot_name = "OMEGA KNIGHT" if bot_skin_index == 1 else "GIRL KNIGHT"
	if is_instance_valid(visual):
		visual.set_skin(bot_skin_index)
		visual.weapon_enabled = true
		if is_instance_valid(visual.weapon):
			visual.weapon.show()
	if is_instance_valid(light):
		light.light_color = LIGHTNING_COLOR if bot_skin_index == 1 else FIRE_COLOR

func element() -> String:
	return "lightning" if bot_skin_index == 1 else "fire"

func element_color() -> Color:
	return LIGHTNING_COLOR if bot_skin_index == 1 else FIRE_COLOR

func receive_damage(damage: float, _source_pos: Vector3 = Vector3.ZERO) -> void:
	if is_down or not is_instance_valid(game) or game.state != "playing":
		return
	health = maxf(0.0, health - damage)
	update_label()
	if is_instance_valid(game.fx):
		game.fx.burst(global_position + Vector3.UP * 1.2, Color("ff9966"), 8)
		game.fx.number(global_position + Vector3.UP * 2.0, ceili(damage))
	if is_instance_valid(game.sound):
		game.sound.play("hit", -8)
	if health <= 0.0:
		knock_down()

func take_damage(amount: float, _critical: bool = false) -> bool:
	if is_down or not is_instance_valid(game) or game.state != "playing":
		return false
	receive_damage(amount)
	return true

func knock_down() -> void:
	is_down = true
	down_timer = 6.0
	velocity = Vector3.ZERO
	if is_instance_valid(visual):
		visual.action("Death01", 6.0)
	if is_instance_valid(game.hud):
		game.hud.announce("ALLY KNOCKED DOWN!", "%s has fallen! Auto-reviving in 6.0s..." % bot_name)
	if is_instance_valid(game.sound):
		game.sound.play("telegraph", -4)
	update_label()

func revive() -> void:
	is_down = false
	health = max_health * 0.65
	if is_instance_valid(visual):
		visual.action("Jump_Land", 0.4)
	if is_instance_valid(game.fx):
		game.fx.burst(global_position + Vector3.UP, element_color(), 25)
		game.fx.ring(global_position, 4.5, element_color(), 0.6)
	if is_instance_valid(game.hud):
		game.hud.announce("ALLY REVIVED!", "%s has returned to the fight!" % bot_name)
	if is_instance_valid(game.sound):
		game.sound.play("pickup", -2)
	update_label()

func update_label() -> void:
	if not is_instance_valid(health_label):
		return
	if is_down:
		health_label.text = "%s\nDOWN (REVIVING %.1fs)" % [bot_name, maxf(0.0, down_timer)]
		health_label.modulate = Color("ff664c")
	else:
		health_label.text = "%s\n%d / %d HP" % [bot_name, ceili(health), ceili(max_health)]
		health_label.modulate = Color("8bedd6") if health > 100 else Color("ff9870")

func tick_ai(delta: float) -> void:
	_physics_process(delta)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or game.state != "playing" or is_queued_for_deletion():
		return

	if is_down:
		down_timer -= delta
		update_label()
		if down_timer <= 0.0:
			revive()
		velocity.y -= 28.0 * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if is_instance_valid(visual):
			visual.tick(delta, 0.0, is_on_floor(), false)
		return

	# Gradual HP recovery
	health = minf(max_health, health + 4.5 * delta)
	update_label()

	# Cooldowns
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	combo_window = maxf(0.0, combo_window - delta)
	ranged_timer = maxf(0.0, ranged_timer - delta)
	enchant_timer = maxf(0.0, enchant_timer - delta)
	ultimate_timer = maxf(0.0, ultimate_timer - delta)
	roll_cooldown = maxf(0.0, roll_cooldown - delta)
	action_lock = maxf(0.0, action_lock - delta)

	if enchantment_time > 0.0:
		enchantment_time = maxf(0.0, enchantment_time - delta)
		if enchantment_time <= 0.0:
			clear_enchant_visual()

	velocity.y -= 28.0 * delta

	# Check hazards for dodge/evasion
	check_hazard_evasion()

	if action_lock > 0.0:
		# Performing committed cast or attack step
		velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)
		move_and_slide()
		var ground_speed := Vector2(velocity.x, velocity.z).length()
		visual.set_motion_state(visual.global_basis.inverse() * velocity, is_on_floor(), velocity.y, 0.0, false, false)
		visual.tick(delta, ground_speed, is_on_floor(), false)
		return

	# Navigation & Target selection
	var player_pos: Vector3 = game.player.global_position if is_instance_valid(game.player) else Vector3.ZERO
	var dist_to_player: float = global_position.distance_to(player_pos)

	var move_target := global_position
	var move_speed := WALK_SPEED

	if dist_to_player > 45.0:
		# Too far from player: sprint back to team
		move_target = player_pos + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
		move_speed = RUN_SPEED
	else:
		current_target = acquire_target()
		if is_instance_valid(current_target) and not current_target.dead:
			var target_pos := current_target.global_position
			var dist_to_target := global_position.distance_to(target_pos)

			# Tactical ability checks
			if ultimate_timer <= 0.0 and count_nearby_enemies(22.0) >= 2:
				cast_ultimate(target_pos)
				return
			elif enchant_timer <= 0.0 and dist_to_target < 15.0:
				cast_blade_enchant()
				return
			elif ranged_timer <= 0.0 and dist_to_target >= 6.0 and dist_to_target <= 32.0:
				cast_ranged_spell(target_pos)
				return
			elif dist_to_target <= MELEE_REACH and attack_cooldown <= 0.0:
				execute_melee_combo(current_target)
				return

			# Movement towards enemy
			move_target = target_pos
			move_speed = RUN_SPEED if dist_to_target > 10.0 else WALK_SPEED
		else:
			# Stay near player
			if dist_to_player > 8.0:
				move_target = player_pos + Vector3(2.5, 0.0, 2.5)
				move_speed = WALK_SPEED

	# Drive movement towards move_target
	var diff := move_target - global_position
	diff.y = 0.0
	var horizontal_dist := diff.length()

	var previous_yaw: float = visual.rotation.y
	if horizontal_dist > 1.2:
		var dir := diff.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		var target_yaw := atan2(-dir.x, -dir.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-10.0 * delta))
	else:
		velocity.x = move_toward(velocity.x, 0.0, 60.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 60.0 * delta)
		if is_instance_valid(current_target) and not current_target.dead:
			var to_enemy := current_target.global_position - global_position
			to_enemy.y = 0.0
			if to_enemy.length_squared() > 0.01:
				visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-to_enemy.x, -to_enemy.z), 1.0 - exp(-12.0 * delta))

	move_and_slide()

	var actual_velocity := get_real_velocity()
	var planar_speed := Vector2(actual_velocity.x, actual_velocity.z).length()
	var turn_speed: float = wrapf(visual.rotation.y - previous_yaw, -PI, PI) / maxf(delta, 0.001)
	visual.set_motion_state(visual.global_basis.inverse() * actual_velocity, is_on_floor(), actual_velocity.y, turn_speed, planar_speed > 12.0, false)
	visual.tick(delta, planar_speed, is_on_floor(), false)

func acquire_target() -> CharacterBody3D:
	var best_candidate: CharacterBody3D = null
	var best_score: float = -9999.0
	var enemies := get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy is CharacterBody3D or enemy.dead:
			continue
		var dist_to_me: float = global_position.distance_to(enemy.global_position)
		if dist_to_me > 65.0:
			continue

		var dist_to_player: float = 50.0
		if is_instance_valid(game.player):
			dist_to_player = game.player.global_position.distance_to(enemy.global_position)

		# Scoring: prioritize bosses and enemies close to player
		var score := 100.0 - dist_to_me
		if enemy.is_boss:
			score += 35.0
		if dist_to_player < 12.0:
			score += 30.0

		if score > best_score:
			best_score = score
			best_candidate = enemy

	return best_candidate

func count_nearby_enemies(radius: float) -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.dead and global_position.distance_to(enemy.global_position) <= radius:
			count += 1
	return count

func check_hazard_evasion() -> void:
	if roll_cooldown > 0.0:
		return
	for hazard in get_tree().get_nodes_in_group("combat_hazards"):
		if not is_instance_valid(hazard) or hazard.active:
			continue
		var dist: float = global_position.distance_to(hazard.global_position)
		if dist < 4.5:
			# Evade away from hazard
			roll_cooldown = 2.4
			action_lock = 0.42
			var away: Vector3 = (global_position - hazard.global_position).normalized()
			away.y = 0.0
			if away.length_squared() < 0.01:
				away = -visual.global_basis.z
			velocity.x = away.x * 12.5
			velocity.z = away.z * 12.5
			visual.rotation.y = atan2(-away.x, -away.z)
			visual.action("Roll", 0.42)
			if is_instance_valid(game.sound):
				game.sound.play("dodge", -6)
			break

func execute_melee_combo(target: CharacterBody3D) -> void:
	combo_index = (combo_index + 1) % 3 if combo_window > 0.0 else 0
	combo_window = 1.0
	var fire_duration: float = [0.32, 0.37, 0.52][combo_index]
	attack_cooldown = fire_duration + 0.08
	action_lock = 0.22

	# Face target
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.01:
		visual.rotation.y = atan2(-to_target.x, -to_target.z)

	var attack_yaw := visual.rotation.y
	visual.action(["Sword_Attack", "Sword_Attack02", "Sword_Attack03"][combo_index], fire_duration)

	# Lunge step
	velocity += -Basis(Vector3.UP, attack_yaw).z * (3.0 if combo_index < 2 else 4.8)

	var enchanted: bool = enchantment_time > 0.0
	var damage: float = [44.0, 56.0, 85.0][combo_index] * (1.8 if enchanted else 1.0)
	var reach: float = (3.6 if combo_index < 2 else 4.2) + (1.0 if enchanted else 0.0)

	# Visual effects
	if is_instance_valid(game.fx):
		game.fx.slash(global_position + Vector3.UP * 1.0, attack_yaw, element_color() if enchanted else Color("fff0c5"), reach - 0.4, enchanted or combo_index == 2)
		if enchanted and element() == "lightning":
			game.fx.lightning_arc(global_position + Vector3.UP, global_position + Vector3.UP - Basis(Vector3.UP, attack_yaw).z * reach, 0.2)
	if is_instance_valid(game.sound):
		game.sound.play("sword", -2 if combo_index == 2 else -5)

	# Arc damage
	var forward: Vector3 = -Basis(Vector3.UP, attack_yaw).z
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.dead or not enemy is CharacterBody3D:
			continue
		var offset: Vector3 = enemy.global_position - global_position
		var flat := Vector3(offset.x, 0.0, offset.z)
		if flat.length() <= reach and absf(offset.y) <= 3.0 and (flat.length() < 0.2 or flat.normalized().dot(forward) > 0.2):
			var push_direction := Vector3(enemy.global_position.x-global_position.x,0,enemy.global_position.z-global_position.z).normalized()
			if enemy.take_damage(damage, combo_index == 2, push_direction):
				if is_instance_valid(game.fx):
					game.fx.number(enemy.global_position + Vector3.UP * enemy.head_height, ceili(damage), combo_index == 2)

func cast_blade_enchant() -> void:
	enchant_timer = 16.0
	enchantment_time = 12.0
	action_lock = 0.35
	visual.action("Power_Up", 0.45)
	if is_instance_valid(game.fx):
		game.fx.enchant_blade(visual.weapon, element(), enchantment_time)
		game.fx.ring(global_position, 2.8, element_color(), 0.5)
	if is_instance_valid(game.sound):
		game.sound.play("lightning" if element() == "lightning" else "fire_slash", -2)

func clear_enchant_visual() -> void:
	if not is_instance_valid(visual) or not is_instance_valid(visual.weapon):
		return
	for effect_name in ["LivingBladeFire", "LivingBladeLightning"]:
		var effect: Node = visual.weapon.get_node_or_null(effect_name)
		if effect != null:
			visual.weapon.remove_child(effect)
			effect.queue_free()

func cast_ranged_spell(target_pos: Vector3) -> void:
	ranged_timer = 3.5
	action_lock = 0.35

	var to_target: Vector3 = target_pos - global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.01:
		visual.rotation.y = atan2(-to_target.x, -to_target.z)

	visual.action("Fire_Cast", 0.42)
	var origin: Vector3 = visual.muzzle.global_position if is_instance_valid(visual.muzzle) else (global_position + Vector3.UP * 1.3)
	var dir := (target_pos + Vector3.UP * 1.0 - origin).normalized()

	if element() == "lightning":
		# Instant arc bolt
		var end := target_pos + Vector3.UP * 1.0
		var query := PhysicsRayQueryParameters3D.create(origin, end, 5, [get_rid()])
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			end = hit.position
			var collider: Object = hit.collider
			if is_instance_valid(collider) and collider.has_method("take_damage"):
				if collider.take_damage(65.0, false):
					if is_instance_valid(game.fx):
						game.fx.number(end + Vector3.UP * 0.3, 65)
		if is_instance_valid(game.fx):
			game.fx.lightning_arc(origin, end, 0.28)
			game.fx.burst(end, LIGHTNING_COLOR, 14)
		if is_instance_valid(game.sound):
			game.sound.play("lightning", -2)
	else:
		# Flying firebolt
		var bolt := PROJECTILE.new()
		bolt.game = game
		bolt.caster = self
		bolt.friendly = true
		bolt.element = "fire"
		bolt.direction = dir
		bolt.damage = 58.0
		bolt.speed = 36.0
		bolt.color = FIRE_COLOR
		bolt.radius = 0.22
		bolt.splash = 1.6
		bolt.position = origin
		game.combatants.add_child(bolt)
		if is_instance_valid(game.sound):
			game.sound.play("fire", -2)

func cast_ultimate(target_pos: Vector3) -> void:
	ultimate_timer = 22.0
	action_lock = 0.65

	var to_target: Vector3 = target_pos - global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.01:
		visual.rotation.y = atan2(-to_target.x, -to_target.z)

	visual.action("Cast_Release", 0.5)

	var spell := SKY_SPELL.new()
	spell.game = game
	spell.caster = self
	spell.element = element()
	spell.position = target_pos if element() == "fire" else global_position
	game.combatants.add_child(spell)

	if is_instance_valid(game.fx):
		game.fx.burst(global_position + Vector3.UP * 1.5, element_color(), 20)
		game.fx.ring(global_position, 5.0, element_color(), 0.7)
	if is_instance_valid(game.sound):
		game.sound.play("lightning" if element() == "lightning" else "fire_slash", 0)
