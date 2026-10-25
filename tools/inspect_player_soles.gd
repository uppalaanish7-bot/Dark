extends "res://tests/player_combat_validation.gd"

func run() -> void:
	for id in ["female", "omega"]:
		var actor: Node3D = PLAYER.new()
		actor.asset_id = id
		root.add_child(actor)
		for i in 60: actor.tick(1.0 / 60.0, 0, true)
		print(id, " idle bounds ", rest_bounds(actor), " feet ", actor._player_feet)
		for clip in ["Sword_Attack", "Cast", "Fire_Cast"]:
			actor.action(clip)
			for i in 8:
				actor.tick(actor._action_duration / 8.0, 0, true)
				print(id, " ", clip, " ", i, " sole ", rest_bounds(actor).position.y)
		actor.free()
	quit()
