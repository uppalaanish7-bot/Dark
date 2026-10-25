extends SceneTree
var texture_paths: Dictionary = {}
var report: Array = []
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/provided/source_manifest.json"))
	for item in manifest.assets:
		var path: String = "res://" + item.derived
		var packed := load(path) as PackedScene
		if packed == null:
			failures += 1
			continue
		var scene := packed.instantiate() as Node3D
		root.add_child(scene)
		var meshes := scene.find_children("*", "MeshInstance3D", true, false)
		var surfaces := 0
		var triangles := 0
		for node in meshes:
			var instance := node as MeshInstance3D
			for index in instance.mesh.get_surface_count():
				surfaces += 1
				var array: Array = instance.mesh.surface_get_arrays(index)
				triangles += array[Mesh.ARRAY_INDEX].size() / 3
				var material: Material = instance.mesh.surface_get_material(index)
				if material == null: continue
				for property in material.get_property_list():
					if property.type == TYPE_OBJECT:
						var value: Variant = material.get(property.name)
						if value is Texture2D and not value.resource_path.is_empty():
							texture_paths[value.resource_path] = true
		if meshes.is_empty(): failures += 1
		report.append({"id": item.id, "meshes": meshes.size(), "surfaces": surfaces, "triangles": triangles, "loaded": true})
		scene.free()
		await process_frame
	var stale: Array[String] = []
	for file in DirAccess.get_files_at("res://assets/provided"):
		if file.get_extension().to_lower() in ["png", "jpg", "jpeg"]:
			var path := "res://assets/provided/" + file
			if not texture_paths.has(path): stale.append(path)
	var output := FileAccess.open("res://art/asset_review/runtime_validation.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"failures": failures, "assets": report, "used_textures": texture_paths.keys(), "unused_extracted_textures": stale}, "\t"))
	print("PROVIDED_ASSET_VALIDATION assets=",report.size()," failures=",failures," unused_textures=",stale.size())
	quit(failures)
