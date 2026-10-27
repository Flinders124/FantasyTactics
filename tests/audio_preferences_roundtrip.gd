extends SceneTree
## Run as two separate launches: -- write, then -- read.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var service := GameAudio.new()
	service.settings_path="user://audio-launch-roundtrip.cfg"
	var malformed := OS.get_cmdline_user_args().has("malformed")
	if malformed:
		var file := FileAccess.open(service.settings_path,FileAccess.WRITE)
		file.store_string("[Master\nvolume=0.1")
		file.close()
	root.add_child(service)
	var writing := OS.get_cmdline_user_args().has("write")
	if writing:
		service.set_preference("SFX",.27,true)
		service.set_preference("Music",.41,false)
	elif malformed:
		assert(is_equal_approx(service.volumes.Master,.8) and not service.preferences_warning.is_empty())
		DirAccess.remove_absolute(ProjectSettings.globalize_path(service.settings_path))
	else:
		assert(is_equal_approx(service.volumes.SFX,.27) and service.muted.SFX)
		assert(is_equal_approx(service.volumes.Music,.41) and not service.muted.Music)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(service.settings_path))
	service.queue_free()
	await process_frame
	print("PREFERENCES ","WRITE" if writing else ("MALFORMED FALLBACK" if malformed else "READ"), " RESULT: 0 failures")
	quit()
