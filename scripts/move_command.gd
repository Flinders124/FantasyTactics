class_name MoveCommand
extends CombatCommand

var destination: Vector3
# Explicit player convenience; AI commands keep strict endpoint/budget semantics.
var allow_partial: bool=false

func _init(id: String, target: Vector3) -> void:
	actor_id = id
	destination = target
