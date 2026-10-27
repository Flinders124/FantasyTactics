extends "res://tests/flow_tests.gd"
## Native GPU benchmark: no --headless/--fixed-fps; before/after labels are user args.
var report: Dictionary = {}
var samples: Array[Dictionary] = []
func frames(count: int) -> void:
	for i in range(count): await process_frame
func sample(label: String) -> void:
	await frames(45)
	var timings: Array[float] = []
	var draw: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in range(180):
		await process_frame
		var now := Time.get_ticks_usec()
		timings.append(float(now-previous)/1000.0); previous=now
		draw.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	timings.sort(); draw.sort()
	samples.append({"scene":label,"resolution":str(root.size),"sample_frames":180,"warmup_frames":45,"median_frame_ms":timings[90],"p95_frame_ms":timings[171],"draw_calls_median":draw[90],"render_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000})
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps=0
	report={"os":OS.get_distribution_name(),"os_version":OS.get_version(),"cpu":OS.get_processor_name(),"logical_processors":OS.get_processor_count(),"gpu":RenderingServer.get_video_adapter_name(),"gpu_vendor":RenderingServer.get_video_adapter_vendor(),"renderer":RenderingServer.get_current_rendering_method(),"seed":7,"preset":"standard/default; camp seed 78231; default vsync enabled; fps limit 0; wall frame timing includes pacing","engine":Engine.get_version_info(),"headless":DisplayServer.get_name()=="headless"}
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate(); root.add_child(flow)
	flow.audio.settings_path="user://release-profile.cfg"; flow.audio.preferences=SettingsSchema.defaults(); flow.audio.apply_preferences(false)
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		flow.campaign.state=CampaignState.new(17,"standard"); flow.campaign.hq_open=false; flow.campaign.headquarters(); await frames(15)
		await sample("camp_overview")
		flow.menu.open_camp_page(0)
		await sample("camp_covered_by_mission_board")
		check(flow.menu.camp.view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Covered camp does not render")
		check(not flow.menu.camp.stage.can_process(),"Covered camp pauses presentation descendants")
		flow.menu.close_camp_page(); await frames(4)
		check(flow.menu.camp.view.render_target_update_mode!=SubViewport.UPDATE_DISABLED,"Camp resumes rendering on return")
		check(flow.menu.camp.stage.can_process(),"Camp presentation resumes on return")
		check(not flow.menu.camp.layout_dirty,"Projected labels settle after returning to camp")
		flow.audio.preferences.Accessibility.high_contrast=true; flow.audio.preferences.Camera.reduced_motion=true; flow.audio.apply_preferences(false)
		await sample("camp_high_contrast_reduced_motion")
		flow.audio.preferences=SettingsSchema.defaults(); flow.audio.apply_preferences(false)
		flow.campaign.state=null
		var config := EncounterConfiguration.new(); config.battlefield_seed=7
		var started := Time.get_ticks_usec()
		flow.start_configuration(config); flow.combat.get_node("EnemyController").enabled=false
		await wait_ready(); await drain()
		samples.append({"scene":"combat_load_navigation","resolution":str(root.size),"load_to_navigation_ready_ms":float(Time.get_ticks_usec()-started)/1000.0})
		await sample("courtyard_idle")
		flow.show_title(); await drain()
	var cycles: Array[Dictionary] = []
	for i in range(10):
		var config := EncounterConfiguration.new(); config.battlefield_seed=7
		flow.start_configuration(config); flow.combat.get_node("EnemyController").enabled=false
		await wait_ready(); await drain()
		var old: WeakRef = weakref(flow.combat)
		flow.show_title(); await drain(); await frames(8)
		check(old.get_ref()==null,"Cycle %d frees encounter"%i)
		cycles.append({"cycle":i+1,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"orphan_nodes":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)})
	report.samples=samples; report.cycles=cycles; report.failures=failures
	var label := "headless-checks" if DisplayServer.get_name()=="headless" else ("before" if OS.get_cmdline_user_args().has("before") else "after")
	var output := FileAccess.open("res://../verification/release/performance/"+label+".json",FileAccess.WRITE); output.store_string(JSON.stringify(report,"\t")); output.close()
	flow.free(); await frames(4)
	print("RELEASE PROFILE RESULT: %d failures"%failures); quit(0 if failures==0 else 1)

