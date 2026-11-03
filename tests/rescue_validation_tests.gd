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
 combat.retreat_center=hero.global_position
 await reset()
 var health := enemy.health
 var funds := hero.action_available
 check(not combat.submit_command(RescueCommand.new(hero.stable_id,enemy.stable_id,0)),"Hostile rescue rejected")
 check(not combat.submit_command(RescueCommand.new(hero.stable_id,ally.stable_id,0)),"Conscious rescue rejected")
 check(hero.action_available==funds and enemy.health==health,"Rejected rescue spends nothing")
 enemy.global_position=hero.global_position+Vector3(3,0,0)
 var wall := StaticBody3D.new()
 wall.collision_layer=9
 wall.position=hero.global_position+Vector3(1.5,.9,0)
 var collider := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 shape.size=Vector3(.2,1.8,1.3)
 collider.shape=shape
 wall.add_child(collider)
 encounter.add_child(wall)
 await physics_frame
 await physics_frame
 check(not combat.evaluate_ability(hero,enemy,"reel_in").valid(),"Wall blocks Reel preview")
 check(not combat.submit_player_command(UseAbilityCommand.new(hero.stable_id,enemy.stable_id,"reel_in")),"Wall blocks Reel commit")
 check(hero.action_available and hero.cooldown_remaining("reel_in")==0 and enemy.health==health,"Blocked pull costs no action/cooldown/health")
 ally.global_position=enemy.global_position
 combat._deal_damage(ally,999)
 check(not combat.evaluate_ability(hero,ally,"towline").valid(),"Wall blocks friendly Tow")
 wall.queue_free()
 await physics_frame
 await physics_frame
 await reset()
 ally.global_position=hero.global_position+Vector3(1.1,0,0)
 combat._deal_damage(ally,999)
 check(combat.submit_player_command(RescueCommand.new(hero.stable_id,ally.stable_id,1)),"Pickup fixture accepted")
 await reset()
 check(hero.carried_unit==null and ally.carried_by==null and ally.visible and ally.collision_layer==5,"Restart clears carry references, presentation and collision")
 combat.objectives.definition=EncounterOptions.objectives()[2].duplicate(true)
 combat.objectives.center=hero.global_position+Vector3.LEFT*3
 ally.global_position=hero.global_position+Vector3(1.1,0,0)
 combat._deal_damage(ally,999)
 check(combat.submit_player_command(RescueCommand.new(hero.stable_id,ally.stable_id,1)),"Extraction pickup accepted")
 hero.begin_turn()
 hero.global_position=combat.objectives.center
 check(combat.submit_player_command(RescueCommand.new(hero.stable_id,hero.stable_id,3)),"Extraction with carried companion commits")
 check(combat.state==CombatController.State.VICTORY and ally.survival_outcome=="extracted","Both original people extracted alive gives objective victory")
 await reset()
 combat.objectives.center=hero.global_position
 ally.global_position=hero.global_position+Vector3(1.1,0,0)
 combat._deal_damage(ally,999)
 check(combat.submit_player_command(RescueCommand.new(hero.stable_id,ally.stable_id,1)),"Pickup inside exit completes objective")
 check(combat.state==CombatController.State.VICTORY and ally.survival_outcome=="extracted","Automatic exit success preserves carried companion")
 combat.objectives.definition=EncounterOptions.objectives()[0].duplicate(true)
 await reset()
 combat._damage_in_progress=true
 for unit in combat.units: combat._deal_damage(unit,999)
 combat._damage_in_progress=false
 combat._check_outcome(true)
 check(combat.state==CombatController.State.DRAW and hero.survival_outcome=="dead" and ally.survival_outcome=="dead","Atomic simultaneous elimination gives one draw and explicit unrescued deaths")
 encounter.shutdown()
 encounter.queue_free()
 await process_frame
 await physics_frame
 print("RESCUE VALIDATION RESULT: %d failures" % failures)
 quit(1 if failures else 0)
