extends "res://tests/campaign_flow_tests.gd"
func run() -> void:
 flow=load("res://scenes/main.tscn").instantiate();root.add_child(flow)
 var state := CampaignState.new(37);flow.campaign.state=state;flow.campaign.headquarters();await settle()
 check(flow.menu.camp.get_meta("command_tier",-1)==0,"Camp presentation exposes its authoritative tier")
 if flow.menu.camp.get_meta("command_tier",-1)<0:
  flow.queue_free();await settle();print("HEADQUARTERS CAMP RESULT: %d failures"%failures);quit(1);return
 for tier in [0,1,2]:
  state.command_tier=tier
  flow.campaign.headquarters();await settle()
  check(flow.menu.camp.stage.has_node("CommandTentTier%d"%tier),"Each camp tier has a distinct command tent")
 check(flow.menu.camp.stage.has_node("OutfitterStall"),"Permanent Armoury is visibly a shop")
 check(flow.menu.camp.destinations.size()==5,"No trader destination without a visit")
 state.resolutions=2
 state.trader=CampaignTrader.arrival(state)
 flow.campaign.headquarters();await settle()
 var camp: Node=flow.menu.camp
 check(camp.destinations.size()==6 and camp.stage.has_node("TraderWagon"),"Visiting trader has a wagon and sixth interaction")
 for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=dimensions
  for large in [false,true]:
   flow.audio.preferences.Accessibility.ui_scale=1.15 if large else 1.0;flow.audio.preferences.Accessibility.large_text=large;flow.audio.apply_preferences(false);await settle()
   for index in range(camp.destinations.size()):
    var rect: Rect2=camp.destinations[index].get_rect()
    check(Rect2(Vector2.ZERO,camp.size).encloses(rect),"All six labels remain in bounds")
    for other in range(index): check(not rect.intersects(camp.destinations[other].get_rect()),"Camp labels never overlap")
 flow.campaign.state=null;flow.queue_free();await settle()
 print("HEADQUARTERS CAMP RESULT: %d failures"%failures);quit(1 if failures else 0)
