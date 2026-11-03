extends SceneTree
## Standalone external harness; packaged production resources only.
var failures: int=0
func check(ok: bool,message: String) -> void:
 if not ok: failures+=1;push_error(message)
func _initialize() -> void:
 if OS.get_environment("OATH_TEST_ISOLATED")!="1":push_error("Use isolated user data.");quit(1);return
 call_deferred("run")
func run() -> void:
 var state := CampaignState.new(37)
 for cycle in range(2):
  var party := PackedStringArray(state.living_ids().slice(0,2))
  check(state.commit(state.offers[0].id,party)!=null,"Pack opening commits")
  var people: Dictionary={}
  for id: String in party:
   var definition := state.preview_definition(id)
   people[id]={"health":definition.maximum_health,"maximum_health":definition.maximum_health,"survival":"recovered","death_cause":""}
  check(state.resolve(CampaignMissionResult.new({"version":2,"mission_id":state.active.id,"outcome":"victory","abandoned":false,"reason":"Pack fixture","heroes":people,"rounds":2,"tactical_result":"VICTORY"})),"Pack result resolves")
  if not state.pending_event.is_empty():state.choose_event(state.pending_event.id,"decline")
  if cycle==0:check(state.buy_command_upgrade(1),"Pack first command upgrade")
 var checkpoint := CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"headquarters"))
 check(checkpoint.state!=null,"Pack checkpoint roundtrip")
 var premium: String=""
 for offer: Dictionary in state.trader.offers:
  if offer.item_id=="beacon_helm":premium=state.purchase_trader(offer.offer_id)
 check(not premium.is_empty() and state.owner_of(premium).is_empty(),"Pack stock purchases to shared inventory")
 check(state.equip(state.living_ids()[0],premium),"Pack character slot equips")
 var texture := CampaignEquipment.texture(state.item("beacon_helm"),state.inventory[premium].art_variant)
 check(texture!=null and texture.get_width()<=256,"Pack contains imported legendary artwork")
 state=checkpoint.state;check(state.buy_command_upgrade(2),"Pack four-hero upgrade")
 var party := PackedStringArray(state.living_ids())
 var config := state.commit(state.offers[0].id,party)
 var store := CampaignSaveStore.new();store.path="user://headquarters-pack/active.json"
 check(store.write(state,"in_progress"),"Pack four-hero interrupted state saves")
 var restored := store.read_file(store.path)
 check(restored.state!=null,"Pack four-hero state loads")
 config=CampaignSaveCodec.resume(restored.state)
 check(config!=null and config.hero_ids.size()==4,"Pack recovery has four heroes")
 var encounter := load("res://scenes/combat_encounter.tscn").instantiate() as CombatEncounter
 encounter.configuration=config;root.add_child(encounter)
 for frame in range(1600):
  if not encounter.preparing:break
  await process_frame
 check(encounter.navigation_ready and encounter.get_node("CombatController").units.size()==4+config.enemies.size(),"Pack larger deployment navigates and spawns")
 encounter.shutdown();encounter.queue_free()
 for frame in range(20):await process_frame
 print("HEADQUARTERS PACK RESULT: %d failures"%failures);quit(1 if failures else 0)
