extends "res://tests/headquarters_rules_tests.gd"
func run() -> void:
 var state := CampaignState.new(37)
 check(state.offers[0].name.begins_with("First Watch"),"New campaign has an authored opening identity")
 for stage in range(3):
  for entry: Dictionary in state.offers:
   var configuration := EncounterCode.decode(entry.code).configuration
   check(configuration!=null and configuration.validation_error().is_empty(),"Opening code is playable")
   check(configuration.resolved_enemy_ids.size()<=3,"Opening fights stay bounded regardless of capacity")
   check("Commander" in str(entry.template.briefing) or "specialisation" in str(entry.template.briefing),"Opening briefing explains progression opportunity")
  if stage<2: win(state)
 var old := CampaignSaveCodec.decode(FileAccess.get_file_as_string("res://tests/fixtures/headquarters_v3.json"))
 check(old.state!=null and old.state.opening_version==0,"Old campaign keeps old opening semantics")
 if old.state!=null:
  var board := old.state.offers.duplicate(true);old.state.generate_offers()
  check(old.state.offers==board,"Migration does not rewrite an old frozen board")
 print("HEADQUARTERS OPENING RESULT: %d failures"%failures);quit(1 if failures else 0)
