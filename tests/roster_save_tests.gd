extends SceneTree
var failures: int=0
func check(value: bool,message: String) -> void:
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state := CampaignState.new(93)
	var text := CampaignSaveCodec.encode(state,"headquarters")
	var decoded := CampaignSaveCodec.decode(text)
	check(decoded.state!=null,"version two roundtrip: "+decoded.error)
	if decoded.state!=null: check(decoded.state.snapshot()==state.snapshot(),"all individual records preserved")
	var future: Dictionary=JSON.parse_string(text); future.version=999
	check(CampaignSaveCodec.decode(JSON.stringify(future)).state==null,"future schema refused")
	var legacy := FileAccess.get_file_as_string("res://tests/legacy_campaign_v1.json")
	if not legacy.is_empty():
		var migrated := CampaignSaveCodec.decode(legacy)
		check(migrated.state!=null,"actual legacy v1 migrates: "+migrated.error)
		if migrated.state!=null: check(migrated.state.heroes.knight.legacy_specialist,"legacy specialists grandfathered")
	for field in ["level","experience","missions_completed","trained","specialisation","equipment"]:
		var envelope: Dictionary=JSON.parse_string(text)
		var payload: Dictionary=JSON.parse_string(envelope.payload)
		payload.state.heroes[state.living_ids()[0]][field]="invalid"
		envelope.payload=JSON.stringify(payload)
		envelope.sha256=envelope.payload.sha256_text()
		check(CampaignSaveCodec.decode(JSON.stringify(envelope)).state==null,"Malformed individual field rejected: "+field)
	print("Roster save RESULT: %d failures" % failures); quit(1 if failures else 0)
