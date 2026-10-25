@tool
extends SceneTree
## Generate explicit export roots. Godot exports their recursive dependencies;
## dynamically loaded actor scenes and motion libraries must be roots too.
const CATALOG = preload("res://scripts/asset_catalog.gd")

func _initialize() -> void:
	var roots: PackedStringArray = ["res://ground.tscn", "res://player.tscn", "res://player.gd",
		"res://assets/hero_icon.svg", "res://assets/Rajdhani-SemiBold.ttf",
		"res://assets/ui/girl_knight_portrait.png", "res://assets/ui/omega_knight_portrait.png"]
	for directory in ["res://scripts", "res://shaders", "res://assets/ui/controls", "res://assets/motion"]:
		for filename in DirAccess.get_files_at(directory):
			if filename.get_extension() in ["gd", "gdshader", "svg", "res"]:
				roots.append(directory.path_join(filename))
	# Scripts do not report their load()/preload() literals as resource
	# dependencies. Include those paths before closing the scene/resource graph.
	var resource_literal := RegEx.new()
	resource_literal.compile("[\"'](res://[^\"']+)[\"']")
	for script_path in roots.duplicate():
		if script_path.get_extension() not in ["gd", "gdshader"]:
			continue
		for match_result in resource_literal.search_all(FileAccess.get_file_as_string(script_path)):
			var resource_path: String = match_result.get_string(1)
			if ResourceLoader.exists(resource_path) and not roots.has(resource_path):
				roots.append(resource_path)
	var actor_ids: Array[String] = ["female", "omega", "sword", "main_boss", "grand_boss", "grand_soldier"]
	for index in range(1, 10):
		actor_ids.append("soldier_" + str(index))
		actor_ids.append("subboss_" + str(index))
	var actors := {}
	for actor_id in actor_ids:
		var path: String = CATALOG.path_for(actor_id)
		actors[actor_id] = path
		roots.append(path)
	var seen := {}
	var pending := Array(roots)
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if seen.has(path):
			continue
		if not ResourceLoader.exists(path):
			push_error("Missing Android runtime resource: " + path)
			quit(1)
			return
		seen[path] = true
		for dependency in ResourceLoader.get_dependencies(path):
			var parts := dependency.split("::")
			var dependency_path: String = parts[-1] if parts[-1].begins_with("res://") else parts[0]
			if dependency_path.begins_with("uid://"):
				dependency_path = ResourceUID.get_id_path(ResourceUID.text_to_id(dependency_path))
			pending.append(dependency_path)
	roots.sort()
	var dependencies: Array = seen.keys()
	dependencies.sort()
	var config := ConfigFile.new()
	if config.load("res://export_presets.cfg") != OK:
		push_error("Could not read export_presets.cfg.")
		quit(1)
		return
	var preset := ""
	for section in config.get_sections():
		if config.get_value(section, "name", "") == "Android":
			preset = section
			break
	if preset.is_empty():
		push_error("Android export preset is missing.")
		quit(1)
		return
	config.set_value(preset, "export_filter", "resources")
	config.set_value(preset, "export_files", roots)
	config.set_value(preset, "include_filter", "assets/OFL.txt,License.txt,read me .txt,CREDITS.md,ENGINE-LICENSES.txt,assets/provided/ATTRIBUTION.md")
	if config.save("res://export_presets.cfg") != OK:
		push_error("Could not save Android resource roots.")
		quit(1)
		return
	var report := {"roots": Array(roots), "dependencies": dependencies, "actors": actors}
	var output := FileAccess.open("res://build/android/resource-manifest.json", FileAccess.WRITE)
	if output == null:
		push_error("Could not save Android resource manifest.")
		quit(1)
		return
	output.store_string(JSON.stringify(report, "\t") + "\n")
	print("Android runtime roots: %d; dependency closure: %d; actor assets: %d" % [roots.size(), dependencies.size(), actors.size()])
	quit()
