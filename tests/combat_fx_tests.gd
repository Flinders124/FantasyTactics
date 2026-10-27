extends SceneTree
var failures:int=0
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1280,720)
 var lab=load("res://dev/combat/showcase.tscn").instantiate();root.add_child(lab)
 while lab.busy:await process_frame
 for i in 12:
  await lab.prepare(i)
  var presentation=lab.encounter.get_node("CombatPresentation")
  await lab.play_action()
  check(lab.caption.text.contains("CONFIRMED"),"Real showcase command accepted: "+str(i))
  if lab.armed:
   check(lab.combat.pending_telegraphs.has(lab.actor.stable_id),"Warning remains until caster turn")
   await lab.play_action()
   check(int(presentation.presented_events.get("area",0))==1,"Warning resolves one blast")
 # Resolved ranged afterimage starts at the real bow, arrives on the hit frame.
 await lab.prepare(2)
 var ranged=lab.encounter.get_node("CombatPresentation")
 var ranged_before=lab.target.health
 check(lab.combat.submit_command(AttackCommand.new(lab.actor.stable_id,lab.target.stable_id)),"Bow fixture accepted")
 var tracer:Dictionary=ranged.tracers[0]
 check(tracer.from.distance_to(lab.actor.character.emission_point())<.001,"Projectile release uses animated bow grip")
 var transform:Transform3D=tracer.bead.global_transform
 ranged._process(.08)
 check(tracer.bead.global_transform==transform and lab.target.health==ranged_before-lab.actor.definition.basic_attack.damage,"Resolved arrow fades in place without a second arrival or damage event")
 # A crowned caster has a blade silhouette, but its basic ranged action is magic.
 await lab.prepare(8)
 var crowned=lab.encounter.get_node("CombatPresentation")
 check(lab.combat.submit_command(AttackCommand.new(lab.actor.stable_id,lab.target.stable_id)),"Hollow Castellan basic ranged attack accepted")
 check(lab.actor.character.current_clip=="Cast" and crowned.oath_fx.slots.any(func(slot:Dictionary)->bool:return slot.active and slot.kind=="grave"),"Crowned ranged caster uses cast pose and grave magic")
 check(crowned.pending_sounds.any(func(sound:Dictionary)->bool:return sound.id=="arcane") and not crowned.pending_sounds.any(func(sound:Dictionary)->bool:return sound.id.begins_with("bow_") or sound.id.begins_with("arrow_")),"Magic caster never plays physical bow or arrow audio")
 var tender=CharacterVisual.new();root.add_child(tender);tender.load_role("verdant_tender")
 check(tender.emission_point().distance_to(tender.weapon_landmark(Vector3(.48,2.08,-.065)))<.001,"Tender healing/magic emission uses its authored staff crown")
 tender.free()
 # Dangerous areas retain exact radius independent of decorative pool pressure.
 await lab.prepare(8)
 await lab.play_action()
 var warnings=lab.combat.get_child(0)
 check(warnings is EliteWarnings and not warnings.markers.is_empty(),"Persistent warning uses authoritative pending cast")
 var marker=warnings.markers[lab.actor.stable_id]
 var vertices:PackedVector3Array=marker.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 var radius:float=lab.actor.ability_by_id("elite_hollow").area_radius
 var contained:=true
 for v in vertices:
  if Vector2(v.x,v.z).length()>radius+.001:contained=false
 check(contained,"Warning teeth and boundary never exceed actual blast radius")
 # Queue actual Power Strike, check event-time impacts, transformed grip and pause/cleanup.
 await lab.prepare(1)
 var p=lab.encounter.get_node("CombatPresentation")
 var rig=lab.encounter.get_node("TacticalCamera")
 var before=lab.target.health
 var data:Dictionary={}
 lab.combat.combat_event.connect(func(kind:String,event:Dictionary):
  if kind=="attack":data.merge(event,true))
 var accepted=lab.combat.submit_command(UseAbilityCommand.new(lab.actor.stable_id,lab.target.stable_id,"power_strike"))
 check(accepted and lab.target.health==before-7 and p.oath_fx.active_count()==1,"Confirmed damage and impact share event frame")
 check(not p.oath_fx.trails.is_empty(),"Melee starts animated weapon ribbon")
 check(p.pending_sounds.all(func(s:Dictionary)->bool:return s.delay==0),"Contact audio has no invented travel delay")
 var count=p.oath_fx.active_count()
 p._on_event("attack",data)
 check(count==p.oath_fx.active_count() and lab.target.health==before-7,"Duplicate delivery cannot repeat FX or damage")
 for n in 5:p._spawn_effect(lab.target.stable_id,"−3 HP",Color.ORANGE)
 p._process(0)
 var separated:=true
 for a in p._effect_rects.size():
  for b in a:
   if p._effect_rects[a].intersects(p._effect_rects[b]):separated=false
 check(separated,"Simultaneous combat text remains separated")
 await physics_frame;await process_frame;await physics_frame;await process_frame
 var edge=lab.actor.character.weapon_edge()
 var trail=p.oath_fx.trails[0]
 check(not trail.samples.is_empty() and trail.samples[-1].edge[1].distance_to(edge[1])<.3,"Ribbon samples follow actual animated skinned weapon")
 var original_position=rig.position;var original_yaw=rig.yaw;var original_distance=rig.distance
 rig.impact_impulse(lab.target.position,.16);rig._process(.01)
 check(rig.camera.position!=Vector3(0,0,rig.distance),"Major hit displaces child camera")
 check(rig.position==original_position and rig.yaw==original_yaw and rig.distance==original_distance,"Impulse preserves controlled framing")
 lab.flow.audio.preferences.Camera.shake=0;rig.apply_preferences(lab.flow.audio)
 check(rig.camera.position==Vector3(0,0,rig.distance),"Zero intensity clears shake immediately")
 lab.flow.audio.preferences.Camera.shake=1;lab.flow.audio.preferences.Camera.reduced_motion=true;rig.apply_preferences(lab.flow.audio);rig.impact_impulse(Vector3.ZERO,.16)
 check(rig._impact_remaining==0,"Reduced motion suppresses future impulses")
 var fx=p.oath_fx
 fx.clear()
 for i in 200:fx.burst(Vector3.ZERO,"blade",Color.WHITE,Vector3.UP,1,1)
 check(fx.active_count()==32 and fx.get_child_count()==32,"Burst pool remains fixed at 32 nodes")
 fx.burst(Vector3.ZERO,"heal",Color.GREEN,Vector3.UP,1,3)
 check(fx.slots.any(func(slot:Dictionary)->bool:return slot.active and slot.priority==3),"Important healing replaces decoration at capacity")
 fx._process(2)
 check(fx.active_count()==0,"All pooled bursts return inactive after lifetime")
 lab.flow.audio.preferences.Accessibility.reduced_effects=true;p.apply_preferences(lab.flow.audio)
 fx.burst(Vector3.ZERO,"blade",Color.WHITE)
 check(fx.active_count()==0 and fx.trails.is_empty(),"Reduced effects clear and suppress transient bursts/ribbons")
 await lab.combat.restart_encounter()
 check(p.tracers.is_empty() and p.glyphs.is_empty() and p.blasts.is_empty() and fx.active_count()==0,"Restart cleans all presentation types")
 lab.queue_free();await process_frame;await process_frame
 print("COMBAT FX RESULT: %d failures"%failures);quit(1 if failures else 0)
