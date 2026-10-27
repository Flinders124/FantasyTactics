extends SceneTree
var failures: int=0
var viewport: SubViewport
var flow: Node
var review_size: Vector2i
func check(value: bool,message: String) -> void:
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func frames(count: int=4) -> void:
	for i in range(count): await process_frame
func capture(label: String) -> void:
	await frames(); await RenderingServer.frame_post_draw
	var path := "res://../verification/camp/%d-%s.png"%[review_size.x,label]
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
func click(item: Button) -> void:
	item.grab_focus(); await frames()
	var point := item.get_global_rect().get_center()
	check(Rect2(Vector2.ZERO,Vector2(review_size)).has_point(point),"Camp button stays inside screen")
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.global_position=point; event.pressed=down
		viewport.push_input(event,true)
	await frames()
func gesture(camp: Node) -> void:
	var point: Vector2=camp.global_position+camp.size*.5
	var press := SettingsSchema.token_event(flow.audio.preferences.Controls.orbit[0]) as InputEventMouseButton
	press.position=point; press.global_position=point; press.pressed=true; viewport.push_input(press,true)
	var motion := InputEventMouseMotion.new(); motion.position=point+Vector2(80,0); motion.global_position=motion.position; motion.relative=Vector2(80,0); viewport.push_input(motion,true)
	press.position=Vector2(5,5); press.global_position=press.position; press.pressed=false; viewport.push_input(press,true)
	await frames()
func button(start: String,host: Node=null) -> Button:
	for item in (flow.menu if host==null else host).find_children("*","Button",true,false):
		if item.text.begins_with(start) and item.is_visible_in_tree(): return item as Button
	return null
func run() -> void:
	review_size=Vector2i(1920,1080) if OS.get_cmdline_user_args().has("1080") else Vector2i(1280,720)
	root.size=review_size
	viewport=SubViewport.new(); viewport.size=review_size; viewport.own_world_3d=true; viewport.gui_embed_subwindows=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate(); viewport.add_child(flow)
	flow.audio.settings_path="user://camp-review.cfg"; flow.audio.preferences=SettingsSchema.defaults(); flow.audio.apply_preferences(false)
	flow.campaign.state=CampaignState.new(17,"standard"); flow.campaign.hq_open=false; flow.campaign.headquarters(); await frames(15)
	for large in [false,true]:
		flow.audio.preferences.Accessibility.ui_scale=1.15 if large else 1.0; flow.audio.preferences.Accessibility.large_text=large; flow.audio.apply_preferences(false); await frames(8)
		var label := "large" if large else "default"
		await capture(label+"-overview")
		for index in range(5):
			await click(flow.menu.camp.destinations[index]); check(flow.menu.panel_overlay.visible and flow.menu.tabs.current_tab==index,"Camp location opens correct page")
			await capture(label+"-page-%d"%index)
			if index==0:
				var cancel := SettingsSchema.token_event(flow.audio.preferences.Controls.cancel[0]); cancel.pressed=true; viewport.push_input(cancel,true)
				cancel=cancel.duplicate(); cancel.pressed=false; viewport.push_input(cancel,true); await frames()
			else: await click(flow.menu.camp_back)
			check(not flow.menu.panel_overlay.visible,"Back to Camp / cancel closes page")
		var camp: Node=flow.menu.camp
		camp.reset_view(); await gesture(camp)
		check(camp.yaw!=0 and not camp.orbiting,"Real orbit gesture works and releasing outside camp stops drag")
		flow.audio.panel.open(); await frames(); var yaw: float=camp.yaw; await gesture(camp)
		check(camp.yaw==yaw,"Settings intercepts real camera gestures")
		await capture(label+"-settings"); flow.audio.panel.close(); await frames()
		camp.reset_view()
		await physics_frame
		var spot: Vector2=camp.camera.unproject_position(CampOverview.POINTS[0]+Vector3.UP*.5)+camp.global_position
		for down in [true,false]:
			var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=spot; event.global_position=spot; event.pressed=down; viewport.push_input(event,true)
		await frames(); check(flow.menu.panel_overlay.visible and flow.menu.tabs.current_tab==0,"Scenery click opens mission board")
		flow.menu.close_camp_page(); await frames()
		camp.destinations[2].grab_focus()
		for down in [true,false]:
			var event := InputEventKey.new(); event.keycode=KEY_ENTER; event.physical_keycode=KEY_ENTER; event.pressed=down; viewport.push_input(event,true)
		await frames(); check(flow.menu.panel_overlay.visible and flow.menu.tabs.current_tab==2,"Keyboard activates focused camp destination")
		flow.menu.close_camp_page(); await frames()
		flow.request_transition("controls"); await frames(); check(camp.blocked(),"Help blocks camera while open")
		await click(flow.menu_guide.close_button); check(not camp.blocked(),"Closing help restores real camp controls")
		if not large:
			flow.menu.open_camp_page(3); await frames(); await click(button("Buy Broadwatch Blade"))
			check(flow.menu.panel_overlay.visible and flow.menu.tabs.current_tab==3,"Actual purchase retains armoury panel")
			await click(button("Equip Broadwatch Blade")); await capture(label+"-equipped")
			var state: CampaignState=flow.campaign.state
			check(state.item(state.inventory[state.heroes.knight.equipment.weapon].definition_id).stable_id=="broadwatch","Actual camp armoury equips purchased instance")
			flow.menu.close_camp_page(); await frames()
		flow.menu.camp.yaw=-.48; flow.menu.camp.update_camera(); await capture(label+"-angle-left")
		flow.menu.camp.yaw=.48; flow.menu.camp.update_camera(); await capture(label+"-angle-right")
		flow.menu.camp.reset_view()
	flow.campaign.state=null; flow.show_title(); await frames(); flow.queue_free(); await frames(6); viewport.queue_free(); await frames()
	print("CAMP VISUAL RESULT: %d failures"%failures); quit(0 if failures==0 else 1)
