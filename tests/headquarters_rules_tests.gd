extends "res://tests/campaign_tests.gd"
func settle_decision(state: CampaignState) -> void:
 if not state.pending_event.is_empty(): check(state.choose_event(state.pending_event.id,"decline"),"Neutral decision settles")
func win(state: CampaignState,party: PackedStringArray=[]) -> void:
 if party.is_empty(): party=PackedStringArray(state.living_ids().slice(0,2))
 check(state.commit(state.offers[0].id,party)!=null,"Test mission commits")
 check(state.resolve(record(state)),"Real campaign result resolves")
 settle_decision(state)
func run() -> void:
 var state := CampaignState.new(37)
 check(state.has_method("deployment_capacity"),"Commander upgrades expose deployment capacity")
 if not state.has_method("deployment_capacity"):
  print("HEADQUARTERS RULES RESULT: %d failures"%failures);quit(1);return
 check(state.deployment_capacity()==2,"Starts with two slots")
 var initial := state.snapshot()
 check(not state.buy_command_upgrade(1) and state.snapshot()==initial,"Cannot buy before victory")
 win(state)
 var before := state.supplies
 check(state.buy_command_upgrade(1) and state.deployment_capacity()==3 and state.supplies==before-20,"First upgrade costs20 after first victory")
 check(not state.buy_command_upgrade(1) and not state.buy_command_upgrade(2),"Duplicate and early tier2 rejected")
 var party := PackedStringArray(state.living_ids().slice(0,3))
 check(state.prepare(state.offers[0].id,party)!=null,"Three-person deployment valid")
 check(state.prepare(state.offers[0].id,PackedStringArray(state.living_ids()))==null,"Cannot exceed capacity")
 win(state,party)
 before=state.supplies
 check(state.buy_command_upgrade(2) and state.deployment_capacity()==4 and state.supplies==before-30,"Second upgrade costs30 after second victory")
 for count in [2,3,4]:
  party=PackedStringArray(state.living_ids().slice(0,count))
  var config := state.prepare(state.offers[0].id,party)
  check(config!=null and config.validation_error().is_empty(),"Capacity supports smaller parties and four heroes")
  if config!=null:
   var decoded := EncounterCode.decode(EncounterCode.encode(config))
   check(decoded.configuration!=null and decoded.configuration.hero_ids==config.hero_ids,"Code roundtrip2/3/4: "+decoded.error)
 check(state.prepare(state.offers[0].id,[party[0],party[0],party[1]])==null,"Duplicate people rejected")
 check(state.commit(state.offers[0].id,party)!=null,"Four-person mission commits")
 var restored := CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"in_progress"))
 check(restored.state!=null,"Four-person active save validates: "+restored.error)
 if restored.state!=null:
  var resumed := CampaignSaveCodec.resume(restored.state)
  check(resumed!=null and resumed.campaign_hero_ids==party and resumed.hero_overrides.size()==4,"Interrupted recovery keeps all four people")
 check(state.resolve(record(state)),"Four-person result resolves")
 check(CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"debrief")).state!=null,"Four-person debrief persists")
 for name: String in ["headquarters_v3.json","headquarters_active_v3.json"]:
  var old_text := FileAccess.get_file_as_string("res://tests/fixtures/"+name)
  var old: Dictionary=CampaignSaveCodec.normalize(JSON.parse_string(JSON.parse_string(old_text).payload))
  var migrated := CampaignSaveCodec.decode(old_text)
  check(migrated.state!=null,"Real v3 fixture migrates: "+migrated.error)
  if migrated.state!=null:
   check(migrated.state.deployment_capacity()==2 and migrated.state.offers==old.state.offers and migrated.state.active==old.state.active,"Migration preserves old missions and no free upgrades")
 print("HEADQUARTERS RULES RESULT: %d failures"%failures);quit(1 if failures else 0)
