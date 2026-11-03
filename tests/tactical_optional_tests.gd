extends "res://tests/headquarters_rules_tests.gd"
func run() -> void:
 check(ResourceLoader.exists("res://scripts/optional_goal_controller.gd"),"Optional goals have separate runtime state")
 if not ResourceLoader.exists("res://scripts/optional_goal_controller.gd"):
  print("TACTICAL OPTIONAL RESULT: %d failures"%failures);quit(1);return
 var script: Variant=load("res://scripts/optional_goal_controller.gd")
 var goal: Variant=script.new();goal.configure("cache");goal.point=Vector3.ZERO
 check(not goal.summary().contains("Supplies"),"Standalone skirmish shows completion, not a currency reward")
 var marker := OptionalGoalMarker.new();root.add_child(marker);marker.bind(goal)
 check(marker.label.text.contains("BONUS CHALLENGE"),"Skirmish world marker does not promise a currency payout")
 marker.queue_free();await process_frame
 var unit := load("res://scenes/combat_unit.tscn").instantiate() as CombatUnit
 unit.definition=HeroCatalog.find("knight");unit.stable_id="hero-test";unit.faction=CombatUnit.Faction.HERO;root.add_child(unit);unit.reset_for_encounter()
 var units: Array[CombatUnit]=[unit]
 unit.global_position=Vector3(1.2,0,0)
 goal.sample(units,false);check(not goal.collected,"Cache only samples completed atomic actions")
 var independent: Variant=script.new();independent.configure("cache")
 goal.sample(units,true);check(not independent.collected,"Shared definition has independent encounter progress")
 check(goal.collected,"Cache includes its exact radius boundary")
 goal.finish("defeat",units,2);check(not goal.report().completed and goal.report().reward==0,"Losing cannot pay a cache reward")
 goal.configure("cache");goal.point=Vector3.ZERO;goal.sample(units,true);goal.finish("victory",units,2)
 check(goal.report().completed and goal.report().reward==8,"Winning with cache pays configured bonus")
 goal.configure("swift");goal.finish("victory",units,4);check(goal.report().completed,"Swift goal includes round4")
 goal.configure("swift");goal.finish("victory",units,5);check(not goal.report().completed,"Swift goal excludes round5")
 goal.configure("together");goal.observe("downed",unit);goal.finish("victory",units,3);check(not goal.report().completed,"Healing a previously downed hero cannot erase goal failure")
 goal.configure("together");goal.finish("victory",units,3);check(goal.report().completed,"Fresh goal has independent clean progress")
 unit.queue_free();await process_frame
 var state := CampaignState.new(37)
 check(EncounterCode.decode(state.offers[0].code).configuration.optional_goal_id!="","New offers freeze an optional goal")
 var party := PackedStringArray(state.living_ids().slice(0,2))
 state.commit(state.offers[0].id,party)
 var id: String=EncounterCode.decode(state.active.encounter.code).configuration.optional_goal_id
 var reward: int=load("res://definitions/optional/"+id+".tres").supplies
 var data := record(state).snapshot();data.version=3
 for hero: Dictionary in data.heroes.values():hero.survival="recovered";hero.death_cause=""
 data.optional={"id":id,"completed":true,"reward":reward}
 var untouched := state.snapshot()
 for forged: Dictionary in [{"id":id,"completed":true,"reward":reward+1},{"id":"missing","completed":true,"reward":reward}]:
  var bad := data.duplicate(true);bad.optional=forged
  check(not state.resolve(CampaignMissionResult.new(bad)) and state.snapshot()==untouched,"Forged or mismatched goal cannot change campaign state")
 var before := state.supplies
 check(state.resolve(CampaignMissionResult.new(data)),"Completed optional result applies")
 check(state.supplies==before+state.last_debrief.mission.supplies+reward,"Bonus adds exactly once alongside normal rewards")
 var settled := state.snapshot();check(not state.resolve(CampaignMissionResult.new(data)) and state.snapshot()==settled,"Duplicate result cannot award bonus twice")
 check(CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"debrief")).state!=null,"Bonus debrief saves and loads")
 for file: String in ["tactical_v4.json","tactical_active_v4.json"]:
  var loaded := CampaignSaveCodec.decode(FileAccess.get_file_as_string("res://tests/fixtures/"+file))
  check(loaded.state!=null,"Pre-milestone v4 save migrates: "+loaded.error)
  if loaded.state!=null:
   if not loaded.state.active.is_empty():check(CampaignSaveCodec.resume(loaded.state).generator_settings.generator_version==2,"Old interrupted mission keeps old geometry")
   else:check(EncounterCode.decode(loaded.state.offers[0].code).configuration.optional_goal_id=="","Old frozen board gains no surprise goals")
 print("TACTICAL OPTIONAL RESULT: %d failures"%failures);quit(1 if failures else 0)
