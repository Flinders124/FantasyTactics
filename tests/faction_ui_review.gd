extends "res://tests/flow_tests.gd"
## Native renderer review; no headless frame-time claims. Fixed seed 7.
const OUTPUT: String = "res://../verification/factions/ui"
var samples: Array[Dictionary] = []
var shots: Array[String] = []
var requested_size: Vector2i = Vector2i(1280,720)
func frames(count: int) -> void:
	for frame in count: await process_frame
func capture(label: String) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=requested_size
	await frames(4)
	check(root.size==requested_size, "Screenshot uses exact requested resolution")
	await RenderingServer.frame_post_draw
	var path: String = OUTPUT + "/" + label + ".png"
	root.get_texture().get_image().save_png(path)
	shots.append(path)
func profile(label: String) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	root.size=requested_size
	await frames(45)
	var timings: Array[float] = []
	var calls: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for frame in 180:
		if root.size!=requested_size: root.size=requested_size
		await process_frame
		check(root.size==requested_size, "Profile frame uses requested size")
		var now: int = Time.get_ticks_usec()
		timings.append(float(now-previous)/1000.0); previous=now
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	timings.sort(); calls.sort()
	samples.append({"scene":label,"resolution":str(root.size),"warmup_frames":45,"sample_frames":180,"median_frame_ms":timings[90],"p95_frame_ms":timings[171],"median_draw_calls":calls[90],"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps=0
	flow=load("res://scenes/main.tscn").instantiate() as SceneFlow
	root.add_child(flow)
	flow.audio.settings_path="user://faction-review.cfg"
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		requested_size=resolution
		root.size=resolution
		for large in [false,true]:
			flow.audio.preferences=SettingsSchema.defaults()
			flow.audio.preferences.Accessibility.ui_scale=1.15 if large else 1.0
			flow.audio.preferences.Accessibility.large_text=large
			flow.audio.apply_preferences(false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			root.size=resolution
			await frames(4)
			flow.show_party()
			flow.party.toggle("knight") if not flow.party.selected.has("knight") else false
			flow.party.toggle("ranger") if not flow.party.selected.has("ranger") else false
			flow.menu.seed_input.text="7"; flow.menu.seed_input.text_changed.emit("7")
			flow.menu.faction_selector.select(1); flow.menu.faction_selector.item_selected.emit(1)
			flow.menu.elite_toggle.button_pressed=true; flow.menu.elite_toggle.toggled.emit(true)
			var prefix: String = "%d-%s" % [resolution.x,"max" if large else "normal"]
			flow.menu.settings_scroll.ensure_control_visible(flow.menu.faction_selector)
			await capture(prefix+"-setup-faction")
			check(flow.menu.start_button.get_global_rect().end.y<=resolution.y,"Start footer fits "+prefix)
			flow.request_transition("bestiary")
			await frames(3)
			var reference := flow.menu.get_node("EnemyReference") as EnemyReference
			for faction in 3:
				reference.faction_choice.select(faction); reference.choose_faction()
				reference.unit_choice.select(4); reference.show_unit()
				await capture(prefix+"-bestiary-"+FactionCatalog.ids()[faction])
			reference.queue_free(); await frames(3)
		flow.audio.preferences=SettingsSchema.defaults(); flow.audio.apply_preferences(false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		root.size=resolution
		await frames(4)
		var config:=EncounterConfiguration.new()
		config.faction_id="ashfang"; config.campaign_stage=4; config.battlefield_seed=7
		config.difficulty=load("res://definitions/difficulties/hard.tres") as DifficultyDefinition
		config.resolve_roster()
		# Explicit valid maximum-count fixture; budget-driven seed7 has three enemies.
		config.resolved_enemy_ids=PackedStringArray(["ashfang_raider","ashfang_shieldguard","ashfang_bowhunter","ashfang_shaman"])
		config.enemies.clear()
		for id in config.resolved_enemy_ids: config.enemies.append(EnemyCatalog.find(id).duplicate(true) as UnitDefinition)
		var started: int = Time.get_ticks_usec()
		flow.start_configuration(config)
		flow.combat.get_node("EnemyController").enabled=false
		await wait_ready(); await drain()
		var combat:=flow.combat.get_node("CombatController") as CombatController
		check(combat.units.size()==6,"Largest normal encounter contains six units")
		samples.append({"scene":"six_unit_load_navigation","resolution":str(resolution),"seed":7,"load_to_navigation_ready_ms":float(Time.get_ticks_usec()-started)/1000.0,"unit_count":combat.units.size(),"roster":flow.current_configuration.resolved_enemy_ids})
		await capture("%d-six-units"%resolution.x)
		await profile("six_unit_explicit_roster_hard_ashfang_idle")
		config=EncounterConfiguration.new(); config.faction_id="ashfang"; config.elite_encounter=true; config.campaign_stage=4; config.battlefield_seed=7; config.resolve_roster()
		flow.start_configuration(config); flow.combat.get_node("EnemyController").enabled=false
		await wait_ready(); await drain()
		combat=flow.combat.get_node("CombatController") as CombatController
		var elite: CombatUnit
		for unit in combat.units:
			if unit.definition.is_elite: elite=unit
		check(elite!=null,"Elite fixture exists")
		combat.scheduler.cursor=combat.scheduler.order.find(elite)
		elite.action_available=true; combat.state=CombatController.State.AWAITING_COMMAND
		var rig := flow.combat.get_node("TacticalCamera") as TacticalCamera
		# Fixture pans the normal camera to the committed location; pitch/distance unchanged.
		rig.position=elite.global_position
		rig._update_transform()
		var point: Vector3=elite.global_position
		check(combat.submit_command(UseAbilityCommand.on_ground(elite.stable_id,"elite_ashfang",point)),"Actual prepare command accepted")
		await frames(60)
		check(combat.pending_telegraphs.has(elite.stable_id),"Warning persists after preparation")
		await capture("%d-elite-persistent-warning"%resolution.x)
		flow.show_title(); await drain()
	var report: Dictionary={"failures":failures,"engine":Engine.get_version_info(),"os":OS.get_distribution_name(),"os_version":OS.get_version(),"cpu":OS.get_processor_name(),"logical_processors":OS.get_processor_count(),"gpu":RenderingServer.get_video_adapter_name(),"gpu_vendor":RenderingServer.get_video_adapter_vendor(),"renderer":RenderingServer.get_current_rendering_method(),"seed":7,"vsync":"enabled; wall-frame measurements include pacing; local machine only","headless":DisplayServer.get_name()=="headless","samples":samples,"screenshots":shots}
	var file:=FileAccess.open(OUTPUT+"/results.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	flow.free(); await frames(3)
	print("FACTION UI REVIEW RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)



