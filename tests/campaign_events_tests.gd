extends "res://tests/campaign_tests.gd"
func decline(state: CampaignState) -> void:
 var pending: Dictionary=state.get("pending_event")
 if not pending.is_empty(): state.call("choose_event",pending.id,"decline")
func run() -> void:
 var state := CampaignState.new(37)
 check(state.has_method("choose_event"),"Campaign exposes validated event choices")
 if not state.has_method("choose_event"):
  print("CAMPAIGN EVENTS RESULT: %d failures"%failures); quit(1); return
 var same := CampaignState.new(37)
 var party := PackedStringArray(state.living_ids().slice(0,2))
 for run_state: CampaignState in [state,same]:
  check(run_state.commit(run_state.offers[0].id,party)!=null,"First deployment works")
  check(run_state.resolve(record(run_state)),"Mission resolves before event selection")
 check(state.pending_event==same.pending_event and not state.pending_event.is_empty(),"Same state produces frozen event")
 check(state.offers==same.offers,"Identity/event stream does not alter mission layout stream")
 var before := state.snapshot()
 check(not state.deployment_error(state.offers[0].id,party).is_empty(),"Pending decision explains deployment gate")
 check(not state.choose_event("stale", "decline") and state.snapshot()==before,"Stale event cannot mutate state")
 var pending: Dictionary=state.pending_event.duplicate(true)
 check(state.choose_event(pending.id,"decline"),"Explicit decline always resolves safely")
 var after := state.snapshot()
 check(not state.choose_event(pending.id,"decline") and state.snapshot()==after,"Choice cannot apply twice")
 check(state.supplies==before.supplies and state.offers==before.offers,"Decline changes neither funds nor mission board")
 check(CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"headquarters")).state!=null,"Resolved event persists")
 # Exercise complete run; neutral choices never alter old campaign balance/outcome.
 for mission in range(4):
  check(state.commit(state.offers[0].id,party)!=null,"Subsequent deployment accepted")
  check(state.resolve(record(state)),"Subsequent result accepted")
  decline(state)
 check(state.ending=="victory" and state.pending_event.is_empty() and state.event_records.size()<=4,"Final result takes precedence and event frequency bounded")
 print("CAMPAIGN EVENTS RESULT: %d failures"%failures); quit(1 if failures else 0)
