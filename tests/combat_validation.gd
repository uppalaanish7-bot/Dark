extends SceneTree
const PLAYER = preload("res://player.gd")
const ENEMY = preload("res://scripts/enemy.gd")
const HAZARD = preload("res://scripts/combat_hazard.gd")
const PROJECTILE = preload("res://scripts/magic_projectile.gd")
const DATA = preload("res://scripts/encounter_data.gd")
var checks: int = 0
var failures: Array[String] = []
var game: TestGame

class TestHUD extends Control:
	var damage_flash: float = 0
	var announcements: int = 0
	var last_title: String = ""
	func announce(title: String, _body: String) -> void:
		announcements += 1
		last_title = title

class TestArena extends Node3D:
	func route(from: Vector3, to: Vector3) -> PackedVector2Array:
		return PackedVector2Array([Vector2(from.x, from.z), Vector2(to.x, to.z)])
	func is_walkable(_pos: Vector3) -> bool:
		return true

class TestGame extends Node3D:
	var state: String = "playing"
	var session_id: int = 1
	var player: CharacterBody3D
	var fx: Node3D
	var sound: Node
	var arena: Node3D
	var hud: Control
	var combatants: Node3D
	var touch_controls: Control
	var sensitivity: float = 0.0025
	var mobile_controls: bool = false
	var camera_shake: bool = false
	var shots: int = 0
	var hits: int = 0
	var kills: int = 0
	func register_hit(_critical: bool) -> void:
		hits += 1
	func enemy_defeated(_pos: Vector3, _critical: bool, _boss: bool) -> void:
		kills += 1
	func finish(_win: bool) -> void:
		state = "dead"

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("COMBAT TEST: " + message)

func freeze_combatants() -> void:
	for node in game.combatants.get_children():
		node.set_physics_process(false)

func clear_combatants() -> void:
	for node in game.combatants.get_children():
		node.free()

func make_actor(index: int, boss: bool) -> CharacterBody3D:
	var actor := ENEMY.new()
	actor.game = game
	actor.encounter_index = index
	actor.is_boss = boss
	actor.asset_id = DATA.record(index).boss_id if boss else DATA.record(index).soldier_id
	actor.home_position = Vector3.ZERO
	actor.position = Vector3.ZERO
	game.combatants.add_child(actor)
	actor.set_physics_process(false)
	return actor

func run() -> void:
	for action in ["left", "right", "forward", "back", "sprint", "aim", "fire"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	game = TestGame.new()
	root.add_child(game)
	game.fx = preload("res://scripts/effects.gd").new()
	game.add_child(game.fx)
	game.sound = preload("res://scripts/sound.gd").new()
	game.add_child(game.sound)
	game.arena = TestArena.new()
	game.add_child(game.arena)
	game.hud = TestHUD.new()
	game.add_child(game.hud)
	game.combatants = Node3D.new()
	game.add_child(game.combatants)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	floor_shape.shape = box
	floor_shape.position.y = -0.5
	floor_body.add_child(floor_shape)
	game.add_child(floor_body)
	game.player = PLAYER.new()
	game.player.game = game
	game.player.position = Vector3(0, 0.05, 7)
	game.add_child(game.player)
	game.player.set_physics_process(false)
	await physics_frame
	await physics_frame
	for i in range(12):
		game.player._physics_process(1.0 / 60.0)
		await physics_frame
	game.player.mana = 30
	game.player.mana_regen_delay = 0
	Input.action_press("forward")
	Input.action_press("sprint")
	game.player._physics_process(0.2)
	check(game.player.mana > 30, "Running regenerates mana instead of consuming it")
	check(Vector2(game.player.velocity.x, game.player.velocity.z).length() > 10, "Natural sprint accelerates beyond ten metres per second")
	Input.action_release("forward")
	Input.action_release("sprint")
	var before: float = game.player.mana
	game.player.dodge()
	check(is_equal_approx(game.player.mana, before), "Dodge does not consume mana")
	check(game.player.invulnerable > 0 and game.player.dash_cooldown > 0, "Dodge grants a bounded invulnerability window and cooldown")
	game.player.dash_timer = 0
	game.player.position = Vector3(0, 0.03, 7)
	game.player.velocity = Vector3.ZERO
	game.player.mana = 100
	game.player.invulnerable = 0
	game.player.update_camera(1)
	game.player.cast_firebolt()
	check(is_equal_approx(game.player.mana, 88), "Firebolt spends exactly 12 mana")
	check(get_nodes_in_group("magic_projectiles").is_empty() and game.player.attack_kind == "ranged", "Sword aim anticipates the ranged release")
	game.player.visual.tick(0.17, 0, true)
	game.player.attack_pending = 0
	game.player.resolve_attack()
	check(get_nodes_in_group("magic_projectiles").size() == 1, "Firebolt creates a real travelling projectile")
	freeze_combatants()
	clear_combatants()
	game.player.fire_slash()
	check(is_equal_approx(game.player.mana, 62), "Sword enchantment spends exactly 26 mana")
	check(game.player.enchantment_time == 12 and game.player.visual.weapon.has_node("LivingBladeFire"), "Fire enchantment stays on the actual sword for twelve seconds")
	game.player.attack_pending = 0
	game.player.resolve_attack()
	freeze_combatants()
	check(get_nodes_in_group("magic_projectiles").is_empty(), "Enchanting prepares melee without emitting unwanted extra projectiles")
	clear_combatants()
	game.player.mana = 100
	game.player.ultimate()
	check(is_equal_approx(game.player.mana, 30), "Meteor spends exactly 70 mana")
	check(game.player.ultimate_cooldown == 0, "Sky magic has no separate cooldown after mana restoration")
	game.player.visual.tick(0.60, 0.0, true)
	check(game.player.visual.current_clip == "Cast" and game.player.visual.one_shot_time > 0.20, "Ultimate gather stays in its cast pose through the 0.84-second charge")
	game.player.attack_pending = 0
	game.player.resolve_attack()
	freeze_combatants()
	check(get_nodes_in_group("player_sky_spells").size() == 1, "Girl Knight creates a falling meteor")
	clear_combatants()
	game.player.mana_regen_delay = 0
	game.player._physics_process(3.0)
	check(game.player.mana >= 70, "Mana naturally recharges enough for a second sky spell")
	game.player.ultimate()
	check(game.player.attack_kind == "ultimate" and game.player.mana < 30, "R can cast again in the same fight as soon as mana recharges")
	game.player.attack_pending = 0
	game.player.attack_kind = ""
	game.player.mana = 3
	game.player.magic_cooldown = 0
	game.player.cast_firebolt()
	check(game.player.mana == 3 and get_nodes_in_group("magic_projectiles").is_empty(), "Insufficient mana cannot cast or become negative")
	game.player.fire_timer = 0
	game.player.sword_attack()
	check(game.player.attack_pending > 0 and game.player.mana == 3, "Sword remains usable with empty mana")
	game.player.attack_pending = 0
	game.player.attack_kind = ""
	game.player.enchantment_time = 0
	var distinct_elements: Dictionary = {}
	for index in range(11):
		var actor: CharacterBody3D = make_actor(index, true)
		distinct_elements[actor.element] = true
		check(actor.element == DATA.record(index).element, "Guardian %d carries its own assigned element" % index)
		check(actor.asset_id == DATA.record(index).boss_id, "Guardian %d uses its assigned source asset" % index)
		check(actor.is_in_group("bosses"), "Guardian %d registers as a boss" % index)
		check(actor.magic_enabled() == (index >= 2), "Enemy magic begins on Floor 3")
		for cycle in range(3):
			var expected_spell_element: String = actor.element
			var prior_effect_ids: Dictionary = {}
			for effect in get_nodes_in_group("combat_hazards") + get_nodes_in_group("magic_projectiles"):
				prior_effect_ids[effect.get_instance_id()] = true
			if index == 10:
				# begin_attack() advances the counter, then selects the slot matching its previous value.
				var sequence_slot: int = actor.attack_number % actor.pattern_sequence.size()
				var signature_index: int = actor.pattern_sequence[sequence_slot]
				if signature_index == 5: expected_spell_element = "lightning"
				elif signature_index == 6: expected_spell_element = "fire"
				elif signature_index == 7: expected_spell_element = "ice"
				elif signature_index == 8: expected_spell_element = "wind"
			actor.attack_windup = 0
			actor.begin_attack()
			check(not actor.events.is_empty() or get_nodes_in_group("combat_hazards").size() > 0, "Guardian %d pattern %d creates a readable attack" % [index, cycle])
			actor.process_events(4.0)
			if index < 2:
				check(get_nodes_in_group("combat_hazards").is_empty() and get_nodes_in_group("magic_projectiles").is_empty(), "First two boss floors create no magical attacks")
			freeze_combatants()
			var matching_elements: bool = true
			for region in get_nodes_in_group("combat_hazards"):
				if prior_effect_ids.has(region.get_instance_id()): continue
				matching_elements = matching_elements and region.element == expected_spell_element
			for bolt in get_nodes_in_group("magic_projectiles"):
				if prior_effect_ids.has(bolt.get_instance_id()): continue
				matching_elements = matching_elements and bolt.element == expected_spell_element
			check(matching_elements, "Guardian %d pattern %d gives every spell the correct elemental effect" % [index, cycle])
		actor.take_damage(actor.max_health * 0.46)
		check(actor.phase == 2, "Guardian %d awakens below 55 percent health" % index)
		if index == 10:
			actor.take_damage(actor.max_health * 0.25)
			check(actor.phase == 3, "Main boss enters third eclipse phase below 30 percent")
			var awakened_speed: float = actor.speed
			actor.phase = 1
			actor.speed -= 0.9
			actor.update_health_label()
			check(actor.phase == 3 and is_equal_approx(actor.speed, awakened_speed), "Restoring low boss health restores both phase and movement speed")
			actor.attack_number = 0
			actor.pattern_sequence.clear()
			actor.pattern_sequence.append_array([0, 1, 2])
			actor.begin_attack()
			freeze_combatants()
			var waves: int = 0
			for region in get_nodes_in_group("combat_hazards"):
				if region.kind == "wave": waves += 1
			check(waves >= 4, "Final eclipse creates successive jumpable shockwaves")
			actor.pattern_sequence.clear()
			actor.pattern_sequence.append(3)
			actor.attack_number = 0
			actor.attack_windup = 0
			actor.begin_attack()
			var beam_count: int = 0
			for region in get_nodes_in_group("combat_hazards"):
				if region.kind == "line": beam_count += 1
			check(beam_count > 0, "Final boss black beam creates a warned line hazard")
			clear_combatants()
			actor = make_actor(10, true)
			actor.take_damage(actor.max_health * 0.71)
			actor.pattern_sequence.clear()
			actor.pattern_sequence.append(4)
			actor.attack_number = 0
			actor.attack_windup = 0
			actor.begin_attack()
			actor.process_events(1.1)
			var void_sphere_found: bool = false
			for projectile in get_nodes_in_group("magic_projectiles"):
				if projectile.element == "void" and is_equal_approx(projectile.radius, 0.72):
					void_sphere_found = true
			check(void_sphere_found, "Final boss dark sphere releases a distinct void projectile")
			var signature_moves: Array[Dictionary] = [
				{"pattern": 5, "cue": "Storm_Lance", "element": "lightning"},
				{"pattern": 6, "cue": "Ember_Burst", "element": "fire"},
				{"pattern": 7, "cue": "Frost_Lattice", "element": "ice"},
				{"pattern": 8, "cue": "Gale_Shear", "element": "wind"}
			]
			for move in signature_moves:
				clear_combatants()
				actor = make_actor(10, true)
				actor.phase = 3
				actor.attack_number = 0
				actor.pattern_sequence.clear()
				actor.pattern_sequence.append(int(move.pattern))
				var main_rig: Skeleton3D = actor.visual.skeleton
				var spine_bone: int = main_rig.find_bone("sculpt_spine")
				var spine_before: Quaternion = main_rig.get_bone_pose_rotation(spine_bone)
				actor.begin_attack()
				check(actor.visual.current_clip == move.cue and actor.visual.animator.has_animation(move.cue), "Final boss phase three uses its dedicated %s animation" % move.cue)
				for frame in 12: actor.visual.tick(1.0 / 60.0, 0.0, true)
				check(main_rig.get_bone_pose_rotation(spine_bone).angle_to(spine_before) > 0.03, "Final boss %s visibly articulates its torso during windup" % move.cue)
				var finite_pose: bool = true
				for bone in main_rig.get_bone_count():
					finite_pose = finite_pose and main_rig.get_bone_pose_rotation(bone).is_finite() and main_rig.get_bone_pose_scale(bone).distance_to(Vector3.ONE) < 0.0001
				check(finite_pose, "Final boss %s preserves finite rigid bone poses" % move.cue)
				var matching_effect: bool = false
				for hazard_node in get_nodes_in_group("combat_hazards"):
					if hazard_node.element == move.element:
						matching_effect = true
				if move.cue == "Ember_Burst":
					actor.process_events(1.0)
					for bolt in get_nodes_in_group("magic_projectiles"):
						if bolt.element == "fire": matching_effect = true
				check(matching_effect, "Final boss %s emits its matching elemental effect" % move.cue)
		actor.take_damage(actor.health + 1)
		check(actor.dead and not actor.is_in_group("enemies") and not actor.is_in_group("bosses"), "Dead guardian %d is removed before progression callback" % index)
		clear_combatants()
		var soldier: CharacterBody3D = make_actor(index, false)
		soldier.begin_attack()
		soldier.process_events(2)
		freeze_combatants()
		check(soldier.asset_id == DATA.record(index).soldier_id, "Retinue %d uses its matching source asset" % index)
		check(soldier.element == DATA.record(index).element, "Retinue %d shares its guardian's combat element" % index)
		clear_combatants()
	check(distinct_elements.size() == 11, "All eleven guardians have distinct elements")
	await check_enemy_melee_and_pursuit()
	check_hidden_target_regions()
	await check_elemental_mechanics()
	var protected_boss: CharacterBody3D = make_actor(0, true)
	game.player.position = Vector3(0, 0.03, 44)
	game.player.court_notice_active = false
	var reward_count: int = game.kills
	var notice_count: int = game.hud.announcements
	check(not protected_boss.take_damage(500), "A shot from outside the 43m court cannot damage its guardian")
	check(protected_boss.health == protected_boss.max_health and protected_boss.ward.visible and protected_boss.ward_pulse > 0, "Blocked damage displays a visible court ward")
	check(game.hud.last_title == "COURT WARD ACTIVE" and game.hud.announcements == notice_count + 1, "Blocked damage explains how to remove the protection")
	protected_boss.take_damage(99999)
	check(game.hud.announcements == notice_count + 1, "Repeated blocked attacks do not spam the court warning")
	check(game.kills == reward_count and not protected_boss.dead, "Lethal damage outside the court grants no reward or death callback")
	var accepted_hits: int = game.hits
	var damage_labels: int = game.fx.find_children("*", "Label3D", true, false).size()
	var blocked_bolt := PROJECTILE.new()
	blocked_bolt.game = game
	blocked_bolt.caster = game.player
	blocked_bolt.friendly = true
	blocked_bolt.damage = 62
	game.combatants.add_child(blocked_bolt)
	blocked_bolt.impact(protected_boss.global_position + Vector3.UP, protected_boss)
	check(game.hits == accepted_hits and game.fx.find_children("*", "Label3D", true, false).size() == damage_labels, "A blocked firebolt shows neither false damage numbers nor an accepted hit")
	protected_boss._physics_process(0.1)
	check(game.kills == reward_count and protected_boss.is_in_group("enemies"), "Leashing an actor home never grants elimination rewards")
	game.player.position = Vector3(0, 0.03, 10)
	check(protected_boss.take_damage(70) and protected_boss.health == protected_boss.max_health - 70, "Returning inside the court immediately permits ordinary damage")
	var accepted_bolt := PROJECTILE.new()
	accepted_bolt.game = game
	accepted_bolt.caster = game.player
	accepted_bolt.friendly = true
	accepted_bolt.damage = 62
	game.combatants.add_child(accepted_bolt)
	accepted_bolt.impact(protected_boss.global_position + Vector3.UP, protected_boss)
	check(game.hits == accepted_hits + 1 and protected_boss.health == protected_boss.max_health - 132, "An in-court firebolt deals damage and registers feedback normally")
	protected_boss._physics_process(0.016)
	check(not protected_boss.ward.visible, "Ward vanishes when the player reenters combat range")
	protected_boss.take_damage(99999)
	check(game.kills == reward_count + 1 and protected_boss.dead, "Ordinary in-court defeat grants exactly one reward")
	check(not protected_boss.take_damage(99999) and game.kills == reward_count + 1, "Repeated corpse hits cannot grant duplicate rewards")
	clear_combatants()
	var protected_soldier: CharacterBody3D = make_actor(0, false)
	game.player.position.z = 44
	check(not protected_soldier.take_damage(99999) and not protected_soldier.dead, "Matching retinue cannot be farmed beyond the combat boundary")
	game.player.position.z = 8
	check(protected_soldier.take_damage(30), "Retinue takes damage normally after reentering the court")
	protected_soldier.stunned = 0
	check(protected_soldier.stagger_resistance > 0 and protected_soldier.take_damage(1) and is_zero_approx(protected_soldier.stunned), "Rapid light hits deal damage without refreshing soldier hit-stun")
	check(protected_soldier.take_damage(1, true) and protected_soldier.stunned > 0, "A critical hit always breaks through soldier stagger resistance")
	protected_soldier.stunned = 0
	protected_soldier.stagger_resistance = 0
	protected_soldier.knockback_velocity = Vector3.ZERO
	check(protected_soldier.take_damage(1, true, Vector3.RIGHT) and protected_soldier.knockback_velocity.x > 3.0 and protected_soldier.visual.current_clip == "Hit_Chest", "A clean finisher adds directional knockback and a visible hit reaction")
	game.player.position = Vector3(0, 0.03, 42.5)
	protected_soldier.path_timer = 0
	protected_soldier.pursue(game.player.global_position, 0.1)
	check(protected_soldier.target_point.z >= 40.9, "Chase range reaches the court edge instead of leaving a safe sniping band")
	protected_soldier.position = Vector3(0, 0.03, 41)
	protected_soldier.spawn_time = 0
	protected_soldier.stunned = 0
	protected_soldier.attack_cooldown = 0
	protected_soldier.melee_cooldown = 0
	protected_soldier._physics_process(0.016)
	check(protected_soldier.attack_windup > 0, "Even a melee retainer can retaliate just inside the ward boundary")
	clear_combatants()
	var caster: CharacterBody3D = make_actor(0, true)
	var wave := HAZARD.new()
	wave.game = game
	wave.caster = caster
	wave.kind = "wave"
	wave.radius = 12
	wave.current_radius = 5
	wave.width = 0.45
	wave.jumpable = true
	game.combatants.add_child(wave)
	wave.set_physics_process(false)
	game.player.position = Vector3(5, 0.03, 0)
	check(wave.player_inside(), "Grounded player on a shockwave is vulnerable")
	game.player.position.y = 1.5
	check(not wave.player_inside(), "Jumping clears the shockwave")
	game.player.position.y = 0.9
	check(not wave.player_inside(), "Feet above the visible low-wave crest already clear its damage region")
	game.player.position = Vector3(8, 0.03, 0)
	check(not wave.player_inside(), "Player outside a shockwave band is safe")
	var lane := HAZARD.new()
	lane.game = game
	lane.caster = caster
	lane.kind = "line"
	lane.width = 1
	lane.length = 12
	game.combatants.add_child(lane)
	lane.set_physics_process(false)
	game.player.position = Vector3(0, 0.03, -6)
	check(lane.player_inside(), "Locked lane hits inside the visible lane")
	game.player.position.x = 2.5
	check(not lane.player_inside(), "Sidestepping the locked lane avoids damage")
	game.player.position = Vector3(0, 0.03, 4)
	check(not lane.player_inside(), "A forward lane cannot hit behind its caster")
	game.player.invulnerable = 1
	var hp: float = game.player.health
	game.player.receive_damage(30)
	check(game.player.health == hp, "Dodge invulnerability prevents combat damage")
	game.player.invulnerable = 0
	game.player.receive_damage(30)
	check(game.player.health == hp - 30, "Vulnerable player takes the expected damage")
	clear_combatants()
	# A bolt crosses a very thin wall in a single tick and must stop there.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.position = Vector3(0, 1.4, -3)
	var wall_collision := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(6, 4, 0.12)
	wall_collision.shape = wall_box
	wall.add_child(wall_collision)
	game.add_child(wall)
	await physics_frame
	await physics_frame
	var bolt := PROJECTILE.new()
	bolt.game = game
	bolt.caster = game.player
	bolt.friendly = true
	bolt.position = Vector3(0, 1.2, 0)
	bolt.direction = Vector3.FORWARD
	bolt.speed = 100
	game.combatants.add_child(bolt)
	bolt.set_physics_process(false)
	bolt._physics_process(0.1)
	check(bolt.is_queued_for_deletion(), "Swept projectile collision stops a fast bolt at a thin wall")
	await process_frame
	wall.free()
	game.player.position = Vector3.ZERO
	game.player.attack_yaw = 0
	var front: CharacterBody3D = make_actor(0, false)
	front.position = Vector3(0, 0.03, -2)
	var rear: CharacterBody3D = make_actor(0, false)
	rear.position = Vector3(0, 0.03, 2)
	front.begin_attack()
	freeze_combatants()
	await physics_frame
	game.player.arc_damage(48, 3.4, 0.2, false)
	check(front.health == front.max_health - 48, "Sword arc damages a target in front")
	check(rear.health == rear.max_health, "Sword arc cannot damage a target behind the player")
	for region in get_nodes_in_group("combat_hazards"):
		region._physics_process(0.016)
		check(region.is_queued_for_deletion(), "Interrupting a soldier cancels its uncommitted attack warning")
	clear_combatants()
	game.player.position = Vector3(0, 0.05, 7)
	var flyer: CharacterBody3D = make_actor(3, false)
	flyer.position = Vector3(0, 0.05, 0)
	flyer.spawn_time = 10.0
	check(flyer.is_flyer(), "The supplied winged soldier is classified for flight behavior")
	for frame in range(48):
		await physics_frame
		flyer._physics_process(1.0 / 60.0)
	check(flyer.position.y > 2.4 and flyer.position.y < 3.8, "Winged soldier lifts into a stable midair hover (y=%.2f)" % flyer.position.y)
	game.player.yaw = 0.0
	game.player.pitch = -0.15
	game.player.update_camera(1.0)
	var aim_origin: Vector3 = game.player.camera.global_position
	var aim_direction: Vector3 = -game.player.camera.global_basis.z
	flyer.global_position = aim_origin + aim_direction * 8.0 - Vector3.UP * 1.0
	await physics_frame
	await physics_frame
	var flyer_aim: Dictionary = game.player.aim_hit()
	check(flyer_aim.hit.get("collider") == flyer, "Reticle ray can acquire the flying soldier at aerial height")
	game.player.mana = 100
	game.player.enchantment_time = 0
	game.player.fire_slash()
	var aerial_bolts: Array[Node] = get_nodes_in_group("magic_projectiles").filter(func(projectile): return projectile.friendly)
	check(aerial_bolts.size() == 1 and game.player.enchantment_time == 0, "Q launches its aerial magic bolt while preserving the normal blade enchant outside this case")
	clear_combatants()
	print("COMBAT_CHECKS ", checks, " FAILURES ", failures.size())
	for failure in failures: print("FAILED: ", failure)
	# Let one-shot particle timers release their callbacks before tree teardown.
	await create_timer(0.9).timeout
	game.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func check_enemy_melee_and_pursuit() -> void:
	game.player.position = Vector3(0, 0.03, -14)
	var runner: CharacterBody3D = make_actor(2, false)
	runner.spawn_time = 0
	runner.attack_cooldown = 5
	var start: Vector3 = runner.position
	for frame in range(20):
		runner._physics_process(1.0 / 60.0)
		await physics_frame
	check(runner.position.distance_to(start) > 2.0, "A ranged retainer visibly runs toward the player instead of parking at spell range")
	check(Vector2(runner.velocity.x, runner.velocity.z).length() > runner.speed * 1.3, "Long pursuit uses running speed")
	check((-runner.visual.global_basis.z).dot(Vector3.FORWARD) > 0.9, "Pursuit faces its route instead of sliding sideways")
	runner.position = Vector3(0, 0.03, -7.0)
	game.player.position.z = -12.0
	runner.path_timer = 0
	runner._physics_process(1.0 / 60.0)
	check(Vector2(runner.velocity.x, runner.velocity.z).length() > 4.0, "Ranged retainer keeps closing inside the old 6.5 metre stopping distance")
	runner.begin_attack()
	runner.movement_lock = 0
	runner._physics_process(1.0 / 60.0)
	check(runner.attack_windup > 0 and Vector2(runner.velocity.x, runner.velocity.z).length() > 2.0, "A caster resumes footsteps during spell recovery")
	clear_combatants()
	var fighter: CharacterBody3D = make_actor(1, false)
	fighter.spawn_time = 0
	fighter.attack_cooldown = 0
	fighter.melee_cooldown = 0
	game.player.health = 200
	game.player.invulnerable = 0
	game.player.position = Vector3(0, 0.03, -1.3)
	fighter._physics_process(1.0 / 60.0)
	check(not fighter.melee_weapon() and fighter.attack_is_melee, "An unarmed caster chooses a physical punch when the player is close")
	check(not fighter.casting_aura.visible and get_nodes_in_group("combat_hazards").is_empty(), "A punch has no spell aura or area damage warning")
	var before: float = game.player.health
	fighter.process_events(0.1)
	check(game.player.health == before, "A punch cannot damage before its visible contact frame")
	fighter.process_events(0.3)
	check(is_equal_approx(game.player.health, before - 11.6), "The unarmed punch lands its intended single contact damage")
	game.player.invulnerable = 0
	fighter.process_events(2.0)
	check(is_equal_approx(game.player.health, before - 11.6), "One punch cannot damage twice")
	fighter.attack_windup = 0
	fighter.begin_attack()
	check(fighter.attack_is_melee and get_nodes_in_group("combat_hazards").is_empty(), "Second-floor unarmed fighter uses physical attacks without magic")
	clear_combatants()
	var armed: CharacterBody3D = make_actor(0, true)
	game.player.position = Vector3(0, 0.03, -2.0)
	game.player.invulnerable = 0
	before = game.player.health
	armed.begin_melee()
	armed.process_events(0.5)
	check(armed.melee_weapon() and game.player.health == before - 19.0, "An armed guardian strikes with weapon reach and physical damage")
	clear_combatants()
	for dodge_case in ["behind", "range", "jump", "invulnerability", "interrupt", "court"]:
		fighter = make_actor(1, false)
		game.player.position = Vector3(0, 0.03, -1.3)
		game.player.invulnerable = 0
		fighter.begin_melee()
		before = game.player.health
		match dodge_case:
			"behind": game.player.position.z = 1.3
			"range": game.player.position.z = -3.0
			"jump": game.player.position.y = 1.6
			"invulnerability": game.player.invulnerable = 1.0
			"interrupt": fighter.take_damage(1.0)
			"court": game.player.position.z = 44.0
		fighter.process_events(1.0)
		check(game.player.health == before, "A physical blow respects %s avoidance" % dodge_case)
		clear_combatants()
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.position = Vector3(0, 1.0, -0.65)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.12)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	await physics_frame
	await physics_frame
	fighter = make_actor(1, false)
	game.player.position = Vector3(0, 0.03, -1.3)
	game.player.invulnerable = 0
	before = game.player.health
	fighter.begin_melee()
	fighter.process_events(1.0)
	check(game.player.health == before, "A punch cannot hit through solid architecture")
	wall.free()
	clear_combatants()
	game.player.health = 200
	game.player.invulnerable = 0

func check_hidden_target_regions() -> void:
	for kind in ["line", "disk", "pool", "wave"]:
		var caster: CharacterBody3D = make_actor(0, true)
		var region: Node3D = caster.hazard(kind, Vector3.ZERO, 6.0, 0.9, 1.0, 8.0)
		region.width = 0.5
		region.length = 4.0
		region.jumpable = kind == "wave"
		region.element = "fire" if kind == "disk" else ("lightning" if kind == "line" else ("water" if kind == "pool" else "stone"))
		game.combatants.add_child(region)
		region.set_physics_process(false)
		game.player.position = Vector3(0, 0.03, -1.0)
		game.player.invulnerable = 0
		var before: float = game.player.health
		check(region.find_children("*", "MeshInstance3D", true, false).is_empty(), "A pending %s has no ground preview meshes" % kind)
		region._physics_process(0.89)
		check(not region.active and region.get_child_count() == 0 and game.player.health == before, "A pending %s stays hidden and harmless until its release" % kind)
		region._physics_process(0.02)
		check(region.active and not region.find_children("*", "MeshInstance3D", true, false).is_empty(), "An active %s creates its elemental effect at release" % kind)
		region._physics_process(0.01)
		check(game.player.health == before - 8.0, "An active %s keeps its intended contact damage without a preview" % kind)
		game.player.invulnerable = 0
		region._physics_process(0.1)
		check(game.player.health == before - 8.0, "An active %s retains its bounded damage interval" % kind)
		clear_combatants()
	for canceled_by in ["interrupt", "death"]:
		var caster: CharacterBody3D = make_actor(1, false)
		var region: Node3D = caster.hazard("disk", Vector3.ZERO, 6.0, 0.9, 1.0, 8.0)
		game.combatants.add_child(region)
		region.set_physics_process(false)
		game.player.invulnerable = 0
		var before: float = game.player.health
		if canceled_by == "interrupt": caster.take_damage(1.0)
		else: caster.die(false)
		region._physics_process(1.0)
		check(region.is_queued_for_deletion() and not region.active and region.get_child_count() == 0 and game.player.health == before, "A hidden cast canceled by %s never activates or damages" % canceled_by)
		clear_combatants()
	game.player.health = 200
	game.player.invulnerable = 0

func check_elemental_mechanics() -> void:
	game.player.position = Vector3(2, 0.03, 0)
	game.player.velocity = Vector3.ZERO
	game.player.external_velocity = Vector3.ZERO
	game.player.invulnerable = 0
	game.player.health = game.player.MAX_HEALTH
	game.player.attack_pending = 0
	game.player.attack_kind = ""
	game.player.dash_timer = 0
	var water: CharacterBody3D = make_actor(1, true)
	var tide: Node3D = water.hazard("disk", Vector3.ZERO, 6, 0.01, 1.0, 10)
	game.combatants.add_child(tide)
	tide.set_physics_process(false)
	tide._physics_process(0.02)
	tide._physics_process(0.02)
	var tidal_force: float = game.player.external_velocity.x
	check(tidal_force > 6.5 and game.player.health == game.player.MAX_HEALTH - 10, "Tidal contact damages and pushes the player outward")
	clear_combatants()
	var wind: CharacterBody3D = make_actor(5, true)
	game.player.external_velocity = Vector3.ZERO
	var gust: Node3D = wind.hazard("disk", Vector3.ZERO, 6, 0.01, 1.0, 10)
	game.combatants.add_child(gust)
	gust.set_physics_process(false)
	gust._physics_process(0.02)
	gust._physics_process(0.02)
	check(game.player.external_velocity.x > tidal_force + 4.0, "Wind gusts push harder than water currents")
	clear_combatants()
	var ice: CharacterBody3D = make_actor(7, true)
	game.player.external_velocity = Vector3.ZERO
	var frost: Node3D = ice.hazard("disk", Vector3.ZERO, 6, 0.01, 1.0, 10)
	game.combatants.add_child(frost)
	frost.set_physics_process(false)
	frost._physics_process(0.02)
	frost._physics_process(0.02)
	check(is_equal_approx(game.player.slow_factor, 0.65) and game.player.slow_timer > 1.3, "Ice contact creates a bounded frost slow")
	game.player._physics_process(1.5)
	check(game.player.slow_factor == 1.0 and game.player.slow_timer == 0, "Natural movement speed returns when frost expires")
	game.player.dash_timer = 0.2
	game.player.apply_slow(0.55, 2)
	game.player.apply_combat_force(Vector3(12, 0, 0))
	check(game.player.slow_factor == 1.0 and game.player.external_velocity.is_zero_approx(), "A committed dodge evades elemental slow and knockback")
	game.player.dash_timer = 0
	clear_combatants()
	var gravity: CharacterBody3D = make_actor(8, true)
	game.player.position = Vector3(5, 0.03, 0)
	game.player.velocity = Vector3.ZERO
	game.player.external_velocity = Vector3.ZERO
	game.player.health = game.player.MAX_HEALTH
	gravity.field_at(Vector3.ZERO, 8, 0.01, 3.0, 0, 13.0)
	var orbit: Node = get_nodes_in_group("combat_hazards").back()
	orbit.set_physics_process(false)
	orbit._physics_process(0.02)
	var original_x: float = game.player.position.x
	for i in range(60):
		orbit._physics_process(1.0 / 60.0)
		game.player._physics_process(1.0 / 60.0)
		await physics_frame
	check(game.player.position.x < original_x - 1.5, "A sustained gravity field physically draws the player toward its center")
	check(game.player.external_velocity.x < -2, "Delta-scaled gravity is not erased by movement damping")
	clear_combatants()
	game.player.external_velocity = Vector3.ZERO
	game.player.velocity = Vector3.ZERO
	game.player.position = Vector3(0, 0.03, 7)
	var poison: CharacterBody3D = make_actor(6, true)
	poison.pools_at(Vector3.ZERO, 1, 3, 1, 10)
	freeze_combatants()
	check(get_nodes_in_group("combat_hazards").back().active_time == 7, "Poison denies ground longer than transient impact attacks")
	clear_combatants()
	var lava: CharacterBody3D = make_actor(9, true)
	lava.attack_number = 2
	lava.pattern_sequence.clear()
	lava.pattern_sequence.append_array([0, 1, 2])
	lava.begin_attack()
	freeze_combatants()
	var trails: Array[Node] = get_nodes_in_group("combat_hazards").filter(func(region): return region.kind == "pool")
	check(trails.size() == 4 and trails[0].position.distance_to(trails[3].position) > 10, "The molten charge leaves four separate lava patches along its route")
	clear_combatants()
	var soul: CharacterBody3D = make_actor(3, true)
	soul.recall_servants()
	freeze_combatants()
	var servants: Array[Node] = get_nodes_in_group("enemies").filter(func(actor): return not actor.is_boss)
	check(servants.size() == 2 and soul.recalled_servants == 2, "Soul recall creates exactly two matching, real combatants")
	var souls_match: bool = true
	for servant in servants:
		souls_match = souls_match and servant.encounter_index == 3 and servant.element == "soul" and servant.asset_id == DATA.record(3).soldier_id
		servant.die(false)
	check(souls_match, "Recalled servants use the Soul Shepherd's supplied retinue and element")
	soul.recall_servants()
	check(get_nodes_in_group("enemies").size() == 1 and soul.recalled_servants == 2, "Defeating recalled souls cannot create an unlimited summon or reward loop")
	clear_combatants()
	var target: CharacterBody3D = make_actor(0, true)
	target.position = Vector3(0, 0.03, 3)
	game.player.position = Vector3(0, 0.03, 7)
	game.player.attack_yaw = 0
	game.player.attack_kind = "slash"
	game.player.resolve_attack()
	freeze_combatants()
	check(is_equal_approx(target.max_health - target.health, 170), "Fire slash deals a substantial 170 direct damage before its travelling flame")
	check(get_nodes_in_group("magic_projectiles").size() == 1 and get_nodes_in_group("magic_projectiles")[0].damage == 55, "Fire slash adds a single 55-damage wave without triple-hit stacking")
	clear_combatants()
	game.player.health = game.player.MAX_HEALTH
	game.player.invulnerable = 0
