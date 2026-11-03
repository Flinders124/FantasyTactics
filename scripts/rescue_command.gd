class_name RescueCommand
extends CombatCommand

enum Kind { STABILISE, PICKUP, DROP, EXTRACT }
var target_id: String
var kind: Kind
func _init(actor: String = "", target: String = "", action: Kind = Kind.STABILISE) -> void:
 actor_id = actor
 target_id = target
 kind = action
