extends SceneTree
const IDS:PackedStringArray=["ashfang_raider","ashfang_shieldguard","ashfang_bowhunter","ashfang_shaman","ashfang_chieftain","hollow_gravebound","hollow_archer","hollow_adept","hollow_warden","hollow_castellan","verdant_thornblade","verdant_stalker","verdant_tender","verdant_sentinel","verdant_grovekeeper"]
var failures:int=0
func _initialize():call_deferred("run")
func verify(value:bool,message:String):
 if not value:failures+=1;push_error(message)
func run():
 for id in IDS:
  var visual=CharacterVisual.new();root.add_child(visual);visual.load_role(id)
  verify(visual.role==id and visual.authored,id+" loads its dedicated exported asset")
  verify(visual.model.get_meta("authored_character","")==id,id+" keeps its identity")
  var meshes=visual.model.find_children("*","MeshInstance3D",true,false)
  verify(meshes.size()==1,id+" uses one skinned model instead of rigid runtime body parts")
  for mesh in meshes:verify(mesh.visible and mesh.skin!=null,id+" body and equipment are skinned")
  verify(visual.scale==Vector3.ONE and visual.model.scale==Vector3.ONE,"Gameplay scale is unchanged")
  for clip in ["Idle","Walk","Run","Attack","Cast","Hit","Death"]:verify(visual._clips.has(clip),id+" retains "+clip)
  visual.play_clip("Death",true);visual.player.play(visual._clips.Death,0);visual.player.advance(0);visual.player.pause();visual.player.seek(.6,true)
  await process_frame;await process_frame
  verify(not visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hips")).basis.is_equal_approx(Basis.IDENTITY),id+" has a skeletal collapse")
  visual.reset_pose();verify(not visual._dead and visual.current_clip=="Idle",id+" can reset from death")
  visual.free()
 print("FACTION VISUAL RESULT: %d failures"%failures);quit(1 if failures else 0)
