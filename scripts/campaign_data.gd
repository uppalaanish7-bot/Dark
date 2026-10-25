extends RefCounted
const LEVEL_CAPACITY := 10
const LEVELS := [
	{"name": "CATHEDRAL OF CINDERS", "subtitle": "Break nine seals. Defeat the Molten Sun. End the Eclipse.", "waves": 11, "health_scale": 1.0},
]
const CHARACTERS := [
	{"name": "SERAPHINA (EMBER VOW)", "ability": "EMBER HEART", "description": "Former hearth-warden of Greywake who swore to carry the last uncorrupted ember into the Spire. Her flame magic burns away the cold ash of forgotten names."},
	{"name": "OMEGA (ASTRAL RELIQUARY)", "ability": "STORM HEART", "description": "An ancient brass-and-storm sentinel forged by the Spire's original architects to guard the Moonwell's memory conduits. His arc-lightning jumpstarts dormant copper echoes."},
]
const MAX_RANK := 5
const COSTUME_SLOTS := 8
const CHARACTER_SKIN_SLOTS := 2
const KILL_COINS := 10
const BOSS_COINS := 100
const CLEAR_COINS := 500
const MARKET_ITEMS: Array[Dictionary] = []

static func ability_value(_character: int, rank: int) -> float:
	return 4.0 + rank * 2.0

static func ability_text(_character: int, rank: int) -> String:
	return "+%d vitality per elimination" % roundi(ability_value(0, rank))

static func upgrade_cost(rank: int) -> int:
	return 150 * rank if rank < MAX_RANK else 0
