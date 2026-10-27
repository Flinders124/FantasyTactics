extends "res://tests/camp_review.gd"
func capture(label: String) -> void:
	await frames(); await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../verification/release/review-%d-%s.png"%[review_size.x,label]))
func run() -> void:
	review_size=Vector2i(1920,1080) if OS.get_cmdline_user_args().has("1080") else Vector2i(1280,720)
	root.size=review_size
	viewport=SubViewport.new(); viewport.size=review_size; viewport.own_world_3d=true; viewport.gui_embed_subwindows=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate(); viewport.add_child(flow)
	flow.campaign.store.path="user://release-review/%d/active.json"%OS.get_process_id()
	flow.audio.settings_path="user://release-review/%d/settings.cfg"%OS.get_process_id()
	for larger in [false,true]:
		flow.campaign.store.discard(); flow.campaign.state=null; flow.show_title()
		flow.audio.preferences=SettingsSchema.defaults(); flow.audio.preferences.Accessibility.ui_scale=1.15 if larger else 1.0; flow.audio.preferences.Accessibility.large_text=larger; flow.audio.apply_preferences(false); await frames(8)
		var tag := "large" if larger else "default"
		await capture(tag+"-title-new")
		await click(button("New Campaign")); await capture(tag+"-creation")
		flow.campaign.seed_text="17"; flow.campaign.difficulty_index=0
		await click(button("Establish the Watch")); await capture(tag+"-camp-saved")
		check(flow.screen=="headquarters" and not flow.campaign.dirty,"Creation UI commits a durable slot")
		await click(flow.menu.camp.destinations[0]); await capture(tag+"-missions")
		await click(button("Prepare mission")); await capture(tag+"-preparation")
		await click(button("Deploy"))
		for frame in range(6000):
			if flow.screen!="loading": break
			await process_frame
		check(flow.screen=="combat" and flow.combat.navigation_ready,"Real deployment waits for navigation")
		await capture(tag+"-briefing")
		flow.combat.guide.close(); await frames(12); await capture(tag+"-combat")
		flow.campaign.abandon_mission(); await frames(); await capture(tag+"-abandon-confirmation")
		await click(flow.combat.guide.confirm_button); await capture(tag+"-debrief")
		check(flow.campaign.state.resolutions==1 and not flow.campaign.dirty,"Abandonment consequences commit exactly once")
		await click(button("Return to Headquarters")); await click(button("Save & Main Menu")); await capture(tag+"-title-continue")
		await click(button("Continue Campaign")); await capture(tag+"-continued-camp")
		check(flow.screen=="headquarters" and flow.campaign.state.resolutions==1,"Continue UI restores progress")
		flow.audio.panel.open(); await frames(); await capture(tag+"-settings"); flow.audio.panel.close()
		flow.campaign.store.discard(); flow.campaign.state=null; flow.show_title(); await frames(8)
	flow.queue_free(); await frames(8); viewport.queue_free(); await frames()
	print("RELEASE VISUAL RESULT: %d failures"%failures); quit(0 if failures==0 else 1)
