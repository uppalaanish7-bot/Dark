extends CharacterBody3D
const CHARACTER = preload("res://scripts/character_visual.gd")
const PROJECTILE = preload("res://scripts/magic_projectile.gd")
const SKY_SPELL = preload("res://scripts/player_sky_spell.gd")
const MANA_GATHER = preload("res://scripts/mana_gather.gd")
const GROWTH = preload("res://scripts/player_growth.gd")
const MAX_HEALTH: float = 200.0
const MAX_MANA: float = 100.0
const WALK_SPEED: float = 10.0
const RUN_SPEED: float = 14.5
const FIREBOLT_COST: float = 12.0
const FIRE_SLASH_COST: float = 26.0
const ULTIMATE_COST: float = 70.0
const FIRE_COLOR := Color("ff9355")
const LIGHTNING_COLOR := Color("81deff")
const ENCHANTMENT_DURATION: float = 12.0
const GROUND_ACCELERATION: float = 72.0
const GROUND_BRAKING: float = 88.0
const AIR_ACCELERATION: float = 38.0
const MAX_STEP_HEIGHT: float = 0.34
var game: Node3D
var visual: Node3D
var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var growth = GROWTH.new()
var max_health: float:
	get: return growth.health_capacity()
var max_mana: float:
	get: return growth.mana_capacity()
var growth_feedback: String = ""
var health: float = MAX_HEALTH
var mana: float = MAX_MANA
var mana_regen_delay: float = 0.0
var yaw: float = 0.0
var pitch: float = -0.15
var fire_timer: float = 0.0
var melee_timer: float = 0.0
var magic_cooldown: float = 0.0
var slash_cooldown: float = 0.0
var ultimate_cooldown: float = 0.0
var enchantment_time: float = 0.0
var spell_target := Vector3.ZERO
var ranged_target := Vector3.ZERO
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var dash_direction := Vector3.ZERO
var invulnerable: float = 0.0
var coyote: float = 0.0
var jump_buffer: float = 0.0
var air_jumps: int = 1
var aiming: bool = false
var shoulder: float = 1.0
var shake: float = 0.0
var step_time: float = 0.0
var last_shot: float = 0.0
var trigger_held: bool = false
var combo_index: int = 0
var combo_window: float = 0.0
var attack_pending: float = 0.0
var attack_kind: String = ""
var attack_yaw: float = 0.0
var mana_notice_timer: float = 0.0
var court_notice_active: bool = false
var safe_position := Vector3.ZERO
var recovery_count: int = 0
var slow_timer: float = 0.0
var slow_factor: float = 1.0
var external_velocity := Vector3.ZERO
var _safe_places: Dictionary = {}
var _safety_timer: float = 0.15
var _embedded_time: float = 0.0
var _stand_shape: CapsuleShape3D
var _last_forward_release: float = -10.0
var _w_sprinting: bool = false
var _w_press_time: float = 0.0
var _tap_step_timer: float = 0.0
var _space_sprint_active: bool = false
var _combat_stance_timer: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	floor_snap_length = 0.4
	floor_constant_speed = true
	floor_stop_on_slope = true
	safe_margin = 0.02
	max_slides = 8
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.85
	_stand_shape = CapsuleShape3D.new()
	_stand_shape.radius = 0.30
	_stand_shape.height = 1.75
	collider.shape = shape
	collider.position.y = 0.94
	add_child(collider)
	visual = CHARACTER.new()
	visual.name = "Character"
	add_child(visual)
	pivot = Node3D.new()
	pivot.position = Vector3(0, 1.5, 0)
	add_child(pivot)
	arm = SpringArm3D.new()
	pivot.add_child(arm)
	arm.position.x = 0.6
	arm.spring_length = 5.8
	arm.margin = 0.18
	arm.collision_mask = 1
	var camera_shape := SphereShape3D.new()
	camera_shape.radius = 0.24
	arm.shape = camera_shape
	arm.add_excluded_object(get_rid())
	camera = Camera3D.new()
	arm.add_child(camera)
	camera.near = 0.08
	camera.far = 520
	camera.fov = 76
	var light := OmniLight3D.new()
	light.name = "EmberPresence"
	light.position = Vector3(0, 1.8, 0)
	light.light_color = Color("ffcf9a")
	light.light_energy = 0.75
	light.omni_range = 5.8
	light.shadow_enabled = false
	add_child(light)
	reset()

func reset() -> void:
	health = max_health
	mana = max_mana
	mana_regen_delay = 0
	invulnerable = 1
	dash_timer = 0
	dash_cooldown = 0
	melee_timer = 0
	fire_timer = 0
	magic_cooldown = 0
	slash_cooldown = 0
	ultimate_cooldown = 0
	enchantment_time = 0
	clear_enchantment_visual()
	last_shot = 0
	combo_index = 0
	combo_window = 0
	attack_pending = 0
	attack_kind = ""
	court_notice_active = false
	slow_timer = 0
	slow_factor = 1
	external_velocity = Vector3.ZERO
	_safe_places.clear()
	_safety_timer = 0.15
	_embedded_time = 0
	_w_press_time = 0.0
	_tap_step_timer = 0.0
	_space_sprint_active = false
	_combat_stance_timer = 0.0
	air_jumps = 1
	velocity = Vector3.ZERO
	yaw = 0
	pitch = -0.15
	visual.rotation = Vector3.ZERO
	visual.one_shot_time = 0
	visual.action("Idle_Loop", 0.05)
	safe_position = fallback_position()
	release_input()

func release_input() -> void:
	trigger_held = false
	aiming = false
	jump_buffer = 0

func growth_snapshot() -> Dictionary:
	return growth.snapshot()

func restore_growth(data: Dictionary) -> void:
	growth.restore(data)
	health = clampf(health, 0.0, max_health)
	mana = clampf(mana, 0.0, max_mana)
	growth_feedback = ""

func award_xp(amount: int) -> int:
	return growth.earn(amount)

func damage_multiplier() -> float:
	return growth.damage_multiplier()

func growth_cost(kind: String) -> int:
	return growth.cost(kind)

func growth_purchase_reason(kind: String) -> String:
	if kind not in GROWTH.KINDS: return "Unknown upgrade."
	if is_instance_valid(game) and (not game.runtime_world_is_current() or game.state not in ["playing", "world", "paused"]):
		return "Enter your saved world before spending XP."
	if kind == "heal" and is_instance_valid(game) and (game.state in ["playing", "lift"] or (game.state == "paused" and game.paused_from == "playing")):
		return "Health can only be restored after reaching the next floor."
	if health <= 0: return "Retry the encounter before spending XP."
	if kind == "heal" and health >= max_health: return "Health is already full."
	if kind == "mana" and mana >= max_mana: return "Mana is already full."
	if growth.capped(kind): return "Maximum level reached."
	if growth.xp < growth.cost(kind): return "%d more XP needed." % (growth.cost(kind)-growth.xp)
	return ""

func purchase_growth(kind: String) -> bool:
	growth_feedback = growth_purchase_reason(kind)
	if not growth_feedback.is_empty(): return false
	var old_health_cap := max_health
	var old_mana_cap := max_mana
	if not growth.spend(kind): return false
	# Raising a capacity never refills current health during a floor.
	health = minf(health, max_health)
	mana = minf(max_mana, mana + max_mana-old_mana_cap)
	match kind:
		"heal":
			health = minf(max_health, health + max_health * 0.5)
			growth_feedback = "Health restored by up to 50%."
		"mana":
			mana = max_mana
			mana_regen_delay = 0.0
			growth_feedback = "Mana fully restored."
		"power": growth_feedback = "Power level %d · all damage increased." % growth.power_level
		"health": growth_feedback = "Health level %d · +20 maximum HP." % growth.health_level
		"magic": growth_feedback = "Mana level %d · +10 maximum mana." % growth.mana_level
		"overall": growth_feedback = "Hero level %d · Power, Health and Mana each gained 1 level." % growth.level
	if is_instance_valid(game) and game.has_method("save_current_session"):
		if not game.save_current_session(): growth_feedback += " Save pending; progress remains in this session."
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(game) or not game.state in ["playing", "world"]:
		return
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not captured and not (OS.has_feature("web") and not game.mobile_controls):
		return
	if event is InputEventMouseMotion:
		if captured or event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			look(event.relative)
	if event.is_action_pressed("forward") and not event.is_echo():
		_w_press_time = Time.get_ticks_msec() / 1000.0
		var now: float = _w_press_time
		if now - _last_forward_release < 0.32:
			_w_sprinting = true
	elif event.is_action_released("forward"):
		var now: float = Time.get_ticks_msec() / 1000.0
		var duration: float = now - _w_press_time
		_last_forward_release = now
		_w_sprinting = false
		_space_sprint_active = false
		# Tap W: single committed step
		if duration < 0.18 and not held("left") and not held("right") and not held("back"):
			_tap_step_timer = 0.22
	if event.is_action_pressed("jump"):
		jump_buffer = 0.15
	if event.is_action_pressed("dodge"):
		dodge()
	if event.is_action_pressed("melee"):
		sword_attack()
	if event.is_action_pressed("magic_slash"):
		fire_slash()
	if event.is_action_pressed("ultimate"):
		ultimate()
	if event.is_action_pressed("shoulder"):
		shoulder *= -1
	if event.is_action_pressed("fire"):
		trigger_held = true
		sword_attack()
	if event.is_action_released("fire"):
		trigger_held = false
	if event.is_action_pressed("aim"):
		cast_firebolt()

func look(motion: Vector2) -> void:
	yaw -= motion.x * game.sensitivity
	pitch = clampf(pitch - motion.y * game.sensitivity, -1.05, 0.8)

func held(action: String) -> bool:
	var pressed: bool = InputMap.has_action(action) and Input.is_action_pressed(action)
	return pressed or (is_instance_valid(game.touch_controls) and game.touch_controls.is_held(action))

func just_pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)

func just_released(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_released(action)

func movement_input() -> Vector2:
	var movement := Input.get_vector("left", "right", "forward", "back")
	if is_instance_valid(game.touch_controls):
		movement += game.touch_controls.movement
	return movement.limit_length()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game):
		return
	if not game.state in ["playing", "world"]:
		if game.state in ["menu", "dead", "victory"]:
			visual.tick(delta, 0, true)
		return
	for key in ["invulnerable", "fire_timer", "melee_timer", "magic_cooldown", "slash_cooldown", "ultimate_cooldown", "enchantment_time", "dash_cooldown", "last_shot", "jump_buffer", "combo_window", "mana_notice_timer", "mana_regen_delay"]:
		set(key, maxf(0, float(get(key)) - delta))
	update_enchantment_visual()
	_combat_stance_timer = maxf(0, _combat_stance_timer - delta)
	if enchantment_time > 0:
		_combat_stance_timer = maxf(_combat_stance_timer, 1.0)
	if mana_regen_delay <= 0:
		mana = minf(max_mana, mana + delta * 15.0)
	slow_timer = maxf(0, slow_timer - delta)
	if slow_timer <= 0:
		slow_factor = 1.0
	if attack_pending > 0:
		var prev_pending: float = attack_pending
		attack_pending = maxf(0, attack_pending - delta)
		if attack_kind == "ultimate" and prev_pending > 0.46 and attack_pending <= 0.46:
			visual.action("Channel_Loop", 0.46)
		if attack_pending == 0:
			resolve_attack()
	aiming = held("aim") and dash_timer <= 0
	if just_pressed("forward"):
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _last_forward_release < 0.35:
			_w_sprinting = true
	if just_released("forward") or not held("forward"):
		if just_released("forward"):
			_last_forward_release = Time.get_ticks_msec() / 1000.0
		_w_sprinting = false
		_space_sprint_active = false

	if just_pressed("jump"):
		jump_buffer = 0.15
	# Tap-step committed forward stride
	_tap_step_timer = maxf(0, _tap_step_timer - delta)
	var input_vector: Vector2 = movement_input()
	if _tap_step_timer > 0 and input_vector.length_squared() < 0.01:
		input_vector = Vector2(0, -1.0)
	# W + Space sprint activation
	if held("forward") and held("jump") and input_vector.y < -0.05:
		_space_sprint_active = true
	if not held("forward") or not held("jump"):
		if not held("forward"):
			_space_sprint_active = false
	var sprint: bool = (held("sprint") or _w_sprinting or _space_sprint_active) and input_vector.length() > 0.05
	var direction: Vector3 = Basis(Vector3.UP, yaw) * Vector3(input_vector.x, 0, input_vector.y)
	var speed: float = (RUN_SPEED if sprint else WALK_SPEED) * slow_factor
	if attack_pending > 0 and attack_kind == "ultimate":
		speed *= 0.18
	var was_grounded: bool = is_on_floor()
	if was_grounded:
		coyote = 0.12
		air_jumps = 1
		velocity.y = minf(velocity.y, -0.25)
	else:
		coyote = maxf(0, coyote - delta)
		velocity.y -= 27.0 * delta

	# Jump on just_pressed or jump_buffer; holding Space does NOT auto-jump
	var space_just: bool = just_pressed("jump")
	if space_just and was_grounded and dash_timer <= 0:
		jump_buffer = maxf(jump_buffer, 0.15)
	# W + Space sprint: boost velocity on ground takeoff
	if _space_sprint_active and was_grounded and jump_buffer > 0:
		speed = RUN_SPEED * slow_factor

	if jump_buffer > 0 and (coyote > 0 or air_jumps > 0) and dash_timer <= 0:
		var double_jump: bool = coyote <= 0
		if double_jump:
			air_jumps -= 1
			game.fx.ring(global_position, 1.2, element_color(), 0.35)
			game.fx.burst(global_position + Vector3.UP * 0.2, element_color(), 10)
		velocity.y = 9.8
		if _space_sprint_active and direction.length_squared() > 0.01:
			var boost_dir := direction.normalized()
			velocity.x = boost_dir.x * RUN_SPEED
			velocity.z = boost_dir.z * RUN_SPEED
		coyote = 0
		jump_buffer = 0
		visual.action("Double_Jump" if double_jump else "Jump_Start", 0.28 if double_jump else 0.22)
		game.sound.play("jump", -6)
	if dash_timer > 0:
		dash_timer = maxf(0, dash_timer - delta)
		velocity.x = dash_direction.x * 22
		velocity.z = dash_direction.z * 22
	else:
		var acceleration: float = (GROUND_ACCELERATION if direction.length_squared() > 0.01 else GROUND_BRAKING) if was_grounded else AIR_ACCELERATION
		var planar: Vector2 = Vector2(velocity.x, velocity.z).move_toward(Vector2(direction.x, direction.z) * speed, delta * acceleration)
		velocity.x = planar.x
		velocity.z = planar.y
	var locomotion_velocity := Vector2(velocity.x, velocity.z)
	var contact_start: Vector3 = global_position
	var recoveries_before: int = recovery_count
	velocity.x += external_velocity.x
	velocity.z += external_velocity.z
	var stepped: bool = was_grounded and velocity.y <= 0 and try_step(Vector3(velocity.x, 0, velocity.z) * delta)
	if stepped:
		var planar: Vector2 = Vector2(velocity.x, velocity.z)
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		velocity.x = planar.x
		velocity.z = planar.y
	else:
		move_and_slide()
	if external_velocity.length_squared() > 0.01:
		velocity.x = locomotion_velocity.x
		velocity.z = locomotion_velocity.y
	external_velocity *= exp(-delta * 4.0)
	if not was_grounded and is_on_floor():
		if attack_pending <= 0 and dash_timer <= 0 and fire_timer <= 0 and last_shot <= 0:
			visual.action("Jump_Land", 0.13)
		game.sound.play("step", -7)
	validate_contact(delta)
	var contact_velocity: Vector3 = (global_position - contact_start) / maxf(delta, 0.001) if recovery_count == recoveries_before else Vector3.ZERO
	var planar_speed: float = minf(26.0, Vector2(contact_velocity.x, contact_velocity.z).length())
	var facing: float = yaw
	if not aiming and last_shot <= 0 and direction.length_squared() > 0.01:
		facing = atan2(-direction.x, -direction.z)
	if attack_pending > 0:
		facing = attack_yaw
	var old_facing: float = visual.rotation.y
	if aiming or last_shot > 0 or direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, facing, 1 - exp(-19 * delta))
	if visual.has_method("set_motion_state"):
		var local_velocity: Vector3 = Basis(Vector3.UP, visual.rotation.y).inverse() * Vector3(contact_velocity.x, velocity.y, contact_velocity.z)
		var turn_rate: float = wrapf(visual.rotation.y - old_facing, -PI, PI) / maxf(delta, 0.001)
		visual.set_motion_state(local_velocity, is_on_floor(), velocity.y, turn_rate, dash_timer > 0, aiming or last_shot > 0)
	visual.tick(delta, planar_speed, is_on_floor(), aiming or last_shot > 0)
	if (trigger_held or (is_instance_valid(game.touch_controls) and game.touch_controls.is_held("fire"))) and fire_timer <= 0:
		sword_attack()
	if aiming and magic_cooldown <= 0:
		cast_firebolt()
	step_time -= delta
	if is_on_floor() and planar_speed > 0.5 and step_time <= 0:
		game.sound.play("step", -19)
		step_time = 0.23 if sprint else 0.32
	update_camera(delta, sprint)

func active_place() -> Node3D:
	if not is_instance_valid(game):
		return null
	return game.story_world if game.state == "world" else game.arena

func play_bounds() -> Rect2:
	var place: Node3D = active_place()
	if is_instance_valid(place) and place.has_method("get_play_bounds"):
		return place.get_play_bounds()
	return Rect2(-224, -244, 448, 488) if is_instance_valid(game) and game.state == "world" else Rect2(-156, -236, 312, 472)

func fallback_position() -> Vector3:
	var place: Node3D = active_place()
	if is_instance_valid(place):
		if place.has_method("floor_spawn"):
			return place.floor_spawn(game.safe_floor_index())
		if place.has_method("safe_spawn_position"):
			return place.safe_spawn_position()
		if place.has_method("spawn_point"):
			return place.spawn_point()
	return Vector3(0, 0.12, 170 if is_instance_valid(game) and game.state == "world" else 190)

func pose_clear(at: Vector3) -> bool:
	if not at.is_finite() or not play_bounds().has_point(Vector2(at.x, at.z)):
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _stand_shape
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.94)
	query.collision_mask = 1
	query.margin = 0.001
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func supported_pose(at: Vector3) -> bool:
	if not pose_clear(at):
		return false
	var space := get_world_3d().direct_space_state
	for offset in [Vector3.ZERO, Vector3(0.23, 0, 0), Vector3(-0.23, 0, 0), Vector3(0, 0, 0.23), Vector3(0, 0, -0.23)]:
		var query := PhysicsRayQueryParameters3D.create(at + offset + Vector3.UP * 0.18, at + offset + Vector3.DOWN * 0.42, 1)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or Vector3(hit.normal).dot(Vector3.UP) < 0.7:
			return false
	return true

func validate_contact(delta: float) -> void:
	var bounds: Rect2 = play_bounds()
	var inside: bool = global_position.is_finite() and bounds.has_point(Vector2(global_position.x, global_position.z))
	var within_stage: bool = true
	if game.state == "playing" and is_instance_valid(game.arena) and game.arena.has_method("clamp_to_stage"):
		var safe_target: Vector3 = game.arena.clamp_to_stage(global_position, 0.25)
		within_stage = safe_target.distance_squared_to(global_position) < 0.01
		if not within_stage:
			# Closing-ring pressure is continuous; a stage change never teleports
			# the player or overwrites their last safe recovery point.
			global_position = global_position.move_toward(safe_target, delta * 8.0)
			var outward := Vector3(global_position.x, 0.0, global_position.z).normalized()
			if Vector3(velocity.x, 0.0, velocity.z).dot(outward) > 0.0:
				velocity.x = 0.0
				velocity.z = 0.0
	if not inside and global_position.is_finite():
		var clamped := Vector3(clampf(global_position.x, bounds.position.x + 0.02, bounds.end.x - 0.02), global_position.y, clampf(global_position.z, bounds.position.y + 0.02, bounds.end.y - 0.02))
		# A small outward step meets a stable edge; it never poisons the recovery anchor.
		if clamped.distance_to(global_position) < 1.2 and supported_pose(clamped):
			global_position = clamped
			velocity.x = 0 if clamped.x < bounds.position.x + 0.1 or clamped.x > bounds.end.x - 0.1 else velocity.x
			velocity.z = 0 if clamped.z < bounds.position.y + 0.1 or clamped.z > bounds.end.y - 0.1 else velocity.z
			inside = true
	if not inside or global_position.y < -4:
		recover_contact()
		return
	_safety_timer -= delta
	if _safety_timer > 0:
		return
	_safety_timer = 0.12
	if not pose_clear(global_position):
		_embedded_time += 0.12
		if _embedded_time >= 0.24:
			recover_contact()
		return
	_embedded_time = 0
	if within_stage and is_on_floor() and supported_pose(global_position):
		var place: Node3D = active_place()
		safe_position = global_position
		if is_instance_valid(place):
			_safe_places[place.get_instance_id()] = safe_position

func recover_contact() -> void:
	var place: Node3D = active_place()
	var fallback: Vector3 = fallback_position()
	var target: Vector3 = _safe_places.get(place.get_instance_id(), fallback) if is_instance_valid(place) else fallback
	if not supported_pose(target):
		target = fallback
	global_position = target + Vector3.UP * 0.06
	safe_position = target
	velocity = Vector3.ZERO
	external_velocity = Vector3.ZERO
	dash_timer = 0
	jump_buffer = 0
	attack_pending = 0
	attack_kind = ""
	coyote = 0
	air_jumps = 1
	_embedded_time = 0
	_safety_timer = 0.15
	recovery_count += 1
	invulnerable = maxf(invulnerable, 0.4)
	visual.action("Jump_Land", 0.16)

func try_step(motion: Vector3) -> bool:
	if motion.length_squared() < 0.0001:
		return false
	var obstruction := KinematicCollision3D.new()
	if not test_move(global_transform, motion, obstruction) or obstruction.get_normal().y > 0.7:
		return false
	var lifted: Transform3D = global_transform
	lifted.origin.y += MAX_STEP_HEIGHT
	# At a blocked curb move_and_slide has already removed forward speed. Probe
	# past the capsule's rounded toe so a tiny re-acceleration step can still land
	# on the top, instead of repeatedly finding the curb's steep front edge.
	var step_motion: Vector3 = motion.normalized() * maxf(motion.length(), 0.38)
	if test_move(global_transform, Vector3.UP * MAX_STEP_HEIGHT) or test_move(lifted, step_motion):
		return false
	lifted.origin += step_motion
	var landing := KinematicCollision3D.new()
	if not test_move(lifted, Vector3.DOWN * (MAX_STEP_HEIGHT + 0.08), landing) or landing.get_normal().y < 0.7:
		return false
	var target: Vector3 = lifted.origin + landing.get_travel()
	var rise: float = target.y - global_position.y
	if rise < 0.025 or rise > MAX_STEP_HEIGHT + 0.02 or not pose_clear(target):
		return false
	global_position = target + Vector3.UP * 0.005
	return true

func apply_combat_force(force: Vector3) -> void:
	if not is_gameplay_active() or dash_timer > 0 or not force.is_finite():
		return
	external_velocity = (external_velocity + Vector3(force.x, 0, force.z)).limit_length(16.0)
	if force.y > 0:
		velocity.y = maxf(velocity.y, minf(force.y, 8.0))

func apply_slow(multiplier: float, duration: float) -> void:
	if not is_gameplay_active() or dash_timer > 0:
		return
	slow_factor = minf(slow_factor, clampf(multiplier, 0.55, 1.0))
	slow_timer = maxf(slow_timer, clampf(duration, 0.0, 2.5))

func update_camera(delta: float, sprint: bool = false) -> void:
	pivot.rotation = Vector3(pitch, yaw, 0)
	arm.spring_length = lerpf(arm.spring_length, 4.3 if aiming else 5.8, 1 - exp(-9 * delta))
	arm.position.x = lerpf(arm.position.x, shoulder * 0.65, 1 - exp(-12 * delta))
	camera.fov = lerpf(camera.fov, 68.0 if aiming else (82.0 if sprint else 76.0), 1 - exp(-8 * delta))
	shake = move_toward(shake, 0, delta * 0.65)
	camera.h_offset = randf_range(-shake, shake) if game.camera_shake else 0.0
	camera.v_offset = randf_range(-shake, shake) if game.camera_shake else 0.0
	visual.visible = camera.global_position.distance_to(global_position + Vector3.UP) > 0.85

func aim_hit() -> Dictionary:
	var origin: Vector3 = camera.global_position
	var end: Vector3 = origin - camera.global_basis.z * 110.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 5, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return {"point": hit.get("position", end), "hit": hit}

func spend_mana(amount: float) -> bool:
	if mana < amount:
		if mana_notice_timer <= 0:
			mana_notice_timer = 2.0
			game.hud.announce("MANA RECOVERING", "Keep moving and use your sword. Magic restores naturally.")
		return false
	mana -= amount
	mana_regen_delay = 0.7
	return true

func element() -> String:
	return "lightning" if visual.skin_index == 1 else "fire"

func element_color() -> Color:
	return LIGHTNING_COLOR if element() == "lightning" else FIRE_COLOR

func power_label(action_name: String) -> String:
	var lightning: bool = element() == "lightning"
	match action_name:
		"ranged": return "ARC BOLT" if lightning else "FIREBALL"
		"enchant": return "STORM BLADE" if lightning else "FLAME BLADE"
		"ultimate": return "THUNDERSTORM" if lightning else "METEOR"
	return "SWORD"

func clear_enchantment_visual() -> void:
	if not is_instance_valid(visual) or not is_instance_valid(visual.weapon): return
	for effect_name in ["LivingBladeFire", "LivingBladeLightning"]:
		var effect: Node = visual.weapon.get_node_or_null(effect_name)
		if effect != null:
			visual.weapon.remove_child(effect)
			effect.queue_free()

func update_enchantment_visual() -> void:
	if enchantment_time <= 0:
		clear_enchantment_visual()
		return
	game.fx.enchant_blade(visual.weapon, element(), enchantment_time)

func spell_aim_point() -> Vector3:
	var aim: Dictionary = aim_hit()
	var point: Vector3 = aim.point
	if aim.hit.is_empty():
		point = global_position - Basis(Vector3.UP, yaw).z * 22.0
	var flat := Vector3(point.x-global_position.x, 0, point.z-global_position.z).limit_length(55.0)
	point = global_position + flat
	var ground := PhysicsRayQueryParameters3D.create(point + Vector3.UP*12.0, point + Vector3.DOWN*25.0, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ground)
	return Vector3(hit.position) if not hit.is_empty() else Vector3(point.x, global_position.y, point.z)

func show_court_warning() -> void:
	if court_notice_active:
		return
	court_notice_active = true
	game.hud.announce("COURT WARD ACTIVE", "Return to the illuminated court to break its protection.")

func clear_court_warning() -> void:
	court_notice_active = false

func sword_attack() -> void:
	if not is_gameplay_active() or fire_timer > 0 or dash_timer > 0 or attack_pending > 0:
		return
	combo_index = (combo_index + 1) % 3 if combo_window > 0 else 0
	combo_window = 1.0
	fire_timer = [0.32, 0.37, 0.53][combo_index]
	melee_timer = fire_timer
	attack_yaw = assisted_facing(4.5)
	visual.rotation.y = attack_yaw
	last_shot = fire_timer
	attack_pending = 0.11 if combo_index < 2 else 0.18
	attack_kind = "sword"
	visual.action(["Sword_Attack", "Sword_Attack02", "Sword_Attack03"][combo_index], fire_timer)
	game.sound.play("sword", -1 if combo_index == 2 else -4)
	# Melee forward micro-lunge
	if is_on_floor():
		external_velocity += -Basis(Vector3.UP, attack_yaw).z * (3.2 if combo_index < 2 else 5.0)
	game.shots += 1
	_combat_stance_timer = 6.0

func assisted_facing(reach: float) -> float:
	var closest: float = reach
	var facing: float = yaw
	var forward: Vector3 = -Basis(Vector3.UP, yaw).z
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0
		if offset.length() < closest and offset.normalized().dot(forward) > 0.55:
			closest = offset.length()
			facing = atan2(-offset.x, -offset.z)
	return facing

func resolve_attack() -> void:
	if not is_gameplay_active():
		return
	if attack_kind == "sword":
		var damage: float = [48.0, 58.0, 90.0][combo_index]
		var enchanted: bool = enchantment_time > 0
		var reach: float = (3.4 if combo_index < 2 else 3.9) + (1.2 if enchanted else 0.0)
		game.fx.slash(global_position + Vector3.UP * 1.0, attack_yaw, element_color() if enchanted else Color("fff0c5"), reach - 0.4, enchanted or combo_index == 2)
		if enchanted and element() == "lightning":
			game.fx.lightning_arc(global_position + Vector3.UP, global_position + Vector3.UP - Basis(Vector3.UP, attack_yaw).z * reach, 0.22)
		arc_damage(damage * (1.8 if enchanted else 1.0), reach, 0.0 if combo_index == 2 else 0.2, enchanted or combo_index == 2)
	elif attack_kind == "slash":
		game.fx.slash(global_position + Vector3.UP * 1.0, attack_yaw, FIRE_COLOR, 7.0, true)
		game.fx.ring(global_position, 2, FIRE_COLOR, 0.3)
		game.fx.flash(global_position + Vector3.UP, FIRE_COLOR, 3)
		arc_damage(170, 7.0, -0.1, true)
		launch_fire(-Basis(Vector3.UP, attack_yaw).z, 55, 28, 0.3)
		shake = 0.14
	elif attack_kind == "ultimate":
		visual.action("Cast_Release", 0.36)
		var spell := SKY_SPELL.new()
		spell.game = game
		spell.caster = self
		spell.element = element()
		spell.position = spell_target if element() == "fire" else global_position
		game.combatants.add_child(spell)
		game.fx.burst(visual.muzzle.global_position, element_color(), 16)
		shake = maxf(shake, 0.11)
	elif attack_kind == "ranged":
		release_ranged_magic()
	attack_kind = ""

func arc_damage(amount: float, reach: float, cone_dot: float, critical: bool) -> void:
	amount *= damage_multiplier()
	var forward: Vector3 = -Basis(Vector3.UP, attack_yaw).z
	var hit_any: bool = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		# Killing the sovereign can dissolve the remaining nodes in this snapshot.
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.is_in_group("enemies"):
			continue
		var offset: Vector3 = enemy.global_position - global_position
		var flat := Vector3(offset.x, 0, offset.z)
		var vertical_reach: float = 6.0 if enemy.has_method("is_flyer") and enemy.is_flyer() else 3.8
		if enemy.dead or flat.length() > reach or absf(offset.y) > vertical_reach or (flat.length() > 0.2 and flat.normalized().dot(forward) < cone_dot):
			continue
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, enemy.global_position + Vector3.UP * 1.2, 1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		var push_direction := Vector3(enemy.global_position.x-global_position.x,0,enemy.global_position.z-global_position.z).normalized()
		if not enemy.take_damage(amount, critical, push_direction):
			continue
		game.fx.number(enemy.global_position + Vector3.UP * enemy.head_height, ceili(amount), critical)
		hit_any = true
	if hit_any:
		game.register_hit(critical)
		shake = maxf(shake, 0.085 if critical else 0.045)

func cast_firebolt() -> void:
	if not is_gameplay_active() or magic_cooldown > 0 or dash_timer > 0 or attack_pending > 0:
		return
	if not spend_mana(FIREBOLT_COST):
		magic_cooldown = 0.22
		return
	magic_cooldown = 0.42
	last_shot = 0.42
	visual.rotation.y = yaw
	visual.action("Fire_Cast", 0.42)
	var aim: Dictionary = aim_hit()
	ranged_target = aim.point
	if visual.has_method("set_cast_target"):
		visual.set_cast_target(ranged_target)
	attack_pending = 0.17
	attack_kind = "ranged"
	attack_yaw = yaw
	game.shots += 1

func release_ranged_magic() -> void:
	var origin: Vector3 = visual.muzzle.global_position
	# Validate the segment out of the body as well as the flight, so an aimed
	# blade cannot launch a projectile through a wall touching its point.
	var chest := global_position + Vector3.UP * 1.25
	var query := PhysicsRayQueryParameters3D.create(chest, origin, 1, [get_rid()])
	var obstruction := get_world_3d().direct_space_state.intersect_ray(query)
	if not obstruction.is_empty():
		game.fx.burst(obstruction.position, element_color(), 6)
		return
	if element() == "lightning":
		cast_arc_bolt(origin, {"point": ranged_target})
	else:
		launch_fire((ranged_target - origin).normalized(), 62, 37, 0.24, origin)
	game.fx.burst(origin, element_color(), 7)
	game.sound.play("lightning" if element() == "lightning" else "fire", -2)
	shake = 0.035

func cast_arc_bolt(origin: Vector3, aim: Dictionary) -> void:
	# Camera aiming chooses the target; a second ray from the hand prevents
	# shoulder cameras from firing through a nearby wall.
	var end: Vector3 = aim.point
	end += (end-origin).normalized()*0.35
	if origin.distance_to(end) > 75.0: end = origin + (end-origin).normalized()*75.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 5, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit.position
		var target: Object = hit.collider
		var amount := 68.0 * damage_multiplier()
		if is_instance_valid(target) and target.has_method("take_damage") and target.take_damage(amount, false):
			game.fx.number(end + Vector3.UP*0.3, ceili(amount))
			game.register_hit(false)
	game.fx.lightning_arc(origin, end, 0.28)
	game.fx.burst(end, LIGHTNING_COLOR, 14)

func launch_fire(direction: Vector3, damage: float, speed: float, radius: float, origin: Vector3 = Vector3.INF) -> void:
	var bolt := PROJECTILE.new()
	bolt.game = game
	bolt.caster = self
	bolt.friendly = true
	bolt.element = "fire"
	bolt.direction = direction
	bolt.damage = damage * damage_multiplier()
	bolt.speed = speed
	bolt.color = FIRE_COLOR
	bolt.radius = radius
	bolt.splash = 1.4
	bolt.position = global_position + Vector3.UP * 1.25 + direction * 0.5 if origin == Vector3.INF else origin
	game.combatants.add_child(bolt)

func fire_slash() -> void:
	if not is_gameplay_active() or slash_cooldown > 0 or dash_timer > 0 or attack_pending > 0:
		return
	# Preserve Q's blade enchant for grounded combat. When the reticle is on a
	# winged foe, the same input spends its usual mana cost on a quick aerial bolt.
	if cast_aerial_q():
		return
	if not spend_mana(FIRE_SLASH_COST):
		return
	slash_cooldown = 0.32
	enchantment_time = ENCHANTMENT_DURATION
	update_enchantment_visual()
	game.fx.ring(global_position, 2.4, element_color(), 0.5)
	game.sound.play("lightning" if element() == "lightning" else "fire_slash", -2)
	_combat_stance_timer = 6.0

func cast_aerial_q() -> bool:
	var aim: Dictionary = aim_hit()
	var hit: Dictionary = aim.get("hit", {})
	var target: Object = hit.get("collider") if hit is Dictionary else null
	if not is_instance_valid(target) or not target is CharacterBody3D or not target.is_in_group("enemies") or not target.has_method("is_flyer") or not target.is_flyer() or bool(target.get("dead")):
		return false
	if not spend_mana(FIRE_SLASH_COST):
		return true
	slash_cooldown = 0.48
	var origin: Vector3 = camera.global_position
	var flyer: CharacterBody3D = target as CharacterBody3D
	var direction: Vector3 = (flyer.global_position + Vector3.UP * 0.8 - origin).normalized()
	var bolt := PROJECTILE.new()
	bolt.game = game
	bolt.caster = self
	bolt.friendly = true
	bolt.element = element()
	bolt.direction = direction
	bolt.damage = 42.0 * damage_multiplier()
	bolt.speed = 34.0
	bolt.color = element_color()
	bolt.radius = 0.24
	bolt.position = origin + direction * 0.7
	game.combatants.add_child(bolt)
	visual.action("Cast", 0.34)
	if element() == "lightning":
		game.fx.lightning_arc(origin, flyer.global_position + Vector3.UP, 0.22)
	else:
		game.fx.burst(origin, FIRE_COLOR, 7)
	game.sound.play("lightning" if element() == "lightning" else "fire_slash", -3)
	shake = maxf(shake, 0.045)
	return true

func ultimate() -> void:
	if not is_gameplay_active() or dash_timer > 0 or attack_pending > 0:
		return
	if not spend_mana(ULTIMATE_COST):
		return
	# Mana is the recharge gate. Old saves may contain an 18-second cooldown;
	# that obsolete field must never block a fully recharged spell.
	ultimate_cooldown = 0
	spell_target = spell_aim_point()
	fire_timer = 1.20
	melee_timer = 1.20
	last_shot = 1.20
	invulnerable = maxf(invulnerable, 1.0)
	attack_pending = 0.84
	attack_kind = "ultimate"
	attack_yaw = yaw
	visual.rotation.y = attack_yaw
	# Keep the gather pose alive for the full mana channel. The old 0.38 s
	# one-shot fell back to idle midway through the 0.84 s charge.
	visual.action("Cast", 0.84)
	var gather := MANA_GATHER.new()
	gather.caster = self
	gather.color = element_color()
	gather.duration = 0.84
	game.fx.add_child(gather)
	game.sound.play("charge")
	game.shots += 1
	_combat_stance_timer = 6.0

func dodge() -> void:
	if not is_instance_valid(game) or not game.state in ["playing", "world"] or dash_cooldown > 0:
		return
	dash_timer = 0.27
	dash_cooldown = 0.68
	invulnerable = maxf(invulnerable, 0.32)
	attack_pending = 0
	attack_kind = ""
	var input_vector: Vector2 = movement_input()
	dash_direction = Basis(Vector3.UP, yaw) * Vector3(input_vector.x, 0, input_vector.y)
	if dash_direction.length_squared() < 0.01:
		dash_direction = -Basis(Vector3.UP, yaw).z
	dash_direction = dash_direction.normalized()
	visual.rotation.y = atan2(-dash_direction.x, -dash_direction.z)
	visual.action("Roll", 0.27)
	game.fx.burst(global_position + Vector3.UP * 0.3, Color("e9ccb3"), 10)
	game.sound.play("dash", -4)
	_combat_stance_timer = 6.0

func shoot() -> void:
	sword_attack()

func melee() -> void:
	sword_attack()

func receive_damage(amount: float, _hit_position: Vector3 = Vector3.ZERO) -> void:
	if not is_gameplay_active() or invulnerable > 0:
		return
	health = maxf(0, health - amount)
	invulnerable = 0.42
	game.hud.damage_flash = 0.45
	shake = 0.14
	game.sound.play("hurt")
	if health <= 0:
		attack_pending = 0
		visual.action("Death01")
		game.finish(false)

func is_gameplay_active() -> bool:
	return is_instance_valid(game) and game.state == "playing"
