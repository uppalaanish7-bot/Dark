@tool
extends SceneTree

func _initialize() -> void:
	_configure.call_deferred()

func _configure() -> void:
	var java_home := OS.get_environment("RELIC_JAVA_HOME")
	var android_home := OS.get_environment("RELIC_ANDROID_HOME")
	if java_home.is_empty() or android_home.is_empty():
		push_error("Use tools/package_android.ps1 to configure the Android toolchain.")
		quit(1)
		return
	# Quit only after the editor has completed initialization. Exiting from
	# _initialize interrupts its scan and produces spurious RID/resource leaks.
	var filesystem := EditorInterface.get_resource_filesystem()
	while filesystem.is_scanning():
		await process_frame
	await process_frame
	var settings := EditorInterface.get_editor_settings()
	settings.set_setting("export/android/java_sdk_path", java_home)
	settings.set_setting("export/android/android_sdk_path", android_home)
	quit()
