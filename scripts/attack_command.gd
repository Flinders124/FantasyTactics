class_name AttackCommand
extends CombatCommand

var target_id: String

func _init(actor: String, target: String) -> void:
	actor_id = actor
	target_id = target
