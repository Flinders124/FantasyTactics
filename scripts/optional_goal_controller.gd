class_name OptionalGoalController
extends RefCounted
signal changed
var campaign_rewards: bool=false
var definition: OptionalGoalDefinition
var point: Vector3=Vector3.ZERO
var collected: bool=false
var failed: bool=false
var finished: bool=false
var completed: bool=false
func configure(id: String,rewards: bool=false) -> void:
 campaign_rewards=rewards;definition=OptionalGoals.find(id);reset()
func reset() -> void:
 collected=false;failed=false;finished=false;completed=false;changed.emit()
func observe(kind: String,unit: CombatUnit) -> void:
 if not finished and definition!=null and definition.rule=="together" and unit.faction==CombatUnit.Faction.HERO and kind in ["downed","death"]:failed=true
func sample(units: Array[CombatUnit],completed_action: bool) -> void:
 if finished or definition==null or definition.rule!="cache" or not completed_action or collected:return
 for unit in units:
  if unit.faction==CombatUnit.Faction.HERO and unit.is_alive() and unit.ground_anchor().distance_to(point)<=definition.radius+.000001:
   collected=true;changed.emit();return
func finish(result: String,units: Array[CombatUnit],round_number: int) -> void:
 if finished or definition==null:return
 if definition.rule=="together":
  for unit in units:
   if unit.faction==CombatUnit.Faction.HERO and not unit.is_alive() and unit.life_state!=CombatUnit.LifeState.EXTRACTED:failed=true
 completed=result=="victory" and (collected if definition.rule=="cache" else round_number<=definition.round_limit if definition.rule=="swift" else not failed)
 finished=true;changed.emit()
func report() -> Dictionary:
 return {} if definition==null else {"id":definition.stable_id,"completed":completed,"reward":definition.supplies if completed else 0}
func summary() -> String:
 if definition==null:return ""
 var progress := ("COMPLETE" if completed else "NOT COMPLETED") if finished else ("Collected — win to secure" if collected else "Reach blue cache") if definition.rule=="cache" else ("Win by round %d"%definition.round_limit if definition.rule=="swift" else "FAILED: incapacitation" if failed else "No incapacitations")
 return "Optional: %s · %s"%[definition.display_name,progress]+(" (+%d Supplies on victory)"%definition.supplies if campaign_rewards else "")
func place(layout: BattlefieldLayout,navigation: NavigationService) -> bool:
 if definition==null or definition.rule!="cache":return true
 var flip := -1.0 if layout.original_seed%2==0 else 1.0
 for candidate: Vector3 in [Vector3(-layout.arena_size.x*.07,0,flip*layout.arena_size.y*.18),Vector3(layout.arena_size.x*.07,0,-flip*layout.arena_size.y*.18),Vector3.ZERO,layout.objective_center]:
  if navigation.query_path(candidate,candidate).valid() and navigation.query_path(layout.spawns[0],candidate).valid():point=candidate;return true
 return false
