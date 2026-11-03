extends SceneTree
var failures: int=0
func check(value: bool,message: String) -> void:
	if not value:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var profile:=EnemyTacticalProfile.new()
	var original:=EncounterCode.fingerprint(profile)
	var content:=EncounterCode.content(profile)
	for key in ["warning_damage_weight","protection_weight","focus_fire_weight","target_threat_weight","support_access_weight","objective_commitment_weight","oscillation_penalty"]:
		check(not content.has(key),"Default AI addition preserves old fingerprint: "+key)
	profile.warning_damage_weight=15
	check(EncounterCode.content(profile).get("warning_damage_weight")==15 and EncounterCode.fingerprint(profile)!=original,"Explicit AI tuning still participates in fingerprints")
	var legacy:=CampaignSaveCodec.decode(FileAccess.get_file_as_string("res://tests/legacy_campaign_v1.json"))
	check(legacy.state!=null,"Existing shipped campaign loads with default tactical additions")
	if legacy.state!=null:
		var offers:=legacy.state.offers.duplicate(true)
		var again:=CampaignSaveCodec.decode(CampaignSaveCodec.encode(legacy.state,"headquarters"))
		check(again.state!=null and again.state.offers==offers,"Legacy offers remain frozen after re-save")
	for definition in HeroCatalog.definitions():
		var before:=EncounterCode.fingerprint(definition)
		EnemyTactics.profile_for_definition(definition)
		check(EncounterCode.fingerprint(definition)==before,"Role inference never mutates shared hero definition")
	print("AI COMPATIBILITY RESULT: %d failures"%failures);quit(0 if failures==0 else 1)