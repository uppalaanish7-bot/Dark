extends SceneTree
## Direct external GLB import only; no files are copied into the game's assets.
const INVENTORY := "res://art/asset_review/provided_assets_inventory.json"
const REPORT := "res://art/asset_review/godot_import_report.json"
var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func inspect_asset(asset: Dictionary) -> Dictionary:
	var result := {"source": asset.source, "relative_path": asset.relative_path, "imported": false}
	if not asset.container_valid:
		result.reason = "Skipped: invalid GLB container; replace the damaged original."
		return result
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(asset.source, state)
	result.import_error = error
	if error != OK:
		return result
	var scene := document.generate_scene(state)
	if scene == null:
		result.reason = "Godot could not generate the scene."
		return result
	root.add_child(scene)
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var bounds := AABB()
	var first := true
	var surfaces := 0
	for child in meshes:
		var mesh := child as MeshInstance3D
		var transformed: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = transformed if first else bounds.merge(transformed)
		first = false
		surfaces += mesh.mesh.get_surface_count()
	var skeletons: Array[Dictionary] = []
	for skeleton in scene.find_children("*", "Skeleton3D", true, false):
		skeletons.append({"name": skeleton.name, "bones": skeleton.get_bone_count()})
	var clips: Array[String] = []
	for animation_player in scene.find_children("*", "AnimationPlayer", true, false):
		for clip in animation_player.get_animation_list():
			clips.append(clip)
	result.imported = true
	result.mesh_instances = meshes.size()
	result.material_surfaces = surfaces
	result.bounds_min = [bounds.position.x, bounds.position.y, bounds.position.z]
	result.dimensions = [bounds.size.x, bounds.size.y, bounds.size.z]
	result.skeletons = skeletons
	result.animation_names = clips
	scene.free()
	return result

func run() -> void:
	var inventory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INVENTORY))
	for asset in inventory.assets:
		print("CHECKING ", asset.relative_path)
		var result := inspect_asset(asset)
		results.append(result)
		var report := FileAccess.open(REPORT, FileAccess.WRITE)
		report.store_string(JSON.stringify({"godot_version": Engine.get_version_info().string, "assets": results}, "\t"))
		report.close()
		print("IMPORT ", result.imported, " | ", result.relative_path, " | ", result.get("dimensions", []))
		await process_frame
	print("PROVIDED_ASSET_IMPORTS_COMPLETE count=", results.size())
	quit()
