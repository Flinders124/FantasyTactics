extends SceneTree
## External harness runs against production PCK; no dependency on packaged tests/dev.
var failures: int=0
var flow: SceneFlow
func check(ok: bool,message: String) -> void:
 if not ok: failures+=1;push_error(message)
func _initialize() -> void:
 if OS.get_environment("OATH_TEST_ISOLATED")!="1": push_error("Isolated test data is required.");quit(1);return
 call_deferred("run")
func run() -> void:
 var state := CampaignState.new(37)
 var party := PackedStringArray(state.living_ids().slice(0,2))
 check(state.commit(state.offers[0].id,party)!=null,"Pack deployment works")
 var people: Dictionary={}
 for id: String in party: people[id]={"health":3,"maximum_health":10,"survival":"recovered","death_cause":""}
 check(state.resolve(CampaignMissionResult.new({"version":2,"mission_id":state.active.id,"outcome":"victory","abandoned":false,"reason":"Export smoke","heroes":people,"rounds":3,"tactical_result":"VICTORY"})),"Pack real result resolves")
 check(not state.pending_event.is_empty(),"Pack event resources included")
 var store := CampaignSaveStore.new();store.path="user://events-pack/active.json"
 check(store.write(state,"headquarters"),"Pending event persists")
 var loaded := store.read_file(store.path)
 check(loaded.state!=null,"Pack save loads")
 if loaded.state==null:print("CAMPAIGN EVENTS PACK RESULT: %d failures"%failures);quit(1);return
 state=loaded.state
 var instance: String=state.pending_event.id
 check(state.choose_event(instance,"decline") and not state.choose_event(instance,"decline"),"Pack choice applies once")
 check(store.write(state,"headquarters"),"Resolved event persists")
 loaded=store.read_file(store.path)
 check(loaded.state!=null and loaded.state.event_records.size()==1,"Pack once-only history reloads")
 flow=load("res://scenes/main.tscn").instantiate();root.add_child(flow)
 flow.campaign.state=state;flow.campaign.selected=party;flow.campaign.store.path=store.path
 flow.campaign.show_dossier(party[0])
 for frame in range(15): await process_frame
 check(flow.screen=="campaign_dossier","Pack dossier opens with models and background")
 var configuration := state.commit(state.offers[0].id,party)
 check(configuration!=null,"Next mission remains available")
 check(store.write(state,"in_progress"),"Interrupted mission checkpoint with identity saves")
 loaded=store.read_file(store.path)
 check(loaded.state!=null and CampaignSaveCodec.resume(loaded.state)!=null,"Interrupted mission still restores")
 flow.campaign.state=null;flow.queue_free()
 for frame in range(20): await process_frame
 print("CAMPAIGN EVENTS PACK RESULT: %d failures"%failures);quit(1 if failures else 0)
