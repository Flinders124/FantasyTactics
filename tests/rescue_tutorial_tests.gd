extends "res://tests/campaign_flow_tests.gd"
func run() -> void:
 flow=load("res://scenes/main.tscn").instantiate(); root.add_child(flow)
 check(flow.has_method("start_rescue_tutorial"),"Optional isolated rescue entry exists")
 if not flow.has_method("start_rescue_tutorial"):
  flow.queue_free(); await settle(); print("RESCUE TUTORIAL RESULT: %d failures"%failures); quit(1); return
 var state := CampaignState.new(17)
 flow.campaign.state=state
 var before := state.snapshot()
 flow.campaign.store.path="user://rescue-lesson-campaign.json"
 check(flow.campaign.store.write(state,"headquarters"),"Isolated campaign save fixture")
 var bytes := FileAccess.get_file_as_string(flow.campaign.store.path)
 var completed_before: bool=flow.audio.tutorial_completed
 flow.call("start_rescue_tutorial")
 if flow.combat==null:
  check(false,"Rescue setup accepted a valid training configuration"); flow.queue_free(); await settle(); quit(1); return
 await wait_ready()
 var scene := flow.combat
 var combat: CombatController=scene.get_node("CombatController")
 var lesson: Variant=scene.get("rescue_lesson")
 check(lesson!=null,"Lesson has encounter-local guidance")
 if lesson==null: quit(1); return
 for frame in range(1600):
  if lesson.stage=="approach": break
  await process_frame
 check(lesson.stage=="approach" and combat.find_unit("hero-01").is_downed(),"Legal scripted attack produces a downed companion")
 var actor := combat.find_unit("hero-02")
 check(not scene.get_node("HUD").ability_buttons.any(func(item: Button) -> bool: return item.visible),"Rescue practice removes unrelated ability-row clutter")
 check(scene.get_node("HUD").attack_button.disabled and not scene.get_node("HUD").move_button.disabled,"Practice button states match current guidance")
 check(not combat.submit_player_command(AttackCommand.new(actor.stable_id,"enemy-01")) and actor.action_available,"Wrong action cannot advance lesson or spend action")
 check(combat.submit_player_command(MoveCommand.new(actor.stable_id,Vector3(-5.8,0,1.2))),"Approach uses approved navigation")
 await action_wait(combat)
 check(lesson.stage=="stabilise","Movement completion advances guidance")
 check(combat.submit_player_command(RescueCommand.new(actor.stable_id,"hero-01",RescueCommand.Kind.STABILISE)),"Stabilise through real command")
 check(lesson.stage=="end_for_carry" and not actor.action_available,"Stabilise spends shared action and requires next turn")
 check(combat.submit_player_command(EndTurnCommand.new(actor.stable_id)),"End turn before carrying")
 for frame in range(400):
  if lesson.stage=="carry": break
  await process_frame
 check(lesson.stage=="carry","Actual next owner turn enables carry")
 check(combat.submit_player_command(RescueCommand.new(actor.stable_id,"hero-01",RescueCommand.Kind.PICKUP)),"Carry through real command")
 check(actor.carried_unit!=null and actor.movement_granted==actor.definition.movement_allowance*.5,"Carry halves actual movement")
 check(combat.submit_player_command(MoveCommand.new(actor.stable_id,Vector3(-3.5,0,1.2))),"Carry to marked safe zone")
 await action_wait(combat)
 check(lesson.stage=="end_for_extract","Completed carry move advances guidance")
 check(combat.submit_player_command(EndTurnCommand.new(actor.stable_id)),"End turn before extraction")
 for frame in range(400):
  if lesson.stage=="extract": break
  await process_frame
 check(combat.submit_player_command(RescueCommand.new(actor.stable_id,"",RescueCommand.Kind.EXTRACT)),"Extract through normal rule pipeline")
 await process_frame; await process_frame
 check(lesson.stage=="complete" and combat.state==CombatController.State.DEFEAT,"Training completion does not rewrite retreat outcome")
 flow.audio.apply_preferences(false); await process_frame
 check(not scene.get_node("HUD").overlay.visible,"Settings refresh does not restore misleading defeat overlay over practice result")
 check(flow.audio.tutorial_completed==completed_before,"Rescue practice does not falsely complete basic tutorial")
 check(state.snapshot()==before and FileAccess.get_file_as_string(flow.campaign.store.path)==bytes,"Practice cannot mutate campaign or save bytes")
 flow.request_transition("main_menu"); await settle()
 check(not paused and flow.combat==null,"Completed lesson exit clears encounter and pause")
 flow.call("start_rescue_tutorial"); await wait_ready()
 flow.request_transition("main_menu")
 check(paused and flow.combat.guide.confirm_button.visible,"Leaving active lesson asks confirmation")
 flow.combat.guide.confirm_button.pressed.emit(); await settle()
 check(flow.combat==null and not paused,"Confirmed early exit cleans pending scripted work")
 flow.call("start_rescue_tutorial");await wait_ready()
 var pause_scene := flow.combat
 flow.audio.panel.open()
 var held_stage: String=pause_scene.rescue_lesson.stage
 var held_health: int=pause_scene.get_node("CombatController").find_unit("hero-01").health
 for frame in range(30): await process_frame
 check(paused and pause_scene.rescue_lesson.stage==held_stage and pause_scene.get_node("CombatController").find_unit("hero-01").health==held_health,"Settings pauses scripted attack and lesson advancement")
 flow.audio.panel.close()
 for frame in range(1600):
  if pause_scene.rescue_lesson.stage=="approach": break
  await process_frame
 pause_scene.get_node("CombatController").find_unit("hero-01").force_death("Development premature-loss fixture")
 check(pause_scene.rescue_lesson.stage=="recovery","Lost required companion offers safe recovery")
 flow.request_transition("rescue_tutorial")
 flow.combat.guide.confirm_button.pressed.emit();await wait_ready()
 var blocked_scene := flow.combat
 for frame in range(1600):
  if blocked_scene.rescue_lesson.stage=="approach": break
  await process_frame
 var blocked_combat: CombatController=blocked_scene.get_node("CombatController")
 var blocker := StaticBody3D.new();var collider := CollisionShape3D.new();var shape := BoxShape3D.new()
 shape.size=Vector3(5,2,.35);collider.shape=shape;blocker.add_child(collider);blocker.position=Vector3(-5.4,1,2.6);blocked_scene.add_child(blocker)
 await physics_frame;await physics_frame
 blocked_combat.motor.blocked_timeout=.15
 check(blocked_combat.submit_player_command(MoveCommand.new("hero-02",Vector3(-5.8,0,1.2))),"Blocked-route exercise starts through normal command")
 await action_wait(blocked_combat)
 check(blocked_combat.state==CombatController.State.AWAITING_COMMAND and blocked_scene.rescue_lesson.stage!="stabilise","Blocked motion finishes without falsely completing lesson step")
 check("restart" in blocked_scene.rescue_lesson.instructions.text.to_lower(),"Blocked exercise retains explicit restart recovery")
 flow.request_transition("main_menu");flow.combat.guide.confirm_button.pressed.emit();await settle()
 for cycle in range(3):
  flow.call("start_rescue_tutorial");await wait_ready()
  flow.request_transition("main_menu");flow.combat.guide.confirm_button.pressed.emit();await settle()
  check(flow.combat==null and flow.retired.is_empty() and not paused,"Repeated training exits clean their encounters and pause")
 check(state.snapshot()==before and FileAccess.get_file_as_string(flow.campaign.store.path)==bytes,"All restarts and failure exercises preserve campaign bytes")
 flow.campaign.state=null; flow.queue_free(); await settle()
 print("RESCUE TUTORIAL RESULT: %d failures"%failures)
 quit(1 if failures else 0)
