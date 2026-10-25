extends SceneTree
const PLAYER = preload("res://player.gd")
const GROWTH = preload("res://scripts/player_growth.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	var hero := PLAYER.new()
	root.add_child(hero)
	hero.set_physics_process(false)
	check(hero.growth_snapshot() == GROWTH.sanitize({}), "Fresh hero starts at level 1 with zero XP")
	check(hero.max_health == 200 and hero.max_mana == 100 and hero.damage_multiplier() == 1, "Base capacities and damage remain unchanged")
	check(not hero.purchase_growth("power") and hero.growth.xp == 0, "Unaffordable upgrade cannot spend or grant a level")
	hero.award_xp(-90)
	check(hero.growth.xp == 0, "Negative rewards never remove XP")
	hero.award_xp(3000)
	check(not hero.purchase_growth("heal") and hero.growth.xp == 3000, "Full health cannot consume healing XP")
	check(not hero.purchase_growth("mana") and hero.growth.xp == 3000, "Full mana cannot consume restoration XP")
	hero.health = 40
	hero.mana = 15
	check(hero.purchase_growth("heal") and hero.health == 140 and hero.growth.xp == 2970, "Healing spends 30 XP and restores half the maximum HP")
	check(hero.purchase_growth("mana") and hero.mana == 100 and hero.growth.xp == 2945, "Mana refill spends 25 XP and restores the whole bar")
	check(hero.purchase_growth("power") and hero.growth.power_level == 2 and is_equal_approx(hero.damage_multiplier(), 1.1), "Power advances one level and increases all damage scale")
	check(hero.purchase_growth("health") and hero.growth.health_level == 2 and hero.max_health == 220 and hero.health == 160, "Health upgrade adds one level and 20 current/max HP")
	check(hero.purchase_growth("magic") and hero.growth.mana_level == 2 and hero.max_mana == 110 and hero.mana == 110, "Mana upgrade adds one level and 10 current/max mana")
	var before: Dictionary = hero.growth_snapshot()
	check(hero.purchase_growth("overall"), "Overall level can be purchased")
	var after: Dictionary = hero.growth_snapshot()
	for key in ["level", "power_level", "health_level", "mana_level"]:
		check(after[key] == before[key]+1, "Overall upgrade increments " + key + " exactly once")
	check(after.xp == before.xp-210, "Overall upgrade charges once for all three stats")
	hero.health = 73
	hero.mana = 28
	hero.restore_growth(before)
	check(hero.health == 73 and hero.mana == 28, "Restoring levels does not refill saved vital values")
	check(hero.growth_snapshot() == before, "Run snapshot restores XP and levels exactly")
	hero.reset()
	check(hero.health == 220 and hero.mana == 110 and hero.growth_snapshot() == before, "Retry reset refills current capacities while preserving run growth")
	hero.restore_growth({})
	hero.reset()
	check(hero.growth.xp == 0 and hero.max_health == 200 and hero.max_mana == 100, "New game can reset XP and all levels")
	hero.restore_growth({"xp":"bad", "level":NAN, "health_level":-40, "power_level":999999, "mana_level":2})
	check(hero.growth.xp == 0 and hero.growth.level == 1 and hero.growth.health_level == 1 and hero.growth.power_level == 99, "Malformed save values are bounded safely")
	hero.award_xp(2000000000)
	check(not hero.purchase_growth("overall") and hero.growth.xp == 2000000000, "Capped overall level cannot partially charge or upgrade")
	hero.free()
	print("PLAYER_GROWTH_CHECKS ",checks," FAILURES ",failures.size())
	quit(0 if failures.is_empty() else 1)
