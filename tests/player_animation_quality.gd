extends SceneTree
## Runtime regression: planted boot geometry, continuous gait through attacks,
## action recovery and separate blade arcs on both supplied player skeletons.
const PLAYER = preload("res://scripts/character_visual.gd")
const CUTS := ["Sword_Attack","Sword_Attack02","Sword_Attack03"]
var failures: Array[String] = []
var records: Array = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func feet(actor: Node3D) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for leg in actor._player_feet:
		result.append(actor.to_local(actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(leg.foot).origin)))
	return result

func run() -> void:
	for identity in ["female","omega"]:
		var actor: Node3D = PLAYER.new()
		actor.asset_id=identity
		root.add_child(actor)
		check(actor._player_feet.size()==2,identity+": both articulated legs must be available")
		actor.set_motion_state(Vector3.ZERO,true,0,0,false,false)
		for n in 90: actor.tick(1.0/60.0,0,true)
		var planted := feet(actor)
		var drift := 0.0
		var sole_rotation_error := 0.0
		for clip in CUTS:
			actor.action(clip)
			for n in 45:
				actor.tick(1.0/60.0,0,true)
				var positions := feet(actor)
				for side in positions.size():
					drift=maxf(drift,positions[side].distance_to(planted[side]))
					var bone: int=actor._player_feet[side].foot
					var rest: Quaternion=actor.skeleton.get_bone_global_rest(bone).basis.orthonormalized().get_rotation_quaternion()
					var posed: Quaternion=actor.skeleton.get_bone_global_pose(bone).basis.orthonormalized().get_rotation_quaternion()
					sole_rotation_error=maxf(sole_rotation_error,rest.angle_to(posed))
			check(actor.current_clip=="Sword_Idle_Loop",identity+": "+clip+" must recover to guard")
		check(drift<0.025,identity+": planted foot drifts more than 2.5cm: "+str(drift))
		check(sole_rotation_error<0.01,identity+": grounded soles pitch off their rest plane")
		actor.action("Roll",0.27)
		check(actor.one_shot_time>=0.43,identity+": visual roll has no uncoiling recovery")
		for n in 50: actor.tick(1.0/60.0,0,true)
		actor.action("Jump_Land",0.13)
		check(actor.one_shot_time>=0.23,identity+": visual landing is accelerated past the impact pose")
		for n in 40: actor.tick(1.0/60.0,0,true)
		actor.set_motion_state(Vector3(0,0,-10),true,0,0,false,false)
		for n in 43: actor.tick(1.0/60.0,10,true)
		var phase: float=actor._locomotion_clock
		actor.action("Sword_Attack02")
		var max_phase_step := 0.0
		for n in 42:
			actor.tick(1.0/60.0,10,true)
			var next: float=actor._locomotion_clock
			max_phase_step=maxf(max_phase_step,absf(wrapf(next-phase,-0.5,0.5)))
			phase=next
		check(max_phase_step<0.05,identity+": gait phase jumps across moving attack: "+str(max_phase_step))
		# Ten metres/second is the current jog tier; sprint starts at 11.5.
		check(actor.current_clip=="Jog_Fwd_Loop",identity+": moving attack fails to return to locomotion")
		records.append({"id":identity,"max_planted_foot_drift_m":drift,"max_sole_rotation_error_rad":sole_rotation_error,"max_moving_attack_gait_step_cycles":max_phase_step})
		actor.free()
	var output := FileAccess.open("res://art/asset_review/player_animation_quality.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"actors":records,"failures":failures},"\t"))
	for failure in failures: push_error(failure)
	print("PLAYER_ANIMATION_QUALITY actors=",records.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
