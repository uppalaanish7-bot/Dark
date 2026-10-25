extends SceneTree
const VISUAL = preload("res://scripts/provided_visual.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func run() -> void:
	for id in ["soldier_1", "subboss_7"]:
		for height in [2.1, 3.0]:
			var actor := VISUAL.new()
			actor.asset_id = id
			actor.target_height = height
			root.add_child(actor)
			var prop: MeshInstance3D = actor.get_node("SuppliedSwordGrip" if id=="soldier_1" else "SuppliedRifleGrip")
			var hand := actor.skeleton.find_bone("R_wrist_063" if id=="soldier_1" else "npc_soldier_knight_arm_hand_rt_030")
			var initial := Vector3.ZERO
			var most_moved := 0.0
			var original_count := 0
			for original in actor.model.find_children("*","MeshInstance3D",true,false):
				var source_weapon: bool = original.name=="sword_sword_0"
				for surface in original.mesh.get_surface_count():
					var mat: Material = original.mesh.surface_get_material(surface)
					source_weapon = source_weapon or (mat != null and "sentinelrifl" in mat.resource_name.to_lower())
				if source_weapon:
					check(not original.visible,id+" hides its detached exported prop")
					for surface in original.mesh.get_surface_count(): original_count+=original.mesh.surface_get_array_len(surface)
			var repaired_count := 0
			for surface in prop.mesh.get_surface_count(): repaired_count+=prop.mesh.surface_get_array_len(surface)
			check(repaired_count==original_count and original_count>0,id+" retains the supplied weapon vertices")
			var attack: String = "Rifle_Butt" if id == "subboss_7" else "Sword_Attack"
			var special: String = "Rifle_Aim_Shot" if id == "subboss_7" else "Sword_Attack03"
			for clip in ["Sword_Idle_Loop", "Jog_Fwd_Loop", attack, special, "Death01"]:
				for phase in [0.0,0.2,0.43,0.74,0.98]:
					actor.action(clip, 1.0)
					actor.animator.play(clip, 0)
					actor.animator.seek(actor.animator.get_animation(clip).length * phase, true)
					actor.one_shot_time = 1.0 - phase
					actor.update_weapon()
					var wrist: Vector3 = actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(hand).origin)
					check(prop.global_position.distance_to(wrist)<0.23*height/2.1,id+" grip follows the palm through "+clip)
					check(prop.global_basis.get_scale().distance_to(Vector3.ONE*height/2.1)<0.003,id+" weapon retains rigid source dimensions")
					if clip == attack:
						# A rifle pivots between both palms; measure its rigid muzzle
						# corner rather than requiring the pistol grip to leave them.
						var point: Vector3 = prop.to_global(prop.mesh.get_aabb().position) if id == "subboss_7" else prop.global_position
						if phase == 0.0: initial = point
						else: most_moved = maxf(most_moved, point.distance_to(initial))
			check(most_moved>0.25,id+" visibly swings its actual weapon during contact animation")
			actor.free()
	print("ENEMY_LOADOUT_CHECKS ",checks," FAILURES ",failures.size())
	for failure in failures: print("FAILED: ",failure)
	quit(0 if failures.is_empty() else 1)
