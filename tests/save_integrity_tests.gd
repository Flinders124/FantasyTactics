extends SceneTree
var failures: int=0
func check(value: bool,message: String) -> void:
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func changed(text: String,mutator: Callable) -> String:
	var envelope: Dictionary=JSON.parse_string(text)
	var payload: Dictionary=CampaignSaveCodec.normalize(JSON.parse_string(envelope.payload))
	mutator.call(payload)
	envelope.payload=JSON.stringify(payload); envelope.sha256=envelope.payload.sha256_text()
	return JSON.stringify(envelope)
func result_for(state: CampaignState) -> CampaignMissionResult:
	var people: Dictionary={}
	for id: String in state.active.party: people[id]={"health":0 if id=="knight" else 8,"maximum_health":20}
	return CampaignMissionResult.new({"version":1,"mission_id":state.active.id,"outcome":"victory","abandoned":false,"reason":"Integrity fixture","heroes":people,"rounds":4,"tactical_result":"VICTORY"})
func run() -> void:
	var state := CampaignState.new(17,"standard")
	state.commit(state.offers[0].id,["knight","ranger"]); state.resolve(result_for(state))
	var text := CampaignSaveCodec.encode(state,"debrief")
	check(CampaignSaveCodec.decode(text).state!=null,"Baseline valid: "+CampaignSaveCodec.decode(text).error)
	check(CampaignSaveCodec.decode(changed(text,func(data: Dictionary) -> void:
		data.state.processed["00000011-999-0"]=true
		data.state.processed.erase("00000011-000-0")
		data.state.last_debrief={}
		data.phase="headquarters")).state==null,"Future processed resolution must be rejected")
	var two := CampaignState.new(17,"standard")
	for index in range(2):
		two.commit(two.offers[0].id,["knight","ranger"]); two.resolve(result_for(two))
	check(CampaignSaveCodec.decode(changed(CampaignSaveCodec.encode(two,"headquarters"),func(data: Dictionary) -> void:
		data.state.processed.erase("00000011-001-0")
		data.state.processed["00000011-000-1"]=true
		data.state.last_debrief={})).state==null,"Only one processed mission per resolution is valid")
	var fresh := CampaignState.new(17,"standard")
	check(CampaignSaveCodec.decode(changed(CampaignSaveCodec.encode(fresh,"headquarters"),func(data: Dictionary) -> void:
		var offer: Dictionary=data.state.offers[0]
		offer.final=true; offer.ignored=0
		var config := EncounterCode.decode(offer.code).configuration
		config.difficulty.enemy_health_multiplier=minf(1.5,config.difficulty.enemy_health_multiplier*fresh.rules.final_enemy_multiplier)
		config.difficulty.enemy_damage_multiplier=minf(1.5,config.difficulty.enemy_damage_multiplier*fresh.rules.final_enemy_multiplier)
		offer.code=EncounterCode.encode(config))).state==null,"Premature final offer must not create an unsaveable campaign")
	# A real mid-campaign checkpoint contains injuries, XP, purchases and operation guards.
	var item := state.purchase("broadwatch","integrity-purchase")
	check(not item.is_empty() and state.equip("knight",item),"Gear fixture succeeds")
	check(state.heroes.knight.experience>0 and not state.heroes.knight.injury.is_empty(),"XP and injury fixture succeeds")
	var expected := state.snapshot()
	for iteration in range(5):
		var loaded := CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"headquarters"))
		check(loaded.state!=null,"Mid-campaign checkpoint reloads")
		if loaded.state==null: break
		state=loaded.state
		check(CampaignSaveCodec.normalize(state.snapshot())==CampaignSaveCodec.normalize(expected),"Repeated load preserves XP, injuries, gear, Supplies, Threat, offers and processed IDs")
		check(state.purchase("broadwatch","integrity-purchase").is_empty(),"Operation guard survives reload")
	var baseline := CampaignSaveCodec.encode(state,"headquarters")
	for field: String in CampaignSaveCodec.FIELDS:
		for bad: Variant in [null, [], true, "unexpected"]:
			# Some empty arrays and strings are legitimate, so wrong types are selected per field.
			var original: Variant=expected[field]
			if typeof(original)==typeof(bad): continue
			check(CampaignSaveCodec.decode(changed(baseline,func(data: Dictionary) -> void: data.state[field]=bad)).state==null,"Wrong type rejected for "+field)
	check(CampaignSaveCodec.decode("{").state==null,"Malformed JSON rejected")
	check(CampaignSaveCodec.decode(" ".repeat(CampaignSaveCodec.MAX_BYTES+1)).state==null,"Oversize input rejected")
	var legacy := CampaignState.new(29,"standard")
	for offer: Dictionary in legacy.offers:
		for field: String in ["faction","stage","elite"]: offer.erase(field)
		offer.erase("code")
		offer.code=EncounterCode.encode(legacy.configuration_for(offer,["knight","ranger"]))
	var frozen := legacy.offers.duplicate(true)
	var old_save := CampaignSaveCodec.decode(CampaignSaveCodec.encode(legacy,"headquarters"))
	check(old_save.state!=null and old_save.state.offers==frozen,"Legacy v1 offers remain frozen")
	var store := CampaignSaveStore.new(); store.path="user://save-integrity/%d/active.json"%OS.get_process_id()
	check(store.write(legacy,"headquarters"),"Legacy checkpoint writes")
	check(store.read_file(store.path).state!=null,"Legacy file decodes")
	check(store.write(state,"headquarters"),"Mid-campaign checkpoint writes")
	var current := FileAccess.get_file_as_string(store.path)
	for failure: String in ["write","backup","replace"]:
		store.fail_stage=failure
		check(not store.write(state,"headquarters"),"Filesystem failure is reported: "+failure)
		check(FileAccess.get_file_as_string(store.path)==current,"Failed write retains exact current bytes")
		check(store.read_file(store.path).state!=null,"Failed write retains decodable checkpoint")
	store.fail_stage=""
	# Model the crash window after current is displaced and before temporary is promoted.
	check(DirAccess.rename_absolute(ProjectSettings.globalize_path(store.path),ProjectSettings.globalize_path(store.path+".previous"))==OK,"Crash fixture displaces slot")
	check(store.inspect().status=="backup","Interrupted replacement exposes recoverable backup")
	check(store.recover_backup().state!=null,"Interrupted replacement can recover")
	check(store.read_file(store.path).state!=null,"Recovered checkpoint is valid")
	var damaged := FileAccess.open(store.path,FileAccess.WRITE); damaged.store_string("{"); damaged.close()
	var backup_bytes := FileAccess.get_file_as_string(store.path+".bak")
	store.fail_stage="replace"
	check(store.recover_backup().state==null,"Failed recovery reports failure")
	check(FileAccess.get_file_as_string(store.path)=="{" and FileAccess.get_file_as_string(store.path+".bak")==backup_bytes,"Failed recovery preserves damaged file and backup")
	store.fail_stage=""
	check(store.recover_backup().state!=null,"Recovery can retry after filesystem failure")
	check(store.discard(),"Isolated checkpoint files cleaned")
	print("SAVE INTEGRITY RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)




