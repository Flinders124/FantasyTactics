extends "res://tests/headquarters_rules_tests.gd"
func run() -> void:
 var state := CampaignState.new(37)
 check(state.has_method("equipment_error"),"Equipment exposes shared level/slot validation")
 if not state.has_method("equipment_error"):
  print("HEADQUARTERS EQUIPMENT RESULT: %d failures"%failures);quit(1);return
 state.supplies=1000
 var ids := state.living_ids();var hero: String=ids[0]
 var before := state.snapshot()
 check(state.purchase("watch_helm").is_empty() and state.snapshot()==before,"Level1 cannot buy an unusable helm")
 state.heroes[hero].experience=20;state.heroes[hero].level=2
 var helm := state.purchase("watch_helm","helm-once")
 check(not helm.is_empty() and state.owner_of(helm).is_empty(),"Buying puts item in shared inventory, never equips")
 check(state.purchase("watch_helm","helm-once").is_empty(),"Purchase request cannot spend twice")
 check(state.equip(hero,helm) and state.heroes[hero].equipment.get("helmet")==helm,"Unlocked helmet slot equips")
 check(not state.equip(ids[1],helm) and state.owner_of(helm)==hero,"Locked target slot cannot steal item")
 state.heroes[ids[1]].experience=20;state.heroes[ids[1]].level=2
 check(state.equip(ids[1],helm) and not state.heroes[hero].equipment.has("helmet"),"Single owned item transfers safely")
 check(state.unequip(ids[1],"helmet"),"Unequip works without losing inventory")
 check(state.purchase("pathfinder_charm").is_empty(),"Accessory requires level3")
 state.heroes[hero].experience=50;state.heroes[hero].level=3
 var charm := state.purchase("pathfinder_charm")
 var coat := state.purchase("stoneweave")
 check(state.equip(hero,helm) and state.equip(hero,charm) and state.equip(hero,coat),"Independent slots equip together")
 var preview := state.preview_definition(hero)
 check(preview.maximum_health==24 and is_equal_approx(preview.movement_allowance,5.75),"Modifiers combine once across four slots")
 check(state.preview_definition(ids[1]).maximum_health==20 and HeroCatalog.find("recruit").maximum_health==20,"Other hero/shared stats unchanged")
 check(state.purchase("veteran_blade").is_empty(),"Advanced gear requires level4")
 state.heroes[hero].experience=90;state.heroes[hero].level=4
 check(not state.purchase("veteran_blade").is_empty(),"Advanced gear available at4")
 check(state.purchase("beacon_helm").is_empty(),"Trader-only equipment cannot be bought from permanent shop")
 var legendary := state.create_item("beacon_helm")
 var variant: String=state.inventory[legendary].art_variant
 check(not variant.is_empty(),"Legendary owned items receive stable art")
 check(state.equip(hero,legendary) and state.inventory[legendary].art_variant==variant,"Equip does not reroll art")
 var restored := CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"headquarters"))
 check(restored.state!=null,"Extended inventory roundtrips: "+restored.error)
 if restored.state!=null: check(restored.state.inventory[legendary].art_variant==variant,"Art variant survives reload")
 for role: String in SpecialisationCatalog.ids():
  var advanced: bool=false;var premium: bool=false
  for option: CampaignItemDefinition in CampaignEquipment.catalogue(state):
   if option.slot!="weapon" or not option.compatible_heroes.has(role): continue
   if option.vendor=="armoury" and option.minimum_level==4: advanced=true
   if option.vendor=="trader": premium=true
  check(advanced and premium,"Each class has advanced and premium weapon choices: "+role)
 print("HEADQUARTERS EQUIPMENT RESULT: %d failures"%failures);quit(1 if failures else 0)
