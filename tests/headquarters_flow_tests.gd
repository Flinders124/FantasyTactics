extends "res://tests/campaign_flow_tests.gd"
func run() -> void:
 root.size=Vector2i(1280,720)
 flow=load("res://scenes/main.tscn").instantiate();root.add_child(flow)
 var coordinator: Node=flow.campaign
 check(coordinator.has_method("show_equipment_slot"),"Character screen has a slot chooser route")
 if not coordinator.has_method("show_equipment_slot"):
  flow.queue_free();await settle();print("HEADQUARTERS FLOW RESULT: %d failures"%failures);quit(1);return
 var state := CampaignState.new(37);coordinator.state=state;coordinator.store.path="user://headquarters-flow.json"
 state.supplies=100;var hero: String=state.living_ids()[0]
 state.heroes[hero].experience=20;state.heroes[hero].level=2
 check(coordinator.store.write(state,"headquarters"),"Isolated fixture saved")
 coordinator.armoury_hero=hero;coordinator.hq_tab=3;coordinator.hq_open=true;coordinator.headquarters();await settle()
 for picture in flow.menu.tabs.get_child(3).find_children("*","TextureRect",true,false):
  if picture.custom_minimum_size==Vector2(96,110):
   check(picture.get_parent().get_parent().size.x>400,"Shop item cards fill their grid columns without squeezed text")
 for node in flow.menu.tabs.get_child(3).find_children("*","Button",true,false):
  check(not node.text.begins_with("Equip") and not node.text.begins_with("Transfer"),"Permanent shop does not equip items")
 flow.request_transition("campaign_shop_buy:watch_helm:"+str(state.next_item));await settle()
 var item: String=""
 for id: String in state.inventory:
  if state.inventory[id].definition_id=="watch_helm": item=id
 check(not item.is_empty() and state.owner_of(item).is_empty(),"Shop purchase stays in inventory")
 coordinator.show_equipment_slot(hero,"helmet");await settle()
 check(flow.screen=="campaign_equipment","Selecting unlocked slot opens owned equipment")
 var before := state.snapshot();coordinator.store.fail_stage="write"
 check(not coordinator.mutate("equip",[hero,item]) and state.snapshot()==before,"Failed equipment save restores inventory and stats")
 coordinator.store.fail_stage=""
 flow.request_transition("campaign_equip_for:"+hero+":"+item);await settle()
 check(state.owner_of(item)==hero and flow.screen=="campaign_equipment","Equip uses selected character and slot")
 coordinator.show_equipment_slot(state.living_ids()[1],"helmet");await settle()
 check(not state.equipment_error(state.living_ids()[1],item).is_empty(),"Locked companion slot explains rejection")
 for cycle in range(5):
  coordinator.headquarters();await settle();coordinator.show_dossier(hero);await settle()
 check(get_nodes_in_group("headquarters_camps").size()<=1,"Repeated character/shop transitions clean camp")
 # Visiting stock and command upgrades share the existing transactional save boundary.
 var progress := CampaignState.new(37)
 for cycle in range(2):
  progress.commit(progress.offers[0].id,PackedStringArray(progress.living_ids().slice(0,2)))
  var people: Dictionary={}
  for id: String in progress.active.party:
   var definition := progress.preview_definition(id)
   people[id]={"health":definition.maximum_health,"maximum_health":definition.maximum_health,"survival":"recovered","death_cause":""}
  check(progress.resolve(CampaignMissionResult.new({"version":2,"mission_id":progress.active.id,"outcome":"victory","abandoned":false,"reason":"Fixture","heroes":people,"rounds":2,"tactical_result":"VICTORY"})),"Transactional trader fixture resolves")
  if not progress.pending_event.is_empty(): progress.choose_event(progress.pending_event.id,"decline")
 coordinator.state=progress;check(coordinator.store.write(progress,"headquarters"),"Trader checkpoint saves")
 var checkpoint := progress.snapshot();coordinator.store.fail_stage="write"
 check(not coordinator.mutate("buy_command_upgrade",[1]) and progress.snapshot()==checkpoint,"Failed command save rolls back capacity and spending")
 var offer_id: String=progress.trader.offers[0].offer_id
 check(not coordinator.mutate("purchase_trader",[offer_id]) and progress.snapshot()==checkpoint,"Failed trader save rolls back sold flag, stock, inventory and spending")
 coordinator.store.fail_stage=""
 coordinator.state=null;flow.queue_free();await settle()
 print("HEADQUARTERS FLOW RESULT: %d failures"%failures);quit(1 if failures else 0)
