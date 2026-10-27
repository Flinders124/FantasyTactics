extends "res://tests/flow_tests.gd"

func run() -> void:
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	flow.request_transition("new_encounter")
	# This fixture asserts the original Raider/Sentinel HP values, not a random faction roster.
	flow.party.faction_choice="legacy"
	flow.party.toggle("knight")
	flow.party.toggle("ranger")
	flow.menu.seed_input.text="not-a-seed"
	flow.menu.seed_input.text_changed.emit("not-a-seed")
	check(flow.menu.start_button.disabled and flow.menu.message.text.contains("Seed"),"Invalid setup blocks Start with explanation")
	flow.menu.seed_input.text="7"
	flow.menu.seed_input.text_changed.emit("7")
	flow.show_title()
	flow.request_transition("new_encounter")
	check(flow.party.ready() and flow.menu.seed_input.text=="7","Back and New Encounter preserve draft selections")
	for index in range(3):
		flow.menu.difficulty_selector.select(index)
		flow.menu.difficulty_selector.item_selected.emit(index)
		var id := EncounterOptions.difficulties()[index].stable_id
		check(flow.menu.summary_label.text.contains(EncounterOptions.difficulties()[index].display_name),"Summary shows selected difficulty")
		flow.request_transition("start_encounter")
		await wait_ready()
		var config := flow.current_configuration
		var expected: Array[int]=[]
		expected.assign([14,14] if index==0 else ([16,18] if index==1 else [18,20]))
		var combat := flow.combat.get_node("CombatController") as CombatController
		check(combat.units[2].health==expected[0] and combat.units[3].health==expected[1],"Selected difficulty applies adjusted enemy health")
		var signature := config.layout.signature()
		var cosmetic := (flow.combat.get_node("CourtyardDressing") as CourtyardDressing).signature()
		var code := EncounterCode.encode(config)
		var decoded := EncounterCode.decode(code)
		check(decoded.configuration!=null,"Prepared encounter code valid")
		flow.start_configuration(decoded.configuration)
		await wait_ready()
		check(flow.current_configuration.layout.signature()==signature,"Shared code reproduces accepted layout without cached geometry")
		check((flow.combat.get_node("CourtyardDressing") as CourtyardDressing).signature()==cosmetic,"Shared code reproduces cosmetic stream")
		for retry in range(2):
			combat=flow.combat.get_node("CombatController") as CombatController
			combat.units[2].set_health(1)
			var old: WeakRef=weakref(flow.combat)
			flow.request_transition("retry")
			await wait_ready()
			await drain()
			combat=flow.combat.get_node("CombatController") as CombatController
			check(old.get_ref()==null and combat.units[2].health==expected[0] and combat.units[3].health==expected[1],"Retry is fresh without compound modifiers")
			check(flow.current_configuration.layout.signature()==signature and flow.current_configuration.difficulty.stable_id==id,"Retry preserves frozen setup")
		var original_seed := flow.current_configuration.battlefield_seed
		flow.request_transition("new_battlefield")
		await wait_ready()
		check(flow.current_configuration.battlefield_seed!=original_seed and flow.current_configuration.difficulty.stable_id==id and flow.current_configuration.resolved_enemy_ids==config.resolved_enemy_ids,"New Battlefield retains difficulty and resolves deterministic template")
		combat=flow.combat.get_node("CombatController") as CombatController
		combat.submit_player_command(EndTurnCommand.new(combat.scheduler.active_unit().stable_id))
		for frame in range(60):
			if (flow.combat.get_node("EnemyController") as EnemyController).stage==EnemyController.Stage.PLANNING: break
			await process_frame
		var old: WeakRef=weakref(flow.combat)
		flow.request_transition("change_setup")
		await drain()
		check(old.get_ref()==null and flow.party.difficulty_index==index and flow.menu.seed_input.text==str(flow.current_configuration.battlefield_seed),"Change Setup cancels old AI and preserves all selections")
		check(flow.menu.start_button.text=="Start Encounter" and flow.party.ready(),"Restored setup starts normally")
	# A shared accepted fallback must reproduce its attempt, not start a new retry
	# sequence. This is configuration sharing with no cached geometry in the code.
	var fallback := EncounterConfiguration.new()
	fallback.generator_settings.obstacle_count=30
	fallback.generator_settings.obstacle_min_size=Vector2(10,10)
	fallback.generator_settings.obstacle_max_size=Vector2(10,10)
	fallback.generator_settings.generation_attempts=1
	fallback.generator_settings.placement_attempts=1
	flow.start_configuration(fallback)
	await wait_ready()
	check(flow.current_configuration.layout.used_fallback,"Sharing fixture actually uses bounded fallback")
	var fallback_signature := flow.current_configuration.layout.signature()
	var fallback_code := EncounterCode.decode(EncounterCode.encode(flow.current_configuration))
	check(fallback_code.configuration!=null and fallback_code.configuration.requested_attempt==2,"Fallback attempt represented in code")
	flow.start_configuration(fallback_code.configuration)
	await wait_ready()
	check(flow.current_configuration.layout.signature()==fallback_signature,"Code reproduces exact fallback geometry")
	flow.request_transition("change_setup")
	# Restore the previous Hard selection for the result-interface scenario.
	flow.party.difficulty_index=2
	flow.party.edited()
	# Authoritative result snapshot, including defeat lists and rounds completed.
	flow.request_transition("start_encounter")
	await wait_ready()
	var combat := flow.combat.get_node("CombatController") as CombatController
	(flow.combat.get_node("EnemyController") as EnemyController).enabled=false
	for turn in range(4): combat.submit_command(EndTurnCommand.new(combat.scheduler.active_unit().stable_id))
	combat._damage_in_progress=true
	combat.units[2].set_health(0)
	combat.units[3].set_health(0)
	combat._damage_in_progress=false
	combat._check_outcome(true)
	var hud: CanvasLayer=flow.combat.get_node("HUD")
	check(combat.completed_rounds==1 and combat.result_summary.defeated_enemies.size()==2,"Result uses authoritative completed rounds and defeats")
	check(hud.overlay_summary.text.contains("Hard") and hud.overlay_summary.text.contains("Rounds completed: 1") and hud.result_flow_buttons["change_party"].text=="Change Setup","Result displays difficulty and Change Setup")
	flow.show_title()
	await drain()
	flow.queue_free()
	await process_frame
	print("DIFFICULTY FLOW RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
