extends "res://tests/tutorial_tests.gd"
var viewport: SubViewport
var prefix: String
func capture(label: String) -> void:
	await process_frame; await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(prefix+"-"+label+".png"))
func click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.global_position=point; event.pressed=pressed
		viewport.push_input(event,true)
	await process_frame
func press(code: int) -> void:
	for down in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=down
		viewport.push_input(event,true)
	await process_frame
func run() -> void:
	root.size=Vector2i(1920,1080) if OS.get_cmdline_user_args().has("1080") else Vector2i(1280,720)
	prefix="res://../verification/settings/review-%d"%root.size.x
	viewport=SubViewport.new(); viewport.size=root.size; viewport.own_world_3d=true; viewport.gui_embed_subwindows=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	viewport.add_child(flow)
	flow.audio.settings_path="user://settings-review.cfg"
	flow.audio.preferences=SettingsSchema.defaults(); flow.audio.accepted_preferences=flow.audio.preferences.duplicate(true); flow.audio.apply_preferences(false)
	var panel := flow.audio.panel
	for large in [false,true]:
		var scale_label := "max" if large else "min"
		await press(KEY_F10)
		check(panel.visible,"Protected settings shortcut opens unified panel")
		panel.tabs.current_tab=4
		panel.widgets["Accessibility/ui_scale"].value=1.15 if large else .85
		panel.widgets["Accessibility/large_text"].button_pressed=large
		panel.widgets["Accessibility/high_contrast"].button_pressed=large
		panel.widgets["Accessibility/reduced_effects"].button_pressed=large
		for category in range(5):
			panel.tabs.current_tab=category
			await capture(scale_label+"-"+panel.tabs.get_tab_title(category))
			check(Rect2(Vector2.ZERO,Vector2(viewport.size)).encloses(panel.card.get_global_rect()),"Settings card fits at every category and scale")
			check(panel.apply_button.get_global_rect().end.y<=viewport.size.y,"Apply/Cancel remain accessible at maximum scale")
		await press(KEY_PAGEUP)
		check(panel.tabs.current_tab==3,"Keyboard-only category navigation works")
		for count in range(6): await press(KEY_TAB)
		var focused := viewport.gui_get_focus_owner()
		check(focused!=null and focused.is_visible_in_tree(),"Settings keyboard navigation retains visible focus")
		await click(panel.apply_button.get_global_rect().get_center())
		check(not panel.visible,"Actual Apply button closes settings and commits")
		await capture(scale_label+"-title")
		check(flow.menu.quit_button.get_global_rect().end.y<=viewport.size.y or flow.menu.quit_button.get_parent().get_parent() is ScrollContainer,"Title remains scrollable with larger text")
		flow.menu.new_button.grab_focus()
		for navigation in range(12):
			if flow.menu.quit_button.has_focus(): break
			await press(KEY_TAB)
		await process_frame; await process_frame
		check(flow.menu.quit_button.has_focus() and flow.menu.quit_button.get_global_rect().end.y<=viewport.size.y,"Keyboard navigation scrolls title controls into view")
		flow.show_party(); await capture(scale_label+"-setup")
		flow.party.clear(); flow.party.toggle("knight"); flow.party.toggle("ranger")
		await process_frame; await process_frame
		check(flow.menu.start_button.get_global_rect().end.y<=viewport.size.y,"Setup Start remains accessible")
		for card in flow.menu.cards.values(): check(card.get_global_rect().end.y<=viewport.size.y,"Four hero choices fit supported scale")
		flow.party.seed_text="7"; flow.party.preview_seed=7
		await click(flow.menu.start_button.get_global_rect().get_center())
		await ready_flow()
		await capture(scale_label+"-combat")
		var combat := flow.combat.get_node("CombatController") as CombatController
		check(not combat.guidance_paused,"Combat resumes after briefing")
		await press(KEY_F10)
		check(paused and combat.guidance_paused,"In-encounter settings opens a real pause")
		panel.tabs.current_tab=2
		panel.begin_capture("move")
		await press(KEY_T)
		await capture(scale_label+"-conflict")
		check(panel.conflicts.has("attack"),"Rendered rebinding conflict is explicit")
		await press(KEY_ESCAPE)
		check(panel.capture_id.is_empty() and panel.visible,"Capture cancellation does not leak into combat")
		await click(panel.cancel_button.get_global_rect().get_center())
		check(not paused,"Cancel resumes same encounter")
		flow.show_title()
	for frame in range(8): await process_frame
	flow.queue_free()
	for frame in range(8): await process_frame
	viewport.queue_free()
	await process_frame
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists("user://settings-review.cfg"+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings-review.cfg"+suffix))
	print("SETTINGS VISUAL RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
