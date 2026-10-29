extends SceneTree
func _initialize() -> void:
 var failures := 0
 var controller := CombatController.new()
 for method in ["evaluate_rescue", "abandon_encounter"]:
  if not controller.has_method(method):
   push_error("Missing authoritative contract: " + method)
   failures += 1
 controller.free()
 print("ROSTER CONTRACT RESULT: %d failures" % failures)
 quit(1 if failures else 0)
