extends SceneTree
var failures: int=0
func check(value: bool,message: String) -> void:
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func frames(count: int=3) -> void:
	for frame in range(count): await process_frame
func run() -> void:
	var audio := GameAudio.new()
	audio.settings_path="user://native-display-review.cfg"
	root.add_child(audio)
	var panel := audio.panel
	var screen := DisplayServer.screen_get_size()
	var original: Dictionary = audio.preferences.Display.duplicate(true)
	var target := 1 if screen.x>=1600 and screen.y>=900 else 0
	panel.open()
	panel.change("Display","resolution",target)
	await frames()
	check(panel.remaining>0,"Native display preview starts confirmation")
	check(DisplayServer.window_get_size()==SettingsSchema.RESOLUTIONS[target],"Native window resolution applies")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../verification/settings/native-display-confirmation.png"))
	# Test application countdown while the gameplay tree is paused.
	paused=true
	panel.remaining=.1
	await frames(20)
	check(panel.remaining==0 and audio.preferences.Display==original,"Real-time native confirmation reverts even while paused")
	paused=false
	await frames()
	check(DisplayServer.window_get_size()==SettingsSchema.RESOLUTIONS[original.resolution],"Native rollback restores prior window size")
	panel.change("Display","resolution",target); await frames(); panel.keep_display(); panel.close(); await frames()
	check(DisplayServer.window_get_size()==SettingsSchema.RESOLUTIONS[original.resolution],"Cancel restores previously confirmed but unaccepted display preview")
	for mode in [1,2]:
		panel.open(); panel.change("Display","mode",mode); await frames()
		if panel.remaining>0:
			check(DisplayServer.window_get_mode()==[DisplayServer.WINDOW_MODE_WINDOWED,DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN][mode],"Native fullscreen preview applies requested mode")
			panel.remaining=.1; await frames(20)
			check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED,"Native fullscreen timeout restores windowed mode")
			print("NATIVE MODE ",mode," applied and reverted")
		else: check(panel.notice.text.contains("restored"),"Unsupported fullscreen reports safe restoration")
		panel.close(); await frames()
	audio.preferences.Display=original; audio.apply_display(original)
	panel.close(); audio.queue_free(); await frames(4)
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists("user://native-display-review.cfg"+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path("user://native-display-review.cfg"+suffix))
	print("NATIVE DISPLAY ",screen," tested ",SettingsSchema.RESOLUTIONS[target])
	print("DISPLAY VISUAL RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
