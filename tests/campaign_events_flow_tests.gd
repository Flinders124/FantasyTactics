extends "res://tests/campaign_flow_tests.gd"
func run() -> void:
 root.size=Vector2i(1280,720)
 flow=load("res://scenes/main.tscn").instantiate();root.add_child(flow)
 var coordinator: Node=flow.campaign
 check(coordinator.has_method("show_event"),"Camp has an event presentation route")
 if not coordinator.has_method("show_event"):
  flow.queue_free();await settle();print("CAMPAIGN EVENTS FLOW RESULT: %d failures"%failures);quit(1);return
 var state := CampaignState.new(37)
 coordinator.state=state;coordinator.store.path="user://events-flow/%d.json"%OS.get_process_id()
 var party := PackedStringArray(state.living_ids().slice(0,2))
 state.commit(state.offers[0].id,party)
 var people: Dictionary={}
 for id: String in party: people[id]={"health":3,"maximum_health":10}
 state.resolve(CampaignMissionResult.new({"version":1,"mission_id":state.active.id,"outcome":"victory","abandoned":false,"reason":"Event UI fixture","heroes":people,"rounds":3,"tactical_result":"VICTORY"}))
 state.pending_event=CampaignEvents.freeze(state,CampaignEvents.definition("herbs"))
 check(coordinator.store.write(state,"headquarters"),"Pending event fixture saves")
 coordinator.headquarters();await settle()
 var before := state.snapshot()
 flow.request_transition("campaign_event");await settle()
 check(flow.screen=="campaign_event" and state.snapshot()==before,"Opening event does not resolve it")
 flow.request_transition("audio_settings");await settle()
 check(flow.audio.editing and state.snapshot()==before,"Settings remain available without resolving the decision")
 flow.audio.panel.close();await settle()
 var instance: String=state.pending_event.id
 coordinator.store.fail_stage="write"
 check(not coordinator.mutate("choose_event",[instance,"treat"]),"Write failure reports failure")
 check(state.snapshot()==before,"Write failure restores entire pending event and effects")
 coordinator.store.fail_stage=""
 check(coordinator.mutate("choose_event",[instance,"treat"]),"Accepted choice persists through coordinator")
 check(not coordinator.mutate("choose_event",[instance,"treat"]),"Rapid duplicate cannot commit twice")
 check(state.supplies==int(before.supplies)-4,"Exactly one accepted treatment cost")
 var disk: CampaignSaveCodec.Decoded=coordinator.store.read_file(coordinator.store.path)
 check(disk.state!=null,"Accepted result loads: "+disk.error)
 if disk.state!=null:
  check(CampaignSaveCodec.normalize(disk.state.snapshot())==CampaignSaveCodec.normalize(state.snapshot()),"All persisted fields match accepted effects under the codec numeric convention")
 coordinator.call("show_dossier",party[0]);await settle()
 check(flow.screen=="campaign_dossier","Hero has a dossier route")
 coordinator.headquarters();await settle();flow.menu.open_camp_page(4)
 var displayed: int=0
 for label: Node in flow.menu.find_children("*","Label",true,false):
  if str(state.event_records[0].text) in label.text: displayed+=1
 check(displayed==1,"History displays each committed decision once")
 for cycle in range(5):
  coordinator.headquarters();await settle();coordinator.call("show_dossier",party[0]);await settle()
 check(state.event_records.size()==1,"Repeated pages never duplicate event entries")
 # A cancelled confirmation must never apply to a later same-seed campaign.
 var fresh := CampaignState.new(state.seed_value)
 var fresh_party := PackedStringArray(fresh.living_ids().slice(0,2))
 fresh.commit(fresh.offers[0].id,fresh_party)
 var fresh_people: Dictionary={}
 for id: String in fresh_party: fresh_people[id]={"health":3,"maximum_health":10}
 fresh.resolve(CampaignMissionResult.new({"version":1,"mission_id":fresh.active.id,"outcome":"victory","abandoned":false,"reason":"Fresh campaign","heroes":fresh_people,"rounds":3,"tactical_result":"VICTORY"}))
 fresh.pending_event=CampaignEvents.freeze(fresh,CampaignEvents.definition("herbs"))
 coordinator.state=fresh;coordinator.show_event();await settle()
 flow.request_transition("campaign_event_choose:"+str(fresh.pending_event.id)+":treat")
 var stale_callback: Callable=flow.menu_guide.on_confirm
 var next_run := CampaignState.new(fresh.seed_value,"standard",null,true)
 CampaignSaveCodec.apply_snapshot(next_run,fresh.snapshot());next_run.campaign_id=Crypto.new().generate_random_bytes(16).hex_encode()
 coordinator.state=next_run;coordinator.headquarters();await settle()
 var fresh_before := next_run.snapshot()
 stale_callback.call()
 check(next_run.snapshot()==fresh_before,"Stale confirmation cannot affect a replacement campaign with the same seed")
 coordinator.state=null;flow.queue_free();await settle()
 print("CAMPAIGN EVENTS FLOW RESULT: %d failures"%failures);quit(1 if failures else 0)

