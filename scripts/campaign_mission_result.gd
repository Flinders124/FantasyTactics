class_name CampaignMissionResult
extends RefCounted
## Value boundary: no encounter Nodes/Resources are retained or returned.
var _record: Dictionary
func _init(data: Dictionary={}) -> void:
	_record=data.duplicate(true)
	_freeze(_record)
func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for child: Variant in value.values(): _freeze(child)
		value.make_read_only()
	elif value is Array:
		for child: Variant in value: _freeze(child)
		value.make_read_only()
func snapshot() -> Dictionary:
	return _record.duplicate(true)
static func capture(mission_id: String,hero_ids: PackedStringArray,combat: Node,abandoned: bool=false) -> RefCounted:
	var heroes: Dictionary={}
	for index in range(hero_ids.size()):
		var unit: CombatUnit=combat.find_unit("hero-%02d"%(index+1))
		heroes[hero_ids[index]]={"health":unit.health,"maximum_health":unit.definition.maximum_health}
	var outcome := "failure" if abandoned else ("victory" if combat.state==CombatController.State.VICTORY else "failure")
	return load("res://scripts/campaign_mission_result.gd").new({"version":1,"mission_id":mission_id,"outcome":outcome,"abandoned":abandoned,"reason":"Mission abandoned" if abandoned else combat.outcome_reason,"heroes":heroes,"rounds":combat.completed_rounds,"tactical_result":"abandoned" if abandoned else CombatController.State.keys()[combat.state]})
