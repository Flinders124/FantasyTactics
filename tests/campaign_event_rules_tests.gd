extends "res://tests/campaign_tests.gd"
func clone_state(state: CampaignState) -> CampaignState:
 var copy := CampaignState.new(state.seed_value,state.difficulty_id,null,true)
 CampaignSaveCodec.apply_snapshot(copy,state.snapshot())
 return copy
func run() -> void:
 var base := CampaignState.new(91)
 var party := PackedStringArray(base.living_ids().slice(0,2))
 base.commit(base.offers[0].id,party);base.resolve(record(base))
 var original_offer := base.pending_event.duplicate(true)
 base.choose_event(original_offer.id,"decline")
 check(CampaignEvents.offer(base).is_empty(),"Repeated scheduling cannot create another event for the same resolution")
 base.event_records.clear();base.resolved_events.clear();base.pending_event={}
 var subject: String=party[0]
 base.heroes[subject].experience=20;base.heroes[subject].level=2;base.specialise(subject,"cleric")
 # All eligibility branches use real existing state; no altered normal definitions.
 for id: String in base.living_ids(): base.heroes[id].injury={"name":"Severe injury","remaining":3}
 var dead: String=base.living_ids()[-1];base.heroes[dead].dead=true;base.heroes[dead].death_cause="Test loss";base.heroes[dead].injury={}
 var branches: int=0
 for template: String in CampaignEvents.EVENTS:
  var definition := CampaignEvents.definition(template)
  var event := CampaignEvents.freeze(base,definition)
  check(not event.is_empty(),"Template eligible: "+template)
  if event.is_empty(): continue
  for option: Dictionary in event.choices:
   var state := clone_state(base);state.pending_event=event.duplicate(true)
   var funds := state.supplies
   var remaining: int=int(state.heroes[event.subject].injury.get("remaining",0))
   check(state.choose_event(event.id,option.id),"Template branch accepted: "+template+"/"+option.id)
   branches+=1
   check(state.supplies==funds+int(option.supplies),"Exact Supplies consequence")
   check(int(state.heroes[event.subject].injury.get("remaining",0))==maxi(0,remaining-int(option.recovery)),"Exact recovery consequence")
   var after := state.snapshot()
   check(not state.choose_event(event.id,option.id) and state.snapshot()==after,"Every branch rejects duplicate effect")
   var loaded := CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"headquarters"))
   check(loaded.state!=null,"Branch save validates: "+template+"/"+option.id+" "+loaded.error)
  var pending := clone_state(base);pending.pending_event=event.duplicate(true)
  var loaded := CampaignSaveCodec.decode(CampaignSaveCodec.encode(pending,"headquarters"))
  check(loaded.state!=null and loaded.state.pending_event==event,"Pending snapshot survives load without reroll")
 var bad := CampaignEvents.definition("caravan").duplicate(true) as CampaignEventDefinition
 bad.choices[0].supplies=7
 check(CampaignEvents.freeze(base,bad).is_empty(),"Out-of-envelope editable content is rejected")
 var recovery := CampaignEvents.freeze(base,CampaignEvents.definition("herbs"))
 var stale := clone_state(base);stale.pending_event=recovery.duplicate(true)
 stale.heroes[recovery.subject].injury={}
 var before := stale.snapshot()
 check(not stale.choose_event(recovery.id,"treat") and stale.snapshot()==before,"Already recovered participant costs nothing")
 stale.heroes[recovery.subject].dead=true
 check(stale.choose_event(recovery.id,"decline"),"Dead participant never traps neutral decline")
 var poor := clone_state(base);poor.pending_event=recovery.duplicate(true)
 for id: String in poor.living_ids().slice(1): poor.heroes[id].dead=true
 poor.supplies=poor.recruitment_reserve()
 before=poor.snapshot()
 check(not poor.choose_event(recovery.id,"treat") and poor.snapshot()==before,"Insufficient free Supplies cannot spend reserve")
 for seed_number in range(10):
  var seeded := clone_state(base);seeded.seed_value=seed_number
  var one := CampaignEvents.offer(seeded);var two := CampaignEvents.offer(seeded)
  check(one==two,"Ten fixed seeds reproduce bounded selection")
  check(seeded.pending_event.is_empty(),"Evaluation alone has no side effects")
 var invalid := clone_state(base);invalid.pending_event=recovery.duplicate(true)
 invalid.pending_event.choices[0].supplies=6
 check(CampaignSaveCodec.decode(CampaignSaveCodec.encode(invalid,"headquarters")).state==null,"Tampered frozen choice rejected")
 var versioned := clone_state(base);versioned.pending_event=recovery.duplicate(true)
 var old_pending := CampaignSaveCodec.encode(versioned,"headquarters")
 versioned.choose_event(recovery.id,"decline")
 var old_resolved := CampaignSaveCodec.encode(versioned,"headquarters")
 var source := CampaignEvents.definition("herbs")
 var original_choices: Array[Dictionary]=source.choices.duplicate(true)
 source.revision=2;source.choices[0].supplies=-5
 var migrated := CampaignSaveCodec.decode(old_pending)
 check(migrated.state!=null,"Frozen older event survives an authored content revision")
 if migrated.state!=null:
  var money: int=migrated.state.supplies
  check(migrated.state.choose_event(recovery.id,"treat") and migrated.state.supplies==money-4,"Old pending event applies its displayed original effect")
 check(CampaignSaveCodec.decode(old_resolved).state!=null,"Historical resolved event survives later content revisions")
 source.revision=1;source.choices=original_choices
 print("CAMPAIGN EVENT RULES branches=%d seeds=10"%branches)
 print("CAMPAIGN EVENT RULES RESULT: %d failures"%failures);quit(1 if failures else 0)
