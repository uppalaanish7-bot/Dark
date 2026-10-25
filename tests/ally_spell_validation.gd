extends "res://tests/battle_royale_validation.gd"
## Real ally casts, with isolated profiles and deterministic impact timing.

func run() -> void:
	for skin in 2:
		var game := isolated_game()
		game.selected_skin = 1 - skin
		game.start_run()
		var bot: CharacterBody3D = game.ally_bot
		var boss: CharacterBody3D = get_first_node_in_group("bosses")
		bot.position = Vector3(20, 0.12, 60)
		game.player.position = Vector3(22, 0.12, 62)
		boss.position = Vector3(20, 0.12, 50)
		await physics_frame
		await physics_frame
		var initial_health: float = boss.health
		var player_health: float = game.player.health
		var ally_health: float = bot.health
		game.player.shake = 0
		bot.cast_ultimate(boss.global_position)
		var spell: Node3D = get_first_node_in_group("player_sky_spells")
		check(spell != null and spell.caster == bot, "Ally creates its own sky spell: skin %d" % skin)
		var voice_before: int = game.sound.voice_index
		game.state = "paused"
		spell._physics_process(1.0)
		check(spell.age == 0 and not spell.impacted, "Paused ally spell does not impact")
		game.state = "playing"
		spell._physics_process(0.79)
		check(not spell.impacted and boss.health == initial_health, "Ally cast respects anticipation")
		spell._physics_process(0.02)
		var damage := 320.0 if skin == 0 else 240.0
		check(spell.impacted and is_equal_approx(initial_health - boss.health, damage), "Ally delayed impact damages target once")
		check(game.sound.voice_index != voice_before, "Ally impact reaches its sound cue")
		var last_voice: AudioStreamPlayer = game.sound.voices[posmod(game.sound.voice_index - 1, game.sound.voices.size())]
		check(last_voice.stream == game.sound.streams["meteor" if skin == 0 else "thunder"], "Ally impact plays the correct elemental sound")
		check(game.player.shake >= 0.24, "Ally impact shakes the active player's camera")
		check(game.player.health == player_health and bot.health == ally_health, "Ally sky spell preserves friendly health")
		spell.impact()
		check(is_equal_approx(initial_health - boss.health, damage), "Repeated impact cannot duplicate damage")
		spell._physics_process(0.9)
		check(spell.is_queued_for_deletion(), "Ally spell expires after its effect")
		await process_frame
		check(get_nodes_in_group("player_sky_spells").is_empty(), "Expired sky spell leaves no active node")
		bot.cast_ultimate(boss.global_position)
		spell = get_first_node_in_group("player_sky_spells")
		game.session_id += 1
		spell._physics_process(1.0)
		check(spell.is_queued_for_deletion() and not spell.impacted, "Session change cancels pending ally spell")
		game.free()
		await process_frame
	# Finish the catalog's background prefetch before this short test exits.
	for id in preload("res://scripts/asset_catalog.gd").requested.keys():
		var prefetched: Node = preload("res://scripts/asset_catalog.gd").instantiate(id)
		if is_instance_valid(prefetched):
			prefetched.free()
	await process_frame
	for profile in test_profiles:
		for path in [profile, profile.get_basename() + "_progress.cfg"]:
			for suffix in ["", ".bak", ".tmp"]:
				DirAccess.remove_absolute(path + suffix)
	print("ALLY_SPELL_CHECKS: %d FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
