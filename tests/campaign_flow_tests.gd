extends "res://tests/objective_encounter_tests.gd"
var flow: SceneFlow
func wait_ready() -> void:
	for frame in range(2000):
		if flow.screen!="loading":
			check(flow.screen=="combat" and flow.combat.navigation_ready,"Campaign navigation/setup completes")
			if flow.combat.guide!=null: flow.combat.guide.close()
			return
		await process_frame
	check(false,"Campaign setup timeout")
func settle() -> void:
	for frame in range(12): await process_frame
func run() -> void:
	root.size=Vector2i(1280,720)
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow; root.add_child(flow)
	var skirmish_draft := flow.party.selected.duplicate()
	var names: PackedStringArray=["knight","ranger","mage","cleric"]
	# Each pair enters real generated combat with the correct fresh definitions.
	for first in range(4):
		for second in range(first+1,4):
			var state := CampaignState.new(7,"standard")
			flow.campaign.state=state
			var ids := PackedStringArray([names[first],names[second]])
			var config := state.commit(state.offers[0].id,ids)
			flow.start_configuration(config); await wait_ready()
			var combat := flow.combat.get_node("CombatController") as CombatController
			for index in range(2):
				var unit := combat.find_unit("hero-%02d"%(index+1))
				check(unit.campaign_id==ids[index] and unit.definition.maximum_health==state.preview_definition(ids[index]).maximum_health and unit.cooldown_ready_turn.is_empty() and unit.statuses.is_empty(),"Campaign identity/preview/fresh runtime match for every pair")
			check(not flow.combat.get_node("HUD").restart_button.visible,"Campaign retry is unavailable")
			if first==0 and second==1:
				var actor := combat.scheduler.active_unit()
				check(combat.submit_player_command(MoveCommand.new(actor.stable_id,actor.global_position+Vector3.RIGHT*.75)),"Campaign movement uses the existing command pipeline")
				await physics_frame
			flow.audio.panel.open(); var serial := combat.turn_serial
			var held_position := combat.find_unit("hero-01").global_position
			for frame in range(10): await process_frame
			check(paused and serial==combat.turn_serial and combat.find_unit("hero-01").global_position==held_position,"Campaign settings pauses progression and in-flight movement")
			flow.audio.panel.close()
			flow.request_transition("retry"); check(flow.combat.configuration.deployment_id==config.deployment_id,"Hidden retry request cannot reroll campaign")
			flow.request_transition("main_menu")
			check(flow.combat.guide.panel.visible and paused,"Mission abandonment requires confirmation")
			flow.combat.guide.confirm_button.pressed.emit()
			check(flow.screen=="campaign_debrief" and state.resolutions==1 and state.victories==0,"Confirmed abandonment resolves one failure into debrief")
			flow.campaign.headquarters(); await settle()
			check(flow.retired.is_empty(),"Old campaign encounter/AI retires before next deployment")
	check(flow.party.selected==skirmish_draft,"Campaign deployments preserve the independent skirmish draft")
	# Abandon while navigation is still being prepared: confirmation must exist.
	var early := CampaignState.new(9,"standard"); flow.campaign.state=early
	flow.start_configuration(early.commit(early.offers[0].id,["mage","cleric"]))
	flow.request_transition("main_menu")
	check(flow.menu_guide!=null and paused,"Loading abandonment has a responsive confirmation and pause owner")
	for frame in range(220): await process_frame
	check(is_instance_valid(flow.menu_guide) and flow.menu_guide.panel.visible,"Confirmation survives navigation completing behind it")
	flow.menu_guide.confirm_button.pressed.emit(); await settle()
	check(early.resolutions==1 and early.active.is_empty() and flow.screen=="campaign_debrief" and not paused,"Loading cancellation resolves once and cleans the pause")
	# Extraction failure keeps tactical rules even though the persistent hero survives.
	var extraction := CampaignState.new(7,"easy"); flow.campaign.state=extraction
	var extraction_offer: Dictionary={}
	for value in extraction.offers:
		if value.objective==2: extraction_offer=value
	flow.start_configuration(extraction.commit(extraction_offer.id,["knight","ranger"])); await wait_ready()
	var combat := flow.combat.get_node("CombatController") as CombatController
	flow.combat.get_node("EnemyController").enabled=false
	combat.find_unit("hero-01").set_health(0); combat._check_outcome(true)
	check(combat.state==CombatController.State.DEFEAT and extraction.heroes.knight.injury.remaining==3,"Extraction remains defeat on one hero incapacitated; campaign hero survives injured")
	var once := extraction.resolutions
	combat.combat_event.emit("result",{"victory":false,"draw":false,"reason":"Duplicate development notification","event_id":"duplicate-test"})
	check(extraction.resolutions==once,"Duplicate encounter result cannot apply strategic consequences twice")
	flow.campaign.show_debrief(); await settle()
	# Simultaneous tactical elimination is still DRAW; the campaign treats it as failure.
	var draw_case := CampaignState.new(12,"standard"); flow.campaign.state=draw_case
	flow.start_configuration(draw_case.commit(draw_case.offers[0].id,["mage","ranger"])); await wait_ready()
	combat=flow.combat.get_node("CombatController")
	flow.combat.get_node("EnemyController").enabled=false
	while combat.scheduler.active_unit().stable_id!="hero-01": combat.submit_command(EndTurnCommand.new(combat.scheduler.active_unit().stable_id))
	var point := combat.find_unit("hero-01").global_position+Vector3.RIGHT
	var offsets: Array[Vector3]=[Vector3.LEFT*.6,Vector3.RIGHT*.6,Vector3.FORWARD*.6,Vector3.BACK*.6,Vector3(-.4,0,-.4),Vector3(.4,0,.4)]
	# Include every configured opponent when faction missions contain more than two.
	for index in range(combat.units.size()):
		combat.units[index].global_position=point+offsets[index]; combat.units[index].set_health(3)
	await physics_frame; await physics_frame
	check(combat.submit_player_command(UseAbilityCommand.on_ground("hero-01","fireburst",point)),"Draw harness commits a real all-faction atomic blast")
	check(combat.state==CombatController.State.DRAW and draw_case.victories==0 and draw_case.heroes.mage.injury.remaining==3 and draw_case.heroes.ranger.injury.remaining==3,"Atomic tactical draw yields one failed mission and surviving injured campaign heroes")
	flow.campaign.show_debrief(); await settle()
	flow.campaign.state=null; flow.show_title(); flow.queue_free(); await settle()
	print("CAMPAIGN FLOW RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
