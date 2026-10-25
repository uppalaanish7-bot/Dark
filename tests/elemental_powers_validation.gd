extends "res://tests/combat_validation.gd"
## Regression checks exercise real collisions, friendly AoE, enchant expiry,
## character selection and repeated casts with naturally regenerated mana.
func run() -> void:
	for action in ["left","right","forward","back","sprint","aim","fire"]:
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
	game.player = PLAYER.new()
	game.player.game = game
	game.player.position = Vector3(0,0.03,7)
	game.add_child(game.player)
	game.player.set_physics_process(false)
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	collider.shape.size = Vector3(200,1,200)
	collider.position.y = -0.5
	floor_body.add_child(collider)
	game.add_child(floor_body)
	await physics_frame
	await physics_frame
	check(game.player.health==200,"Both player forms start with 200 vitality")
	for skin in 2:
		game.player.visual.set_skin(skin)
		game.player.reset()
		game.player.position = Vector3(0,0.03,7)
		check(game.player.element()==("fire" if skin==0 else "lightning"),"Character selection chooses the correct element")
		var before_enchant: String = game.player.visual.current_clip
		game.player.fire_slash()
		check(game.player.visual.current_clip == before_enchant, "Q enchantment does not interrupt the current animation")
		check(game.player.mana==74 and game.player.enchantment_time==12,"Q spends 26 mana for twelve seconds of enchantment")
		var name: String = "LivingBladeFire" if skin==0 else "LivingBladeLightning"
		check(game.player.visual.weapon.has_node(name),"The matching effect is attached to the animated sword")
		var target: CharacterBody3D = make_actor(0,true)
		target.position = game.player.position+Vector3(0,0,-2.5)
		await physics_frame
		var hp: float = target.health
		game.player.fire_timer=0
		game.player.sword_attack()
		game.player.attack_pending=0
		game.player.resolve_attack()
		check(is_equal_approx(hp-target.health,48*1.8),"Enchanted first sword strike deals 80 percent extra damage")
		check(game.player.mana==74,"Enchanted swings do not keep draining mana")
		game.player._physics_process(12.1)
		check(game.player.enchantment_time==0 and not game.player.visual.weapon.has_node(name),"Enchantment expires and removes the sword effect")
		clear_combatants()
		game.player.position=Vector3(0,0.03,7)
		game.player.velocity=Vector3.ZERO
		var boss: CharacterBody3D = make_actor(0,true)
		boss.position=Vector3(0,0.03,-12)
		var other: CharacterBody3D = make_actor(1,true)
		other.position=Vector3(3,0.03,-14)
		await physics_frame
		await physics_frame
		game.player.mana=100
		game.player.magic_cooldown=0
		game.player.attack_pending=0
		game.player.update_camera(1)
		game.player.camera.look_at(boss.global_position+Vector3.UP*1.1)
		game.player.cast_firebolt()
		check(game.player.attack_kind == "ranged" and boss.health == boss.max_health, "Right-click aims the sword before releasing magic")
		game.player.visual.tick(0.17, 0, true)
		game.player.attack_pending = 0
		game.player.resolve_attack()
		if skin==1:
			check(boss.health==boss.max_health-68,"Arc Bolt damages a real enemy at the aimed release frame")
		else:
			var bolts: Array[Node] = get_nodes_in_group("magic_projectiles")
			check(bolts.size()==1 and bolts[0].element=="fire","Girl Knight fires a flame projectile")
			bolts[0].free()
		game.player.mana=100
		game.player.ultimate_cooldown=18 # Explicit legacy-save regression.
		game.player.ultimate()
		check(game.player.mana==30 and game.player.attack_kind=="ultimate","R ignores the retired cooldown when mana is available")
		game.player.attack_pending=0
		game.player.resolve_attack()
		var spell: Node = get_first_node_in_group("player_sky_spells")
		check(spell!=null and spell.element==game.player.element(),"R creates the selected character's sky spell")
		if skin==0: spell.position=boss.position
		var player_hp: float = game.player.health
		var boss_hp: float = boss.health
		var other_hp: float = other.health
		spell.impact()
		var damage: float = 320 if skin==0 else 240
		check(boss.health==boss_hp-damage and other.health==other_hp-damage,"Sky spell damages every enemy in its area")
		check(game.player.health==player_hp,"Sky spell never damages the caster")
		spell.impact()
		check(boss.health==boss_hp-damage,"Impact and lightning echoes do not duplicate damage")
		spell.free()
		var wall := StaticBody3D.new()
		var wall_shape := CollisionShape3D.new()
		wall_shape.shape = BoxShape3D.new()
		wall_shape.shape.size = Vector3(20,8,1)
		wall_shape.position = Vector3(0,3,-4)
		wall.add_child(wall_shape)
		game.add_child(wall)
		await physics_frame
		await physics_frame
		var protected_health: float = boss.health
		if skin==1:
			game.player.magic_cooldown=0
			game.player.mana=100
			game.player.cast_firebolt()
			game.player.visual.tick(0.17, 0, true)
			game.player.attack_pending = 0
			game.player.resolve_attack()
			check(boss.health==protected_health,"Ranged lightning cannot cross a wall")
			var blocked_storm := preload("res://scripts/player_sky_spell.gd").new()
			blocked_storm.game=game
			blocked_storm.caster=game.player
			blocked_storm.element="lightning"
			blocked_storm.position=game.player.position
			game.combatants.add_child(blocked_storm)
			blocked_storm.impact()
			check(boss.health==protected_health,"Thunderstorm respects walls")
			blocked_storm.free()
		wall.free()
		await physics_frame
		# XP Power levels apply once to ranged and ultimate damage for both
		# elements. The level-one checks above still protect original balance.
		game.player.restore_growth({"power_level":2})
		game.player.magic_cooldown = 0
		game.player.attack_pending = 0
		game.player.mana = 100
		game.player.camera.look_at(boss.global_position+Vector3.UP*1.1)
		var empowered_hp: float = boss.health
		game.player.cast_firebolt()
		game.player.visual.tick(0.17,0,true)
		game.player.attack_pending = 0
		game.player.resolve_attack()
		if skin == 1:
			check(is_equal_approx(empowered_hp-boss.health,68.0*1.1),"Power level scales Arc Bolt damage exactly once")
		else:
			var empowered_bolts: Array[Node] = get_nodes_in_group("magic_projectiles")
			check(empowered_bolts.size()==1 and is_equal_approx(empowered_bolts[0].damage,62.0*1.1),"Power level scales fire projectile damage exactly once")
			for bolt in empowered_bolts: bolt.free()
		var empowered_spell := preload("res://scripts/player_sky_spell.gd").new()
		empowered_spell.game = game
		empowered_spell.caster = game.player
		empowered_spell.element = game.player.element()
		empowered_spell.position = boss.position if skin == 0 else game.player.position
		game.combatants.add_child(empowered_spell)
		boss.health = boss.max_health
		other.health = other.max_health
		empowered_hp = boss.health
		empowered_spell.impact()
		check(is_equal_approx(empowered_hp-boss.health,(320.0 if skin==0 else 240.0)*1.1),"Power level scales sky spell damage exactly once: skin=%d before=%f after=%f" % [skin,empowered_hp,boss.health])
		empowered_spell.free()
		boss.health = boss.max_health
		other.health = other.max_health
		empowered_hp = boss.health
		game.player.attack_yaw = 0
		game.player.arc_damage(50,25,-1,false)
		check(is_equal_approx(empowered_hp-boss.health,55),"Power level scales sword damage exactly once")
		game.player.restore_growth({})
		game.player.mana=30
		game.player.mana_regen_delay=0
		game.player._physics_process(3.0)
		game.player.ultimate()
		check(game.player.attack_kind=="ultimate" and game.player.mana<30,"A second R works in the same encounter after natural mana regeneration")
		game.player.attack_pending=0
		game.player.attack_kind=""
		clear_combatants()
	game.free()
	await process_frame
	print("ELEMENTAL_POWER_CHECKS ",checks," FAILURES ",failures.size())
	quit(0 if failures.is_empty() else 1)
