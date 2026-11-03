extends SceneTree
var failures: int=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok: failures+=1; push_error(message)
func run() -> void:
 for role in ["recruit","aegisbearer","chainbinder"]:
  var visual := CharacterVisual.new()
  root.add_child(visual)
  visual.load_role(role)
  visual.player.advance(.1)
  visual.set_survival_pose("DOWNED")
  for frame in range(3): await process_frame
  var head := visual.skeleton.find_bone("head")
  var height := visual.skeleton.get_bone_global_pose(head).origin.y
  print("HELD POSE ",role," head_y=",height)
  check(height<.9,role+" downed mesh must actually lie down, not hold an idle blend")
  visual.set_survival_pose("ACTIVE")
  visual.player.advance(.1)
  for frame in range(12): await process_frame
  check(visual.skeleton.get_bone_global_pose(head).origin.y>1.2,role+" revival restores standing pose")
  visual.free()
 print("SURVIVAL POSE RESULT: %d failures" % failures)
 quit(1 if failures else 0)
