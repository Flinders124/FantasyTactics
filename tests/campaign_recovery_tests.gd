extends SceneTree
var failures: int=0
func check(value: bool,message: String) -> void:
 if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func outcome(state: CampaignState,kind: String,dead_id: String="") -> CampaignMissionResult:
 var people: Dictionary={}
 for id: String in state.active.party:
  var dead := id==dead_id
  people[id]={"health":0 if dead else (5 if kind=="failure" else state.preview_definition(id).maximum_health),"maximum_health":state.preview_definition(id).maximum_health,"survival":"dead" if dead else "extracted","death_cause":"Development casualty" if dead else ""}
 return CampaignMissionResult.new({"version":2,"mission_id":state.active.id,"outcome":kind,"abandoned":false,"reason":"Recovery timing fixture","heroes":people,"rounds":4,"tactical_result":"VICTORY" if kind=="victory" else "DEFEAT"})
func run() -> void:
 var state := CampaignState.new(17,"standard")
 var party := PackedStringArray(state.living_ids().slice(0,2))
 var before := state.supplies
 state.commit(state.offers[0].id,party)
 var failed := outcome(state,"failure",party[0])
 check(state.resolve(failed),"Casualty failure resolves")
 check(state.threat==5,"One loss adds2 mission threat and at most1 ignored threat")
 check(state.supplies==before+12,"Failed mission funds one replacement")
 check(state.heroes[party[0]].dead and state.heroes[party[0]].experience==0,"Permanent loss keeps no XP")
 check(state.heroes[party[1]].injury.remaining==2,"New injury does not recover immediately")
 check(not state.resolve(failed) and state.supplies==before+12,"Failure recovery funds cannot duplicate")
 var reserves := PackedStringArray(["hero-0003","hero-0004"])
 check(state.train_recruit(reserves[0]) and state.train_recruit(reserves[1]),"Two reserves can train after an early casualty")
 check(state.specialise(reserves[0],"knight") and state.specialise(reserves[1],"ranger"),"Trained reserves are ready for replacement deployment")
 state.commit(state.offers[0].id,reserves)
 check(state.resolve(outcome(state,"victory")),"Recovery party resolves a victory")
 check(state.heroes[party[1]].injury.is_empty(),"Resting heals existing strain in one mission resolution")
 check(state.threat<=5 and state.ending.is_empty(),"A win arrests threat growth after a loss")
 for difficulty in ["easy","standard","hard"]:
  var probe := CampaignState.new(423,difficulty)
  for wins in range(5):
   probe.victories=wins; probe.resolutions=wins; probe.generate_offers()
   for offer in probe.offers:
    var config := probe.prepare(offer.id,PackedStringArray(probe.living_ids().slice(0,2)))
    check(config!=null and config.validation_error().is_empty(),"Every bounded composition is legal")
    check(config.resolved_enemy_ids.size()<=(2 if wins<2 else 3),"Campaign opposition ramps gradually: %s/%d"%[difficulty,wins])
 var old_text: String=JSON.parse_string(FileAccess.get_file_as_string("res://tests/legacy_campaign_balance_v2.json"))
 var old := CampaignSaveCodec.decode(old_text)
 check(old.state!=null,"Actual pre-balance v2 save remains loadable: "+old.error)
 if old.state!=null:
  var envelope: Dictionary=JSON.parse_string(old_text)
  var original: Dictionary=CampaignSaveCodec.normalize(JSON.parse_string(envelope.payload))
  check(old.state.offers==original.state.offers,"Migration never rerolls frozen mission offers")
  check(old.state.supplies==original.state.supplies and old.state.threat==original.state.threat,"Migration preserves existing funds and pressure")
  check(old.state.rules.version==2,"Rules version migrates explicitly")
  check(CampaignSaveCodec.decode(CampaignSaveCodec.encode(old.state,"headquarters")).state!=null,"Migrated save roundtrips")
 print("CAMPAIGN RECOVERY RESULT: %d failures"%failures)
 quit(1 if failures else 0)
