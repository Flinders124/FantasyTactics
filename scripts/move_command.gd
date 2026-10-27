class_name MoveCommand
extends CombatCommand

var destination: Vector3

func _init(id: String, target: Vector3) -> void:
	actor_id = id
	destination = target
