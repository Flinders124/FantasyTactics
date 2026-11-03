extends "res://tests/objective_encounter_tests.gd"
func simulation_prepare(config: EncounterConfiguration) -> CombatEncounter:
 var encounter := SCENE.instantiate() as CombatEncounter
 encounter.configuration=config
 encounter.get_node("EnemyController").presentation_delay=0
 root.add_child(encounter)
 for frame in range(1600):
  if not encounter.preparing: return encounter
  await process_frame
 check(false,"Simulation navigation timeout");return encounter
func run() -> void:
 for count in [2,3,4]:
  for seed_value in [17,37]:
   var state := CampaignState.new(seed_value)
   # Private stage-two fixture: same public definitions and opening opponents for every squad size.
   state.command_tier=2
   var party := PackedStringArray(state.living_ids().slice(0,count))
   var config := state.configuration_for(state.offers[0],party)
   config.battlefield_seed=seed_value
   var start := Time.get_ticks_msec()
   var encounter := await simulation_prepare(config)
   check(encounter.navigation_ready,"Squad simulation navigation ready")
   var combat: CombatController=encounter.get_node("CombatController")
   var enemy: EnemyController=encounter.get_node("EnemyController")
   enemy.enabled=true;enemy.presentation_delay=0
   var last_serial := -1
   var turns := 0
   for frame in range(24000):
    if combat.state in [CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW]: break
    if combat.state==CombatController.State.AWAITING_COMMAND and combat.turn_serial!=last_serial:
     var actor := combat.scheduler.active_unit()
     if actor.faction==CombatUnit.Faction.HERO:
      last_serial=combat.turn_serial;turns+=1
      await hero_turn(combat,actor)
    await process_frame
   check(combat.state in [CombatController.State.VICTORY,CombatController.State.DEFEAT,CombatController.State.DRAW],"Squad simulation completes without stall")
   outcomes.append({"heroes":count,"seed":seed_value,"round":combat.scheduler.round_number,"hero_turns":turns,"result":CombatController.State.keys()[combat.state],"seconds":(Time.get_ticks_msec()-start)/1000.0})
   print("SQUAD SIMULATION ",outcomes[-1])
   check(enemy.stage==EnemyController.Stage.IDLE,"Result cancels larger-squad AI")
   await dispose(encounter)
 check(RegressionReport.write_json("headquarters/encounters.json",outcomes),"Squad measurements written")
 print("HEADQUARTERS SIMULATION RESULT: %d failures"%failures);quit(1 if failures else 0)
