extends SceneTree
var failures: int=0
func check(value: bool,message: String) -> void:
 if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 ControlBindings.ensure()
 var old := InputMap.action_get_events("tactics_cancel")
 InputMap.action_erase_events("tactics_cancel")
 var key := InputEventKey.new(); key.physical_keycode=KEY_B
 InputMap.action_add_event("tactics_cancel",key)
 check(ControlBindings.instructions("Escape cancels. Esc cancels.").count("B")==2,"Both cancel hints use actual binding")
 check("carried" in FieldGuide.objective(EncounterOptions.objectives()[2]).to_lower(),"Extraction teaches carried companions")
 check("downed" in FieldGuide.tips().to_lower() and "reviv" in FieldGuide.tips().to_lower(),"Mend guidance explains downed revival")
 InputMap.action_erase_events("tactics_cancel")
 for event in old: InputMap.action_add_event("tactics_cancel",event)
 print("ONBOARDING HELP RESULT: %d failures"%failures)
 quit(1 if failures else 0)
