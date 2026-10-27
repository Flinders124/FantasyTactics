extends "res://tests/campaign_flow_tests.gd"
func completed_result(state: CampaignState) -> CampaignMissionResult:
	var people: Dictionary={}
	for id: String in state.active.party: people[id]={"health":20,"maximum_health":20}
	return CampaignMissionResult.new({"version":1,"mission_id":state.active.id,"outcome":"victory","abandoned":false,"reason":"Final outcome persistence fixture","heroes":people,"rounds":3,"tactical_result":"VICTORY"})
func run() -> void:
	flow=(load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow; root.add_child(flow)
	flow.campaign.store.path="user://save-flow/%d/active.json"%OS.get_process_id()
	flow.campaign.seed_text="17"; flow.campaign.begin(); await settle()
	check(flow.screen=="headquarters" and flow.campaign.store.read_file(flow.campaign.store.path).state!=null,"Creation autosaves a valid campaign")
	var state: CampaignState=flow.campaign.state
	flow.request_transition("campaign_buy:broadwatch"); await settle()
	var item_id: String=""
	for instance: String in state.inventory:
		if state.inventory[instance].definition_id=="broadwatch": item_id=instance
	check(not item_id.is_empty(),"Purchase commits through existing campaign commands")
	flow.campaign.mutate("equip",["knight",item_id])
	var expected := state.preview_definition("knight")
	var previous := state.snapshot()
	flow.campaign.store.fail_stage="write"
	check(flow.campaign.mutate("purchase",["votive_charm","failed"])==false,"Failed save rejects headquarters mutation")
	check(state.snapshot()==previous,"Failed purchase rolls back currency, inventory and operation guard")
	flow.campaign.store.fail_stage=""
	flow.campaign.prepare(state.offers[0].id)
	flow.campaign.store.fail_stage="replace"; flow.campaign.deploy()
	check(flow.screen=="campaign_preparation" and state.active.is_empty(),"Deployment requires durable committed checkpoint")
	flow.campaign.store.fail_stage=""; flow.campaign.deploy(); await wait_ready()
	check(not flow.campaign.dirty,"Completed generation checkpoint saves")
	var signature := flow.combat.configuration.layout.geometry_signature()
	var decoded: CampaignSaveCodec.Decoded=flow.campaign.store.read_file(flow.campaign.store.path)
	check(decoded.state!=null and decoded.phase=="in_progress","In-progress marker survives navigation setup")
	var old := flow.combat
	var actor := old.get_node("CombatController").scheduler.active_unit() as CombatUnit
	if actor.faction==CombatUnit.Faction.HERO:
		old.get_node("CombatController").submit_player_command(MoveCommand.new(actor.stable_id,actor.global_position+Vector3.RIGHT*.5))
		await physics_frame
	check(flow.campaign.load_campaign(decoded),"Interrupted mission load commits transactionally")
	await wait_ready(); await settle()
	check(not is_instance_valid(old) or old.cancelled,"Previous movement, AI and encounter cancelled on load")
	check(flow.combat.configuration.layout.geometry_signature()==signature,"Interrupted mission reproduces the exact generated layout")
	var knight := flow.combat.get_node("CombatController").find_unit("hero-01") as CombatUnit
	check(knight.definition.maximum_health==expected.maximum_health and knight.health==expected.maximum_health and knight.cooldown_ready_turn.is_empty() and knight.statuses.is_empty(),"Restored hero has fresh health/status/cooldowns and modifiers applied once")
	var combat := flow.combat.get_node("CombatController") as CombatController
	flow.combat.get_node("EnemyController").enabled=false
	for unit: CombatUnit in combat.units:
		if unit.faction==CombatUnit.Faction.ENEMY: unit.set_health(0)
	combat._check_outcome(true); await settle()
	check(combat.state==CombatController.State.VICTORY,"Development outcome fixture reaches tactical victory")
	var saved: CampaignSaveCodec.Decoded=flow.campaign.store.read_file(flow.campaign.store.path)
	check(saved.state!=null and saved.phase=="debrief" and saved.state.resolutions==1,"Whole mission consequence autosaves once")
	var supplies: int=flow.campaign.state.supplies
	combat.combat_event.emit("result",{"victory":true,"draw":false,"reason":"Duplicate notification fixture","event_id":"duplicate-save-test"})
	check(flow.campaign.state.supplies==supplies,"Repeated result callback cannot duplicate rewards")
	check(flow.campaign.load_campaign(saved),"Saved debrief can reload")
	check(flow.screen=="campaign_debrief" and flow.campaign.state.supplies==supplies,"Reloading debrief is read-only")
	flow.request_transition("campaign_hq"); await settle()
	flow.request_transition("campaign_main_menu"); await settle()
	check(flow.screen=="title" and flow.campaign.state==null,"Save & Main Menu clears encounter-owned state")
	flow.request_transition("campaign_continue"); await settle()
	check(flow.screen=="headquarters" and flow.campaign.state.supplies==supplies,"Title Continue restores stable headquarters")
	flow.request_transition("new_campaign"); await settle()
	check(flow.menu_guide.panel.visible and flow.screen=="headquarters","Replacing an existing save requires explicit confirmation")
	flow.menu_guide.close()
	for cycle in range(10):
		flow.request_transition("campaign_main_menu"); await settle()
		flow.request_transition("campaign_continue"); await settle()
		check(flow.screen=="headquarters" and get_nodes_in_group("headquarters_camps").size()==1,"Repeated load/menu transitions retain one camp")
	check(flow.campaign.store.discard(),"Test directory cleanup succeeds")
	var finale := CampaignState.new(39,"easy")
	for mission in range(4):
		finale.commit(finale.offers[0].id,["knight","ranger"]); finale.resolve(completed_result(finale))
	flow.campaign.state=finale; flow.campaign.store.path="user://save-flow/%d/finale.json"%OS.get_process_id()
	finale.commit(finale.offers[0].id,["knight","ranger"]); check(flow.campaign.persist("in_progress"),"Final mission checkpoint persists")
	finale.resolve(completed_result(finale)); flow.campaign.store.fail_stage="write"
	check(not flow.campaign.persist("complete"),"Final result save failure is surfaced")
	flow.campaign.show_debrief(); flow.request_transition("campaign_finish")
	check(flow.campaign.state==finale and flow.screen=="campaign_debrief","Finish cannot discard unsaved final campaign result")
	flow.campaign.state=finale; flow.campaign.store.fail_stage=""
	flow.request_transition("campaign_finish"); await settle()
	check(flow.screen=="title" and flow.campaign.store.read_file(flow.campaign.store.path).phase=="complete","Finish saves final summary before clearing runtime state")
	flow.request_transition("campaign_continue"); await settle()
	check(flow.screen=="campaign_debrief" and flow.campaign.state.ending=="victory","Completed campaigns resume at their unambiguous result")
	flow.campaign.store.discard()
	flow.campaign.state=null; flow.show_title(); flow.queue_free(); await settle()
	print("SAVE FLOW RESULT: %d failures"%failures); quit(0 if failures==0 else 1)



