extends SceneTree
var failures:int=0
var measurements:Array=[]
const IDS:PackedStringArray=["knight","ranger","mage","cleric","raider","sentinel","ashfang_raider","ashfang_shieldguard","ashfang_bowhunter","ashfang_shaman","ashfang_chieftain","hollow_gravebound","hollow_archer","hollow_adept","hollow_warden","hollow_castellan","verdant_thornblade","verdant_stalker","verdant_tender","verdant_sentinel","verdant_grovekeeper"]
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
func sample(v,clip,time):
 v.reset_pose();v.play_clip(clip,true);v.player.play(v._clips[clip],0);v.player.advance(0);v.player.pause();v.player.seek(time,true)
 await process_frame;await process_frame
func min_y(v)->float:
 var result:float=INF
 var mesh=v.model.find_children("*","MeshInstance3D",true,false)[0]
 var matrices:Array[Transform3D]=[]
 for bind in mesh.skin.get_bind_count():
  var bone:int=mesh.skin.get_bind_bone(bind)
  if bone<0:bone=v.skeleton.find_bone(mesh.skin.get_bind_name(bind))
  matrices.append(v.skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
 for surface in mesh.mesh.get_surface_count():
  var a:Array=mesh.mesh.surface_get_arrays(surface)
  var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var bones:PackedInt32Array=a[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
  for i in vertices.size():
   var p:=Vector3.ZERO
   for k in 4:p+=(matrices[bones[i*4+k]]*vertices[i])*weights[i*4+k]
   result=minf(result,p.y)
 return result
func run():
 for id in IDS:
  var v=CharacterVisual.new();root.add_child(v);v.load_role(id)
  check(v.authored and v.skeleton.get_bone_count()==18,id+" uses the shared authored rig")
  var mesh=v.model.find_children("*","MeshInstance3D",true,false)[0]
  var triangles:=0;var blended:=0
  for surface in mesh.mesh.get_surface_count():
   var a:Array=mesh.mesh.surface_get_arrays(surface)
   triangles+=(a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX]!=null else a[Mesh.ARRAY_VERTEX].size())/3
   var weights:PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
   for i in range(0,weights.size(),4):
    check(absf(weights[i]+weights[i+1]+weights[i+2]+weights[i+3]-1)<.001,id+" weights are normalized")
    if weights[i]>.01 and weights[i+1]>.01:blended+=1
   check(mesh.get_active_material(surface) is ShaderMaterial,id+" shares Lantern materials")
  check(triangles<6000 and triangles>2000 and mesh.mesh.get_surface_count()<=8,id+" stays inside character mesh budget")
  check(blended>20,id+" has deforming joint weights")
  for clip in ["Idle","Walk","Run","Attack","Cast","Hit","Death"]:
   var anim:Animation=v.player.get_animation(v._clips[clip])
   for track in anim.get_track_count():check(anim.track_get_type(track)!=Animation.TYPE_METHOD,"Animation cannot execute combat events")
  check(v.player.get_animation(v._clips.Attack).length<.5,"Visual recovery remains short and interruptible")
  for t in [.025,.075,.125,.175,.225]:
   await sample(v,"Walk",t)
   var foot:Transform3D=v.skeleton.get_bone_global_pose(v.skeleton.find_bone("L_foot"))
   check(absf(foot.origin.y-.12)<.025,id+" stance foot stays grounded")
  if id=="mage" or id.ends_with("shaman") or id.ends_with("adept") or id.ends_with("tender") or id.ends_with("grovekeeper"):
   for clip in ["Idle","Walk","Cast"]:
    await sample(v,clip,.08)
    var right:Transform3D=v.skeleton.get_bone_global_pose(v.skeleton.find_bone("R_hand"));var left:Transform3D=v.skeleton.get_bone_global_pose(v.skeleton.find_bone("L_hand"))
    check((right*Vector3(0,.21,0)).distance_to(left.origin)<.02,id+" keeps the off-hand on the staff")
  var ground:float=INF
  for time in [.20,.40,.60,.85]:
   await sample(v,"Death",time)
   ground=minf(ground,min_y(v))
  measurements.append({"id":id,"triangles":triangles,"blended_vertices":blended,"death_min_y":ground})
  check(ground>-.08,id+" collapse avoids major floor penetration")
  v.free()
 var file=FileAccess.open("user://m3-character-measurements.json",FileAccess.WRITE);file.store_string(JSON.stringify(measurements,"\t"));file.close()
 print(JSON.stringify(measurements))
 print("AUTHORED CHARACTER RESULT: %d failures"%failures);quit(1 if failures else 0)
