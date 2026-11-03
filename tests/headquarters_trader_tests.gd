extends "res://tests/headquarters_rules_tests.gd"
func run() -> void:
 var state := CampaignState.new(37)
 check(state.has_method("purchase_trader"),"Visiting trader has an authoritative purchase operation")
 if not state.has_method("purchase_trader"):
  print("HEADQUARTERS TRADER RESULT: %d failures"%failures);quit(1);return
 var twin := CampaignState.new(37)
 check(state.trader.is_empty(),"No trader on campaign creation")
 for probe: CampaignState in [state,twin]:
  win(probe);check(probe.trader.is_empty(),"No visit after first resolution")
  win(probe)
 check(not state.trader.is_empty() and state.trader==twin.trader and state.trader.offers.size()==3,"Second resolution freezes three deterministic offers")
 var clean := state.snapshot()
 for mutation: String in ["price","duplicate","variant","sold"]:
  var corrupt := clean.duplicate(true)
  match mutation:
   "price": corrupt.trader.offers[0].price=1
   "duplicate": corrupt.trader.offers[1].item_id=corrupt.trader.offers[0].item_id
   "variant": corrupt.trader.offers[0].art_variant="../../untrusted.png"
   "sold": corrupt.trader.offers[0].sold=true
  check(not CampaignTrader.valid_saved(corrupt,state),"Malformed trader data rejected: "+mutation)
 var original := state.trader.duplicate(true)
 var offer: Dictionary={}
 for entry: Dictionary in state.trader.offers:
  if entry.item_id=="beacon_helm": offer=entry;break
 check(not offer.is_empty(),"First eligible stock includes a useful helm")
 var money := state.supplies
 var item: String=state.purchase_trader(offer.offer_id)
 check(not item.is_empty() and state.supplies==money-int(offer.price) and state.owner_of(item).is_empty(),"Trader purchase spends once without equipping")
 var snapshot := state.snapshot()
 check(state.purchase_trader(offer.offer_id).is_empty() and state.snapshot()==snapshot,"Sold stock cannot duplicate inventory or spending")
 var loaded := CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"headquarters"))
 check(loaded.state!=null,"Trader stock and sold flags roundtrip: "+loaded.error)
 if loaded.state!=null:
  check(loaded.state.trader==state.trader and loaded.state.inventory[item].art_variant==state.inventory[item].art_variant,"Reload keeps frozen stock and art")
 var config := state.prepare(state.offers[0].id,PackedStringArray(state.living_ids().slice(0,2)))
 check(config!=null and not state.trader.is_empty(),"Inspecting mission does not dismiss trader")
 check(state.commit(state.offers[0].id,PackedStringArray(state.living_ids().slice(0,2)))!=null and state.trader.is_empty(),"Trader leaves only on commitment")
 state.resolve(record(state));settle_decision(state)
 check(state.trader.is_empty(),"No visit after third resolution")
 win(state)
 check(not state.trader.is_empty() and state.trader.visit_id!=original.visit_id,"Fourth resolution creates next visit")
 var failed := CampaignState.new(38)
 for index in range(2):
  failed.commit(failed.offers[0].id,PackedStringArray(failed.living_ids().slice(0,2)))
  failed.resolve(record(failed,"failure"));settle_decision(failed)
 check(not failed.trader.is_empty(),"Failed committed missions also advance trader time")
 print("HEADQUARTERS TRADER RESULT: %d failures"%failures);quit(1 if failures else 0)

