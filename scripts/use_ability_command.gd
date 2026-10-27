class_name UseAbilityCommand
extends CombatCommand

var target_id: String
var ability_id: String
var ground_position: Vector3 = Vector3.ZERO
var has_ground_position: bool = false
var invalid_target_data: bool = false
# Optional stricter request constraint. Player Fireburst retains friendly fire.
var require_safe_area: bool = false

# Variant distinguishes absent data from a legitimate Vector3.ZERO target.
func _init(actor: String, target: String, ability: String, point: Variant = null) -> void:
	actor_id = actor
	target_id = target
	ability_id = ability
	if point != null:
		if point is Vector3:
			ground_position = point
			has_ground_position = true
		else:
			invalid_target_data = true

static func on_ground(actor: String, ability: String, point: Vector3) -> UseAbilityCommand:
	return UseAbilityCommand.new(actor, "", ability, point)

func target_data_error(ground_targeted: bool) -> String:
	if require_safe_area and not ground_targeted: return "Area safety requires a ground ability"
	if invalid_target_data or (has_ground_position and not target_id.is_empty()):
		return "Conflicting or invalid ability target data"
	if ground_targeted and (not has_ground_position or not target_id.is_empty()):
		return "Ability requires a ground position only"
	if not ground_targeted and (has_ground_position or target_id.is_empty()):
		return "Ability requires a unit target only"
	return ""
