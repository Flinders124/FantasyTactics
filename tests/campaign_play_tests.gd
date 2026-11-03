extends "res://tests/campaign_flow_tests.gd"
func run() -> void:
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow; root.add_child(flow)
	var state: CampaignState = LegacyCampaignFixture.new(17,"easy"); flow.campaign.state=state
	var report: Array[Dictionary]=[]
	for attempt in range(8):
		if not state.ending.is_empty(): break
		# Choose a known offered Elimination objective, without replacing its seed/layout.
		var chosen: Dictionary=state.offers[0]
		for offer in state.offers:
			if offer.objective==0: chosen=offer; break
		for id: String in ["knight","ranger"]:
			var pending := state.pending_level(id)
			if pending>0:
				for option in state.rules.upgrades:
					if option.hero_id==id and option.required_level==pending: state.learn(id,option.stable_id); break
		if attempt==0:
			var instance := state.purchase("broadwatch")
			state.equip("knight",instance)
		flow.campaign.selected=["knight","ranger"]
		flow.start_configuration(state.commit(chosen.id,["knight","ranger"])); await wait_ready()
		var combat := flow.combat.get_node("CombatController") as CombatController
		flow.combat.get_node("EnemyController").presentation_delay=0
		var serial := -1
		for frame in range(28000):
			if combat.encounter_has_ended(): break
			if combat.state==CombatController.State.AWAITING_COMMAND and combat.scheduler.active_unit().faction==CombatUnit.Faction.HERO and serial!=combat.turn_serial:
				serial=combat.turn_serial
				await hero_turn(combat,combat.scheduler.active_unit())
			await process_frame
		check(combat.encounter_has_ended(),"Campaign battle finishes within bounded watchdog")
		report.append({"mission":chosen.id,"seed":chosen.seed,"result":CombatController.State.keys()[combat.state],"round":combat.scheduler.round_number,"victories":state.victories,"threat":state.threat})
		print("CAMPAIGN PLAY ",report[-1])
		flow.campaign.show_debrief(); await settle()
		if state.ending.is_empty(): flow.campaign.headquarters(); await settle()
	check(not state.ending.is_empty(),"A complete command-driven campaign reaches an ending")
	print("CAMPAIGN ENDING ",state.ending)
	check(RegressionReport.write_json("campaign/play.json",{"ending":state.ending,"missions":report,"campaign":state.snapshot()}),"Regression report written")
	flow.campaign.state=null; flow.show_title(); flow.queue_free(); await settle()
	print("CAMPAIGN PLAY RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
