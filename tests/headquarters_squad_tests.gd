extends "res://tests/generation_tests.gd"
func run() -> void:
 var state := CampaignState.new(37)
 check(state.has_method("deployment_capacity"),"Variable squad support exists")
 if not state.has_method("deployment_capacity"):
  print("HEADQUARTERS SQUAD RESULT: %d failures"%failures);quit(1);return
 # Development fixture grants capacity; production upgrades are checked separately.
 state.command_tier=2
 for count in [3,4]:
  var party := PackedStringArray(state.living_ids().slice(0,count))
  var config := state.configuration_for(state.offers[0],party)
  config.objective=EncounterOptions.objectives()[2].duplicate(true)
  var encounter := await prepare(config)
  check(encounter.navigation_ready,"Larger squad has valid generated navigation")
  if encounter.navigation_ready:
   var combat: CombatController=encounter.get_node("CombatController")
   var marker: ObjectiveMarker=encounter.get_node("ObjectiveMarker")
   check(marker.label.text.contains("/ %d HEROES"%count),"Extraction world marker matches deployed party size")
   check(combat.scheduler.order.size()==count+config.enemies.size(),"All distinct units scheduled")
   for index in range(count):
    var actor := combat.find_unit("hero-%02d"%(index+1))
    check(actor!=null and actor.campaign_id==party[index] and actor.faction==CombatUnit.Faction.HERO,"Spawn identity/faction correct")
   var heroes: Array[CombatUnit]=[]
   for unit: CombatUnit in combat.units:
    if unit.faction==CombatUnit.Faction.HERO: heroes.append(unit)
   for index in range(count): heroes[index].global_position=combat.objectives.center+Vector3.RIGHT*(index*.25)
   check(combat.objectives.proposed_outcome(combat.scheduler.order,true).get("result")=="victory","Extraction requires all deployed heroes")
   heroes[-1].global_position=combat.objectives.center+Vector3.RIGHT*8
   check(combat.objectives.proposed_outcome(combat.scheduler.order,true).is_empty(),"Partial squad cannot extract successfully")
   heroes[-1].health=0;heroes[-1].life_state=CombatUnit.LifeState.DEAD
   check(combat.objectives.proposed_outcome(combat.scheduler.order,true).get("result")=="defeat","Required loss defeats extraction")
  await dispose(encounter)
 print("HEADQUARTERS SQUAD RESULT: %d failures"%failures);quit(1 if failures else 0)

