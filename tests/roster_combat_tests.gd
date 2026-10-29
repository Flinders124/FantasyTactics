extends SceneTree
var failures: int=0
var encounter: CombatEncounter
var combat: CombatController
var hero: CombatUnit
var ally: CombatUnit
var enemy: CombatUnit
func check(ok: bool,message: String) -> void:
 if not ok:
  failures+=1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
 for frame in range(100):
  await physics_frame
  if combat.state!=CombatController.State.RESOLVING_ACTION: return
 check(false,"Action failed to complete")
func reset() -> void:
 await combat.restart_encounter()
 hero.survival_enabled=true
 ally.survival_enabled=true
 hero.definition=hero.definition.duplicate(true)
 hero.definition.abilities=[load("res://definitions/aegis.tres"),load("res://definitions/reel_in.tres"),load("res://definitions/towline.tres"),load("res://definitions/mend.tres")]
 await physics_frame
func run() -> void:
 encounter=load("res://scenes/combat_encounter.tscn").instantiate()
 encounter.get_node("EnemyController").enabled=false
 root.add_child(encounter)
 for frame in range(600):
  await physics_frame
  if encounter.navigation_ready: break
 check(encounter.navigation_ready,"Navigation ready")
 combat=encounter.get_node("CombatController")
 hero=combat.find_unit("hero-01")
 ally=combat.find_unit("hero-02")
 enemy=combat.find_unit("enemy-01")
 combat.survival_enabled=true
 combat.objectives.survival_enabled=true
 combat.retreat_center=hero.global_position
 await reset()
 ally.global_position=hero.global_position+Vector3(1.4,0,0)
 await physics_frame
 check(combat.evaluate_ability(hero,ally,"aegis").valid(),"Ward valid for ally")
 check(combat.submit_player_command(UseAbilityCommand.new(hero.stable_id,ally.stable_id,"aegis")),"Ward commits")
 check(ally.ward_remaining==3 and not hero.action_available,"Ward action spent once")
 check(not combat.submit_player_command(UseAbilityCommand.new(hero.stable_id,ally.stable_id,"aegis")),"Repeated ability cannot duplicate ward")
 var hp := ally.health
 combat._deal_damage(ally,5)
 check(ally.health==hp-2 and ally.ward_remaining==0,"Ward absorbs before authoritative health damage")
 await settle()
 await reset()
 ally.global_position=hero.global_position+Vector3(1.4,0,0)
 combat._deal_damage(ally,999)
 check(ally.is_downed() and not ally.is_alive() and ally.collision_layer==4,"Downed selectable but nonblocking")
 check(not combat.submit_player_command(AttackCommand.new(hero.stable_id,ally.stable_id)),"Downed friendly cannot be attacked")
 check(combat.submit_player_command(RescueCommand.new(hero.stable_id,ally.stable_id,RescueCommand.Kind.STABILISE)),"Universal stabilise accepted")
 check(ally.life_state==CombatUnit.LifeState.STABILISED and not hero.action_available,"Stabilise spends shared action")
 check(not combat.submit_player_command(RescueCommand.new(hero.stable_id,ally.stable_id,RescueCommand.Kind.PICKUP)),"Cannot rescue twice in turn")
 hero.begin_turn()
 hero.movement_remaining=5
 check(combat.submit_player_command(RescueCommand.new(hero.stable_id,ally.stable_id,RescueCommand.Kind.PICKUP)),"Carry accepted")
 check(hero.carried_unit==ally and hero.movement_remaining<=3 and ally.collision_layer==0,"Carry reduces budget and disables body collision")
 hero.begin_turn()
 check(combat.submit_player_command(RescueCommand.new(hero.stable_id,hero.stable_id,RescueCommand.Kind.EXTRACT)),"Extract at retreat accepted")
 check(hero.life_state==CombatUnit.LifeState.EXTRACTED and ally.life_state==CombatUnit.LifeState.EXTRACTED,"Carrier and companion extract together")
 check(combat.state==CombatController.State.DEFEAT,"Full retreat ends mission safely")
 check(hero.survival_outcome=="extracted" and ally.survival_outcome=="extracted","Extracted survivors preserved on failure")
 await reset()
 ally.global_position=hero.global_position+Vector3(3,0,0)
 combat._deal_damage(ally,999)
 await physics_frame
 check(combat.evaluate_ability(hero,ally,"towline").valid(),"Tow accepts downed ally")
 var before := ally.global_position
 check(combat.submit_player_command(UseAbilityCommand.new(hero.stable_id,ally.stable_id,"towline")),"Tow commits")
 check(ally.global_position.distance_to(before)>.1 and ally.health==0 and ally.is_downed(),"Tow moves without healing or damage")
 await settle()
 await reset()
 enemy.global_position=hero.global_position+Vector3(3,0,0)
 await physics_frame
 var old := enemy.global_position
 var health := enemy.health
 check(combat.evaluate_ability(hero,enemy,"reel_in").valid(),"Reel legal")
 check(combat.submit_player_command(UseAbilityCommand.new(hero.stable_id,enemy.stable_id,"reel_in")),"Reel commits")
 check(enemy.health==health-2 and enemy.global_position.distance_to(old)>.1,"Reel damages once and sweeps toward caster")
 check(not combat.submit_command(UseAbilityCommand.new(hero.stable_id,enemy.stable_id,"reel_in")),"Repeated reel rejected")
 await settle()
 await reset()
 combat._deal_damage(ally,999)
 ally.stabilise()
 combat._damage_in_progress=true
 for unit in combat.units:
  if unit.faction==CombatUnit.Faction.ENEMY: combat._deal_damage(unit,999)
 combat._damage_in_progress=false
 combat._check_outcome(true)
 check(combat.state==CombatController.State.VICTORY and ally.survival_outcome=="recovered","Victory recovers stabilised companion")
 await reset()
 combat.abandon_encounter()
 check(combat.state==CombatController.State.DEFEAT and hero.survival_outcome=="dead","Abandon finalises unrescued once")
 encounter.shutdown()
 encounter.queue_free()
 await process_frame
 await physics_frame
 print("Roster combat RESULT: %d failures" % failures)
 quit(1 if failures else 0)
