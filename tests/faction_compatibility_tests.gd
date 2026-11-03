extends SceneTree
var failures: int=0
func check(value: bool,message: String) -> void:
	if not value: failures+=1; push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var legacy:=CampaignSaveCodec.decode(FileAccess.get_file_as_string("res://tests/legacy_campaign_v1.json"))
	check(legacy.state!=null,"Shipped v1 campaign loads: "+legacy.error)
	if legacy.state!=null:
		var before:=legacy.state.offers.duplicate(true)
		check(legacy.state.prepare(before[0].id,["knight","ranger"]).faction_id=="legacy","Frozen legacy offers keep original enemies")
		check(legacy.state.offers==before,"Load cannot reroll legacy offers")
	var state: CampaignState = LegacyCampaignFixture.new(17,"standard")
	for stage in range(5):
		state.victories=stage; state.resolutions=stage; state.generate_offers()
		for offer in state.offers:
			var config:=state.prepare(offer.id,["mage","cleric"])
			check(config!=null and config.validation_error().is_empty(),"Faction mission valid")
			if config==null: continue
			check(config.faction_id==offer.faction and config.elite_encounter==offer.elite,"Frozen mission metadata")
			var decoded:=EncounterCode.decode(EncounterCode.encode(config))
			check(decoded.configuration!=null,"New faction code roundtrip: "+decoded.error)
			if decoded.configuration!=null: check(decoded.configuration.resolved_enemy_ids==config.resolved_enemy_ids,"Frozen roster deterministic")
		if stage==4: check(state.offers.size()==1 and state.offers[0].elite,"Finale has one elite mission")
	state=LegacyCampaignFixture.new(17,"standard")
	var decoded:=CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"headquarters"))
	check(decoded.state!=null,"New campaign roundtrip: "+decoded.error)
	var config:=state.commit(state.offers[0].id,["knight","ranger"])
	decoded=CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"in_progress"))
	check(decoded.state!=null,"Faction interrupted mission save")
	if decoded.state!=null:
		var restored:=CampaignSaveCodec.resume(decoded.state)
		check(restored!=null and restored.resolved_enemy_ids==config.resolved_enemy_ids and restored.faction_id==config.faction_id,"Interrupted mission restores faction/roster")
	print("FACTION COMPATIBILITY RESULT: %d failures"%failures); quit(0 if failures==0 else 1)
