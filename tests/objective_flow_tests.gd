extends "res://tests/flow_tests.gd"

func run() -> void:
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	for cycle in range(5):
		flow.request_transition("new_encounter")
		flow.party.clear()
		flow.party.toggle("knight")
		flow.party.toggle("ranger")
		flow.menu.preset_selector.select(cycle%3)
		flow.menu.preset_selector.item_selected.emit(cycle%3)
		flow.menu.objective_selector.select((cycle+1)%3)
		flow.menu.objective_selector.item_selected.emit((cycle+1)%3)
		check(flow.party.ready() and not flow.menu.objective_description.text.is_empty(),"Selection includes objective explanation")
		flow.request_transition("start_encounter")
		await wait_ready()
		var config := flow.current_configuration
		var objective := config.objective.stable_id
		var preset := config.generator_settings.preset_id
		check(objective==EncounterOptions.objectives()[(cycle+1)%3].stable_id and preset==EncounterOptions.presets()[cycle%3].preset_id,"Selectors transfer into encounter configuration")
		var signature := config.layout.signature()
		var cosmetic := (flow.combat.get_node("CourtyardDressing") as CourtyardDressing).signature()
		var combat := flow.combat.get_node("CombatController") as CombatController
		combat.objectives.progress=2
		combat.objectives.last_checked_round=2
		var old: WeakRef = weakref(flow.combat)
		flow.request_transition("retry")
		await wait_ready()
		await drain()
		combat=flow.combat.get_node("CombatController") as CombatController
		check(old.get_ref()==null and flow.current_configuration.layout.signature()==signature,"Retry retires previous objective and preserves geometry")
		check((flow.combat.get_node("CourtyardDressing") as CourtyardDressing).signature()==cosmetic,"Retry reproduces dressing")
		check(combat.objectives.progress==0 and combat.objectives.last_checked_round==0 and combat.scheduler.round_completed.get_connections().size()==1,"Retry clears progress and has exactly one round callback")
		check(flow.combat.find_children("ObjectiveMarker","",true,false).size()==1,"One objective marker per encounter")
		var seed_value := flow.current_configuration.battlefield_seed
		flow.request_transition("new_battlefield")
		await wait_ready()
		check(flow.current_configuration.battlefield_seed!=seed_value and flow.current_configuration.objective.stable_id==objective and flow.current_configuration.generator_settings.preset_id==preset,"New Battlefield retains selected objective/preset and changes seed")
		# Cancel during actual incremental enemy planning; no stale routine survives.
		combat=flow.combat.get_node("CombatController") as CombatController
		combat.submit_player_command(EndTurnCommand.new(combat.scheduler.active_unit().stable_id))
		for frame in range(40):
			if (flow.combat.get_node("EnemyController") as EnemyController).stage==EnemyController.Stage.PLANNING: break
			await process_frame
		old=weakref(flow.combat)
		flow.request_transition("change_party")
		await drain()
		check(old.get_ref()==null and flow.combat==null and flow.party.ready(),"Change Party cancels objective AI and keeps party")
		flow.request_transition("main_menu")
		await drain()
		check(flow.screen=="title" and flow.retired.is_empty(),"Main Menu has no old objective/controller")
	flow.queue_free()
	await process_frame
	print("OBJECTIVE FLOW RESULT: %d failures; five complete transition cycles"%failures)
	quit(0 if failures==0 else 1)

