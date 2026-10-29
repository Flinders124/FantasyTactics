class_name ObjectiveController
extends RefCounted
## Runtime progress only. CombatController alone commits a final result.
signal changed
signal round_checked(round_number: int, progress: int, control: String)
const INCLUSION_TOLERANCE: float = 0.000001
var definition: ObjectiveDefinition = ObjectiveDefinition.new()
var center: Vector3 = Vector3.ZERO
var radius: float = 2.8
var required_heroes: PackedStringArray = []
var survival_enabled: bool = false
var progress: int = 0
var last_checked_round: int = 0
var control: String = "Empty"
var heroes_inside: int = 0
var enemies_inside: int = 0

func configure(config: ObjectiveDefinition, layout: BattlefieldLayout = null) -> void:
	definition=config if config!=null else ObjectiveDefinition.new()
	center=layout.objective_center if layout!=null else Vector3.ZERO
	radius=definition.radius
	progress=0
	last_checked_round=0
	required_heroes.clear()
	control="Empty"
	heroes_inside=0
	enemies_inside=0
	changed.emit()

func reset(units: Array[CombatUnit]) -> void:
	progress=0
	last_checked_round=0
	required_heroes.clear()
	for unit in units:
		if unit.faction==CombatUnit.Faction.HERO: required_heroes.append(unit.stable_id)
	refresh(units)

func contains(point: Vector3) -> bool:
	return point.distance_to(center)<=radius+INCLUSION_TOLERANCE

func refresh(units: Array[CombatUnit]) -> void:
	heroes_inside=0
	enemies_inside=0
	for unit in units:
		var extracted_companion := survival_enabled and definition.kind==ObjectiveDefinition.Kind.EXTRACTION and unit.faction==CombatUnit.Faction.HERO and (unit.life_state==CombatUnit.LifeState.EXTRACTED or unit.carried_by!=null)
		var point := unit.carried_by.ground_anchor() if unit.carried_by!=null else unit.ground_anchor()
		if (not unit.is_alive() and not extracted_companion) or not contains(point): continue
		if unit.faction==CombatUnit.Faction.HERO: heroes_inside+=1
		else: enemies_inside+=1
	control="Contested" if heroes_inside>0 and enemies_inside>0 else ("Controlled" if heroes_inside>0 else ("Enemy held" if enemies_inside>0 else "Empty"))
	changed.emit()

func round_end(round_number: int, units: Array[CombatUnit]) -> void:
	if definition.kind!=ObjectiveDefinition.Kind.HOLD_GROUND or round_number<=last_checked_round: return
	last_checked_round=round_number
	refresh(units)
	progress=progress+1 if heroes_inside>0 and enemies_inside==0 else 0
	round_checked.emit(round_number,progress,control)
	changed.emit()

func proposed_outcome(units: Array[CombatUnit], completed_action: bool) -> Dictionary:
	refresh(units)
	if survival_enabled: return _survival_proposal(units,completed_action)
	var heroes := 0
	var enemies := 0
	var required_alive := 0
	for unit in units:
		if not unit.is_alive(): continue
		if unit.faction==CombatUnit.Faction.HERO:
			heroes+=1
			if required_heroes.has(unit.stable_id): required_alive+=1
		else: enemies+=1
	if definition.kind==ObjectiveDefinition.Kind.ELIMINATION:
		if heroes==0 and enemies==0: return {"result":"draw","reason":"Both factions were eliminated by the same action."}
		if heroes==0: return {"result":"defeat","reason":"Your heroes have fallen."}
		if enemies==0: return {"result":"victory","reason":"All enemies have been defeated."}
	elif definition.kind==ObjectiveDefinition.Kind.HOLD_GROUND:
		if heroes==0: return {"result":"defeat","reason":"No heroes remain to hold the courtyard."}
		if progress>=definition.required_rounds: return {"result":"victory","reason":"Ground held for %d consecutive rounds."%definition.required_rounds}
	else:
		if required_alive!=required_heroes.size() or required_heroes.size()!=2: return {"result":"defeat","reason":"A required companion was lost. Extraction is impossible."}
		if completed_action and heroes_inside==2: return {"result":"victory","reason":"Both companions reached the exit alive."}
	return {}

func summary() -> String:
	match definition.kind:
		ObjectiveDefinition.Kind.HOLD_GROUND: return "Hold Ground · %d / %d rounds · %s"%[progress,definition.required_rounds,control]
		ObjectiveDefinition.Kind.EXTRACTION: return "Extraction · Heroes at exit: %d / 2"%heroes_inside
	return "Elimination · Defeat all enemies"

func tactical_points() -> Array[Vector3]:
	if definition.kind==ObjectiveDefinition.Kind.ELIMINATION: return []
	var result: Array[Vector3]=[center]
	for index in range(8):
		var angle := TAU*float(index)/8
		result.append(center+Vector3(cos(angle),0,sin(angle))*radius*.65)
	return result

func position_value(point: Vector3) -> float:
	if definition.kind==ObjectiveDefinition.Kind.ELIMINATION: return 0
	var distance := maxf(0,point.distance_to(center)-radius*.65)
	return -minf(distance,40)*maxf(0,definition.positioning_weight)

func _survival_proposal(units: Array[CombatUnit], completed_action: bool) -> Dictionary:
	var conscious := 0
	var enemies := 0
	var extracted := 0
	var lost := 0
	var at_exit := 0
	for unit in units:
		if unit.faction==CombatUnit.Faction.ENEMY:
			if unit.is_alive(): enemies+=1
			continue
		if unit.is_alive(): conscious+=1
		if unit.life_state==CombatUnit.LifeState.DEAD: lost+=1
		if unit.life_state==CombatUnit.LifeState.EXTRACTED: extracted+=1
		var exit_anchor := unit.carried_by.ground_anchor() if unit.carried_by!=null else unit.ground_anchor()
		if unit.life_state==CombatUnit.LifeState.EXTRACTED or (contains(exit_anchor) and (unit.is_alive() or unit.carried_by!=null)): at_exit+=1
	if definition.kind==ObjectiveDefinition.Kind.EXTRACTION:
		if lost>0: return {"result":"defeat","reason":"A companion died. Extraction is impossible."}
		if completed_action and at_exit==required_heroes.size() and at_exit==2: return {"result":"victory","reason":"Both companions reached safety alive."}
	if conscious==0:
		if enemies==0 and extracted==0 and definition.kind==ObjectiveDefinition.Kind.ELIMINATION: return {"result":"draw","reason":"No conscious combatants remain. Stabilised companions are recovered."}
		return {"result":"defeat","reason":"The party withdrew or no conscious heroes remain. Only extracted companions survive."}
	if definition.kind==ObjectiveDefinition.Kind.ELIMINATION and enemies==0: return {"result":"victory","reason":"All enemies defeated. Conscious and stabilised companions are recovered."}
	if definition.kind==ObjectiveDefinition.Kind.HOLD_GROUND and progress>=definition.required_rounds: return {"result":"victory","reason":"Ground held for %d rounds." % definition.required_rounds}
	return {}
