extends "res://tests/campaign_flow_tests.gd"
func run() -> void:
 flow=load("res://scenes/main.tscn").instantiate()
 root.add_child(flow)
 var state := CampaignState.new(17,"easy")
 flow.campaign.state=state
 var report: Array[Dictionary]=[]
 for attempt in range(8):
  if not state.ending.is_empty(): break
  while state.living_ids().size()<2:
   if state.recruit().is_empty(): break
  var party := PackedStringArray(state.living_ids().slice(0,2))
  check(party.size()==2,"Modern campaign retains deployment route")
  if party.size()!=2: break
  for index in range(2):
   var id: String=party[index]
   if attempt>0 and state.heroes[id].level==1 and state.can_spend(int(state.roster_rules.training_cost)): state.train_recruit(id)
   if state.heroes[id].level>=2 and state.blueprint_id(id)=="recruit": state.specialise(id,"knight" if index==0 else "ranger")
   var pending := state.pending_level(id)
   if state.blueprint_id(id)!="recruit" and pending>0:
    for upgrade in state.rules.upgrades:
     if upgrade.hero_id==state.blueprint_id(id) and upgrade.required_level==pending:
      state.learn(id,upgrade.stable_id)
      break
  var chosen: Dictionary=state.offers[0]
  for offer in state.offers:
   if offer.objective==0: chosen=offer; break
  flow.campaign.selected=party
  flow.start_configuration(state.commit(chosen.id,party))
  await wait_ready()
  var combat: CombatController=flow.combat.get_node("CombatController")
  flow.combat.get_node("EnemyController").presentation_delay=0
  combat.motor.movement_speed=80
  combat.attack_resolution_seconds=.05
  var serial := -1
  for frame in range(40000):
   if combat.encounter_has_ended(): break
   var active := combat.scheduler.active_unit()
   if combat.state==CombatController.State.AWAITING_COMMAND and active!=null and active.faction==CombatUnit.Faction.HERO and serial!=combat.turn_serial:
    serial=combat.turn_serial
    await hero_turn(combat,active)
   await process_frame
  check(combat.encounter_has_ended(),"Modern campaign battle completes")
  check(state.resolutions==attempt+1,"Exactly one consequence batch per real battle")
  report.append({"mission":chosen.id,"seed":chosen.seed,"party":Array(party),"outcome":CombatController.State.keys()[combat.state],"round":combat.scheduler.round_number,"living":Array(state.living_ids()),"victories":state.victories,"threat":state.threat})
  print("ROSTER CAMPAIGN PLAY ",JSON.stringify(report[-1]))
  flow.campaign.show_debrief()
  await settle()
  if state.ending.is_empty(): flow.campaign.headquarters(); await settle()
 check(not state.ending.is_empty(),"Modern campaign reaches a campaign ending")
 check(RegressionReport.write_json("roster-campaign-play.json",{"ending":state.ending,"missions":report,"snapshot":state.snapshot()}),"Modern campaign report written")
 flow.campaign.state=null
 flow.show_title()
 flow.queue_free()
 await settle()
 print("ROSTER CAMPAIGN PLAY RESULT: %d failures" % failures)
 quit(1 if failures else 0)
