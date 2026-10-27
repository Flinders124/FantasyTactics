class_name ReadableActionButton
extends Button
# The in-canvas tooltip owns placement and focus feedback; avoid a duplicate OS popup.
func _get_tooltip(_at_position: Vector2) -> String:
	return ""
