extends SceneTree
var failures: int=0
var flow: SceneFlow
var records: Array[Dictionary]=[]
func check(value: bool,message: String) -> void:
	if not value:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func settle(count: int=12) -> void:
	for frame in count:await process_frame
func run() -> void:
	var cycles: int=12
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--cycles="):cycles=clampi(argument.get_slice("=",1).to_int(),1,100)
	flow=load("res://scenes/main.tscn").instantiate();root.add_child(flow)
	flow.campaign.store.path="user://session-lifecycle-%d/active.json"%OS.get_process_id()
	var warm_nodes: int=-1
	for cycle in cycles:
		var cycle_started:=Time.get_ticks_usec()
		var state: CampaignState = LegacyCampaignFixture.new(9000+cycle,"easy");flow.campaign.state=state
		check(flow.campaign.persist("headquarters"),"Creation saves")
		var started:=Time.get_ticks_usec()
		var loaded:=CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"headquarters"))
		check(loaded.state!=null,"Campaign roundtrip")
		var save_load_usec:=Time.get_ticks_usec()-started
		flow.campaign.state=loaded.state;state=loaded.state;flow.campaign.hq_open=false;flow.campaign.headquarters()
		flow.menu.open_camp_page(1);flow.menu.close_camp_page(false)
		flow.audio.panel.open();flow.audio.panel.close()
		await settle()
		var id: String=state.offers[0].id
		var navigation_started:=Time.get_ticks_usec()
		flow.start_configuration(state.commit(id,["knight","ranger"]))
		for frame in 2000:
			if flow.screen!="loading":break
			await process_frame
		check(flow.screen=="combat" and flow.combat.navigation_ready,"Generation completes")
		if flow.screen!="combat":break
		var navigation_usec:=Time.get_ticks_usec()-navigation_started
		flow.combat.guide.close();flow.combat.get_node("EnemyController").enabled=false
		var combat:=flow.combat.get_node("CombatController") as CombatController
		var old: WeakRef=weakref(flow.combat)
		# Outcome fixture exercises the real atomic result/debrief pipeline.
		combat._damage_in_progress=true
		for unit in combat.units:
			if unit.faction==(CombatUnit.Faction.ENEMY if cycle%2==0 else CombatUnit.Faction.HERO):unit.set_health(0)
		combat._damage_in_progress=false
		combat._check_outcome(true)
		check(combat.encounter_has_ended() and state.resolutions==1,"One completed result")
		var snapshot:=state.snapshot()
		flow.campaign.show_debrief();flow.campaign.show_debrief()
		check(state.snapshot()==snapshot,"Debrief reopening cannot duplicate consequences")
		flow.campaign.headquarters();await settle(16)
		check(old.get_ref()==null and flow.retired.is_empty(),"Old encounter/AI released")
		flow.campaign.state=null;flow.show_title();flow.show_party();flow.show_title();await settle(16)
		var count:=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if cycle==2:warm_nodes=count
		if cycle>2:check(count==warm_nodes,"Warm title node count remains flat")
		records.append({"cycle":cycle,"nodes":count,"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"save_load_usec":save_load_usec,"creation_checkpoint_usec":started-cycle_started,"navigation_usec":navigation_usec,"cycle_usec":Time.get_ticks_usec()-cycle_started})
		print("SESSION CYCLE ",JSON.stringify(records[-1]))
	check(records.size()==cycles,"No session cycles skipped")
	check(RegressionReport.write_json("session-lifecycle.json",{"failures":failures,"cycles":records,"outcomes_are_fixtures":true}),"Session report")
	flow.queue_free();await settle()
	print("SESSION LIFECYCLE RESULT: %d failures; %d cycles"%[failures,records.size()]);quit(0 if failures==0 else 1)
