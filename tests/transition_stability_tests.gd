extends "res://tests/flow_tests.gd"

func start_fresh() -> void:
	var config := EncounterConfiguration.new()
	config.battlefield_seed = 7
	flow.start_configuration(config)
	flow.combat.get_node("EnemyController").enabled = false
	await wait_ready()
	await drain()

func clean_combat() -> void:
	var combat := flow.combat
	var controller := combat.get_node("CombatController") as CombatController
	check(controller.units.size() == 4 and combat.get_node("Units").get_child_count() == 4, "Exactly four units per replacement")
	check(controller.units.all(func(unit: CombatUnit) -> bool: return unit.health == unit.definition.maximum_health and unit.cooldown_ready_turn.is_empty() and unit.statuses.is_empty() and unit.character.get_child_count() == 1), "Replacement has fresh gameplay and visual state")
	check(controller.combat_event.get_connections().size() == 2 and controller.action_completed.get_connections().size() == 1, "No duplicate event/AI subscriptions")
	check(combat.get_node("CombatPresentation").effects.is_empty() and combat.get_node("CombatPresentation").tracers.is_empty() and combat.get_node("CombatPresentation").blasts.is_empty(), "No old presentation work")
	var presentation := combat.get_node("CombatPresentation") as CombatPresentation
	check(presentation.voices.is_empty() and presentation.pending_sounds.is_empty() and presentation.glyphs.is_empty(),"No old world sounds, delayed audio or ability glyphs")
	check(controller.scheduler.round_number == 1 and controller.find_unit("hero-01").owner_turn == 1, "Fresh initiative and exactly one initial turn allocation")
	check(get_nodes_in_group("courtyard_dressing").size()==1 and combat.courtyard_occlusion!=null,"Exactly one courtyard dressing and visibility controller survive transitions")
	check(combat.courtyard_occlusion.roots.all(func(prop: Node3D) -> bool: return is_instance_valid(prop) and combat.is_ancestor_of(prop)),"Visibility references belong only to the current encounter")

func stage_result(result: CombatController.State) -> void:
	var controller := flow.combat.get_node("CombatController") as CombatController
	# The draw's damage batch is exercised by area_tests; stage its simultaneous
	# health snapshot here to exercise every result's real transition buttons.
	controller._damage_in_progress = true
	for unit in controller.units:
		if result == CombatController.State.DRAW or (unit.faction == CombatUnit.Faction.ENEMY) == (result == CombatController.State.VICTORY):
			unit.set_health(0)
	controller._damage_in_progress = false
	controller._check_outcome()
	check(controller.state == result,"Shared outcome evaluation produces requested result")

func run() -> void:
	flow = (load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	var old_title := flow.menu
	flow.show_party()
	flow.party.toggle("knight")
	flow.party.toggle("ranger")
	old_title.requested.emit("new_encounter")
	check(flow.party.ready(),"Retired menu requests cannot reset current selections")
	var old_menu := flow.menu
	flow.start_configuration(EncounterConfiguration.new())
	old_menu.cards["knight"].pressed.emit()
	check(flow.party.selected == PackedStringArray(["knight","ranger"]), "Retired card signals cannot mutate active configuration")
	await wait_ready()
	await drain()
	for result in [CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW]:
		for action in ["retry","new_battlefield","change_party","main_menu"]:
			await start_fresh()
			var signature := flow.current_configuration.layout.signature()
			var dressing_signature := (flow.combat.get_node("CourtyardDressing") as CourtyardDressing).signature()
			var old: WeakRef = weakref(flow.combat)
			var old_seed := flow.current_configuration.battlefield_seed
			stage_result(result)
			flow.combat.get_node("HUD").result_flow_buttons[action].pressed.emit()
			if action in ["retry","new_battlefield"]:
				await wait_ready()
				await drain()
				clean_combat()
				check(flow.current_configuration.hero_ids == PackedStringArray(["knight","ranger"]), "Replay keeps selected heroes")
				if action == "retry":
					check(flow.current_configuration.layout.signature() == signature, "Retry preserves exact layout and enemy setup")
					check((flow.combat.get_node("CourtyardDressing") as CourtyardDressing).signature()==dressing_signature,"Retry reproduces exact courtyard dressing")
				else:
					check(flow.current_configuration.battlefield_seed != old_seed,"New Battlefield chooses a new seed")
			else:
				await drain()
				check(flow.combat == null and flow.screen == ("party" if action == "change_party" else "title"), "Menu option leaves combat")
			check(old.get_ref() == null and flow.retired.is_empty(),"Result transition frees the old encounter")
	# Five consecutive action-effect/retry/menu cycles, with weak references to
	# prove old units, AI, controllers and effect roots have actually been freed.
	for iteration in range(5):
		await start_fresh()
		var controller := flow.combat.get_node("CombatController") as CombatController
		var old: WeakRef = weakref(flow.combat)
		var ai := flow.combat.get_node("EnemyController") as EnemyController
		ai.enabled = true
		controller.submit_player_command(EndTurnCommand.new("hero-01"))
		check(ai.stage != EnemyController.Stage.IDLE,"Enemy routine pending before Retry")
		flow.request_transition("retry")
		await wait_ready()
		await drain()
		clean_combat()
		check(old.get_ref() == null,"Enemy turn restart frees old routine")
		controller = flow.combat.get_node("CombatController") as CombatController
		flow.combat.get_node("EnemyController").enabled = false
		var hero := controller.find_unit("hero-01")
		var target := controller.find_unit("enemy-01")
		target.position = hero.position + Vector3(1.5,0,0)
		await physics_frame
		await physics_frame
		check(controller.submit_player_command(AttackCommand.new(hero.stable_id,target.stable_id)),"Action effect active before menu exit")
		old = weakref(flow.combat)
		flow.show_party()
		await drain()
		check(old.get_ref() == null and flow.combat == null and flow.retired.is_empty(),"Action effect/menu transition leaves no old encounter")
		flow.show_title()
		await process_frame
		check(flow.get_child_count() == 3 and flow.interface_layer.get_child_count() == 1 and get_nodes_in_group("game_audio").size()==1, "Repeated cycles retain one menu, one audio service, one campaign coordinator and no encounter controllers")
	flow.free()
	await process_frame
	print("TRANSITION STABILITY RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
