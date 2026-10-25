extends SceneTree
## Real profile writes keep run growth, resources and defeated foes together.
const PROGRESS = preload("res://scripts/progress.gd")
const SESSION = preload("res://scripts/world_session.gd")
const GROWTH = preload("res://scripts/player_growth.gd")
const LAYOUT = preload("res://scripts/tower_layout.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error(detail)

func run() -> void:
	var path := "res://tests/.growth_session_%d.cfg" % Time.get_ticks_usec()
	var progress := PROGRESS.new(path)
	var growth := GROWTH.new()
	growth.earn(1000)
	growth.spend("power")
	growth.spend("health")
	var original := run_snapshot(growth.snapshot())
	check(progress.update_session(1, original), "Initial upgraded run writes to disk")
	var loaded := PROGRESS.new(path)
	loaded.load_progress()
	check(loaded.session_for_world() == SESSION.sanitize(original, 1), "Disk load restores XP, upgrades, resources and every surviving foe")
	check(loaded.session_for_world().growth == growth.snapshot(), "The checkpoint owns arena growth even if the top-level copy is stale")
	growth.earn(28)
	var rewarded: Dictionary = loaded.session_for_world().duplicate(true)
	rewarded.checkpoint.growth = growth.snapshot()
	rewarded.checkpoint.enemies.pop_back()
	rewarded.checkpoint.player.health = 87.0
	rewarded.checkpoint.floor_keys[0] = true
	rewarded.checkpoint.discovered_rooms[0] = 3
	rewarded.checkpoint.roaming_timer = 9.5
	progress.earn(10, false)
	check(progress.update_session(1, rewarded), "Kill reward and defeated-enemy snapshot save together")
	loaded = PROGRESS.new(path)
	loaded.load_progress()
	check(loaded.coins == 10 and loaded.session_for_world().growth.xp == growth.xp and loaded.session_for_world().checkpoint.enemies.size() == 1, "Reopening never pairs a paid kill with a resurrected enemy")
	check(loaded.session_for_world().player.health == 87 and loaded.session_for_world().checkpoint.floor_keys[0] and loaded.session_for_world().checkpoint.discovered_rooms[0] == 3 and loaded.session_for_world().checkpoint.roaming_timer == 9.5, "Key discovery and spawn countdown survive the same transaction")
	var backup := PROGRESS.new(path + ".bak")
	backup.load_progress()
	check(backup.coins == 0 and backup.session_for_world().growth.xp == 820 and backup.session_for_world().checkpoint.enemies.size() == 2, "Backup is the preceding complete transaction")
	var first_world: Dictionary = loaded.session_for_world().duplicate(true)
	check(progress.create_world("Separate run"), "A second world can be created")
	var second_id: int = progress.active_world
	check(progress.session_for_world().growth == GROWTH.sanitize({}), "New worlds start with their own zero XP and base levels")
	var second: Dictionary = SESSION.fresh()
	second.visited = true
	second.growth.xp = 77
	check(progress.update_session(second_id, second), "Second world's independent growth saves")
	check(not progress.update_session(1, SESSION.fresh()), "A stale runtime cannot overwrite an inactive world")
	check(progress.select_world(1), "Returning to the first world succeeds")
	check(progress.session_for_world() == first_world and progress.session_for_world(second_id).growth.xp == 77, "Switching worlds preserves separate XP, upgrades and survivors")
	var pending: Dictionary = first_world.duplicate(true)
	pending.checkpoint.growth.xp += 180
	pending.checkpoint.enemies.clear()
	progress.earn(100, false)
	progress.path = path + ".missing/progress.cfg"
	check(not progress.update_session(1, pending) and not progress.error.is_empty(), "A failed disk write reports failure")
	check(progress.session_for_world().checkpoint.enemies.is_empty() and progress.session_for_world().growth.xp == growth.xp + 180 and progress.coins == 110, "Failed writes retain one coherent pending reward and enemy snapshot in memory")
	progress.path = path
	check(progress.save() and progress.error.is_empty(), "A later successful transaction persists the pending save")
	loaded = PROGRESS.new(path)
	loaded.load_progress()
	check(loaded.coins == 110 and loaded.session_for_world().checkpoint.enemies.is_empty() and loaded.session_for_world().growth.xp == growth.xp + 180, "Recovery never pairs pending coins or XP with old enemies")
	backup = PROGRESS.new(path + ".bak")
	backup.load_progress()
	var backup_worlds: Array[Dictionary] = backup.worlds.duplicate(true)
	var backup_coins: int = backup.coins
	check(DirAccess.rename_absolute(path, path + ".removed") == OK, "Primary can be set aside to exercise backup recovery")
	var recovered := PROGRESS.new(path)
	recovered.load_progress()
	check(not recovered.primary_valid and recovered.worlds == backup_worlds and recovered.coins == backup_coins, "Missing-primary recovery restores a whole backup transaction")
	check(recovered.save(), "Recovered progress can be saved again")
	backup = PROGRESS.new(path + ".bak")
	backup.load_progress()
	check(backup.worlds == backup_worlds and backup.coins == backup_coins, "Saving after recovery preserves the known-good backup")
	for suffix in ["", ".bak", ".tmp", ".removed"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("GROWTH SESSION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func run_snapshot(growth: Dictionary) -> Dictionary:
	var snapshot := SESSION.fresh()
	snapshot.visited = true
	snapshot.place = "arena"
	snapshot.position = LAYOUT.center(0) + Vector3(0, 0, 18)
	snapshot.checkpoint = {
		"version": SESSION.VERSION, "completed_encounters": 0, "encounter_active": true,
		"growth": growth, "player": {"health": 132, "mana": 41},
		"floor_keys": [false, false, false, false, false, false, false, false, false, false, false],
		"discovered_rooms": [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		"enemies": [
			{"boss": true, "position": LAYOUT.center(0), "health": 231, "recalled_servants": 1},
			{"boss": false, "position": LAYOUT.center(0) + Vector3(8, 0, 0), "health": 71}
		]
	}
	return snapshot
