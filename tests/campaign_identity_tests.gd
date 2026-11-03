extends "res://tests/campaign_tests.gd"
func run() -> void:
 var state := CampaignState.new(37)
 var first: String=state.living_ids()[0]
 check(state.heroes[first].has("identity"),"Recruits have persistent descriptive identity")
 if not state.heroes[first].has("identity"):
  print("CAMPAIGN IDENTITY RESULT: %d failures"%failures); quit(1); return
 var same := CampaignState.new(37)
 check(state.heroes==same.heroes and state.offers==same.offers,"Same seed reproduces identity without changing mission stream")
 check(state.heroes[first].identity.background_id!="" and not state.heroes[first].service.is_empty(),"Background and joining record exist")
 var text := CampaignSaveCodec.encode(state,"headquarters")
 var restored := CampaignSaveCodec.decode(text)
 check(restored.state!=null,"New identity format round trips: "+restored.error)
 if restored.state!=null:
  check(restored.state.snapshot()==state.snapshot(),"All identity data preserved")
  restored.state.heroes[first].service[0].text="independent"
  check(state.heroes[first].service[0].text!="independent","Runtime service records independent")
 for fixture: String in ["campaign_events_v2.json","campaign_events_active_v2.json"]:
  var old_text := FileAccess.get_file_as_string("res://tests/fixtures/"+fixture)
  var old_envelope: Dictionary=JSON.parse_string(old_text)
  var old: Dictionary=CampaignSaveCodec.normalize(JSON.parse_string(old_envelope.payload))
  var loaded := CampaignSaveCodec.decode(old_text)
  check(loaded.state!=null,"Actual v2 fixture migrates: "+fixture+" "+loaded.error)
  if loaded.state==null: continue
  check(loaded.state.offers==old.state.offers and loaded.state.active==old.state.active,"Migration preserves frozen missions")
  check(loaded.state.pending_event.is_empty() and loaded.state.event_records.is_empty(),"Migration invents no reward/event")
  for id: String in old.state.heroes:
   check(loaded.state.hero_name(id)==old.state.heroes[id].name,"Migration preserves existing name")
   check(loaded.state.heroes[id].service[0].text=="Record begins here.","No fabricated legacy service")
  if fixture.contains("active"):
   check(CampaignSaveCodec.resume(loaded.state)!=null,"Interrupted mission still resumes")
 var legacy := CampaignSaveCodec.decode(FileAccess.get_file_as_string("res://tests/legacy_campaign_v1.json"))
 check(legacy.state!=null,"Supported v1 also migrates: "+legacy.error)
 for role: String in SpecialisationCatalog.ids():
  var trained := CampaignState.new(37,"standard",null,true)
  CampaignSaveCodec.apply_snapshot(trained,state.snapshot())
  trained.heroes[first].experience=20;trained.heroes[first].level=2
  var identity: Dictionary=trained.heroes[first].identity.duplicate(true)
  check(trained.specialise(first,role),"All six specialisations supported")
  check(trained.heroes[first].identity==identity and trained.heroes[first].service[-1].kind=="specialisation","Class choice preserves personal identity")
 var recovering := CampaignState.new(38)
 var ids := recovering.living_ids()
 recovering.heroes[ids[2]].injury={"name":"Battle strain","remaining":1}
 recovering.commit(recovering.offers[0].id,PackedStringArray(ids.slice(0,2)))
 recovering.resolve(record(recovering))
 var recovery_entry: Dictionary=recovering.heroes[ids[2]].service[-1]
 check(recovery_entry.text=="Recovered 1 injury step(s); 0 remaining.","Dossier records actual recovery, not unused recovery budget")
 var casualty := CampaignState.new(39)
 var deployed := PackedStringArray(casualty.living_ids().slice(0,2))
 casualty.commit(casualty.offers[0].id,deployed)
 var people: Dictionary={}
 for id: String in deployed:
  people[id]={"health":0 if id==deployed[0] else 10,"maximum_health":10,"survival":"dead" if id==deployed[0] else "recovered","death_cause":"Bled out" if id==deployed[0] else ""}
 casualty.resolve(CampaignMissionResult.new({"version":2,"mission_id":casualty.active.id,"outcome":"victory","abandoned":false,"reason":"Service fixture","heroes":people,"rounds":3,"tactical_result":"VICTORY"}))
 check(casualty.heroes[deployed[0]].service[-1].kind=="death" and casualty.heroes[deployed[0]].missions_completed==1,"Actual death preserves personal record and lifetime service")
 var replacement := casualty.recruit("identity-replacement")
 check(not replacement.is_empty() and replacement!=deployed[0] and casualty.heroes[replacement].service.size()==1,"Replacement is a new companion with fresh independent service")
 for index in range(70): CampaignEvents.service(state,first,"record","Bounded entry")
 check(state.heroes[first].service.size()==64 and state.heroes[first].missions_completed==0,"Display record bound does not change lifetime counters")
 print("CAMPAIGN IDENTITY RESULT: %d failures"%failures); quit(1 if failures else 0)
