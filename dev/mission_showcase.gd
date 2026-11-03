extends SceneTree
## Renderer captures of real campaign screens/configurations, never mockups.
var flow: SceneFlow
var failures: int=0
const OUTPUT: String="res://docs/mission-variety/screenshots"
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for frame in range(20): await process_frame
func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(OUTPUT.path_join(name+".png"))
	if error!=OK: failures+=1; push_error("Screenshot failed: "+error_string(error))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size=Vector2i(1280,720)
	flow=load("res://scenes/main.tscn").instantiate(); root.add_child(flow)
	flow.campaign.store.path="user://mission-showcase/active.json"
	flow.campaign.state=LegacyCampaignFixture.new(17,"standard")
	flow.campaign.headquarters(); await settle()
	flow.menu.open_camp_page(0)
	await capture("mission-board-1280")
	root.size=Vector2i(1920,1080); await capture("mission-board-1920")
	root.size=Vector2i(1280,720)
	for layout_id in ["narrow_approach","split_courtyard"]:
		var config: EncounterConfiguration
		for seed_value in range(17,80):
			var state: CampaignState = LegacyCampaignFixture.new(seed_value,"standard")
			for offer in state.offers:
				var candidate:=state.prepare(offer.id,["knight","ranger"])
				if candidate.generator_settings.preset_id==layout_id:
					flow.campaign.state=state; config=candidate; break
			if config!=null: break
		if config==null: failures+=1; push_error("No showcase mission for "+layout_id); continue
		flow.start_configuration(config)
		for frame in range(1800):
			if flow.screen!="loading": break
			await process_frame
		if flow.screen!="combat" or not flow.combat.navigation_ready: failures+=1; push_error("Showcase navigation unavailable"); continue
		flow.combat.get_node("EnemyController").enabled=false
		if flow.combat.guide!=null: flow.combat.guide.close()
		await capture(layout_id+"-1280")
		root.size=Vector2i(1920,1080); await capture(layout_id+"-1920")
		root.size=Vector2i(1280,720)
	flow.campaign.state=null; flow.show_title(); flow.queue_free(); await settle()
	print("MISSION SHOWCASE RESULT: %d failures"%failures); quit(0 if failures==0 else 1)
