extends "res://tests/flow_tests.gd"
var audio: GameAudio
var panel: AudioSettingsPanel
var path: String="user://settings-regression.cfg"
func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=true
	return event
func mock_display(display: Dictionary) -> bool:
	return display.mode!=2
func run() -> void:
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	audio=flow.audio; panel=audio.panel
	audio.settings_path=path
	var legacy := ConfigFile.new()
	legacy.set_value("Master","volume",.37)
	legacy.set_value("tutorial","completed",true)
	legacy.save(path)
	audio.load_preferences()
	check(audio.tutorial_completed and is_equal_approx(audio.volumes.Master,.37),"Legacy audio/tutorial preferences migrate into one owner")
	var original := audio.preferences.duplicate(true)
	var before := FileAccess.get_file_as_string(path)
	panel.open()
	panel.change("Audio","Master",.64)
	panel.change("Camera","orbit",1.5)
	panel.begin_capture("move"); panel.handle_input(key(KEY_G))
	check(ControlBindings.label("move")=="G" and is_equal_approx(audio.volumes.Master,.64),"Settings preview audio and actual InputMap")
	panel.close()
	check(audio.preferences==original and FileAccess.get_file_as_string(path)==before,"Cancel restores every category without writing previews")
	check(audio.tutorial_completed,"Cancel does not reset tutorial completion")
	panel.open(); panel.change("Camera","pan",1.5); panel.change("Audio","Master",.6); panel.accept()
	var saved := ConfigFile.new(); saved.load(path)
	check(saved.get_value("meta","version")==SettingsSchema.VERSION and is_equal_approx(saved.get_value("Audio","Master"),.6),"Apply persists a versioned configuration")
	audio.preferences=SettingsSchema.defaults(); audio.load_preferences()
	check(is_equal_approx(audio.preferences.Camera.pan,1.5) and audio.tutorial_completed,"Fresh load restores camera/audio and completion")
	panel.open(); panel.change("Audio","Master",.2); audio.mark_tutorial_completed()
	saved.load(path)
	check(is_equal_approx(saved.get_value("Audio","Master"),.6),"Tutorial persistence cannot save an unaccepted settings preview")
	panel.close()
	panel.open(); panel.tabs.current_tab=1; panel.reset_category(); panel.accept()
	check(is_equal_approx(audio.volumes.Master,.8) and is_equal_approx(audio.preferences.Camera.pan,1.5) and audio.tutorial_completed,"Category reset preserves unrelated settings and tutorial completion")
	panel.open(); panel.begin_capture("move"); panel.handle_input(key(KEY_T))
	check(panel.conflicts==PackedStringArray(["attack"]) and ControlBindings.label("move")=="M","Conflicting binding cannot silently replace another action")
	panel.resolve_binding("swap")
	check(ControlBindings.label("move")=="T" and ControlBindings.label("attack")=="M","Explicit swap produces unique bindings")
	panel.close()
	check(ControlBindings.label("move")=="M" and ControlBindings.label("attack")=="T","Cancelling restores both swapped bindings")
	panel.open(); panel.begin_capture("move"); panel.handle_input(key(KEY_F10))
	check(not panel.capture_id.is_empty() and ControlBindings.label("move")=="M","Protected settings escape route cannot be rebound ambiguously")
	panel.handle_input(key(KEY_ESCAPE)); check(panel.capture_id.is_empty() and panel.visible,"Escape exits capture without closing settings or issuing commands")
	panel.begin_capture("ability_1"); panel.handle_input(key(KEY_G)); panel.accept()
	check(ControlBindings.label("ability_1")=="G","Ability slot accepts non-number binding")
	panel.open(); panel.begin_capture("attack")
	var mouse := InputEventMouseButton.new(); mouse.button_index=MOUSE_BUTTON_XBUTTON1; mouse.pressed=true
	panel.handle_input(mouse); check(audio.preferences.Controls.attack==["M:8"],"Gameplay action supports mouse rebinding")
	panel.close()
	audio.display_driver=mock_display
	panel.open(); panel.change("Display","mode",1)
	check(panel.remaining>0 and panel.confirm.visible and panel.apply_button.disabled,"Display preview requires confirmation before Apply")
	panel._process(13)
	check(audio.preferences.Display.mode==0 and panel.remaining==0,"Application-level countdown automatically rolls back")
	panel.change("Display","mode",2)
	check(panel.remaining==0 and audio.preferences.Display.mode==0 and panel.notice.text.contains("restored"),"Unsupported display mode safely restores previous valid setup")
	panel.change("Display","mode",1); panel.keep_display(); panel.close()
	check(audio.preferences.Display.mode==0,"Cancel restores opening display even after confirmation")
	panel.open(); panel.change("Display","mode",1); panel.keep_display(); panel.accept()
	audio.load_preferences(); check(audio.preferences.Display.mode==1,"Confirmed and applied display persists")
	panel.open(); panel.change("Display","mode",0); panel.keep_display(); panel.accept()
	# Invalid values are sanitized without touching definitions or encounter data.
	saved.load(path); saved.set_value("Camera","pan",-99); saved.set_value("Accessibility","ui_scale",500); saved.set_value("Audio","Master","loud"); saved.set_value("Controls","move",["K:0"]); saved.save(path)
	audio.load_preferences()
	check(audio.preferences.Camera.pan==.25 and audio.preferences.Accessibility.ui_scale==1.15 and audio.volumes.Master==.8,"Malformed types default and numeric values clamp")
	check(SettingsSchema.bindings_valid(audio.preferences.Controls) and audio.tutorial_completed,"Malformed bindings restore safe defaults without losing completion")
	# A truncated primary file recovers the last accepted snapshot, never previews.
	audio.preferences=SettingsSchema.defaults(); audio.preferences.Camera.orbit=1.25
	audio.save_preferences(); audio.save_preferences()
	var corrupt := FileAccess.open(path,FileAccess.WRITE)
	corrupt.store_string("interrupted write"); corrupt.close()
	audio.load_preferences()
	check(audio.preferences.Camera.orbit==1.25 and audio.tutorial_completed and audio.preferences_warning.contains("backup"),"Corrupt primary recovers accepted backup and tutorial completion")
	audio.save_preferences()
	# Restore standard presentation for gameplay checks.
	audio.preferences=SettingsSchema.defaults(); audio.apply_preferences(false)
	var config := EncounterConfiguration.new(); config.battlefield_seed=7
	flow.start_configuration(config); flow.combat.get_node("EnemyController").enabled=false
	await wait_ready()
	var scene := flow.combat
	var combat := scene.get_node("CombatController") as CombatController
	var actor := combat.scheduler.active_unit()
	var signature := scene.configuration.layout.geometry_signature()
	var route := combat.navigation.query_path(actor.global_position,actor.global_position+Vector3.RIGHT)
	var definition := EncounterCode.fingerprint(actor.definition)
	panel.open(); panel.change("Display","graphics",0); panel.change("Accessibility","high_contrast",true); panel.change("Accessibility","reduced_effects",true); panel.change("Accessibility","combat_text",1.5)
	check(scene.configuration.layout.geometry_signature()==signature and is_equal_approx(combat.navigation.query_path(actor.global_position,actor.global_position+Vector3.RIGHT).distance,route.distance),"Graphics/accessibility changes preserve layout and navigation path costs")
	check(EncounterCode.fingerprint(actor.definition)==definition,"Preferences never mutate shared combat definitions")
	var presentation := scene.get_node("CombatPresentation") as CombatPresentation
	var glyphs := presentation.glyphs.size(); var blasts := presentation.blasts.size()
	presentation._spawn_glyph(actor.target_point(),"hit",Color.WHITE)
	presentation._spawn_blast(actor.global_position,2.5)
	presentation._spawn_effect(actor.stable_id,"−3 HP",Color.WHITE)
	check(presentation.glyphs.size()==glyphs and presentation.blasts.size()==blasts and presentation.effects[-1].label.text=="−3 HP","Reduced effects retains readable combat outcomes while suppressing decorative bursts")
	check(presentation.effects[-1].label.get_theme_font_size("font_size")==30,"Combat text has an independent size setting")
	panel.close()
	var camera := scene.get_node("TacticalCamera") as TacticalCamera
	panel.open(); panel.change("Camera","orbit",2.0); panel.change("Camera","pan",1.5); panel.change("Camera","zoom",1.4); panel.change("Camera","invert_y",true); panel.change("Camera","edge",true)
	check(is_equal_approx(camera.orbit_sensitivity,.012) and camera.pan_speed==18.0 and camera.zoom_sensitivity==1.4 and camera.invert_y and camera.edge_scrolling,"Camera preferences update existing consumer without scene replacement")
	panel.close()
	check(is_equal_approx(camera.orbit_sensitivity,.006) and camera.pan_speed==12.0 and not camera.invert_y and not camera.edge_scrolling,"Cancel restores all live camera preferences")
	# Rebound ability still addresses slot 1, not the captured key's numeric code.
	panel.open(); panel.begin_capture("ability_1"); panel.handle_input(key(KEY_G)); panel.accept()
	var player := scene.get_node("PlayerController") as PlayerController
	player._unhandled_input(key(KEY_G))
	check(player.selected_ability_id==actor.definition.abilities[0].stable_id,"Rebound ability executes correct slot and updates actual targeting")
	check(scene.get_node("HUD").ability_buttons[0].text.contains("[G]"),"HUD hints refresh after rebinding")
	# Pause halfway through movement; the exact same action resumes.
	check(combat.submit_player_command(MoveCommand.new(actor.stable_id,actor.global_position+Vector3.RIGHT)),"Move accepted before pause")
	await physics_frame; await physics_frame
	panel.open()
	var position := actor.global_position; var spent := actor.movement_remaining; var elapsed := combat.motor.elapsed
	for frame in range(30): await process_frame
	check(paused and combat.guidance_paused and actor.global_position==position and actor.movement_remaining==spent and combat.motor.elapsed==elapsed,"Pause freezes movement, budgets and motor timeout")
	check(not combat.submit_command(EndTurnCommand.new(actor.stable_id)),"Pause rejects direct combat commands")
	panel.close()
	for frame in range(600):
		if combat.state!=CombatController.State.RESOLVING_ACTION: break
		await process_frame
	check(combat.state==CombatController.State.AWAITING_COMMAND and actor.movement_remaining<spent,"Resume finishes original movement without duplicate spending")
	# Pause a committed attack: damage already happened exactly once.
	var target := combat.find_unit("enemy-01"); target.global_position=actor.global_position+Vector3.RIGHT*1.5
	await physics_frame; await physics_frame
	check(combat.submit_player_command(AttackCommand.new(actor.stable_id,target.stable_id)),"Attack resolves through authoritative pipeline")
	panel.open(); var health := target.health; var timer := combat._attack_remaining
	for frame in range(30): await process_frame
	check(target.health==health and combat._attack_remaining==timer,"Pause freezes attack resolution without duplicate damage")
	panel.close()
	for frame in range(100):
		if combat.state!=CombatController.State.RESOLVING_ACTION: break
		await process_frame
	check(target.health==health and not actor.action_available,"Resume does not duplicate damage or refund action")
	# Restart while settings owns a pause must retire all pending work.
	panel.open(); flow.request_transition("retry"); await wait_ready(); await drain()
	check(not paused and not audio.editing and not panel.visible and flow.combat.get_node("CombatController").find_unit("hero-01").action_available,"Restart clears settings pause and creates fresh combat")
	flow.show_title(); flow.queue_free(); await process_frame
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("SETTINGS RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
