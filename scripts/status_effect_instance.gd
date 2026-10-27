class_name StatusEffectInstance
extends RefCounted

var definition: StatusEffectDefinition
var future_turns: int = 0
var affecting_current_turn: bool = false

func _init(config: StatusEffectDefinition) -> void:
	definition = config
	future_turns = config.affected_turns

func label() -> String:
	return "%s: %d future turn(s)%s" % [definition.display_name, future_turns, " + current" if affecting_current_turn else ""]
