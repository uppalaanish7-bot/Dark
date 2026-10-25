extends RefCounted
## Runtime derivatives of the user's supplied assets, with source provenance in
## assets/provided/source_manifest.json. Original files are never modified.
const PLAYER := "female"
static var scene_cache: Dictionary = {}
static var requested: Dictionary = {}

static func request(id: String) -> void:
	if scene_cache.has(id) or requested.has(id): return
	var path := path_for(id)
	if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path) == OK:
		requested[id] = true

static func path_for(id: String) -> String:
	var articulated := "res://assets/sculpt_motion/"+id+".scn"
	if ResourceLoader.exists(articulated): return articulated
	return "res://assets/provided/" + id + ".glb"

static func instantiate(id: String) -> Node3D:
	var path := path_for(id)
	if not ResourceLoader.exists(path): return null
	if not scene_cache.has(id):
		if requested.has(id):
			scene_cache[id] = ResourceLoader.load_threaded_get(path)
			requested.erase(id)
		else: scene_cache[id] = load(path)
	return scene_cache[id].instantiate() as Node3D
