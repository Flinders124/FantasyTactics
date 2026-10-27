extends SceneTree
var failures: int=0
func check(value: bool,message: String) -> void:
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func frames(count: int=4) -> void:
	for i in range(count): await process_frame
func run() -> void:
	var flow := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(flow)
	flow.audio.preferences=SettingsSchema.defaults(); flow.audio.apply_preferences(false)
	flow.campaign.state=CampaignState.new(17,"standard")
	flow.campaign.headquarters()
	await process_frame
	var view: Node=flow.menu
	check(view.get("camp")!=null,"Headquarters must contain the interactive camp overview")
	if view.get("camp")!=null:
		check(view.camp.destinations.size()==5,"Five destinations exist")
		check(not view.panel_overlay.visible,"Headquarters starts in camp overview")
		for index in range(5):
			view.open_camp_page(index)
			check(view.panel_overlay.visible and view.tabs.current_tab==index,"Destination opens its existing page")
			check(not view.camp.interactive,"Panel blocks camp commands")
			view.close_camp_page()
			check(not view.panel_overlay.visible and view.camp.interactive,"Back to Camp restores interaction")
			check(view.camp.destinations[index].has_focus(),"Back restores keyboard focus to selected destination")
		var camp: Node=view.camp
		await physics_frame
		check(camp.pick_at(camp.camera.unproject_position(CampOverview.POINTS[0]+Vector3.UP*1.5))==0,"Clicking the board geometry picks its destination")
		var orbit := SettingsSchema.token_event(flow.audio.preferences.Controls.orbit[0])
		orbit.pressed=true; camp.handle_input(orbit)
		var motion := InputEventMouseMotion.new(); motion.relative=Vector2(200,0)
		camp.handle_input(motion); check(camp.yaw!=0,"Orbit moves the overview camera")
		camp.handle_input(motion); check(absf(camp.yaw)<=.48,"Orbit is bounded")
		view.open_camp_page(0); var heading: float=camp.yaw; camp.handle_input(motion)
		check(camp.yaw==heading,"Panel blocks orbit input")
		view.close_camp_page(); flow.audio.panel.open(); await frames()
		camp.handle_input(orbit); camp.handle_input(motion); camp.select_destination(2)
		check(camp.yaw==heading and not view.panel_overlay.visible,"Settings blocks camera and destination selection")
		flow.audio.panel.close(); await frames()
		camp.reset_view(); check(camp.yaw==0 and camp.zoom==1,"Reset restores initial framing")
		flow.audio.preferences.Camera.reduced_motion=true; flow.audio.preferences.Accessibility.reduced_effects=true; flow.audio.apply_preferences(false)
		await frames(); check(camp.reduced_motion and not camp.flame.visible,"Reduced effects and motion preferences apply")
		for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size=dimensions; await frames(8)
			for large in [false,true]:
				flow.audio.preferences.Accessibility.ui_scale=1.15 if large else 1.0; flow.audio.preferences.Accessibility.large_text=large; flow.audio.apply_preferences(false); await frames(8)
				for first in range(5):
					var rect: Rect2=camp.destinations[first].get_rect()
					check(Rect2(Vector2.ZERO,camp.size).encloses(rect),"Projected label stays inside camp at both resolutions and text sizes")
					for second in range(first+1,5): check(not rect.intersects(camp.destinations[second].get_rect()),"Labels %d/%d overlap at %s large=%s: %s / %s"%[first,second,dimensions,large,rect,camp.destinations[second].get_rect()])
				for heading_value: float in [-.48,0,.48]:
					for zoom_value: float in [.86,1.15]:
						camp.yaw=heading_value; camp.zoom=zoom_value; camp.update_camera(); await frames()
						for first in range(5):
							var rect: Rect2=camp.destinations[first].get_rect()
							check(Rect2(Vector2.ZERO,camp.size).encloses(rect),"Camera extremes retain label bounds")
							for second in range(first+1,5): check(not rect.intersects(camp.destinations[second].get_rect()),"Camera extremes retain distinct labels")
				camp.reset_view()
		view.open_camp_page(3)
		var state: CampaignState=flow.campaign.state
		var supplies: int=state.supplies
		flow.request_transition("campaign_buy:broadwatch"); await frames(8)
		check(flow.menu.panel_overlay.visible and flow.menu.tabs.current_tab==3,"Purchase rebuild retains open armoury")
		check(state.supplies==supplies-state.item("broadwatch").cost,"Purchase still spends through existing campaign rules")
		check(get_nodes_in_group("headquarters_camps").size()==1,"Rebuild retains exactly one camp")
		for cycle in range(5):
			flow.show_title(); await frames(6)
			check(get_nodes_in_group("headquarters_camps").is_empty(),"Menus clean camp-owned nodes")
			flow.campaign.hq_open=false; flow.campaign.headquarters(); await frames(6)
			check(get_nodes_in_group("headquarters_camps").size()==1,"Repeated return creates exactly one camp")
		camp=flow.menu.camp
		flow.request_transition("controls"); check(camp.blocked(),"Help blocks camp input while visible")
		flow.menu_guide.close(); await frames()
		check(not camp.blocked(),"Closing help restores camp input without rebuilding headquarters")
		flow.campaign.confirm("Camp regression","Cancel keeps the current camp",func() -> void: pass)
		flow.menu_guide.close(); await frames()
		check(not camp.blocked(),"Cancelling a confirmation restores camp input")
		flow.menu_guide.queue_free(); flow.menu_guide=null; await frames()
		flow.audio.preferences.Controls.orbit=["K:%d"%KEY_J]; flow.audio.preferences.Controls.zoom_in=["K:%d"%KEY_K]
		SettingsSchema.install_bindings(flow.audio.preferences.Controls)
		camp.reset_view()
		var key := InputEventKey.new(); key.physical_keycode=KEY_J; key.pressed=true
		camp.handle_input(key); camp.handle_input(motion)
		check(camp.yaw!=0,"Remapped keyboard orbit accepts input")
		key.physical_keycode=KEY_K; camp.handle_input(key)
		check(camp.zoom<1,"Remapped keyboard zoom accepts input")
		SettingsSchema.install_bindings(SettingsSchema.defaults().Controls)
	flow.queue_free(); await process_frame; await process_frame
	print("CAMP RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)

