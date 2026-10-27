extends "res://tests/campaign_flow_tests.gd"
var viewport: SubViewport
var prefix: String
var review_size: Vector2i
func frames(count: int=3) -> void:
	for frame in range(count): await process_frame
func capture(label: String) -> void:
	await frames(); await RenderingServer.frame_post_draw
	check(viewport.size==review_size,"Captured viewport retains the requested review resolution")
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(prefix+"-"+label+".png"))
func click(item: Button) -> void:
	check(item!=null,"Review button exists")
	if item==null: return
	item.grab_focus(); await frames()
	var point := item.get_global_rect().get_center()
	check(Rect2(Vector2.ZERO,Vector2(viewport.size)).has_point(point),"Focused campaign button scrolls into viewport")
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.global_position=point; event.pressed=down
		viewport.push_input(event,true)
	await frames()
func button(start: String,host: Node=null) -> Button:
	for item in (flow.menu if host==null else host).find_children("*","Button",true,false):
		if item.text.begins_with(start) and item.is_visible_in_tree(): return item as Button
	return null
func tab(index: int) -> void:
	(flow.menu as CampaignScreen).tabs.current_tab=index
	await frames()
func run() -> void:
	review_size=Vector2i(1920,1080) if OS.get_cmdline_user_args().has("1080") else Vector2i(1280,720)
	root.size=review_size
	viewport=SubViewport.new(); viewport.size=review_size; viewport.own_world_3d=true; viewport.gui_embed_subwindows=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow; viewport.add_child(flow)
	flow.audio.settings_path="user://campaign-review.cfg"
	for larger in [false,true]:
		prefix="res://../verification/campaign/review-%d-%s"%[review_size.x,"large" if larger else "default"]
		flow.audio.preferences=SettingsSchema.defaults(); flow.audio.preferences.Accessibility.ui_scale=1.15 if larger else 1.0; flow.audio.preferences.Accessibility.large_text=larger; flow.audio.apply_preferences(false)
		flow.campaign.state=null; flow.show_title(); await frames()
		await click(button("New Campaign")); await capture("creation")
		flow.campaign.seed_text="17"
		await click(button("Establish the Watch")); await capture("headquarters")
		check(flow.screen=="headquarters","Real campaign creation reaches headquarters")
		# Generate a result fixture through strategy rules for training/injury presentation.
		var state: CampaignState=flow.campaign.state
		state.commit(state.offers[0].id,["knight","ranger"])
		state.resolve(CampaignMissionResult.new({"version":1,"mission_id":state.active.id,"outcome":"victory","abandoned":false,"reason":"Review fixture — party recovered the beacon","heroes":{"knight":{"health":0,"maximum_health":20},"ranger":{"health":14,"maximum_health":14}},"rounds":4,"tactical_result":"VICTORY"}))
		flow.campaign.headquarters(); await tab(1); await capture("roster")
		await tab(2); await capture("training")
		await click(button("Learn Stoneguard")); await capture("upgrade-confirmation")
		await click(flow.menu_guide.confirm_button)
		check(state.heroes.knight.upgrades.has("knight_2_0"),"Actual training confirmation commits one choice")
		await tab(3); await capture("armoury")
		await click(button("Buy Broadwatch Blade"))
		await tab(3); await click(button("Equip Broadwatch Blade")); await capture("equipped")
		check(state.item(state.inventory[state.heroes.knight.equipment.weapon].definition_id).stable_id=="broadwatch","Actual owned instance equips the selected hero")
		flow.campaign.prepare(state.offers[0].id); await capture("preparation")
		await click(button("✓ Selected — Warden"))
		check(button("Deploy").disabled,"One selected hero cannot deploy")
		await click(button("Select — Arcanist")); check(not button("Deploy").disabled,"Two distinct heroes enable deployment")
		await capture("alternative-party")
		flow.campaign.show_debrief(); await capture("debrief")
		await click(button("Return to Headquarters"))
		await tab(4); await capture("history")
		await click(button("Abandon campaign")); await capture("abandon-confirmation")
		await click(flow.menu_guide.close_button); check(flow.screen=="headquarters","Abandon cancellation preserves the run")
		flow.campaign.state=null; flow.show_title(); await frames(8)
	flow.queue_free(); await frames(8); viewport.queue_free(); await frames()
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists("user://campaign-review.cfg"+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path("user://campaign-review.cfg"+suffix))
	print("CAMPAIGN VISUAL RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
