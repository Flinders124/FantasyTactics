extends SceneTree
## --headless --path . --script res://dev/mission_inspector.gd -- --seed=17 --campaigns=20 --report-root=...
var failures: int=0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var seed_value:=17
	var count:=5
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value=argument.get_slice("=",1).to_int()
		if argument.begins_with("--campaigns="): count=clampi(argument.get_slice("=",1).to_int(),1,1000)
	var rows: Array[Dictionary]=[]
	var objectives: Dictionary={}; var layouts: Dictionary={}; var styles: Dictionary={}; var rosters: Dictionary={}; var templates: Dictionary={}
	var exact: Dictionary={}
	var started:=Time.get_ticks_usec()
	for index in range(count):
		var difficulty:=EncounterOptions.difficulties()[index%3].stable_id
		print("MISSION INSPECTOR campaign %d / %d"%[index+1,count])
		var state: CampaignState = LegacyCampaignFixture.new((seed_value+index)&0xffffffff,difficulty)
		# Inspect every real board in a successful short campaign, including recovery and finale.
		for stage in range(5):
			for offer in state.offers:
				var config:=state.prepare(offer.id,["knight","ranger"])
				if config==null or not config.validation_error().is_empty(): failures+=1; push_error("Invalid mission: "+str(offer.id)); continue
				if EncounterCode.encode(config)!=offer.code: failures+=1; push_error("Mission reproduction failed")
				var row: Dictionary={"campaign_seed":state.seed_value,"mission_seed":offer.seed,"template":offer.template.id,"template_version":offer.template.version,"generator":config.generator_settings.generator_version,"style":offer.template.style,"layout":config.generator_settings.preset_id,"objective":config.objective.stable_id,"faction":config.faction_id,"stage":config.campaign_stage,"difficulty":difficulty,"roster":Array(config.resolved_enemy_ids),"supplies":offer.supplies,"ignored_threat":offer.ignored,"code":offer.code}
				rows.append(row)
				for pair: Array in [[objectives,row.objective],[layouts,row.layout],[styles,row.style],[templates,row.template],[rosters,",".join(config.resolved_enemy_ids)]]:
					pair[0][pair[1]]=int(pair[0].get(pair[1],0))+1
				var signature:=str([row.template,row.layout,row.objective,row.faction,row.difficulty,row.roster])
				exact[signature]=int(exact.get(signature,0))+1
			state.commit(state.offers[0].id,["knight","ranger"])
			var people: Dictionary={}
			for id: String in state.active.party: people[id]={"health":20,"maximum_health":20}
			state.resolve(CampaignMissionResult.new({"version":1,"mission_id":state.active.id,"outcome":"victory","abandoned":false,"reason":"Inspector progression fixture","heroes":people,"rounds":2,"tactical_result":"VICTORY"}))
	var report: Dictionary={"version":1,"failures":failures,"campaigns":count,"missions":rows.size(),"unique_tactical_configurations":exact.size(),"objectives":objectives,"layouts":layouts,"styles":styles,"templates":templates,"rosters":rosters,"generation_ms":float(Time.get_ticks_usec()-started)/1000.0,"rows":rows,"note":"Structural inspection, not navigation validation or proof of balance. Missions use existing real campaign transitions; no combat is simulated here."}
	if not RegressionReport.write_json("mission-variety.json",report): failures+=1
	print("MISSION INSPECTOR RESULT: %d failures; %d missions; %d tactical configurations"%[failures,rows.size(),exact.size()]); quit(0 if failures==0 else 1)
