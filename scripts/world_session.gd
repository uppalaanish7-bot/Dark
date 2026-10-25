extends RefCounted
## The entire run is one transaction: XP, keys, exploration and surviving foes.
const VERSION := 4
const LAYOUT = preload("res://scripts/tower_layout.gd")
const GROWTH = preload("res://scripts/player_growth.gd")
const COURTYARD_SPAWN := Vector3(0, 0.1, 170)
static var ARENA_SPAWN: Vector3 = LAYOUT.floor_spawn(0)
const LEGACY_CENTERS := [Vector3(-44, 0, 145), Vector3(44, 0, 114), Vector3(-44, 0, 83), Vector3(44, 0, 52), Vector3(-44, 0, 21), Vector3(44, 0, -10), Vector3(-44, 0, -41), Vector3(44, 0, -72), Vector3(0, 0, -107), Vector3(0, 0, -150), Vector3(0, 0, -194)]
const MAX_ENEMIES := 20

static func number(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	if not (value is float or value is int) or not is_finite(float(value)):
		return fallback
	return clampf(float(value), minimum, maximum)

static func vector(value: Variant, fallback: Vector3, limit: float = 600.0) -> Vector3:
	if not value is Vector3 or not value.is_finite():
		return fallback
	if absf(value.x) > limit or absf(value.y) > limit or absf(value.z) > limit:
		return fallback
	return value

static func position(value: Variant, place: String) -> Vector3:
	var fallback := ARENA_SPAWN if place == "arena" else COURTYARD_SPAWN
	var result := vector(value, fallback)
	var bounds: Rect2 = LAYOUT.floor_bounds().grow(0.5) if place == "arena" else Rect2(-224,-244,448,488)
	var y_limit := LAYOUT.ROOF_HEIGHT+14.0 if place == "arena" else 65.0
	if not bounds.has_point(Vector2(result.x,result.z)) or result.y < -0.1 or result.y > y_limit:
		return fallback
	return result

static func fresh() -> Dictionary:
	return {"version": VERSION, "visited": false, "place": "courtyard", "position": COURTYARD_SPAWN, "yaw": 0.0, "pitch": 0.22, "level": 1, "growth":GROWTH.sanitize({}), "player": sanitize_player({}, GROWTH.sanitize({})), "checkpoint": {}}

static func migrate(world: Dictionary) -> Dictionary:
	if world.get("session") is Dictionary:
		return sanitize(world.session, 1)
	return fresh()

static func sanitize(raw: Dictionary, _selected_level: int) -> Dictionary:
	var result := fresh()
	result.visited = raw.get("visited", false) == true
	result.place = "arena" if raw.get("place") == "arena" else "courtyard"
	result.position = position(raw.get("position"), result.place)
	result.yaw = number(raw.get("yaw"), 0, -1000000, 1000000)
	result.pitch = number(raw.get("pitch"), -0.15, -1.05, 0.9)
	result.growth = GROWTH.sanitize(raw.growth if raw.get("growth") is Dictionary else {})
	result.player = sanitize_player(raw.player if raw.get("player") is Dictionary else {}, result.growth)
	if raw.get("checkpoint") is Dictionary:
		result.checkpoint = sanitize_checkpoint(raw.checkpoint, 1)
	if result.place == "arena":
		if result.checkpoint.is_empty():
			result.position = ARENA_SPAWN
		elif result.checkpoint.get("status", "") == "dead":
			result.position = LAYOUT.floor_spawn(0)
		elif int(number(raw.get("version"), 0, 0, 99)) == 2:
			var stage: int = result.checkpoint.encounter_index
			result.position = migrate_arena_position(raw.get("position"), stage)
			if not result.checkpoint.encounter_active:
				result.position = LAYOUT.floor_spawn(stage)
		if not result.checkpoint.is_empty():
			result.growth = result.checkpoint.growth.duplicate(true)
			result.player = result.checkpoint.player.duplicate(true)
			if LAYOUT.floor_for_position(result.position) > unlocked_floor(result.checkpoint):
				result.position = LAYOUT.floor_spawn(unlocked_floor(result.checkpoint))
	return result

static func unlocked_floor(checkpoint: Dictionary) -> int:
	var completed := int(number(checkpoint.get("completed_encounters"), 0, 0, LAYOUT.FLOOR_COUNT))
	var keys: Array = checkpoint.get("floor_keys", [])
	for stage in completed:
		if stage >= keys.size() or keys[stage] != true: return stage
	return completed

static func sanitize_player(raw: Dictionary, growth: Dictionary) -> Dictionary:
	var health_cap: float = 200.0+(growth.health_level-1)*GROWTH.HEALTH_PER_LEVEL
	var mana_cap: float = 100.0+(growth.mana_level-1)*GROWTH.MANA_PER_LEVEL
	var result := {"health": number(raw.get("health"), health_cap, 1, health_cap), "mana": number(raw.get("mana"), mana_cap, 0, mana_cap), "shoulder": number(raw.get("shoulder"), 1, -1, 1)}
	for key in ["magic_cooldown", "slash_cooldown", "ultimate_cooldown", "mana_regen_delay", "dash_cooldown"]:
		result[key] = number(raw.get(key), 0, 0, 30)
	result.ultimate_cooldown = 0.0
	result.enchantment_time = number(raw.get("enchantment_time"), 0, 0, 12)
	return result

static func migrate_arena_position(value: Variant, stage: int) -> Vector3:
	var offset: Vector3 = vector(value, LEGACY_CENTERS[stage]) - LEGACY_CENTERS[stage]
	return LAYOUT.center(stage)+Vector3(clampf(offset.x,-22,22),0,clampf(offset.z,-22,24))

static func sanitize_checkpoint(raw: Dictionary, _level: int) -> Dictionary:
	var source_version := int(number(raw.get("version"), 0, 0, 99))
	if source_version not in [2, 3, VERSION] or not raw.get("player") is Dictionary:
		return {}
	var completed := int(number(raw.get("completed_encounters"), 0, 0, 11))
	var stage := mini(completed, 10)
	var run_dead: bool = raw.get("status", "") == "dead"
	var keys: Array[bool] = []
	var rooms: Array[int] = []
	for i in LAYOUT.FLOOR_COUNT:
		keys.append(i < completed if source_version < 4 else (raw.get("floor_keys") is Array and raw.floor_keys.size()>i and raw.floor_keys[i] == true))
		rooms.append(int(number(raw.discovered_rooms[i],0,0,31)) if raw.get("discovered_rooms") is Array and raw.discovered_rooms.size()>i else 0)
	var cleared: bool = completed == 11 and keys[10] and raw.get("level_complete", false) == true
	var result := {"version": VERSION, "level": 1, "status": "dead" if run_dead else "playing", "encounter_index": stage, "completed_encounters": completed, "encounter_active": raw.get("encounter_active", false) == true and not cleared and not run_dead, "level_complete": cleared, "player": {}, "enemies": []}
	result.potion_collected = cleared and raw.get("potion_collected", false) == true
	result.floor_keys = keys
	result.discovered_rooms = rooms
	result.growth = GROWTH.sanitize(raw.growth if raw.get("growth") is Dictionary else {})
	result.roaming_timer = number(raw.get("roaming_timer"),16,0,22)
	if completed == 11 or run_dead: result.encounter_active = false
	for key in ["score", "kills", "shots", "hits", "run_coins", "combo"]:
		result[key] = int(number(raw.get(key), 0, 0, 2000000000))
	result.combo = mini(result.combo, 5)
	for key in ["combo_timer", "elapsed"]:
		result[key] = number(raw.get(key), 0, 0, 10000000)
	result.player = sanitize_player(raw.player, result.growth)
	if run_dead:
		result.player.health = 0.0
	if raw.get("enemies") is Array and not run_dead:
		for entry in raw.enemies.slice(0, MAX_ENEMIES):
			if not entry is Dictionary:
				continue
			var roaming: bool = entry.get("roaming",false)==true and entry.get("boss",false)!=true
			var enemy_stage: int = int(number(entry.get("stage"),stage,0,10)) if roaming else stage
			if not roaming and not result.encounter_active: continue
			var at := migrate_arena_position(entry.get("position"), enemy_stage) if source_version == 2 else position(entry.get("position"), "arena")
			if absf(at.y - enemy_stage * LAYOUT.FLOOR_HEIGHT) > 5.0: at = LAYOUT.center(enemy_stage)
			var home := position(entry.get("home",at),"arena") if roaming else LAYOUT.center(enemy_stage)
			if absf(home.y-at.y)>5: home=at
			result.enemies.append({"boss":entry.get("boss",false)==true,"roaming":roaming,"stage":enemy_stage,"home":home,"position":at,"health":number(entry.get("health"),100,1,5000),"recalled_servants":int(number(entry.get("recalled_servants"),0,0,2))})
	return result
