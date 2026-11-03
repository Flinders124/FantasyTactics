extends SceneTree
var failures: int=0
func check(ok: bool,message: String) -> void:
 if not ok:failures+=1;push_error(message)
func _initialize() -> void:
 if OS.get_environment("OATH_TEST_ISOLATED")!="1":push_error("Use isolated user data.");quit(1);return
 call_deferred("run")
func action_wait(combat: CombatController) -> void:
 for frame in range(1200):
  if combat.state!=CombatController.State.RESOLVING_ACTION:return
  await physics_frame
 check(false,"Pack movement did not complete")
func ready_hero(combat: CombatController) -> CombatUnit:
 for frame in range(120):
  if combat.state==CombatController.State.AWAITING_COMMAND:
   var active := combat.scheduler.active_unit()
   if active.stable_id=="hero-01":return active
   combat.submit_command(EndTurnCommand.new(active.stable_id))
  await process_frame
 check(false,"Pack cannot reach hero turn");return null
func run() -> void:
 var state := CampaignState.new(37)
 var party := PackedStringArray(state.living_ids().slice(0,2))
 check(state.commit(state.offers[0].id,party)!=null,"Pack campaign commits")
 var store := CampaignSaveStore.new();store.path="user://tactical-pack/active.json"
 check(store.write(state,"in_progress"),"Pack campaign checkpoint saves")
 var saved := store.read_file(store.path)
 check(saved.state!=null,"Pack campaign checkpoint loads")
 var resumed := CampaignSaveCodec.resume(saved.state)
 check(resumed!=null and resumed.generator_settings.generator_version==3 and not resumed.optional_goal_id.is_empty(),"Interrupted mission retains architecture and frozen goal")
 var data: Dictionary={"version":3,"mission_id":state.active.id,"outcome":"victory","abandoned":false,"reason":"Pack reward fixture","heroes":{},"rounds":2,"tactical_result":"VICTORY","optional":{"id":resumed.optional_goal_id,"completed":true,"reward":OptionalGoals.find(resumed.optional_goal_id).supplies}}
 for id: String in party:data.heroes[id]={"health":20,"maximum_health":20,"survival":"recovered","death_cause":""}
 check(state.resolve(CampaignMissionResult.new(data)) and not state.resolve(CampaignMissionResult.new(data)),"Pack bonus result processes once")
 check(store.write(state,"debrief") and store.read_file(store.path).state!=null,"Pack bonus debrief persists")
 var config := EncounterConfiguration.new();config.generator_settings.generator_version=3;config.optional_goal_id="cache";config.battlefield_seed=37
 check(EncounterCode.decode(EncounterCode.encode(config)).configuration!=null,"Pack code reconstructs new definitions")
 var encounter := load("res://scenes/combat_encounter.tscn").instantiate() as CombatEncounter;encounter.configuration=config;encounter.get_node("EnemyController").enabled=false;root.add_child(encounter)
 for frame in range(1600):
  if not encounter.preparing:break
  await process_frame
 check(encounter.navigation_ready,"Pack new geometry navigation ready")
 check(encounter.get_node("OptionalGoalMarker").label.text.contains("BONUS CHALLENGE"),"Pack skirmish marker promises no currency")
 var combat: CombatController=encounter.get_node("CombatController");var motor: MovementMotor=encounter.get_node("MovementMotor");motor.movement_speed=12
 var actor := await ready_hero(combat)
 var plan := combat.plan_player_move(actor,Vector3.ZERO)
 check(plan.valid() and plan.limited,"Pack full route clips to movement budget")
 var command := MoveCommand.new(actor.stable_id,Vector3.ZERO);command.allow_partial=true
 check(combat.submit_player_command(command),"Pack accepts clipped move")
 check(not combat.submit_player_command(command),"Pack repeated movement input cannot queue")
 await action_wait(combat)
 check(actor.global_position.distance_to(plan.route.path[-1])<.02,"Pack executed endpoint matches preview")
 for attempt in range(3):
  if combat.optional_goals.collected:break
  combat.submit_command(EndTurnCommand.new(actor.stable_id));actor=await ready_hero(combat)
  command=MoveCommand.new(actor.stable_id,combat.optional_goals.point);command.allow_partial=true
  check(combat.submit_player_command(command),"Pack approaches cache through existing move command")
  await action_wait(combat)
 check(combat.optional_goals.collected and not combat.optional_goals.finished and combat.optional_goals.report().reward==0,"Cache collects only after travel and pays nothing before victory")
 encounter.shutdown();encounter.queue_free()
 for frame in range(20):await process_frame
 print("TACTICAL PACK RESULT: %d failures"%failures);quit(1 if failures else 0)
