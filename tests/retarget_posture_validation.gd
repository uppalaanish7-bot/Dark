extends SceneTree
const VISUAL = preload("res://scripts/character_visual.gd")
const ENEMY = preload("res://scripts/provided_visual.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for identity in ["female","omega","subboss_1"]:
		var actor: Node3D = VISUAL.new() if identity != "subboss_1" else ENEMY.new()
		actor.asset_id = identity
		root.add_child(actor)
		for clip in ["rest","Sword_Idle_Loop","Walk_Loop","Sprint_Loop"]:
			actor.skeleton.reset_bone_poses()
			if clip != "rest":
				actor.animator.play(clip,0)
				actor.animator.seek(actor.animator.get_animation(clip).length*0.35,true)
			for bone in actor.skeleton.get_bone_count():
				var key: String = actor.skeleton.get_bone_name(bone).to_lower()
				if key.contains("hips") or key.contains("pelvis") or key.contains("head") or key=="_rootjoint":
					print(identity," ",clip," ",key," rest=",actor.skeleton.get_bone_rest(bone)," pose=",actor.skeleton.get_bone_pose(bone)," global=",actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(bone).origin))
		actor.free()
	quit()
