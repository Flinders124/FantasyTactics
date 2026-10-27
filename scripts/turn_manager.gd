class_name TurnManager
extends Node

signal round_completed(round_number: int)
signal turn_changed(unit: CombatUnit, round_number: int)
var order: Array[CombatUnit] = []
var halted: bool = false
var round_number: int = 0
var cursor: int = -1

func configure(units: Array[CombatUnit]) -> void:
	halted=false
	order.assign(units)
	order.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		if a.definition.initiative == b.definition.initiative:
			return a.stable_id < b.stable_id
		return a.definition.initiative > b.definition.initiative)
	round_number = 1
	cursor = -1

func active_unit() -> CombatUnit:
	return order[cursor] if cursor >= 0 and cursor < order.size() else null

func advance() -> CombatUnit:
	if halted: return null
	if not order.any(func(unit: CombatUnit) -> bool: return unit.is_alive()):
		return null
	for step in range(order.size()):
		cursor += 1
		if cursor >= order.size():
			cursor = 0
			round_completed.emit(round_number)
			if halted: return null
			round_number += 1
		var unit := order[cursor]
		if unit.is_alive():
			turn_changed.emit(unit, round_number)
			return unit
	return null
