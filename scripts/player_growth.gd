extends RefCounted
## Run-owned XP and levels. WorldSession serializes snapshot() alongside enemies
## and vital values, so loading a checkpoint cannot restore spent XP separately.
const MAX_LEVEL := 99
const MAX_XP := 2000000000
const HEALTH_PER_LEVEL := 20.0
const MANA_PER_LEVEL := 10.0
const POWER_PER_LEVEL := 0.10
const KINDS := ["heal", "mana", "power", "health", "magic", "overall"]
var xp: int = 0
var level: int = 1
var power_level: int = 1
var health_level: int = 1
var mana_level: int = 1

static func bounded_int(value: Variant, fallback: int, minimum: int, maximum: int) -> int:
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	return clampi(int(value), minimum, maximum)

static func sanitize(data: Dictionary) -> Dictionary:
	return {
		"version": 1,
		"xp": bounded_int(data.get("xp"), 0, 0, MAX_XP),
		"level": bounded_int(data.get("level"), 1, 1, MAX_LEVEL),
		"power_level": bounded_int(data.get("power_level"), 1, 1, MAX_LEVEL),
		"health_level": bounded_int(data.get("health_level"), 1, 1, MAX_LEVEL),
		"mana_level": bounded_int(data.get("mana_level"), 1, 1, MAX_LEVEL)
	}

func snapshot() -> Dictionary:
	return {"version":1, "xp":xp, "level":level, "power_level":power_level, "health_level":health_level, "mana_level":mana_level}

func restore(data: Dictionary) -> void:
	var clean := sanitize(data)
	xp = clean.xp
	level = clean.level
	power_level = clean.power_level
	health_level = clean.health_level
	mana_level = clean.mana_level

func earn(amount: int) -> int:
	var accepted := mini(maxi(amount, 0), MAX_XP-xp)
	xp += accepted
	return accepted

func grant_boss_level() -> bool:
	# Guardian rewards are earned directly; they never consume saved XP.
	# Each stat is bounded independently so one capped stat cannot block others.
	var previous := snapshot()
	level = mini(level + 1, MAX_LEVEL)
	power_level = mini(power_level + 1, MAX_LEVEL)
	health_level = mini(health_level + 1, MAX_LEVEL)
	mana_level = mini(mana_level + 1, MAX_LEVEL)
	return snapshot() != previous

func cost(kind: String) -> int:
	match kind:
		"heal": return 30
		"mana": return 25
		"power": return 100 * power_level
		"health": return 80 * health_level
		"magic": return 80 * mana_level
		"overall": return 210 * level
	return 0

func capped(kind: String) -> bool:
	match kind:
		"power": return power_level >= MAX_LEVEL
		"health": return health_level >= MAX_LEVEL
		"magic": return mana_level >= MAX_LEVEL
		"overall": return maxi(level, maxi(power_level, maxi(health_level, mana_level))) >= MAX_LEVEL
	return false

func spend(kind: String) -> bool:
	if kind not in KINDS or capped(kind) or xp < cost(kind):
		return false
	xp -= cost(kind)
	match kind:
		"power": power_level += 1
		"health": health_level += 1
		"magic": mana_level += 1
		"overall":
			level += 1
			power_level += 1
			health_level += 1
			mana_level += 1
	return true

func health_capacity() -> float:
	return 200.0 + (health_level-1) * HEALTH_PER_LEVEL

func mana_capacity() -> float:
	return 100.0 + (mana_level-1) * MANA_PER_LEVEL

func damage_multiplier() -> float:
	return 1.0 + (power_level-1) * POWER_PER_LEVEL
