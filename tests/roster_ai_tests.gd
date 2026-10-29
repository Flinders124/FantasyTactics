extends "res://tests/roster_combat_tests.gd"
func run() -> void:
 encounter=load("res://scenes/combat_encounter.tscn").instantiate()
 encounter.get_node("EnemyController").enabled=false
 root.add_child(encounter)
 for frame in range(600):
  await physics_frame
  if encounter.navigation_ready: break
 combat=encounter.get_node("CombatController")
 hero=combat.find_unit("hero-01")
 ally=combat.find_unit("hero-02")
 enemy=combat.find_unit("enemy-01")
 combat.survival_enabled=true
 combat.objectives.survival_enabled=true
 await reset()
 hero.definition.abilities=[load("res://definitions/towline.tres")]
 ally.global_position=hero.global_position+Vector3(3,0,0)
 combat._deal_damage(ally,999)
 await physics_frame
 var planner := EnemyTactics.new()
 planner.begin(combat,hero,false,true)
 check(planner.best.action!=null and planner.best.action.ability_id=="towline","AI considers useful legal rescue pull")
 var warning := (load("res://definitions/fireburst.tres") as AbilityDefinition).duplicate(true) as AbilityDefinition
 warning.stable_id="fixture_warning"
 warning.telegraphed=true
 enemy.definition=enemy.definition.duplicate(true)
 enemy.definition.abilities=[warning]
 var endpoint := combat.displacement_endpoint(hero,ally,hero.global_position,2)
 check(endpoint.is_finite(),"Tow endpoint fixture is legal")
 combat.pending_telegraphs[enemy.stable_id]={"ability_id":warning.stable_id,"point":endpoint,"prepared_turn":0}
 planner=EnemyTactics.new()
 planner.begin(combat,hero,false,true)
 check(planner.best.action==null,"AI refuses to haul an ally into a hostile warning")
 check(planner.action_queries<=1600 and planner.path_queries<=96,"Support decision remains bounded")
 await reset()
 hero.definition.abilities=[load("res://definitions/aegis.tres")]
 ally.global_position=hero.global_position+Vector3(1.4,0,0)
 enemy.global_position=ally.global_position+Vector3(1.5,0,0)
 await physics_frame
 await physics_frame
 planner=EnemyTactics.new()
 planner.begin(combat,hero,false,true)
 check(planner.best.action!=null and planner.best.action.ability_id=="aegis" and planner.best.action.target_id==ally.stable_id,"AI wards a threatened ally when no basic hit is legal")
 ally.apply_ward(3)
 planner=EnemyTactics.new()
 planner.begin(combat,hero,false,true)
 check(planner.best.action==null,"AI does not waste an action refreshing a full fresh ward")
 encounter.shutdown()
 encounter.queue_free()
 await process_frame
 await physics_frame
 print("ROSTER AI RESULT: %d failures" % failures)
 quit(1 if failures else 0)
