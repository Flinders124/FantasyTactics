extends "res://tests/objective_encounter_tests.gd"
func run() -> void:
 for kind: String in ["cache","swift","together"]:
  var config := EncounterConfiguration.new();config.generator_settings=EncounterOptions.presets()[["cache","swift","together"].find(kind)].duplicate(true);config.generator_settings.generator_version=3
  config.optional_goal_id=kind;config.battlefield_seed=37;config.hero_ids=["knight","ranger"]
  var encounter := SCENE.instantiate() as CombatEncounter;encounter.configuration=config;encounter.get_node("EnemyController").presentation_delay=0;root.add_child(encounter)
  for frame in range(1600):
   if not encounter.preparing:break
   await process_frame
  check(encounter.navigation_ready,"Composed encounter starts after navigation")
  var combat: CombatController=encounter.get_node("CombatController")
  var serial := -1
  for frame in range(28000):
   if combat.encounter_has_ended():break
   if combat.state==CombatController.State.AWAITING_COMMAND and combat.turn_serial!=serial and combat.scheduler.active_unit().faction==CombatUnit.Faction.HERO:
    serial=combat.turn_serial;await hero_turn(combat,combat.scheduler.active_unit())
   await process_frame
  check(combat.encounter_has_ended(),"AI and heroes complete architecture encounter")
  check(combat.optional_goals.finished and OptionalGoals.valid_report(combat.optional_goals.report(),kind,"victory" if combat.state==CombatController.State.VICTORY else "failure"),"Optional report matches authoritative result")
  print("TACTICAL ENCOUNTER ",kind," result=",CombatController.State.keys()[combat.state]," round=",combat.scheduler.round_number," optional=",combat.optional_goals.report())
  combat.restart_encounter()
  for frame in range(100):
   if combat.state!=CombatController.State.SETUP:break
   await process_frame
  check(not combat.optional_goals.finished and not combat.optional_goals.collected and not combat.optional_goals.failed,"Restart clears optional progress without losing its definition")
  await dispose(encounter)
 print("TACTICAL ENCOUNTER RESULT: %d failures"%failures);quit(1 if failures else 0)
