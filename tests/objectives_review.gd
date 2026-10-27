extends "res://tests/objective_encounter_tests.gd"
var flow: SceneFlow
var prefix: String
var measurements: Array[Dictionary]=[]

func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(prefix+"-"+label+".png"))

func flow_ready() -> void:
	for frame in range(1600):
		if flow.screen!="loading": break
		await process_frame
	check(flow.screen=="combat","Rendered objective setup ready")

func run() -> void:
	root.size=Vector2i(1920,1080) if OS.get_cmdline_user_args().has("1080") else Vector2i(1280,720)
	prefix="res://../verification/objectives/review-%d"%root.size.x
	if OS.get_cmdline_user_args().has("showcase"): prefix+="-showcase"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	flow.request_transition("new_encounter")
	flow.party.toggle("knight")
	flow.party.toggle("ranger")
	flow.menu.objective_selector.select(1)
	flow.menu.objective_selector.item_selected.emit(1)
	await capture("setup")
	check(flow.menu.start_button.get_global_rect().end.y<=root.size.y,"Setup footer fits resolution")
	for card in flow.menu.cards.values(): check(card.get_global_rect().end.y<=root.size.y,"All four cards fit resolution")
	for kind in range(3):
		var config := EncounterConfiguration.new()
		config.generator_settings=EncounterOptions.presets()[kind].duplicate(true) as BattlefieldSettings
		config.objective=EncounterOptions.objectives()[kind]
		config.battlefield_seed=7
		flow.start_configuration(config)
		await flow_ready()
		var combat := flow.combat.get_node("CombatController") as CombatController
		var rig := flow.combat.get_node("TacticalCamera") as TacticalCamera
		for angle in [0.0,2.1,4.2]:
			rig.yaw=angle
			rig._update_transform()
			await capture(config.generator_settings.preset_id+"-angle-%d"%int(angle*10))
		# Sample actual rendered frame intervals and engine workload after warmup.
		for frame in range(20): await process_frame
		var elapsed: Array[float]=[]
		var previous := Time.get_ticks_usec()
		for frame in range(90):
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			elapsed.append(float(now-previous)/1000)
			previous=now
		elapsed.sort()
		measurements.append({"preset":config.generator_settings.preset_id,"resolution":str(root.size),"median_frame_ms":elapsed[45],"p95_frame_ms":elapsed[85],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)})
		rig.yaw=0
		rig._update_transform()
		if OS.get_cmdline_user_args().has("showcase"): continue
		# Real command-driven full encounter with normal balance and enemy AI.
		var enemy := flow.combat.get_node("EnemyController") as EnemyController
		enemy.presentation_delay=0
		var last_serial := -1
		for frame in range(24000):
			if combat.state in [CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW]: break
			if combat.state==CombatController.State.AWAITING_COMMAND and combat.turn_serial!=last_serial:
				var actor := combat.scheduler.active_unit()
				if actor.faction==CombatUnit.Faction.HERO:
					last_serial=combat.turn_serial
					await hero_turn(combat,actor)
			await process_frame
		check(combat.state in [CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW],"Rendered objective encounter completes")
		outcomes.append({"objective":config.objective.stable_id,"result":CombatController.State.keys()[combat.state],"reason":combat.outcome_reason,"round":combat.scheduler.round_number})
		await capture(config.objective.stable_id+"-result")
		var signature := flow.current_configuration.layout.signature()
		var cosmetic := (flow.combat.get_node("CourtyardDressing") as CourtyardDressing).signature()
		flow.request_transition("retry")
		await flow_ready()
		check(flow.current_configuration.layout.signature()==signature and (flow.combat.get_node("CourtyardDressing") as CourtyardDressing).signature()==cosmetic,"Rendered retry geometry and dressing match")
		check((flow.combat.get_node("CombatController") as CombatController).objectives.progress==0,"Rendered retry resets progress")
	# Outcome-success presentation harness, no normal balance edits: stage a clear
	# board then use actual movement commands/EndTurn to complete the objectives.
	var combat := flow.combat.get_node("CombatController") as CombatController
	(flow.combat.get_node("EnemyController") as EnemyController).enabled=false
	for unit in combat.units:
		if unit.faction==CombatUnit.Faction.ENEMY: unit.set_health(0)
	var zone := combat.objectives.center
	combat.units[0].global_position=zone+Vector3(-.8,0,0)
	combat.units[1].global_position=zone+Vector3(.8,0,0)
	await physics_frame
	await physics_frame
	var actor := combat.scheduler.active_unit()
	check(combat.submit_player_command(MoveCommand.new(actor.stable_id,actor.global_position+Vector3(0,0,.5))),"Staged extraction final movement accepted")
	await action_wait(combat)
	check(combat.state==CombatController.State.VICTORY,"Extraction success overlay from authoritative movement")
	await capture("extraction-victory")
	var held := EncounterConfiguration.new()
	held.generator_settings=EncounterOptions.presets()[1].duplicate(true) as BattlefieldSettings
	held.objective=EncounterOptions.objectives()[1]
	held.battlefield_seed=11
	flow.start_configuration(held)
	await flow_ready()
	combat=flow.combat.get_node("CombatController") as CombatController
	(flow.combat.get_node("EnemyController") as EnemyController).enabled=false
	for unit in combat.units:
		if unit.faction==CombatUnit.Faction.ENEMY: unit.set_health(0)
	combat.units[0].global_position=Vector3(-.8,0,0)
	combat.units[1].global_position=Vector3(.8,0,0)
	combat.objectives.refresh(combat.units)
	combat.encounter_updated.emit()
	await capture("hold-controlled")
	for turn in range(6):
		combat.submit_player_command(EndTurnCommand.new(combat.scheduler.active_unit().stable_id))
	check(combat.state==CombatController.State.VICTORY and combat.objectives.progress==3,"Hold success through actual hero-only rounds")
	await capture("hold-victory")
	flow.show_title()
	await process_frame
	flow.queue_free()
	await process_frame
	var report := FileAccess.open(prefix+"-report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures":failures,"measurements":measurements,"outcomes":outcomes},"\t"))
	print("OBJECTIVES VISUAL RESULT: %d failures; three presets/angles/objectives"%failures)
	quit(0 if failures==0 else 1)
