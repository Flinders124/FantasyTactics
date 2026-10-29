extends SceneTree
var failures: int=0
func check(value: bool,message: String) -> void:
 if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var opening := PackedStringArray(["ashfang_raider","ashfang_bowhunter"])
 for difficulty in ["easy","standard","hard"]:
  for seed_number in [7,17,423]:
   var state := CampaignState.new(seed_number,difficulty)
   var party := PackedStringArray(state.living_ids().slice(0,2))
   for offer in state.offers:
    var config := state.prepare(offer.id,party)
    check(config!=null and config.resolved_enemy_ids==opening,"All introductory objectives use the tested pair: %s/%d"%[difficulty,seed_number])
    check(config!=null and config.validation_error().is_empty(),"Intro configuration remains valid")
   state.resolutions=1
   state.generate_offers()
   check(state.prepare(state.offers[0].id,party).resolved_enemy_ids==opening,"Loss does not remove introductory opposition")
   state.victories=1
   state.generate_offers()
   for offer in state.offers:
    var config := state.prepare(offer.id,party)
    var template := MissionCatalog.find(offer.template.id)
    check(config.resolved_enemy_ids==MissionCatalog.compose(template,config.faction_id,difficulty,1,config.battlefield_seed).slice(0,2),"Template composition resumes within the second-mission cap")
 var old := CampaignState.new(17,"standard")
 var frozen: Dictionary=old.offers[0]
 var config := EncounterCode.decode(frozen.code).configuration
 config.resolved_enemy_ids=PackedStringArray(["ashfang_raider","ashfang_raider","ashfang_bowhunter","ashfang_raider"])
 config.enemies.clear()
 for id in config.resolved_enemy_ids: config.enemies.append(EnemyCatalog.find(id).duplicate(true) as UnitDefinition)
 frozen.code=EncounterCode.encode(config)
 var decoded := CampaignSaveCodec.decode(CampaignSaveCodec.encode(old,"headquarters"))
 check(decoded.state!=null,"Previously frozen larger offer still loads: "+decoded.error)
 if decoded.state!=null:
  check(decoded.state.offers[0].code==frozen.code,"Load never rewrites frozen offers")
  var party := PackedStringArray(decoded.state.living_ids().slice(0,2))
  check(decoded.state.prepare(frozen.id,party).resolved_enemy_ids.size()==4,"Existing offer remains unchanged when committed")
 print("RECRUIT OPENING RESULT: %d failures"%failures)
 quit(1 if failures else 0)
