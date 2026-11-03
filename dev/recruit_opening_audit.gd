extends "res://tests/campaign_flow_tests.gd"
# Diagnostic bot uses the real command/AI planner; win rate is not human balance proof.
func run() -> void:
 flow=load("res://scenes/main.tscn").instantiate()
 root.add_child(flow)
 var report: Array[Dictionary]=[]
 var variant := "baseline"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--variant="): variant=argument.trim_prefix("--variant=")
 for difficulty in ["easy","standard","hard"]:
  for seed_number in [7,17,423]:
   var state := CampaignState.new(seed_number,difficulty)
   flow.campaign.state=state
   var chosen: Dictionary=state.offers[0]
   var party := PackedStringArray(state.living_ids().slice(0,2))
   var config := state.commit(chosen.id,party)
   if variant!="baseline":
    config.resolved_enemy_ids=PackedStringArray(["ashfang_raider","ashfang_raider"] if variant=="two-melee" else ["ashfang_raider","ashfang_bowhunter"])
    config.enemies.clear()
    for id in config.resolved_enemy_ids: config.enemies.append(EnemyCatalog.find(id).duplicate(true) as UnitDefinition)
   var roster := Array(config.resolved_enemy_ids)
   flow.campaign.selected=party
   flow.start_configuration(config)
   await wait_ready()
   var combat: CombatController=flow.combat.get_node("CombatController")
   flow.combat.get_node("EnemyController").presentation_delay=0
   combat.motor.movement_speed=80
   combat.attack_resolution_seconds=.05
   var serial := -1
   for frame in range(40000):
    if combat.encounter_has_ended(): break
    var actor := combat.scheduler.active_unit()
    if combat.state==CombatController.State.AWAITING_COMMAND and actor!=null and actor.faction==CombatUnit.Faction.HERO and serial!=combat.turn_serial:
     serial=combat.turn_serial
     await hero_turn(combat,actor)
    await process_frame
   check(combat.encounter_has_ended(),"Opening encounter completes")
   var people: Array[Dictionary]=[]
   for id in party:
    people.append({"id":id,"dead":state.heroes[id].dead,"xp":state.heroes[id].experience,"level":state.heroes[id].level})
   report.append({"difficulty":difficulty,"campaign_seed":seed_number,"mission_seed":chosen.seed,"roster":roster,"outcome":CombatController.State.keys()[combat.state],"rounds":combat.scheduler.round_number,"heroes":people})
   print("RECRUIT OPENING ",JSON.stringify(report[-1]))
   flow.campaign.show_debrief()
   await settle()
   flow.campaign.state=null
   flow.show_title()
   await settle()
 check(RegressionReport.write_json("recruit-openings.json",report),"Opening report written")
 flow.queue_free()
 await settle()
 print("RECRUIT OPENING RESULT: %d failures"%failures)
 quit(1 if failures else 0)
