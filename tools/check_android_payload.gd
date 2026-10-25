extends SceneTree
## Runs against the resources extracted from the finished Android APK, not the
## development project. The packaging script injects this checker into a
## temporary validation ZIP; it is never shipped inside the APK.
func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://__android_resources.json"))
	var failures: Array[String] = []
	var loaded := 0
	for path in manifest.roots:
		var resource := load(path)
		if resource == null or (resource is Script and not resource.can_instantiate()):
			failures.append(path)
		else:
			loaded += 1
	for actor_id in manifest.actors:
		var scene := load(manifest.actors[actor_id]) as PackedScene
		if scene == null:
			failures.append("actor:" + actor_id)
			continue
		var instance := scene.instantiate()
		if instance == null:
			failures.append("instantiate:" + actor_id)
		else:
			instance.free()
	if not failures.is_empty():
		push_error("Android payload validation failed: " + str(failures))
		quit(1)
		return
	print("Android APK payload validated: %d roots loaded; %d actor scenes instantiated." % [loaded, manifest.actors.size()])
	quit()
