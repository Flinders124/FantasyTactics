extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func run() -> void:
 for id in ["recruit", "aegisbearer", "chainbinder"]:
  var visual := CharacterVisual.new()
  root.add_child(visual)
  visual.load_role(id)
  check(visual.authored, id + " loads its dedicated original model")
  check(visual.skeleton.get_bone_count() == 18, id + " preserves shared rig")
  check(CharacterVisual.ROLES.has(id), id + " is permitted by actor presentation")
  var meshes := visual.model.find_children("*", "MeshInstance3D", true, false)
  check(meshes.size() == 1, id + " has a single skinned body/equipment mesh")
  check(meshes[0].mesh is ArrayMesh, id + " uses authored indexed geometry")
  for clip in ["Idle", "Walk", "Run", "Attack", "Cast", "Hit", "Death"]:
   check(visual._clips.has(clip), id + " includes " + clip)
   var animation: Animation = visual.player.get_animation(visual._clips[clip])
   for track in animation.get_track_count():
    check(animation.track_get_type(track) != Animation.TYPE_METHOD, "Presentation cannot call combat events")
  visual.set_survival_pose("DOWNED")
  check(visual._dead and visual.current_clip == "Death", "Downed holds a resting pose")
  visual.set_survival_pose("STABILISED")
  check(visual._dead and not visual.player.is_playing(), "Stabilised holds the resting pose")
  visual.set_survival_pose("ACTIVE", true)
  check(not visual._dead and visual._carrying and visual.current_clip == "Idle", "Revival resets death and accepts carrier brace")
  visual.set_survival_pose("ACTIVE", false)
  check(not visual._carrying, "Drop clears carrier presentation")
  visual.free()
 print("ROSTER CHARACTER RESULT: %d failures" % failures)
 quit(1 if failures else 0)
