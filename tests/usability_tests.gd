extends "res://tests/flow_tests.gd"
func wait_action(combat: CombatController) -> void:
	for frame in range(600):
		if combat.state!=CombatController.State.RESOLVING_ACTION: return
		await process_frame
	check(false,"Usability action watchdog")
func run() -> void:
	ControlBindings.ensure()
	var original := InputMap.action_get_events("tactics_move")
	InputMap.action_erase_events("tactics_move")
	var alternate := InputEventKey.new()
	alternate.physical_keycode=KEY_G
	InputMap.action_add_event("tactics_move",alternate)
	check(ControlBindings.label("move")=="G" and ControlBindings.describe().contains("Move: G"),"Displayed bindings come from actual InputMap")
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	flow.audio.preferences.Controls.move=["K:%d"%KEY_G]
	flow.audio.apply_preferences(false)
	flow.start_configuration(EncounterConfiguration.new())
	flow.combat.get_node("EnemyController").enabled=false
	await wait_ready()
	var scene := flow.combat
	var combat := scene.get_node("CombatController") as CombatController
	var hud: CanvasLayer=scene.get_node("HUD")
	var player := scene.get_node("PlayerController") as PlayerController
	check(hud.move_button.text.contains("[G]"),"Combat button matches configured move binding")
	player.cancel_targeting()
	alternate.pressed=true
	player._unhandled_input(alternate)
	check(player.mode==PlayerController.Mode.MOVE,"Configured binding invokes actual Move mode")
	for event in original: InputMap.action_add_event("tactics_move",event)
	InputMap.action_erase_event("tactics_move",alternate)
	flow.audio.preferences.Controls.move=SettingsSchema.defaults().Controls.move
	flow.audio.apply_preferences(false)
	var actor := combat.scheduler.active_unit()
	var target := combat.find_unit("enemy-01")
	target.global_position=actor.global_position+Vector3(1.5,0,0)
	await physics_frame
	await physics_frame
	check(combat.submit_player_command(AttackCommand.new(actor.stable_id,target.stable_id)),"Action begins normally")
	var health := target.health
	var remaining := combat._attack_remaining
	scene.show_briefing()
	check(paused and combat.guidance_paused and player.mode==PlayerController.Mode.NONE,"Briefing pauses an action and clears targeting")
	for frame in range(30): await process_frame
	check(combat._attack_remaining==remaining and target.health==health,"Paused action cannot advance invisibly or apply duplicate damage")
	check(not combat.submit_command(EndTurnCommand.new(actor.stable_id)),"Even direct commands reject during blocking guidance")
	var presentation := scene.get_node("CombatPresentation") as CombatPresentation
	var previous_anchor: Vector2=presentation.bars[actor.stable_id].anchor
	Input.action_press("tactics_pan_right")
	scene.get_node("TacticalCamera")._process(.2)
	Input.action_release("tactics_pan_right")
	check(not Vector2(presentation.bars[actor.stable_id].anchor).is_equal_approx(previous_anchor),"Camera pan reprojects world health bars even while combat is paused")
	check(combat._attack_remaining==remaining,"Projection refresh never advances gameplay time")
	scene.guide.close()
	await wait_action(combat)
	check(combat.state==CombatController.State.AWAITING_COMMAND and target.health==health,"Resume completes action once")
	hud._show_feedback("No action remaining")
	check(hud.feedback_label.text.contains("still move"),"No action feedback explains separate movement")
	for objective in EncounterOptions.objectives():
		var briefing := FieldGuide.objective(objective)
		check(not briefing.is_empty(),"Every objective has a readable briefing")
		if objective.kind==ObjectiveDefinition.Kind.HOLD_GROUND: check(briefing.contains("END OF EACH ROUND") and briefing.contains("reset"),"Hold briefing states round timing and reset")
		if objective.kind==ObjectiveDefinition.Kind.EXTRACTION: check(briefing.contains("both") and briefing.contains("either hero dies"),"Extraction briefing explains survival")
	# Queue enemy work, then pause before its timer can fire.
	var enemy := scene.get_node("EnemyController") as EnemyController
	enemy.enabled=true
	check(combat.submit_player_command(EndTurnCommand.new(actor.stable_id)),"Enemy turn starts")
	var serial := combat.turn_serial
	var enemy_hp := combat.find_unit("hero-01").health
	scene.show_help()
	for frame in range(45): await process_frame
	check(combat.turn_serial==serial and combat.find_unit("hero-01").health==enemy_hp,"Enemy planning and timers cannot advance behind blocking help")
	flow.show_title()
	await drain()
	check(not paused and flow.combat==null,"Leaving paused enemy work clears lifecycle state")
	flow.start_configuration(EncounterConfiguration.new())
	await wait_ready()
	check(not flow.combat.get_node("CombatController").guidance_paused,"New encounter has no inherited pause")
	flow.show_title()
	flow.request_transition("controls")
	var guide := flow.menu_guide
	flow.request_transition("controls")
	check(flow.menu_guide==guide,"Menu help reuses one overlay")
	guide.close()
	flow.queue_free()
	await process_frame
	print("USABILITY RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
