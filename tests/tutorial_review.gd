extends "res://tests/tutorial_tests.gd"
var viewport: SubViewport
var prefix: String
func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(prefix+"-"+label+".png"))
func click(point: Vector2) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=point
		event.global_position=point
		event.pressed=down
		viewport.push_input(event,true)
		Input.flush_buffered_events()
	await process_frame
func point_at(point: Vector2) -> void:
	pass # Offscreen viewport receives local events without desktop pointer interference.
	var event := InputEventMouseMotion.new()
	event.position=point
	event.global_position=point
	viewport.push_input(event,true)
	Input.flush_buffered_events()
	for frame in range(4): await process_frame
func run() -> void:
	root.size=Vector2i(1920,1080) if OS.get_cmdline_user_args().has("1080") else Vector2i(1280,720)
	prefix=("res://../verification/settings/tutorial-max-%d" if OS.get_cmdline_user_args().has("max-ui") else "res://../verification/tutorial/review-%d")%root.size.x
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	viewport=SubViewport.new()
	viewport.size=root.size
	viewport.own_world_3d=true
	viewport.gui_embed_subwindows=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	viewport.add_child(flow)
	flow.audio.settings_path="user://tutorial_visual_verification.cfg"
	flow.audio.tutorial_completed=false
	if OS.get_cmdline_user_args().has("max-ui"):
		flow.audio.preferences.Accessibility.ui_scale=1.15
		flow.audio.preferences.Accessibility.large_text=true
		flow.audio.apply_preferences(false)
	flow.show_title()
	await capture("title")
	var tutorial_button: Button
	for button in flow.menu.find_children("*","Button",true,false):
		if button.text=="Tutorial": tutorial_button=button
	check(tutorial_button!=null and tutorial_button.get_global_rect().end.y<=root.size.y,"Tutorial entry fits title")
	await click(tutorial_button.get_global_rect().get_center())
	await ready_flow(false)
	await capture("briefing")
	check(flow.combat.guide.close_button.has_focus(),"Briefing has visible keyboard focus")
	await click(flow.combat.guide.close_button.get_global_rect().get_center())
	var scene := flow.combat
	var combat := scene.get_node("CombatController") as CombatController
	var director := scene.tutorial
	var camera := scene.get_node("TacticalCamera/Camera3D") as Camera3D
	var hud: CanvasLayer=scene.get_node("HUD")
	check(hud.root.get_node("HelpPanel").get_global_rect().end.y<=root.size.y,"Compact help buttons fit target viewport")
	await capture("camera")
	teach_camera(scene)
	await click(hud.move_button.get_global_rect().get_center())
	var point := camera.unproject_position(TutorialEncounter.FIRST_DESTINATION)
	await point_at(point)
	await capture("route")
	check(director.step==TutorialDirector.Step.MOVE,"Rendered mouse hover produces real legal navigation preview")
	if director.step!=TutorialDirector.Step.MOVE:
		flow.show_title()
		quit(1)
		return
	await click(point)
	await action_wait(combat)
	check(director.step==TutorialDirector.Step.ATTACK,"Actual world click moves to teaching destination")
	await capture("attack-instruction")
	await click(hud.attack_button.get_global_rect().get_center())
	point=camera.unproject_position(combat.find_unit("enemy-01").target_point())
	await point_at(point)
	await capture("attack-preview")
	await click(point)
	await action_wait(combat)
	check(director.step==TutorialDirector.Step.MOVE_AGAIN,"Actual target click resolves one melee attack")
	await click(hud.move_button.get_global_rect().get_center())
	point=camera.unproject_position(TutorialEncounter.SECOND_DESTINATION)
	await point_at(point)
	await capture("post-attack-move")
	await click(point)
	await action_wait(combat)
	await click(hud.button.get_global_rect().get_center())
	for frame in range(400):
		if director.step==TutorialDirector.Step.ABILITY: break
		await process_frame
	check(director.step==TutorialDirector.Step.ABILITY,"Rendered End Turn observes training enemy and Scout")
	await click(hud.ability_buttons[0].get_global_rect().get_center())
	point=camera.unproject_position(combat.find_unit("enemy-02").target_point())
	await point_at(point)
	await capture("ability-preview")
	await click(point)
	await action_wait(combat)
	check(director.step==TutorialDirector.Step.FINISH,"Rendered ranged ability reaches free-play finish")
	await capture("free-play")
	# Tooltip positioning, help text and focus at both target sizes.
	await point_at(hud.ability_buttons[0].get_global_rect().get_center())
	for frame in range(45): await process_frame
	var tooltip := hud.root.get_node("ReadableTooltips") as ReadableTooltips
	check(tooltip.visible and tooltip.panel.get_global_rect().end.x<=root.size.x and tooltip.panel.get_global_rect().end.y<=root.size.y,"Cooldown tooltip visible and bounded")
	await capture("tooltip")
	scene.show_help()
	await capture("help")
	check(scene.guide.panel.get_global_rect().size==Vector2(root.size),"Guide covers viewport without world click-through")
	check(paused and scene.guide.close_button.get_global_rect().end.y<=root.size.y,"Scrollable guide and keyboard focus fit viewport; simulation paused")
	for cycle in range(4):
		var tab := InputEventKey.new()
		tab.keycode=KEY_TAB
		tab.pressed=true
		viewport.push_input(tab,true)
		await process_frame
		tab.pressed=false
		viewport.push_input(tab,true)
		var focus := viewport.gui_get_focus_owner()
		check(focus!=null and focus.is_visible_in_tree() and focus.get_global_rect().end.y<=root.size.y,"Tab navigation stays on visible guidance controls")
	var audio_key := InputEventKey.new()
	audio_key.keycode=KEY_F10
	audio_key.pressed=true
	viewport.push_input(audio_key,true)
	check(flow.audio.panel.visible and paused,"Audio settings remain available over paused tutorial help")
	viewport.push_input(audio_key,true)
	check(not flow.audio.panel.visible and paused,"Closing audio retains briefing pause ownership")
	scene.guide.close()
	var serial := -1
	for frame in range(5000):
		if combat.state==CombatController.State.VICTORY: break
		if combat.state==CombatController.State.AWAITING_COMMAND and combat.scheduler.active_unit().faction==CombatUnit.Faction.HERO and serial!=combat.turn_serial:
			serial=combat.turn_serial
			await hero_turn(combat,combat.scheduler.active_unit())
		await process_frame
	check(combat.state==CombatController.State.VICTORY and director.step==TutorialDirector.Step.COMPLETE,"Rendered tutorial full encounter reaches result")
	await capture("result")
	check(hud.overlay_summary.text.contains("Tutorial complete"),"Completion message survives subsequent HUD refreshes")
	await click(hud.result_flow_buttons["retry"].get_global_rect().get_center())
	await ready_flow(false)
	await capture("replay-briefing")
	var exit_button: Button
	for candidate in flow.combat.guide.panel.find_children("*","Button",true,false):
		if candidate.text=="Exit to Main Menu": exit_button=candidate
	check(exit_button!=null and exit_button.get_global_rect().end.y<=root.size.y,"Exit available throughout blocking guidance")
	await click(exit_button.get_global_rect().get_center())
	await capture("abandon-confirmation")
	await click(flow.combat.guide.close_button.get_global_rect().get_center())
	check(flow.screen=="combat" and not paused,"Cancelling abandonment resumes active tutorial")
	var skip_button: Button
	for candidate in flow.combat.tutorial.panel.find_children("*","Button",true,false):
		if candidate.text=="Skip Tutorial": skip_button=candidate
	await click(skip_button.get_global_rect().get_center())
	await process_frame
	await click(flow.combat.guide.confirm_button.get_global_rect().get_center())
	await capture("normal-setup-after-skip")
	check(flow.screen=="party" and flow.combat==null and not paused,"Actual Skip confirmation reaches clean normal setup")
	flow.show_title()
	flow.queue_free()
	await process_frame
	if FileAccess.file_exists("user://tutorial_visual_verification.cfg"): DirAccess.remove_absolute(ProjectSettings.globalize_path("user://tutorial_visual_verification.cfg"))
	print("TUTORIAL VISUAL RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
