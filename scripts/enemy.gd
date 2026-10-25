extends CharacterBody3D
const PROVIDED = preload("res://scripts/provided_visual.gd")
const ART = preload("res://scripts/visuals.gd")
const DATA = preload("res://scripts/encounter_data.gd")
const PROJECTILE = preload("res://scripts/magic_projectile.gd")
const HAZARD = preload("res://scripts/combat_hazard.gd")
const ELEMENT_VFX = preload("res://scripts/elemental_vfx.gd")
const LOADOUT = preload("res://scripts/enemy_loadout.gd")
const COMBAT_RADIUS: float = 43.0
const BOSS_DAMAGE_MULTIPLIER: float = 2.25
const BOSS_STRENGTH_MULTIPLIER: float = 10.0
const FINAL_BOSS_STRENGTH_MULTIPLIER: float = 40.0
const BOSS_SIZE_MULTIPLIER: float = 2.5
const MAX_SOLDIER_MAGIC_PROJECTILES: int = 12
var game: Node3D
var encounter_index: int = 0
var is_boss: bool = false
var roaming: bool = false
var summoner_boss: Node3D = null
var summon_timer: float = 14.0
var asset_id: String = "soldier_1"
var element: String = "stone"
var home_position := Vector3.ZERO
var health: float = 100.0
var max_health: float = 100.0
var head_height: float = 1.8
var visual: Node3D
var low_detail_visual: MeshInstance3D
var health_label: Label3D
var health_label_hide_timer: float = 0.0
var marker: MeshInstance3D
var mark_material: StandardMaterial3D
var dead: bool = false
var attack_cooldown: float = 1.0
var attack_windup: float = 0.0
var stunned: float = 0.0
var stagger_resistance: float = 0.0
var spawn_time: float = 1.3
var path_timer: float = 0
var visual_lod_timer: float = 0.0
var visual_lod_delta: float = 0.0
var physics_lod_delta: float = 0.0
var path := PackedVector2Array()
var target_point := Vector3.ZERO
var separation_vector := Vector3.ZERO
var speed: float = 4.0
var body_scale: float = 1.0
var phase: int = 1
var attack_number: int = 0
var attack_serial: int = 0
var pattern_sequence: Array[int] = [0, 1, 2]
var locked_target := Vector3.ZERO
var attack_direction := Vector3.FORWARD
var locked_yaw: float = 0.0
var color := Color("ff9870")
var events: Array[Dictionary] = []
var charge_time: float = 0.0
var charge_speed: float = 0.0
var age: float = 0.0
var glow: OmniLight3D
var hit_flash: float = 0.0
var ward: Node3D
var ward_material: StandardMaterial3D
var ward_pulse: float = 0.0
var recalled_servants: int = 0
var casting_aura: Node3D
var melee_cooldown: float = 0.0
var attack_is_melee: bool = false
var movement_lock: float = 0.0
var melee_step_time: float = 0.0
var animation_contact_time: float = INF
var knockback_velocity := Vector3.ZERO
var flight_altitude: float = 0.0
var active_pattern: String = ""
var kamehameha_charge_visual: Node3D

func _ready() -> void:
	encounter_index = clampi(encounter_index, 0, 10)
	add_to_group("enemies")
	if is_boss:
		add_to_group("bosses")
	collision_layer = 4
	# Soldiers steer apart through the crowd code; physical soldier-to-soldier
	# contacts create quadratic collision work without helping the fight.
	collision_mask = 3
	floor_snap_length = 0.5
	color = DATA.COLORS[encounter_index]
	element = DATA.ELEMENTS[encounter_index]
	flight_altitude = 4.6 if is_boss else 3.4
	if not is_flyer():
		flight_altitude = 0.0
	var strength_multiplier: float = FINAL_BOSS_STRENGTH_MULTIPLIER if encounter_index == 10 else BOSS_STRENGTH_MULTIPLIER
	max_health = DATA.record(encounter_index).health * strength_multiplier if is_boss else 95.0 + encounter_index * 7.0
	health = max_health
	speed = (5.8 + encounter_index * 0.20) if is_boss else (5.2 + encounter_index * 0.12)
	if is_boss and encounter_index == 9:
		speed += 1.3
	elif is_boss and encounter_index == 10:
		speed = 9.0
	body_scale = (1.3 + encounter_index * 0.025) if is_boss else 1.0
	if is_boss and encounter_index >= 9:
		body_scale = 2.05 if encounter_index == 9 else 2.3
	if is_boss:
		body_scale *= BOSS_SIZE_MULTIPLIER
	if is_boss:
		# Shuffle signature moves so players read telegraphs rather than memorize
		# a loop. Nox's expanded set includes the beams and launched void sphere.
		if encounter_index == 10:
			pattern_sequence.append_array([3, 4, 5, 6, 7, 8, 9, 10])
		pattern_sequence.shuffle()
	head_height = 1.65 * body_scale
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.43 * body_scale
	shape.height = 1.9 * body_scale
	collider.shape = shape
	collider.position.y = shape.height * 0.5 + 0.02
	add_child(collider)
	visual = PROVIDED.new()
	visual.asset_id = asset_id
	visual.target_height = 2.1 * body_scale
	add_child(visual)
	if not is_boss:
		var proxy_mesh := CapsuleMesh.new()
		proxy_mesh.radius = 0.46
		proxy_mesh.height = 1.9
		proxy_mesh.radial_segments = 8
		proxy_mesh.rings = 2
		low_detail_visual = MeshInstance3D.new()
		low_detail_visual.name = "DistantSoldierProxy"
		low_detail_visual.mesh = proxy_mesh
		var proxy_material := StandardMaterial3D.new()
		proxy_material.albedo_color = color.darkened(0.22)
		proxy_material.roughness = 0.8
		proxy_material.emission_enabled = true
		proxy_material.emission = color.darkened(0.55)
		proxy_material.emission_energy_multiplier = 0.28
		low_detail_visual.material_override = proxy_material
		low_detail_visual.position.y = 0.98
		low_detail_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		low_detail_visual.hide()
		add_child(low_detail_visual)
	casting_aura = ELEMENT_VFX.new()
	casting_aura.element = element
	casting_aura.color = color
	casting_aura.radius = 0.15*body_scale
	add_child(casting_aura)
	casting_aura.hide()
	health_label = Label3D.new()
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.position.y = 2.3 * body_scale
	health_label.font_size = 25 if is_boss else 19
	health_label.pixel_size = 0.009 if is_boss else 0.006
	health_label.modulate = color.lightened(0.3)
	health_label.outline_size = 5
	health_label.outline_modulate = Color("10111d")
	add_child(health_label)
	update_health_label()
	if not is_boss:
		health_label.hide()
	mark_material = ART.material(color, 0, 0.8)
	mark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mark_material.albedo_color.a = 0.5
	marker = ART.ring(self, Vector3(0, 0.08, 0), 0.6 * body_scale, 0.025, mark_material)
	build_court_ward()
	if is_boss:
		glow = OmniLight3D.new()
		glow.position.y = 2.2
		glow.light_color = color
		glow.light_energy = 1.4
		glow.omni_range = 7
		glow.shadow_enabled = false
		add_child(glow)
	if is_boss and encounter_index == 10:
		spawn_time = 2.2
		game.fx.ring(global_position, 10.0, Color("8f43cd"), 1.15)
		game.fx.pillar(global_position, Color("6d35ad"), 9, 1.0)
		game.player.shake = maxf(game.player.shake, 0.18)
		game.sound.play("boss_phase", -5)
	if is_boss:
		game.fx.burst(global_position + Vector3.UP, color, 18)
		game.fx.ring(global_position, 2, color, 0.75)
	else:
		game.fx.burst(global_position + Vector3.UP, color, 2)
	attack_cooldown = randf_range(1.0, 2.2)
	# Desynchronize opening melee pressure so a nearby squad does not all
	# commit on the same first eligible frame.
	melee_cooldown = randf_range(0.35, 1.65) if not is_boss else randf_range(0.0, 0.8)
	if is_boss:
		var lines: Dictionary = DATA.boss_lines(encounter_index)
		game.hud.announce(DATA.NAMES[encounter_index], lines.engage)
	path_timer = randf_range(0, 0.4)
	visual_lod_timer = randf_range(0, 0.10)
	if not is_boss and is_instance_valid(game.player):
		update_enemy_lod(global_position.distance_squared_to(game.player.global_position))

func get_target() -> CharacterBody3D:
	var player_char: CharacterBody3D = game.player if is_instance_valid(game) else null
	var ally_char: CharacterBody3D = game.get("ally_bot") if is_instance_valid(game) else null
	if is_instance_valid(ally_char) and not ally_char.is_down and not ally_char.is_queued_for_deletion():
		if not is_instance_valid(player_char) or player_char.is_queued_for_deletion() or player_char.health <= 0:
			return ally_char
		var dist_player := global_position.distance_to(player_char.global_position)
		var dist_ally := global_position.distance_to(ally_char.global_position)
		return ally_char if dist_ally < dist_player else player_char
	return player_char

func update_enemy_lod(player_distance_squared: float) -> void:
	if is_boss or not is_instance_valid(low_detail_visual):
		return
	var use_proxy: bool = low_detail_visual.visible
	# Keep the complete soldier skin visible through the whole formation. Only
	# switch to the proxy at the far edge of the arena, with hysteresis to avoid
	# flicker as the player moves near the threshold.
	if use_proxy and player_distance_squared <= 1225.0:
		use_proxy = false
	elif not use_proxy and player_distance_squared >= 2025.0:
		use_proxy = true
	visual.visible = not use_proxy
	low_detail_visual.visible = use_proxy

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or game.state != "playing" or is_queued_for_deletion():
		return
	if dead:
		visual.tick(delta, 0, true)
		return
	# Distant troops use a 30 Hz simulation step. Their motion stays continuous,
	# while close combat and all guardian logic retain the full physics rate.
	var player_distance_squared: float = INF
	if not is_boss and is_instance_valid(game.player):
		player_distance_squared = global_position.distance_squared_to(game.player.global_position)
		update_enemy_lod(player_distance_squared)
	if not is_boss and player_distance_squared > 100.0:
		physics_lod_delta += delta
		if physics_lod_delta < 0.032:
			return
		delta = physics_lod_delta
		physics_lod_delta = 0.0
	elif not is_boss:
		physics_lod_delta = 0.0
	var previous_yaw: float = visual.rotation.y
	age += delta
	spawn_time = maxf(0, spawn_time - delta)
	attack_cooldown = maxf(0, attack_cooldown - delta)
	melee_cooldown = maxf(0, melee_cooldown - delta)
	movement_lock = maxf(0, movement_lock - delta)
	stunned = maxf(0, stunned - delta)
	stagger_resistance = maxf(0, stagger_resistance - delta)
	if not is_boss and health_label.visible:
		health_label_hide_timer -= delta
		if health_label_hide_timer <= 0.0:
			health_label.hide()
	hit_flash = maxf(0, hit_flash - delta)
	ward_pulse = maxf(0, ward_pulse - delta)
	attack_windup = maxf(0, attack_windup - delta)
	if is_flyer():
		var hover_target: float = home_position.y + flight_altitude + sin(age * 2.3) * 0.28
		velocity.y = clampf((hover_target - global_position.y) * 3.2, -5.0, 5.0)
	else:
		velocity.y -= 27 * delta
	velocity.x = 0
	velocity.z = 0
	if stunned > 0 and knockback_velocity.length_squared() > 0.01:
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
	var current_target: CharacterBody3D = get_target()
	if not is_instance_valid(current_target):
		return
	var offset: Vector3 = current_target.global_position - global_position
	var flat := Vector3(offset.x, 0, offset.z)
	var distance: float = flat.length()
	var protected: bool = outside_court()
	ward.visible = protected
	if not protected and is_instance_valid(game.player):
		game.player.clear_court_warning()
	ward.rotation.y += delta * 0.28
	ward.scale = Vector3.ONE * (1.0 + sin(age * 2.5) * 0.025)
	ward_material.albedo_color.a = 0.045 + ward_pulse * 0.3
	if protected:
		events.clear()
		attack_windup = 0
		charge_time = 0
		melee_step_time = 0
		attack_is_melee = false
		if global_position.distance_to(home_position) > 2:
			pursue(home_position, delta)
	elif spawn_time <= 0 and stunned <= 0:
		# Dynamic Retinue Summoning for Living Bosses
		if is_boss and not dead:
			summon_timer -= delta
			if summon_timer <= 0.0:
				summon_timer = 14.0
				var active_retinue: int = 0
				for enemy in get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(enemy) and not enemy.dead and enemy.get("summoner_boss") == self:
						active_retinue += 1
				if active_retinue < 3:
					var to_spawn: int = mini(randi_range(1, 2), 3 - active_retinue)
					for i in range(to_spawn):
						var spawn_angle: float = randf() * TAU
						var spawn_dist: float = randf_range(4.0, 8.0)
						var spawn_pos: Vector3 = global_position + Vector3(cos(spawn_angle) * spawn_dist, 0.0, sin(spawn_angle) * spawn_dist)
						if is_instance_valid(game) and game.has_method("spawn_soldier_for_boss"):
							game.spawn_soldier_for_boss(self, spawn_pos)
		process_events(delta)
		if charge_time > 0:
			charge_time = maxf(0, charge_time - delta)
			velocity.x = attack_direction.x * charge_speed
			velocity.z = attack_direction.z * charge_speed
		elif attack_is_melee and attack_windup > 0:
			# A short planted step carries the blow forward; the committed attack
			# direction never tracks a dodge after the animation has begun.
			if melee_step_time > 0:
				melee_step_time = maxf(0, melee_step_time - delta)
				velocity.x = attack_direction.x * 1.3
				velocity.z = attack_direction.z * 1.3
		elif attack_windup <= 0:
			attack_is_melee = false
			if distance > 0.01:
				visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-flat.x, -flat.z), 1 - exp(-8 * delta))
			var attack_range: float = boss_range() if is_boss else (15.0 if ranged_soldier() else 2.8)
			if not is_flyer() and distance <= melee_reach() and absf(offset.y) < 1.2 and melee_cooldown <= 0 and line_of_sight(current_target):
				begin_melee(current_target)
			elif magic_enabled() and distance < attack_range and absf(offset.y) < 5.0 and attack_cooldown <= 0 and line_of_sight(current_target):
				begin_attack(current_target)
			elif magic_enabled() and not is_boss and distance < 4.0 and distance > melee_reach() * 0.82:
				# Ranged troops give ground instead of mindlessly closing while
				# their spell is cooling down. The player can still corner them.
				var retreat := -flat.normalized()
				velocity.x = retreat.x * speed * 0.72
				velocity.z = retreat.z * speed * 0.72
			elif is_flyer() and distance < 9.0:
				var retreat := -flat.normalized()
				velocity.x = retreat.x * speed * 0.75
				velocity.z = retreat.z * speed * 0.75
			elif is_flyer() and distance <= 14.0:
				var orbit := Vector3(-flat.z, 0.0, flat.x).normalized()
				var side: float = -1.0 if posmod(int(age * 0.25) + encounter_index, 2) == 0 else 1.0
				velocity.x = orbit.x * speed * 0.48 * side
				velocity.z = orbit.z * speed * 0.48 * side
			elif is_boss and encounter_index == 10 and distance < 18.0:
				var orbit := Vector3(-flat.z, 0.0, flat.x).normalized()
				var side: float = -1.0 if posmod(int(age * 0.5), 2) == 0 else 1.0
				var radial: Vector3 = flat.normalized() * (0.4 if distance > 13.0 else -0.15)
				var strafe: Vector3 = (orbit * side * 0.86 + radial).normalized()
				velocity.x = strafe.x * speed * 0.84
				velocity.z = strafe.z * speed * 0.84
			elif distance > melee_reach() * 0.82:
				pursue(current_target.global_position, delta)
		elif movement_lock <= 0 and distance > melee_reach() * 1.15:
			pursue(current_target.global_position, delta, 0.72)
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 18.0 * delta)
	var casting: bool = attack_windup > 0 and not attack_is_melee
	var actual_velocity: Vector3 = get_real_velocity()
	var turn_speed: float = wrapf(visual.rotation.y - previous_yaw, -PI, PI) / maxf(delta, 0.001)
	visual.combat_phase = phase
	visual.set_motion_state(visual.global_basis.inverse() * actual_velocity, is_on_floor(), actual_velocity.y, turn_speed, false, casting)
	visual_lod_delta += delta
	visual_lod_timer -= delta
	var is_near_player: bool = is_boss or player_distance_squared < 64.0
	if visual.visible and (is_near_player or visual_lod_timer <= 0.0):
		var visual_speed: float = Vector2(actual_velocity.x, actual_velocity.z).length()
		visual.tick(visual_lod_delta, visual_speed, is_on_floor(), casting)
		visual_lod_delta = 0.0
		visual_lod_timer = 0.0 if is_near_player else 0.09 + randf_range(0.0, 0.035)
	elif not visual.visible:
		visual_lod_delta = 0.0
		visual_lod_timer = 0.09
	casting_aura.visible = casting and stunned <= 0 and not protected and visual.visible and active_pattern not in ["kamehameha", "spirit_bomb"]
	var final_charge_active: bool = active_pattern in ["kamehameha", "spirit_bomb"] and attack_windup > 0.0 and not protected
	if final_charge_active:
		if not is_instance_valid(kamehameha_charge_visual):
			start_final_charge_visual(active_pattern == "spirit_bomb")
		if active_pattern == "spirit_bomb":
			kamehameha_charge_visual.global_position = global_position + Vector3.UP * (head_height + 2.0 + sin(age * 2.0) * 0.12)
		else:
			kamehameha_charge_visual.global_position = visual.casting_position()
		var charge_pulse: float = 1.0 + sin(age * 10.0) * (0.08 + 0.05 * phase)
		kamehameha_charge_visual.scale = Vector3.ONE * charge_pulse
	elif is_instance_valid(kamehameha_charge_visual):
		kamehameha_charge_visual.queue_free()
		kamehameha_charge_visual = null
	if casting_aura.visible:
		casting_aura.global_position = visual.casting_position()
		var charge_scale: float = 1.0 if active_pattern != "dark_sphere" else 1.5
		casting_aura.scale = Vector3.ONE * charge_scale * (0.8 + sin(age * 14.0) * 0.16)
		casting_aura.rotation.y += delta*3.0
	marker.scale = Vector3.ONE * (1.0 + (sin(age * 15) * 0.12 if attack_windup > 0 else 0.02))
	marker.visible = attack_windup > 0.0 and stunned <= 0.0
	mark_material.emission_energy_multiplier = 2.3 if attack_windup > 0 else 0.7
	if is_instance_valid(glow):
		glow.light_energy = 1.4 + (2.0 if hit_flash > 0 else 0.0)
	if global_position.y < home_position.y - 8:
		global_position = home_position + Vector3.UP
		velocity = Vector3.ZERO

func boss_range() -> float:
	if encounter_index in [0, 4, 5, 7]:
		return 11.5
	return 20.0 if encounter_index >= 8 else 17.0

func ranged_soldier() -> bool:
	return magic_enabled()

func is_flyer() -> bool:
	# The supplied models with visible, articulated wings are soldier_9,
	# subboss_9 and grand_boss. The robe casters and final reaper stay grounded.
	return asset_id in ["soldier_9", "subboss_9", "grand_boss"]

func magic_enabled() -> bool:
	return encounter_index >= 2

func melee_weapon() -> bool:
	return LOADOUT.profile(asset_id).kind != "fists"

func melee_reach() -> float:
	var kind: String = LOADOUT.profile(asset_id).kind
	var reach: float = 1.30
	if kind == "fists": reach = 0.90
	elif kind == "rifle": reach = 1.05
	elif kind in ["staff", "scythe"]: reach = 1.60
	return reach * body_scale + 0.65

func begin_melee(target: CharacterBody3D = null) -> void:
	if dead or outside_court() or stunned > 0 or attack_windup > 0:
		return
	if target == null:
		target = get_target()
	attack_serial += 1
	attack_is_melee = true
	locked_target = target.global_position if is_instance_valid(target) else (game.player.global_position if is_instance_valid(game.player) else global_position)
	attack_direction = locked_target - global_position
	attack_direction.y = 0
	attack_direction = attack_direction.normalized() if attack_direction.length_squared() > 0.0025 else -visual.global_basis.z
	locked_yaw = atan2(-attack_direction.x, -attack_direction.z)
	visual.rotation.y = locked_yaw
	var armed: bool = melee_weapon()
	var held: String = LOADOUT.profile(asset_id).kind
	attack_windup = (1.10 if held in ["axe", "scythe"] else (0.92 if armed else 0.76)) + (0.12 if is_boss else 0.0)
	melee_cooldown = attack_windup + (0.32 if is_boss else 0.52)
	melee_step_time = 0.0
	movement_lock = attack_windup
	events.clear()
	var damage: float = (19.0 + encounter_index * 0.8) if is_boss else (11.0 + encounter_index * 0.6)
	var cue: String = LOADOUT.melee_cue(asset_id, attack_serial - 1)
	visual.action(cue, attack_windup)
	schedule("melee_step", attack_windup * 0.28)
	schedule("melee", attack_windup * 0.42, {"damage": damage, "armed": armed})

func resolve_melee(damage: float, armed: bool) -> void:
	if dead or stunned > 0 or outside_court() or game.state != "playing":
		return
	if armed and LOADOUT.profile(asset_id).kind != "rifle":
		game.fx.slash(global_position + Vector3.UP * minf(1.25 * body_scale, 1.6), locked_yaw, Color("dce2e9"), melee_reach() * 0.72, false)
		game.sound.play("sword", -10)
	var targets: Array[CharacterBody3D] = []
	if is_instance_valid(game.player):
		targets.append(game.player)
	var ally: CharacterBody3D = game.get("ally_bot")
	if is_instance_valid(ally) and not ally.is_down:
		targets.append(ally)
	for t in targets:
		var offset: Vector3 = t.global_position - global_position
		var flat := Vector3(offset.x, 0, offset.z)
		if absf(offset.y) > 1.4 or flat.length() > melee_reach():
			continue
		if flat.length() > 0.05 and attack_direction.dot(flat.normalized()) < (0.35 if armed else 0.60):
			continue
		if not line_of_sight(t):
			continue
		if t.has_method("receive_damage"):
			t.receive_damage(boss_attack_damage(damage), global_position)

func pursue(destination: Vector3, delta: float, pace: float = 1.0) -> void:
	path_timer -= delta
	if path_timer <= 0:
		# Retinue path searches cost more than direct movement. Refresh soldiers
		# about half as often while keeping the guardian's tighter pursuit cadence.
		path_timer = (0.36 if is_boss else 0.56) + randf() * 0.12
		path = game.arena.route(global_position, destination)
		# Separation only changes meaningfully at the same cadence as pathing.
		# Scanning the whole group each physics tick made crowd movement O(N²)
		# at 60 Hz, although route waypoints refresh only ~2.5 times per second.
		separation_vector = Vector3.ZERO
		if not is_boss:
			for other in get_tree().get_nodes_in_group("enemies"):
				if other == self or other.dead:
					continue
				var away: Vector3 = global_position - other.global_position
				away.y = 0
				var distance_squared := away.length_squared()
				if distance_squared < 1.65 * 1.65 and distance_squared > 0.05 * 0.05:
					separation_vector += away / sqrt(distance_squared) * 0.65
	if path.size() > 1:
		var next: Vector2 = path[1]
		target_point = Vector3(next.x, global_position.y, next.y)
		if global_position.distance_to(target_point) < 0.8:
			path.remove_at(0)
	else:
		target_point = destination
	var direction: Vector3 = target_point - global_position
	direction.y = 0
	var remaining_distance: float = Vector2(destination.x - global_position.x, destination.z - global_position.z).length()
	if remaining_distance < 0.15:
		return
	direction = direction.normalized()
	if not is_boss:
		direction += separation_vector
		direction = direction.normalized()
	var chase_speed: float = speed * pace * (1.38 if remaining_distance > 9.0 else 1.0)
	velocity.x = direction.x * chase_speed
	velocity.z = direction.z * chase_speed
	if direction.length_squared() > 0.01 and attack_windup <= 0:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-11.0 * delta))

func line_of_sight(target: CharacterBody3D = null) -> bool:
	if target == null:
		target = get_target()
	if not is_instance_valid(target):
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.4, target.global_position + Vector3.UP, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func outside_court() -> bool:
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		return false
	var player_position: Vector3 = game.player.global_position
	if absf(player_position.y - home_position.y) > 6.0:
		return true
	return not roaming and Vector2(player_position.x - home_position.x, player_position.z - home_position.z).length() > COMBAT_RADIUS

func build_court_ward() -> void:
	ward = Node3D.new()
	ward.name = "CourtWard"
	add_child(ward)
	ward.position.y = 1.25 * body_scale
	ward_material = ART.material(color.lightened(0.45), 0.0, 1.2)
	ward_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ward_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ward_material.albedo_color.a = 0.045
	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.1 * body_scale
	sphere.height = 2.6 * body_scale
	sphere.radial_segments = 24
	sphere.rings = 12
	shell.mesh = sphere
	shell.material_override = ward_material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ward.add_child(shell)
	var rune_material: StandardMaterial3D = game.fx.luminous(color.lightened(0.4), 0.42)
	for axis in range(3):
		var ring: MeshInstance3D = ART.ring(ward, Vector3.ZERO, 1.3 * body_scale, 0.014 * body_scale, rune_material)
		if axis == 0: ring.rotation.x = PI * 0.5
		if axis == 1: ring.rotation.z = PI * 0.5
	ward.visible = outside_court()

func ward_hit() -> void:
	ward.show()
	if ward_pulse <= 0:
		ward_pulse = 0.45
		game.fx.ring(global_position, body_scale * 1.6, color.lightened(0.5), 0.4)
		game.sound.play("telegraph", -8)
	game.player.show_court_warning()

func begin_attack(target: CharacterBody3D = null) -> void:
	if not magic_enabled():
		begin_melee(target)
		return
	if target == null:
		target = get_target()
	attack_serial += 1
	attack_is_melee = false
	melee_step_time = 0
	movement_lock = (0.72 if encounter_index == 10 else 1.15) if is_boss else 0.85
	locked_target = target.global_position if is_instance_valid(target) else (game.player.global_position if is_instance_valid(game.player) else global_position)
	locked_target.y = home_position.y
	attack_direction = locked_target - global_position
	attack_direction.y = 0
	attack_direction = attack_direction.normalized() if attack_direction.length() > 0.05 else Vector3.FORWARD
	locked_yaw = atan2(-attack_direction.x, -attack_direction.z)
	visual.rotation.y = locked_yaw
	attack_number += 1
	animation_contact_time = INF
	events.clear()
	if not is_boss:
		soldier_attack()
		return
	var patterns: Array = [
		["stone_wave", "charge", "cleave"],
		["tidal_surge", "undertow", "water_geysers"],
		["ember_rain", "fire_breath", "ember_rain"],
		["soul_wells", "soul_recall", "soul_spiral"],
		["lightning", "storm_cross", "charge"],
		["wind_cyclone", "gust_axes", "wind_cross"],
		["blight", "plague_fan", "blight_wave"],
		["frost_step", "ice_lattice", "glacial_nova"],
		["singularity", "star_spiral", "event_horizon"],
		["molten_fault", "lava_eruption", "molten_charge"],
		["eclipse", "reaping", "apocalypse", "black_beam", "dark_sphere", "storm_lance", "ember_burst", "frost_lattice", "gale_shear", "kamehameha", "spirit_bomb"]
	]
	var sequence_index: int = pattern_sequence[(attack_number - 1) % pattern_sequence.size()]
	var pattern: String = patterns[encounter_index][sequence_index]
	active_pattern = pattern
	attack_windup = maxf(1.72, 2.25 - float(mini(encounter_index, 8)) * 0.065)
	attack_cooldown = maxf(1.55, 3.25 - float(mini(encounter_index, 8)) * 0.105) * 0.72 if phase == 1 else maxf(1.4, 2.75 - float(mini(encounter_index, 8)) * 0.09) * 0.72
	if encounter_index == 10:
		attack_cooldown = [2.2, 1.85, 1.55][clampi(phase - 1, 0, 2)]
	elif encounter_index == 9:
		attack_cooldown = 1.95 if phase == 1 else 1.65
		attack_windup = 1.5
	match pattern:
		"stone_wave":
			wave_at(global_position, 17, 0.85, 29)
			if phase > 1: wave_at(global_position, 17, 1.55, 29)
		"charge":
			charge_attack(0.95, 29 if encounter_index < 5 else 37)
		"cleave":
			cleave_at(global_position, locked_yaw, 0.75, 5, 28)
		"tidal_surge":
			wave_at(global_position, 20, 0.95, 25)
			line_at(locked_target + Vector3(6, 0, 10), 0.0, 20, 1.6, 1.5, 22)
			if phase > 1: wave_at(global_position, 20, 1.7, 25)
		"undertow":
			field_at(locked_target, 6.5, 0.95, 2.4, 6, 8.0)
			var geyser: Node3D = hazard("disk", locked_target, 2.6, 2.1, 0.4, 30)
			game.combatants.add_child(geyser)
			attack_windup = 2.7
			attack_cooldown = 3.8
		"water_geysers":
			meteor_cluster(locked_target, 4 + phase, 2.5, 0.95, 26)
		"ember_rain":
			meteor_cluster(locked_target, 3 + phase, 3.1, 1.0, 27)
		"fire_breath":
			for i in range(3):
				schedule("fan", 0.85 + i * 0.23, {"count": 7, "spread": 0.14, "speed": 14.0 + i, "damage": 19.0})
		"soul_wells":
			pools_at(locked_target, 3, 3.5, 1.05, 11)
			schedule("fan", 1.15, {"count": 3, "spread": 0.3, "speed": 12.0, "damage": 22.0})
		"soul_spiral":
			schedule("radial", 0.9, {"count": 12, "speed": 11.5, "offset": 0.0, "damage": 20.0})
			schedule("radial", 1.45, {"count": 12, "speed": 12.0, "offset": 0.15, "damage": 20.0})
		"soul_recall":
			pools_at(global_position, 1, 5.0, 0.95, 9)
			if recalled_servants < 2:
				schedule("recall", 1.2)
			else:
				schedule("radial", 1.0, {"count": 10, "speed": 12.0, "offset": age, "damage": 20.0})
		"lightning":
			for i in range(3 + phase):
				var origin: Vector3 = locked_target + Vector3((i - 2) * 3.5, 0, 10)
				line_at(origin, 0.0, 20, 0.65, 0.8 + i * 0.16, 27)
		"storm_cross":
			cross_at(locked_target, 0.0, 10, 1.0, 30)
			meteor_cluster(locked_target, 2, 2.5, 1.8, 26)
		"wind_cyclone":
			field_at(global_position, 10.0, 0.8, 1.35, 5, 11.0)
			wave_at(global_position, 20, 1.9, 29)
			attack_windup = 3.0
			attack_cooldown = 3.9
		"gust_axes":
			for angle in [-0.35, 0.35]:
				line_at(global_position, locked_yaw + angle, 24, 1.2, 0.9, 28)
			cleave_at(global_position, locked_yaw, 1.4, 6.5, 34)
		"wind_cross":
			cross_at(locked_target, locked_yaw + PI * 0.25, 14, 1.0, 27)
			if phase > 1: wave_at(global_position, 18, 1.6, 25)
		"blight":
			pools_at(locked_target, 3 + phase, 3.0, 1.1, 12)
		"plague_fan":
			schedule("fan", 0.85, {"count": 7, "spread": 0.19, "speed": 12.0, "damage": 20.0})
			pools_at(locked_target, 1, 3, 1.5, 10)
		"blight_wave":
			wave_at(global_position, 19, 0.9, 29)
			pools_at(locked_target, 2, 2.5, 1.3, 10)
		"frost_step":
			shadow_attack()
		"ice_lattice":
			for lane in [-2, 0, 2]:
				line_at(locked_target + Vector3(lane * 3, 0, 10), 0, 20, 0.8, 1.0, 25)
			line_at(locked_target + Vector3(-10, 0, 4), -PI * 0.5, 20, 0.6, 1.6, 23)
		"glacial_nova":
			wave_at(global_position, 20, 0.95, 29)
			meteor_cluster(locked_target, 3 + phase, 2.4, 1.3, 26)
		"star_spiral":
			for i in range(2 + phase):
				schedule("radial", 0.85 + i * 0.4, {"count": 14, "speed": 13.0, "offset": i * 0.14, "damage": 22.0})
		"singularity":
			field_at(locked_target, 8.0, 0.9, 2.7, 8, 13.0)
			var starfall: Node3D = hazard("disk", locked_target, 2.8, 2.5, 0.4, 36)
			game.combatants.add_child(starfall)
			attack_windup = 3.0
			attack_cooldown = 4.0
		"event_horizon":
			field_at(global_position, 10.0, 0.95, 2.0, 7, 10.0)
			schedule("radial", 1.5, {"count": 14, "speed": 13.0, "offset": age, "damage": 24.0})
			meteor_cluster(locked_target, 3, 2.5, 1.8, 29)
		"molten_fault":
			for angle in [-0.38, 0.0, 0.38]:
				line_at(global_position, locked_yaw + angle, 23, 1.1, 1.1, 32)
			pools_at(locked_target, 3 + phase, 3.0, 1.45, 17)
			attack_windup = 2.8
			attack_cooldown = 3.8
		"lava_eruption":
			meteor_cluster(locked_target, 4 + phase, 3.2, 1.05, 34)
			pools_at(locked_target, 2, 3.5, 1.7, 15)
		"molten_charge":
			charge_attack(1.05, 40)
			for i in range(4):
				var lava: Node3D = hazard("pool", global_position + attack_direction * i * 3.5, 2.5, 1.3 + i * 0.12, 5.5, 16)
				game.combatants.add_child(lava)
		"eclipse":
			for i in range(1 + phase):
				wave_at(global_position, 24, 1.0 + i * 0.7, 33)
			attack_windup = 3.0
			attack_cooldown = 4.0
		"reaping":
			charge_attack(1.0, 42)
			cross_at(locked_target, locked_yaw + PI * 0.25, 11, 1.8, 34)
			if phase > 1:
				line_at(locked_target + attack_direction * 12, locked_yaw + PI, 24, 1.1, 2.4, 32)
		"apocalypse":
			meteor_cluster(locked_target, 5 + phase, 3.2, 1.0, 33)
			for i in range(phase):
				schedule("radial", 1.35 + i * 0.45, {"count": 16, "speed": 13.0, "offset": i * 0.13, "damage": 23.0})
			attack_windup = 3.0
			attack_cooldown = 4.0
		"black_beam":
			line_at(global_position + Vector3.UP * 1.4, locked_yaw, 32, 1.05, 1.35, 38 + phase * 3, "void", "black_beam")
			attack_windup = 2.1
			attack_cooldown = 4.1
		"dark_sphere":
			attack_windup = 1.65
			attack_cooldown = 3.7
			animation_contact_time = 1.05
			schedule("dark_sphere", 1.05, {"damage": 39 + phase * 3})
		"storm_lance":
			attack_windup = 1.55
			attack_cooldown = 3.3
			line_at(global_position + Vector3.UP * 1.4, locked_yaw, 30, 0.82, 1.25, 24 + phase, "lightning")
			if phase >= 3:
				line_at(locked_target + attack_direction * 7.0, locked_yaw, 23, 0.7, 1.65, 18, "lightning")
		"ember_burst":
			attack_windup = 1.45
			attack_cooldown = 3.1
			schedule("fan", 0.95, {"count": 5 if phase >= 2 else 3, "spread": 0.14, "speed": 17.5, "damage": 20.0 + phase, "element": "fire", "color": Color("ff703d")})
		"frost_lattice":
			attack_windup = 1.65
			attack_cooldown = 3.4
			for lane in [-1, 0, 1]:
				line_at(locked_target + Vector3(lane * 3.5, 0, 10), 0.0, 21, 0.75, 1.25 + absf(lane) * 0.18, 21, "ice")
		"gale_shear":
			attack_windup = 1.55
			attack_cooldown = 3.2
			cross_at(locked_target, locked_yaw + PI * 0.25, 12, 1.3, 23 + phase, "wind")
		"kamehameha":
			attack_windup = 2.1
			attack_cooldown = 5.2
			movement_lock = 3.15
			start_final_charge_visual(false)
			line_at(global_position, locked_yaw, 48.0, 2.0, 1.85, 64.0 + phase * 8.0, "water", "kamehameha", 1.25)
			schedule("kamehameha_lunge", 3.15, {"duration": 0.5})
		"spirit_bomb":
			attack_windup = 2.45
			attack_cooldown = 6.3
			movement_lock = 3.25
			start_final_charge_visual(true)
			var target_warning: Node3D = hazard("disk", locked_target, 8.5, 3.8, 0.08, 0.0, "water")
			target_warning.telegraph_style = "spirit_bomb"
			game.combatants.add_child(target_warning)
			schedule("spirit_bomb", 2.4, {})
			schedule("spirit_bomb_lunge", 3.25, {"duration": 0.55})
	# Match the visible release to this pattern's first real threat. Telegraphs
	# vary by court; a fixed two-second clip made several attacks land mid-windup.
	var action_cue: String = LOADOUT.attack_cue(asset_id, DATA.ANIMATION_CUES[encounter_index])
	if encounter_index == 10:
		var final_cues: Dictionary = {"eclipse": "Eclipse_Wave", "reaping": "Void_Reap", "apocalypse": "Apocalypse", "black_beam": "Black_Beam", "dark_sphere": "Dark_Sphere", "storm_lance": "Storm_Lance", "ember_burst": "Ember_Burst", "frost_lattice": "Frost_Lattice", "gale_shear": "Gale_Shear", "kamehameha": "Kamehameha", "spirit_bomb": "Spirit_Bomb"}
		action_cue = str(final_cues.get(pattern, "Void_Reap"))
	if pattern == "kamehameha":
		visual.action(action_cue, 3.15)
	elif pattern == "spirit_bomb":
		visual.action(action_cue, 3.25)
	else:
		visual.action(action_cue, animation_contact_time / 0.42 if is_finite(animation_contact_time) else 2.0)
	game.fx.burst(global_position + Vector3.UP * head_height, color, 7)
	game.sound.play("charge", -12)

func soldier_attack() -> void:
	if not magic_enabled():
		begin_melee()
		return
	attack_windup = 1.55
	attack_cooldown = randf_range(2.5, 3.7)
	match encounter_index:
		5:
			line_at(global_position, locked_yaw, 18, 1.2, 0.8, 16)
		7:
			schedule("fan", 0.85, {"count": 3, "spread": 0.18, "speed": 14.0, "damage": 16.0})
		1:
			line_at(global_position, locked_yaw, 15, 0.65, 0.85, 14)
		2, 3:
			schedule("fan", 0.8, {"count": 1 if encounter_index != 2 else 3, "spread": 0.2, "speed": 13.0, "damage": 13.0})
		4:
			line_at(global_position, locked_yaw, 15, 0.45, 0.95, 16)
		6:
			pools_at(locked_target, 1, 2.1, 1.1, 8)
		8:
			field_at(locked_target, 2.8, 1.1, 1.2, 7, 5.0)
		9:
			pools_at(locked_target, 1, 2.5, 1.2, 9)
		10:
			schedule("fan", 0.9, {"count": 3, "spread": 0.24, "speed": 13.5, "damage": 15.0})
			attack_cooldown += 0.4
	visual.action(LOADOUT.attack_cue(asset_id, DATA.ANIMATION_CUES[encounter_index]), animation_contact_time / 0.42 if is_finite(animation_contact_time) else 1.65)

func schedule(kind: String, delay: float, data: Dictionary = {}) -> void:
	events.append({"kind": kind, "time": delay, "data": data})
	if kind in ["fan", "radial", "charge", "slash"]: animation_contact_time = minf(animation_contact_time, delay)

func process_events(delta: float) -> void:
	for i in range(events.size() - 1, -1, -1):
		events[i].time -= delta
		if float(events[i].time) <= 0:
			var event: Dictionary = events[i]
			events.remove_at(i)
			execute_event(event.kind, event.data)

func execute_event(kind: String, data: Dictionary) -> void:
	match kind:
		"melee_step":
			melee_step_time = 0.13
		"melee":
			resolve_melee(float(data.damage), bool(data.armed))
		"fan":
			for i in range(int(data.count)):
				var offset: float = (float(i) - (float(data.count) - 1) * 0.5) * float(data.spread)
				fire_bolt(attack_direction.rotated(Vector3.UP, offset), data.speed, data.damage, str(data.get("element", element)), data.get("color", color))
			game.sound.play("enemy_cast", -10)
		"radial":
			for i in range(int(data.count)):
				var angle: float = float(i) / float(data.count) * TAU + float(data.offset)
				fire_bolt(Vector3(sin(angle), 0, cos(angle)), data.speed, data.damage)
			game.fx.ring(global_position, 2.5, color, 0.35)
			game.sound.play("enemy_cast", -6)
		"charge":
			charge_speed = 23
			charge_time = data.duration
		"kamehameha_lunge", "spirit_bomb_lunge":
			charge_speed = 20.0
			charge_time = float(data.duration)
			movement_lock = 0.0
		"recall":
			recall_servants()
		"slash":
			game.fx.slash(data.position + Vector3.UP, data.facing, color, data.radius, true)
			game.sound.play("sword", -7)
		"teleport":
			game.fx.burst(global_position + Vector3.UP, color, 18)
			global_position = data.position + Vector3.UP * 0.1
			game.fx.burst(global_position + Vector3.UP, color, 18)
			visual.rotation.y = data.facing
		"dark_sphere":
			var target := get_target()
			if not is_instance_valid(target):
				return
			var origin: Vector3 = global_position + Vector3.UP * 3.8
			var direction: Vector3 = (target.global_position + Vector3.UP * 0.9 - origin).normalized()
			var sphere := PROJECTILE.new()
			sphere.game = game
			sphere.caster = self
			sphere.element = "void"
			sphere.direction = direction
			sphere.speed = 11.5
			sphere.damage = boss_attack_damage(float(data.damage))
			sphere.color = Color("b56beb")
			sphere.radius = 0.72
			sphere.splash = 2.0
			sphere.position = origin
			game.combatants.add_child(sphere)
			game.fx.burst(origin, Color("4d1f78"), 24)
			game.fx.ring(global_position, 3.8, Color("b56beb"), 0.55)
			game.sound.play("enemy_cast", -1)
		"spirit_bomb":
			var bomb_origin: Vector3 = global_position + Vector3.UP * (head_height + 2.3)
			var bomb_direction: Vector3 = (locked_target + Vector3.UP * 0.8 - bomb_origin).normalized()
			var bomb := PROJECTILE.new()
			bomb.game = game
			bomb.caster = self
			bomb.element = "water"
			bomb.direction = bomb_direction
			bomb.speed = 11.0
			bomb.damage = boss_attack_damage(100.0 + phase * 12.0)
			bomb.color = Color("49cfff")
			bomb.radius = 0.90 * body_scale
			bomb.splash = 8.5
			bomb.position = bomb_origin
			game.combatants.add_child(bomb)
			game.fx.burst(bomb_origin, Color("b5f5ff"), 28)
			game.sound.play("boss_phase", -4)

func fire_bolt(direction: Vector3, shot_speed: float, shot_damage: float, shot_element: String = "", shot_color: Color = Color.TRANSPARENT) -> void:
	# A full retinue can otherwise launch hundreds of persistent, multi-mesh
	# projectiles together. Keep its spell pressure visible without flooding the
	# renderer; boss attacks and player projectiles do not use this cap.
	if not is_boss:
		var soldier_projectile_count: int = 0
		for active_projectile in get_tree().get_nodes_in_group("magic_projectiles"):
			if not is_instance_valid(active_projectile) or active_projectile.is_queued_for_deletion():
				continue
			if active_projectile.friendly or not is_instance_valid(active_projectile.caster):
				continue
			if not active_projectile.caster.is_boss:
				soldier_projectile_count += 1
				if soldier_projectile_count >= MAX_SOLDIER_MAGIC_PROJECTILES:
					return
	var bolt := PROJECTILE.new()
	bolt.game = game
	bolt.caster = self
	bolt.element = element
	bolt.direction = direction
	bolt.speed = shot_speed
	bolt.damage = boss_attack_damage(shot_damage)
	bolt.color = shot_color if shot_color != Color.TRANSPARENT else color
	bolt.element = shot_element if not shot_element.is_empty() else element
	bolt.radius = 0.22 if is_boss else 0.16
	bolt.position = visual.casting_position() if LOADOUT.profile(asset_id).kind == "rifle" else global_position + Vector3.UP * 1.15 + direction * (0.7 * body_scale)
	game.combatants.add_child(bolt)

func hazard(kind: String, pos: Vector3, radius: float, delay: float, duration: float, damage: float, element_override: String = "") -> Node3D:
	animation_contact_time = minf(animation_contact_time, delay)
	var region := HAZARD.new()
	region.game = game
	region.caster = self
	region.kind = kind
	region.element = element_override if not element_override.is_empty() else element
	var element_index: int = DATA.ELEMENTS.find(region.element)
	region.color = DATA.COLORS[element_index] if element_index >= 0 else color
	region.radius = radius
	region.warning_time = delay
	region.active_time = duration
	region.damage = boss_attack_damage(damage)
	region.position = pos
	if region.element == "water":
		region.push_strength = 7.0
	elif region.element == "wind":
		region.push_strength = 12.0
	elif region.element == "ice":
		region.slow_multiplier = 0.65
		region.slow_seconds = 1.4
	return region

func boss_attack_damage(damage: float) -> float:
	if not is_boss:
		return damage
	var strength_multiplier: float = FINAL_BOSS_STRENGTH_MULTIPLIER if encounter_index == 10 else BOSS_STRENGTH_MULTIPLIER
	return damage * BOSS_DAMAGE_MULTIPLIER * (1.15 if encounter_index >= 9 else 1.0) * strength_multiplier

func start_final_charge_visual(spirit_bomb: bool) -> void:
	if is_instance_valid(kamehameha_charge_visual):
		kamehameha_charge_visual.queue_free()
	var charge_visual := ELEMENT_VFX.new()
	charge_visual.element = "water"
	charge_visual.color = Color("50d9ff")
	charge_visual.radius = (1.15 if spirit_bomb else 0.54) * body_scale
	charge_visual.duration = 0.0
	kamehameha_charge_visual = charge_visual
	game.combatants.add_child(charge_visual)

func field_at(pos: Vector3, radius: float, delay: float, duration: float, damage: float, pull: float) -> void:
	var region: Node3D = hazard("pool", pos, radius, delay, duration, damage)
	region.pull_strength = pull
	region.push_strength = 0.0
	game.combatants.add_child(region)

func recall_servants() -> void:
	if not is_boss or encounter_index != 3 or dead or recalled_servants >= 2:
		return
	for slot in range(recalled_servants, 2):
		if game.active_floor_soldier_count(encounter_index) >= DATA.SOLDIERS_PER_FLOOR:
			break
		var point: Vector3 = global_position + Vector3(-4.0 if slot == 0 else 4.0, 0, 3.0)
		var offset: Vector3 = point - home_position
		offset.y = 0
		if offset.length() > COMBAT_RADIUS - 4.0:
			point = home_position + offset.normalized() * (COMBAT_RADIUS - 4.0)
		if not game.arena.is_walkable(point):
			point = home_position + Vector3(-5.0 if slot == 0 else 5.0, 0, 0)
		if not game.arena.is_walkable(point):
			continue
		var servant: CharacterBody3D = get_script().new()
		servant.game = game
		servant.encounter_index = encounter_index
		servant.is_boss = false
		servant.asset_id = DATA.record(encounter_index).soldier_id
		servant.home_position = home_position
		servant.position = point + Vector3.UP * 0.1
		game.combatants.add_child(servant)
		recalled_servants += 1
		game.fx.pillar(point, color, 4.0, 0.65)

func wave_at(pos: Vector3, radius: float, delay: float, damage: float) -> void:
	var region: Node3D = hazard("wave", pos, radius, delay, 1.75, damage)
	region.width = 0.45
	region.jumpable = true
	game.combatants.add_child(region)

func line_at(pos: Vector3, facing: float, length: float, width: float, delay: float, damage: float, element_override: String = "", telegraph_style: String = "", active_duration: float = 0.32) -> void:
	var region: Node3D = hazard("line", pos, 1, delay, active_duration, damage, element_override)
	region.facing = facing
	region.length = length
	region.width = width
	region.telegraph_style = telegraph_style
	if telegraph_style == "kamehameha":
		region.color = Color("56dfff")
		region.push_strength = 0.0
	game.combatants.add_child(region)

func cleave_at(pos: Vector3, facing: float, delay: float, reach: float, damage: float) -> void:
	line_at(pos, facing, reach, reach * 0.6, delay, damage)
	schedule("slash", delay, {"position": pos, "facing": facing, "radius": reach})

func charge_attack(delay: float, damage: float) -> void:
	var distance: float = clampf(global_position.distance_to(locked_target) + 2, 5, 14)
	line_at(global_position, locked_yaw, distance, 1.1, delay, damage)
	schedule("charge", delay, {"duration": distance / 23.0})

func pools_at(pos: Vector3, count: int, radius: float, delay: float, damage: float) -> void:
	var duration: float = 7.0 if element == "poison" else (6.0 if element == "lava" else 5.0)
	for i in range(count):
		var point: Vector3 = pos if i == 0 else pos + Vector3(sin(float(i) * 2.4), 0, cos(float(i) * 2.4)) * 6
		var region: Node3D = hazard("pool", point, radius, delay + i * 0.15, duration, damage)
		game.combatants.add_child(region)

func meteor_cluster(pos: Vector3, count: int, radius: float, delay: float, damage: float) -> void:
	for i in range(count):
		var point: Vector3 = pos if i == 0 else pos + Vector3(sin(float(i) * 2.4 + age), 0, cos(float(i) * 2.4 + age)) * (4.8 + i * 0.7)
		var region: Node3D = hazard("disk", point, radius, delay + i * 0.17, 0.4, damage)
		game.combatants.add_child(region)

func cross_at(pos: Vector3, facing: float, extent: float, delay: float, damage: float, element_override: String = "") -> void:
	for angle in [facing, facing + PI * 0.5]:
		var forward: Vector3 = -Basis(Vector3.UP, angle).z
		line_at(pos - forward * extent, angle, extent * 2, 0.8, delay, damage, element_override)

func shadow_attack() -> void:
	var destination: Vector3 = locked_target + attack_direction * 4.5
	if not game.arena.is_walkable(destination):
		destination = global_position
	var direction: Vector3 = (locked_target - destination).normalized()
	var facing: float = atan2(-direction.x, -direction.z)
	schedule("teleport", 0.55, {"position": destination, "facing": facing})
	cleave_at(destination, facing, 1.12, 6.5, 34)

func take_damage(amount: float, critical: bool = false, impulse_direction: Vector3 = Vector3.ZERO) -> bool:
	if dead or is_queued_for_deletion() or not is_in_group("enemies") or game.state != "playing":
		return false
	if outside_court():
		ward_hit()
		return false
	game.player.clear_court_warning()
	health = maxf(0, health - amount)
	hit_flash = 0.12
	game.fx.burst(global_position + Vector3.UP * head_height * 0.7, color.lightened(0.3), 6)
	if health <= 0:
		die(critical)
		return true
	if critical and impulse_direction.length_squared() > 0.01:
		impulse_direction.y = 0.0
		knockback_velocity += impulse_direction.normalized() * (1.25 if is_boss else 3.4)
	if is_boss:
		var next_phase: int = 3 if encounter_index == 10 and health < max_health * 0.3 else (2 if health < max_health * 0.55 else 1)
		if next_phase > phase:
			speed += (1.35 if encounter_index == 10 else 0.45) * (next_phase - phase)
			phase = next_phase
			stunned = 0.45
			movement_lock = maxf(movement_lock, 0.45)
			attack_windup = 0.45
			visual.action(LOADOUT.attack_cue(asset_id, DATA.ANIMATION_CUES[encounter_index]), 0.45)
			game.fx.ring(global_position, 6.0, color, 0.8)
			game.fx.ring(global_position, 9.0, color.lightened(0.4), 0.45)
			game.fx.pillar(global_position, color, 12, 0.9)
			var lines: Dictionary = DATA.boss_lines(encounter_index)
			var phase_line: String = lines.get("phase3", lines.phase2) if phase == 3 else lines.phase2
			game.hud.announce("FINAL ECLIPSE" if phase == 3 else "AWAKENING / " + DATA.NAMES[encounter_index], phase_line)
			game.sound.play("boss_phase", -2)
		elif critical and attack_windup <= 0 and stagger_resistance <= 0:
			# A clean finisher can interrupt neutral recovery briefly. Do not
			# cancel a telegraphed boss attack or its phase transition.
			stunned = 0.18
			stagger_resistance = 0.85
			movement_lock = maxf(movement_lock, 0.18)
			visual.action("Hit_Chest", 0.20)
	else:
		# Repeated light hits still deal damage, but cannot hold a soldier in
		# hit-stun forever. Critical hits always break through the resistance.
		if critical or stagger_resistance <= 0:
			stunned = 0.22 if critical else 0.14
			stagger_resistance = 0.0 if critical else 0.30
			attack_serial += 1
			events.clear()
			attack_windup = 0
			attack_is_melee = false
			melee_step_time = 0
			attack_cooldown = maxf(attack_cooldown, 0.5)
			visual.action("Hit_Chest", 0.22)
	update_health_label()
	return true

func die(critical: bool) -> void:
	if dead:
		return
	dead = true
	casting_aura.hide()
	events.clear()
	remove_from_group("enemies")
	remove_from_group("bosses")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	health_label.hide()
	marker.hide()
	ward.hide()
	visual.action("Death01", 1.5)
	game.fx.burst(global_position + Vector3.UP, color, 30 if is_boss else 10)
	game.fx.ring(global_position, 6 if is_boss else 1.5, color, 0.75)
	if is_boss:
		game.sound.play("boss_death", -1)
		if is_instance_valid(game.player):
			game.player.shake = maxf(game.player.shake, 0.15)
		var lines: Dictionary = DATA.boss_lines(encounter_index)
		game.hud.announce(DATA.NAMES[encounter_index] + "  /  DEFEATED", lines.defeat)
		if is_instance_valid(game) and game.has_method("on_boss_killed"):
			game.on_boss_killed(self, critical)
		else:
			game.enemy_defeated(global_position, critical, true)
	else:
		game.enemy_defeated(global_position, critical, false)
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(visual, "position:y", -5.0, 1.0)
	tween.tween_callback(queue_free)

func update_health_label() -> void:
	if not is_instance_valid(health_label):
		return
	# A resumed encounter keeps the phase implied by its saved remaining health.
	if is_boss:
		var previous_phase: int = phase
		phase = maxi(phase, 3 if encounter_index == 10 and health < max_health * 0.3 else (2 if health < max_health * 0.55 else 1))
		speed += 0.45 * (phase - previous_phase)
	health_label.text = (DATA.NAMES[encounter_index] + ("  /  II" if phase == 2 else ("  /  III" if phase == 3 else ""))) if is_boss else str(ceili(health))
	if not is_boss:
		health_label.show()
		health_label_hide_timer = 1.75
