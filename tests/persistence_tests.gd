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
	for id: String in state.active.party: people[id]={"health":10,"maximum_health":20}
	return CampaignMissionResult.new({"version":1,"mission_id":state.active.id,"outcome":"victory","abandoned":false,"reason":"Persistence fixture","heroes":people,"rounds":4,"tactical_result":"VICTORY"})
func run() -> void:
	print("Persistence phase: start")
	var state := CampaignState.new(17,"standard")
	print("Persistence phase: state ready")
	var store := CampaignSaveStore.new(); store.path="user://persistence-tests/%d/active.json"%OS.get_process_id()
	print("Persistence phase: store ready")
	var text := CampaignSaveCodec.encode(state,"headquarters")
	print("Persistence phase: encoded")
	var restored := CampaignSaveCodec.decode(text)
	print("Persistence phase: decoded")
	check(restored.state!=null,"Fresh state round trips: "+restored.error)
	if restored.state==null: print("PERSISTENCE RESULT: %d failures"%failures); quit(1); return
	check(restored.state.snapshot()==state.snapshot(),"All campaign fields round trip exactly")
	check(restored.state.offers==state.offers and restored.state.campaign_id==state.campaign_id,"Offers and identity are frozen")
	restored.state.heroes.knight.experience=8
	check(state.heroes.knight.experience==0,"Loaded hero records are independent")
	restored.state.inventory[restored.state.heroes.knight.equipment.weapon].definition_id="broadwatch"
	check(state.inventory[state.heroes.knight.equipment.weapon].definition_id=="knight_issue","Inventory records are independent")
	check(store.write(state,"headquarters"),"First save succeeds: "+store.last_message)
	var initial_bytes := FileAccess.get_file_as_string(store.path)
	var item := state.purchase("broadwatch","one-purchase")
	check(not item.is_empty() and state.equip("knight",item),"Purchase fixture succeeds")
	check(store.write(state,"headquarters"),"Second save succeeds: "+store.last_message)
	check(FileAccess.get_file_as_string(store.path+".bak")==initial_bytes,"Previous valid slot retained as backup")
	print("Persistence phase: backup saved")
	var previous_bytes := FileAccess.get_file_as_string(store.path)
	for failure: String in ["write","backup","replace"]:
		store.fail_stage=failure
		check(not store.write(state,"headquarters"),"Injected filesystem failure is reported")
		check(FileAccess.get_file_as_string(store.path)==previous_bytes and store.read_file(store.path).state!=null,"Failure preserves usable current file")
	store.fail_stage=""
	for mutation: Callable in [func(data: Dictionary) -> void: data.state.inventory[data.state.heroes.knight.equipment.weapon].definition_id="missing_item",func(data: Dictionary) -> void: data.state.heroes.ranger.equipment.garb=data.state.heroes.knight.equipment.garb,func(data: Dictionary) -> void: data.state.heroes.knight.level=4,func(data: Dictionary) -> void: data.state.heroes.knight.injury={"name":"Slowed","remaining":-1},func(data: Dictionary) -> void: data.state.difficulty="missing",func(data: Dictionary) -> void: data.state.offers[0].seed=3,func(data: Dictionary) -> void: data.state.supplies=-1,func(data: Dictionary) -> void: data.content="outdated"]:
		check(CampaignSaveCodec.decode(changed(text,mutation)).state==null,"Invalid types/IDs/ownership/ranges/content rejected")
	check(CampaignSaveCodec.decode(text.substr(0,text.length()/2)).state==null,"Truncated JSON rejected")
	var future: Dictionary=JSON.parse_string(text); future.version=99
	check(CampaignSaveCodec.decode(JSON.stringify(future)).error.contains("Unsupported"),"Future version receives readable rejection")
	var broken := FileAccess.open(store.path,FileAccess.WRITE); broken.store_string("{"); broken.close()
	check(store.inspect().status=="backup" and not store.write(state,"headquarters"),"Damaged slot is never silently overwritten")
	var recovered := store.recover_backup()
	check(recovered.state!=null and store.read_file(store.path).state!=null,"Explicit backup recovery succeeds")
	check(not store.write(state,"in_progress"),"Phase inconsistent with state rejected")
	print("Persistence phase: active mission")
	var config := state.commit(state.offers[0].id,["knight","ranger"])
	var active := CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"in_progress"))
	var mismatched := changed(CampaignSaveCodec.encode(state,"in_progress"),func(data: Dictionary) -> void:
		var different := EncounterCode.decode(data.state.active.encounter.code).configuration
		different.generator_settings=EncounterOptions.presets()[(data.state.active.preset+1)%3].duplicate(true) as BattlefieldSettings
		data.state.active.encounter.preset=different.generator_settings.preset_id
		data.state.active.encounter.code=EncounterCode.encode(different))
	check(CampaignSaveCodec.decode(mismatched).state==null,"Committed encounter must agree with frozen offer configuration")
	check(config!=null and active.state!=null,"Committed mission round trips: "+active.error)
	if active.state!=null:
		var first := CampaignSaveCodec.resume(active.state)
		var second := CampaignSaveCodec.resume(active.state)
		check(first!=null and second!=null and first.battlefield_seed==config.battlefield_seed and first.resolved_enemy_ids==config.resolved_enemy_ids,"Interrupted encounter retains seed and enemies")
		check(first.hero_overrides[0].maximum_health==state.preview_definition("knight").maximum_health,"Modifiers apply once")
		first.hero_overrides[0].maximum_health+=10
		check(second.hero_overrides[0].maximum_health==state.preview_definition("knight").maximum_health,"Repeated load cannot compound stats")
		var record := result_for(active.state)
		check(active.state.resolve(record),"Whole result processes once")
		var complete := CampaignSaveCodec.decode(CampaignSaveCodec.encode(active.state,"debrief"))
		check(complete.state!=null,"Complete reward/debrief round trips: "+complete.error)
		if complete.state!=null:
			var supplies: int=complete.state.supplies
			check(not complete.state.resolve(record) and complete.state.supplies==supplies,"Loaded debrief cannot duplicate rewards")
			check(complete.state.processed==active.state.processed,"Processed identifiers persist")
	check(store.discard(),"Isolated slot cleanup succeeds")
	print("PERSISTENCE RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)




