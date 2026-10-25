extends RefCounted
const DATA = preload("res://scripts/campaign_data.gd")
const SESSION = preload("res://scripts/world_session.gd")
const STORY = preload("res://scripts/story_data.gd")
var path: String
var coins: int = 0
var ranks: Array[int] = [1, 1, 1, 1]
var worlds: Array[Dictionary] = []
var active_world: int = 1
var next_world_id: int = 2
var owned: Array[String] = []
var catalog: Array[Dictionary] = DATA.MARKET_ITEMS.duplicate(true)
var error: String = ""
var primary_valid: bool = false

func _init(save_path: String = "user://relic_progress.cfg") -> void:
	path = save_path
	worlds = [{"id": 1, "name": "World 01", "completed": 0, "level": 1, "quest": "unmet", "session": SESSION.fresh(), "chronicle": STORY.sanitize({})}]

func load_progress() -> void:
	var config := ConfigFile.new()
	var result := config.load(path)
	primary_valid = result == OK
	if result != OK:
		if config.load(path + ".bak") != OK:
			if result != ERR_FILE_NOT_FOUND:
				error = "Could not read saved progress. Your save has been preserved."
			return
	coins = clampi(int(config.get_value("profile", "coins", 0)), 0, 2000000000)
	var saved_ranks: Variant = config.get_value("profile", "ranks", [1, 1, 1, 1])
	if saved_ranks is Array and saved_ranks.size() == 4:
		for index in range(4):
			ranks[index] = clampi(int(saved_ranks[index]), 1, DATA.MAX_RANK)
	var saved_worlds: Variant = config.get_value("profile", "worlds", [])
	var restored: Array[Dictionary] = []
	var ids: Array[int] = []
	if saved_worlds is Array:
		for entry in saved_worlds:
			if not entry is Dictionary:
				continue
			var id := int(entry.get("id", 0))
			if id < 1 or id in ids:
				continue
			ids.append(id)
			var completed := clampi(int(entry.get("completed", 0)), 0, DATA.LEVELS.size())
			var world_name := str(entry.get("name", "World %02d" % id)).strip_edges().left(24)
			if world_name.is_empty():
				world_name = "World %02d" % id
			var quest := str(entry.get("quest", "elixir" if completed == DATA.LEVELS.size() else "unmet"))
			if not quest in ["unmet", "active", "elixir", "healed"]:
				quest = "unmet"
			var world := {"quest": quest, "id": id, "name": world_name, "completed": completed, "level": clampi(int(entry.get("level", 1)), 1, mini(completed + 1, DATA.LEVELS.size()))}
			world.chronicle = STORY.sanitize(entry.get("chronicle", {}))
			if entry.get("session") is Dictionary:
				world.session = entry.session
			world.session = SESSION.migrate(world)
			restored.append(world)
	if saved_worlds is Array and config.has_section_key("profile", "worlds"):
		worlds = restored
	active_world = int(config.get_value("profile", "active_world", 1))
	if not active_world in ids:
		active_world = int(worlds[0].id) if not worlds.is_empty() else 0
	next_world_id = maxi(1, int(config.get_value("profile", "next_world_id", 1)))
	for world in worlds:
		next_world_id = maxi(next_world_id, int(world.id) + 1)
	var saved_owned: Variant = config.get_value("profile", "owned", [])
	if saved_owned is Array:
		for item in saved_owned:
			if item is String and not item in owned:
				owned.append(item)

func save() -> bool:
	var config := ConfigFile.new()
	config.set_value("profile", "version", 3)
	config.set_value("profile", "next_world_id", next_world_id)
	config.set_value("profile", "coins", coins)
	config.set_value("profile", "ranks", ranks)
	config.set_value("profile", "worlds", worlds)
	config.set_value("profile", "active_world", active_world)
	config.set_value("profile", "owned", owned)
	if config.save(path + ".tmp") != OK:
		error = "Progress could not be saved. Check available disk space."
		return false
	if primary_valid and FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path, path + ".bak") != OK:
			error = "Could not back up progress. Please check the save folder."
			return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		error = "Progress could not be saved. Please try again."
		return false
	primary_valid = true
	error = ""
	return true

func current_world() -> Dictionary:
	for world in worlds:
		if world.id == active_world:
			return world
	return worlds[0] if not worlds.is_empty() else {}

func world_by_id(id: int) -> Dictionary:
	for world in worlds:
		if int(world.id) == id:
			return world
	return {}

func session_for_world(id: int = 0) -> Dictionary:
	var world := current_world() if id == 0 else world_by_id(id)
	return SESSION.migrate(world) if not world.is_empty() else SESSION.fresh()

func has_visited_world(id: int = 0) -> bool:
	return bool(session_for_world(id).visited)

func session_summary(id: int = 0) -> String:
	var session := session_for_world(id)
	if not session.visited:
		return "New world"
	return "Inside tower · Level %02d" % session.level if session.place == "arena" else "Courtyard"

func update_session(id: int, session: Dictionary, persist: bool = true) -> bool:
	# Resolve the runtime identity explicitly; never fall back to another world.
	var world := world_by_id(id)
	if world.is_empty() or active_world != id:
		return false
	world.session = SESSION.sanitize(session, int(world.level))
	# Keep the latest checkpoint in memory when disk writes fail, so a later
	# successful profile transaction cannot pair new coins with old enemies.
	return not persist or save()

func create_world(world_name: String) -> bool:
	world_name = world_name.strip_edges().left(24)
	if world_name.is_empty():
		error = "Enter a world name."
		return false
	for world in worlds:
		if str(world.name).nocasecmp_to(world_name) == 0:
			error = "A world with that name already exists."
			return false
	var previous := active_world
	worlds.append({"id": next_world_id, "name": world_name, "completed": 0, "level": 1, "quest": "unmet", "session": SESSION.fresh(), "chronicle": STORY.sanitize({})})
	active_world = next_world_id
	next_world_id += 1
	if not save():
		worlds.pop_back()
		next_world_id -= 1
		active_world = previous
		return false
	return true

func select_world(id: int) -> bool:
	for world in worlds:
		if world.id == id:
			var previous := active_world
			active_world = id
			if save():
				return true
			active_world = previous
			return false
	return false

func select_level(level: int) -> bool:
	var world := current_world()
	if world.is_empty():
		return false
	if level < 1 or level > DATA.LEVELS.size() or level > int(world.completed) + 1:
		return false
	var previous: int = world.level
	var previous_session: Dictionary = world.get("session", SESSION.fresh()).duplicate(true)
	world.level = level
	if previous != level:
		world.session = SESSION.sanitize(previous_session, level)
	if save():
		return true
	world.level = previous
	world.session = previous_session
	return false

func earn(amount: int, persist: bool = true) -> void:
	coins = clampi(coins + maxi(amount, 0), 0, 2000000000)
	if persist:
		save()

func complete_level(level: int, persist: bool = true) -> void:
	var world := current_world()
	if world.is_empty():
		return
	if level < 1 or level > DATA.LEVELS.size() or level > int(world.completed) + 1:
		return
	# The clear bonus is awarded once per level per world; replays still earn kills.
	if level > int(world.completed):
		world.completed = level
		coins += DATA.CLEAR_COINS
	if persist:
		save()

func collect_elixir() -> bool:
	var world := current_world()
	if world.is_empty() or int(world.completed) < DATA.LEVELS.size():
		return false
	var previous: String = world.get("quest", "unmet")
	if previous in ["elixir", "healed"]:
		return true
	world.quest = "elixir"
	if save():
		return true
	world.quest = previous
	return false

func upgrade(character: int) -> bool:
	if character < 0 or character >= ranks.size() or ranks[character] >= DATA.MAX_RANK:
		return false
	var cost := DATA.upgrade_cost(ranks[character])
	if coins < cost:
		error = "Not enough coins. Earn more by defeating enemies."
		return false
	coins -= cost
	ranks[character] += 1
	if save():
		return true
	coins += cost
	ranks[character] -= 1
	return false

func purchase(item_id: String) -> bool:
	# Only catalog entries can be purchased; empty slots never spend coins.
	for item in catalog:
		if str(item.get("id", "")) != item_id or item_id.is_empty():
			continue
		var price := int(item.get("price", -1))
		if price < 0 or coins < price or item_id in owned:
			return false
		if not str(item.get("category", "")) in ["character", "gun_skin", "costume"]:
			return false
		coins -= price
		owned.append(item_id)
		if save():
			return true
		coins += price
		owned.erase(item_id)
		return false
	return false

func set_quest(stage: String) -> bool:
	var world := current_world()
	if world.is_empty():
		return false
	var previous: String = world.get("quest", "unmet")
	if not ((previous == "unmet" and stage == "active") or (previous == "elixir" and stage == "healed")):
		return false
	world.quest = stage
	if save():
		return true
	world.quest = previous
	return false

func delete_world(id: int) -> bool:
	for index in range(worlds.size()):
		if int(worlds[index].id) != id:
			continue
		var previous: int = active_world
		var removed: Dictionary = worlds[index]
		worlds.remove_at(index)
		if active_world == id:
			active_world = int(worlds[0].id) if not worlds.is_empty() else 0
		if save():
			return true
		worlds.insert(index, removed)
		active_world = previous
		return false
	return false
