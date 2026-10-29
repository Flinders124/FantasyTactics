extends "res://tests/campaign_flow_tests.gd"
func run() -> void:
 flow=load("res://scenes/main.tscn").instantiate()
 root.add_child(flow)
 flow.campaign.store.path="user://roster-flow-%d/active.json" % OS.get_process_id()
 flow.campaign.seed_text="423"
 flow.campaign.begin()
 await settle()
 var state: CampaignState=flow.campaign.state
 var ids := state.living_ids()
 check(ids.size()==4 and state.blueprint_id(ids[0])=="recruit","UI new campaign starts individual recruits")
 var funds := state.supplies
 flow.request_transition("campaign_recruit")
 await settle()
 check(state.living_ids().size()==5 and state.supplies==funds-int(state.roster_rules.recruit_cost),"Recruit command buys a distinct companion")
 check(flow.campaign.store.read_file(flow.campaign.store.path).state!=null,"Recruit purchase autosaves")
 state.supplies=300
 flow.campaign.persist("headquarters")
 for index in range(2):
  check(flow.campaign.mutate("train_recruit",[ids[index]])==true,"Training persisted")
  var class_id := "aegisbearer" if index==0 else "chainbinder"
  check(flow.campaign.mutate("specialise",[ids[index],class_id])==true,"Approved class persisted")
 flow.campaign.headquarters()
 flow.menu.open_camp_page(2)
 await settle()
 check(state.blueprint_id(ids[0])=="aegisbearer" and state.blueprint_id(ids[1])=="chainbinder","Training UI retains permanent class choices")
 var expected := state.preview_definition(ids[0])
 flow.campaign.selected=PackedStringArray([ids[0],ids[1]])
 flow.campaign.prepare(state.offers[0].id)
 flow.campaign.deploy()
 await wait_ready()
 var combat := flow.combat.get_node("CombatController") as CombatController
 flow.combat.get_node("EnemyController").enabled=false
 check(combat.survival_enabled and combat.find_unit("hero-01").campaign_id==ids[0],"Deployment maps people to fresh units")
 check(combat.find_unit("hero-01").definition.maximum_health==expected.maximum_health,"Preview agrees with deployed stats")
 var decoded: CampaignSaveCodec.Decoded = flow.campaign.store.read_file(flow.campaign.store.path)
 check(decoded.state!=null and decoded.phase=="in_progress","Deployment checkpoint valid")
 var signature := flow.combat.configuration.layout.geometry_signature()
 check(flow.campaign.load_campaign(decoded),"Interrupted modern deployment reloads")
 await wait_ready()
 combat=flow.combat.get_node("CombatController")
 flow.combat.get_node("EnemyController").enabled=false
 check(flow.combat.configuration.layout.geometry_signature()==signature,"Interrupted deployment reproduces layout")
 check(combat.find_unit("hero-01").health==expected.maximum_health,"Reload applies stats exactly once")
 combat._damage_in_progress=true
 for unit in combat.units:
  if unit.faction==CombatUnit.Faction.ENEMY: combat._deal_damage(unit,999)
 combat._damage_in_progress=false
 combat._check_outcome(true)
 await settle()
 check(state.resolutions==0 and flow.campaign.state.resolutions==1,"Loaded state isolated and authoritative result applied once")
 flow.campaign.show_debrief()
 await settle()
 check(flow.screen=="campaign_debrief" and flow.campaign.store.read_file(flow.campaign.store.path).state!=null,"Modern debrief saves")
 flow.campaign.headquarters()
 await settle()
 check(get_nodes_in_group("headquarters_camps").size()==1,"Exactly one headquarters after return")
 flow.campaign.store.discard()
 flow.campaign.state=null
 flow.show_title()
 flow.queue_free()
 await settle()
 print("ROSTER FLOW RESULT: %d failures" % failures)
 quit(1 if failures else 0)
