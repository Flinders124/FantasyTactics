class_name RescueTutorialDirector
extends CanvasLayer
## Read-only guidance plus an explicit, bounded training-opponent command policy.
signal requested(action: String)
var stage: String="observe"
var encounter: CombatEncounter
var controller: CombatController
var instructions: Label
var panel: PanelContainer
var marker: Node3D
var cancelled: bool=false
var moved: bool=false
var attacked: bool=false
var queued: bool=false
var spent_serial: int=-1
var recovery_reason: String=""
func bind(owner_encounter: CombatEncounter) -> void:
 encounter=owner_encounter
 controller=encounter.get_node("CombatController")
 process_mode=Node.PROCESS_MODE_ALWAYS
 layer=24
 add_to_group("preference_consumers")
 controller.player_command_policy=restriction
 controller.action_completed.connect(_completed_action)
 controller.combat_event.connect(_event)
 controller.turn_started.connect(_turn)
 controller.encounter_reset.connect(_reset)
 controller.feedback_changed.connect(_feedback)
 controller.encounter_updated.connect(_validate_required)
 _build()
 _refresh()
func _build() -> void:
 var root := Control.new(); add_child(root)
 root.mouse_filter=Control.MOUSE_FILTER_IGNORE
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel=PanelContainer.new();root.add_child(panel)
 panel.theme=OathUI.theme()
 panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel.anchor_left=1;panel.offset_left=-290;panel.offset_right=-16;panel.offset_top=124;panel.offset_bottom=-16
 var scroll := ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;panel.add_child(scroll)
 var box := VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(box)
 instructions=Label.new();instructions.custom_minimum_size.x=236;instructions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;instructions.add_theme_font_size_override("font_size",16);box.add_child(instructions)
 var options: Array=[["Restart Exercise","rescue_tutorial"],["Skip Practice","main_menu"],["Exit to Main Menu","main_menu"],["Help","controls"]]
 var flow := get_tree().get_first_node_in_group("scene_flow")
 if flow!=null and flow.campaign.state!=null: options.append(["Return to Camp","campaign_hq"])
 for item in options:
  var button := Button.new();button.text=item[0];button.custom_minimum_size.y=40;box.add_child(button)
  var action: String=item[1]
  button.pressed.connect(func() -> void: requested.emit(action))
 marker=Node3D.new();encounter.add_child(marker)
 var mesh := MeshInstance3D.new();var ring := TorusMesh.new();ring.inner_radius=.4;ring.outer_radius=.5;mesh.mesh=ring
 var material := StandardMaterial3D.new();material.albedo_color=Color(.9,.8,.45);material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mesh.material_override=material;marker.add_child(mesh)
 var label := Label3D.new();label.text="PRACTICE DESTINATION";label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position.y=.3;label.font_size=24;marker.add_child(label)
func _reset() -> void:
 stage="observe";moved=false;attacked=false;spent_serial=-1;cancelled=false;recovery_reason=""
 if panel!=null:
  encounter.get_node("HUD").suppress_result_overlay=false
  panel.show();_refresh()
func _process(_delta: float) -> void:
 if cancelled or get_tree().paused or controller.scheduler==null or controller.guidance_paused: return
 if controller.state!=CombatController.State.AWAITING_COMMAND: return
 var actor := controller.scheduler.active_unit()
 if actor!=null and actor.faction==CombatUnit.Faction.ENEMY and not queued:
  queued=true;call_deferred("_drive_opponent")
 elif stage=="observe" and actor!=null and actor.stable_id=="hero-02":
  _set_stage("approach" if controller.find_unit("hero-01").is_downed() else "recovery")
func _drive_opponent() -> void:
 queued=false
 if cancelled or get_tree().paused or controller.guidance_paused or controller.state!=CombatController.State.AWAITING_COMMAND: return
 var actor := controller.scheduler.active_unit()
 if actor==null or actor.faction!=CombatUnit.Faction.ENEMY: return
 var accepted := false
 if actor.stable_id=="enemy-01" and not attacked:
  if not moved:
   moved=true
   accepted=controller.submit_command(MoveCommand.new(actor.stable_id,Vector3(-4.6,0,0)))
  else:
   attacked=true
   accepted=controller.submit_command(AttackCommand.new(actor.stable_id,"hero-01"))
  if not accepted:
   _set_stage("recovery")
   controller.submit_command(EndTurnCommand.new(actor.stable_id))
 else:
  controller.submit_command(EndTurnCommand.new(actor.stable_id))
func restriction(command: CombatCommand) -> String:
 if cancelled or stage in ["complete","recovery"]: return "Practice stopped. Restart or exit the exercise."
 if command.actor_id!="hero-02": return "Follow the rescue-practice instruction with the active rescuer."
 var allowed := false
 match stage:
  "approach": allowed=command is MoveCommand and command.destination.distance_to(RescueTutorialEncounter.APPROACH_POINT)<.5
  "stabilise": allowed=command is RescueCommand and command.kind==RescueCommand.Kind.STABILISE and command.target_id=="hero-01"
  "carry": allowed=command is RescueCommand and command.kind==RescueCommand.Kind.PICKUP and command.target_id=="hero-01"
  "move": allowed=command is MoveCommand and command.destination.distance_to(RescueTutorialEncounter.SAFE_POINT)<.5
  "end_for_carry","end_for_extract": allowed=command is EndTurnCommand
  "extract": allowed=command is RescueCommand and command.kind==RescueCommand.Kind.EXTRACT
 return "" if allowed else "Practice: follow the current instruction. Camera, help, settings and exit remain available."
func _set_stage(value: String) -> void:
 if cancelled: return
 stage=value
 encounter.get_node("PlayerController").cancel_targeting()
 _refresh()
func _completed_action(actor_id: String,action: String,_reason: String) -> void:
 if cancelled or actor_id!="hero-02": return
 var actor := controller.find_unit(actor_id)
 var companion := controller.find_unit("hero-01")
 if actor==null or companion==null: _set_stage("recovery");return
 if action=="move" and stage in ["approach","move"]:
  var goal := RescueTutorialEncounter.APPROACH_POINT if stage=="approach" else RescueTutorialEncounter.SAFE_POINT
  if actor.ground_anchor().distance_to(goal)>=.55:
   var route := controller.evaluate_move(actor,goal)
   if not route.valid():
    recovery_reason=route.error;_set_stage("recovery")
   else: instructions.text+="\nMovement stopped. Distance already travelled remains spent. Preview and retry, or Restart Exercise."
   return
 if stage=="approach" and action=="move" and actor.ground_anchor().distance_to(RescueTutorialEncounter.APPROACH_POINT)<.55:
  _set_stage("stabilise")
 elif stage=="stabilise" and action=="rescue" and companion.life_state==CombatUnit.LifeState.STABILISED:
  spent_serial=controller.turn_serial;_set_stage("end_for_carry")
 elif stage=="carry" and action=="rescue" and actor.carried_unit==companion:
  _set_stage("move")
 elif stage=="move" and action=="move" and actor.ground_anchor().distance_to(RescueTutorialEncounter.SAFE_POINT)<.55:
  spent_serial=controller.turn_serial;_set_stage("end_for_extract")
func _turn(unit: CombatUnit,serial: int) -> void:
 if cancelled or unit.stable_id!="hero-02" or serial<=spent_serial: return
 if stage=="end_for_carry": _set_stage("carry")
 elif stage=="end_for_extract": _set_stage("extract")
func _event(kind: String,_data: Dictionary) -> void:
 if cancelled: return
 if kind=="result":
  var safe := controller.units.filter(func(unit: CombatUnit) -> bool: return unit.faction==CombatUnit.Faction.HERO and unit.life_state==CombatUnit.LifeState.EXTRACTED)
  _set_stage("complete" if safe.size()==2 else "recovery")
  call_deferred("_show_result")
 elif kind=="death" and stage!="complete": _set_stage("recovery")
func _validate_required() -> void:
 if cancelled or stage in ["observe","complete","extract","recovery"]: return
 var actor := controller.find_unit("hero-02")
 var companion := controller.find_unit("hero-01")
 if actor==null or companion==null or not actor.is_alive() or companion.life_state==CombatUnit.LifeState.DEAD:
  recovery_reason="A required companion is unavailable.";_set_stage("recovery")
func _feedback(message: String) -> void:
 if cancelled or instructions==null: return
 if stage in ["approach","move"] and ("blocked" in message.to_lower() or "unreachable" in message.to_lower()):
  _refresh();instructions.text+="\n"+message+". Preview and retry, or Restart Exercise."
func _show_result() -> void:
 if cancelled: return
 encounter.get_node("HUD").suppress_result_overlay=true
 encounter.get_node("HUD").overlay.hide()
 panel.show()
func _refresh() -> void:
 var texts := {
 "observe":"RESCUE PRACTICE · No campaign progress is at risk. Watch a training opponent demonstrate one attack. Opponents then hold position; normal enemies fight back.",
 "approach":"1 · APPROACH. Choose Move (%s) and move the active rescuer to the marked point beside the downed companion. Downed is not dead."%ControlBindings.label("move"),
 "stabilise":"2 · STABILISE. Choose Stabilise, then select the downed companion. It spends the shared action and stops bleed-out without healing.",
 "end_for_carry":"3 · NEXT TURN. The action is spent. End Turn (%s) to regain an action. Stabilised companions no longer bleed out."%ControlBindings.label("end_turn"),
 "carry":"4 · CARRY. Choose Carry and select the stabilised companion. Carrying halves the movement allowance. It does not grant a second action.",
 "move":"5 · MOVE WITH YOUR COMPANION. Choose Move (%s), inspect the reduced remaining distance, then move to the practice marker in the retreat zone."%ControlBindings.label("move"),
 "end_for_extract":"6 · NEXT TURN. Carrying spent this turn's action. End Turn (%s) before extracting."%ControlBindings.label("end_turn"),
 "extract":"7 · EXTRACT. Choose Extract while inside the marked retreat zone. The carried companion leaves safely with the rescuer.",
 "complete":"PRACTICE COMPLETE · Both companions were safely extracted. The tactical result is a retreat/defeat, not mission victory. In a campaign they survive that failure. This practice does not change your campaign or complete basic training. Replay or exit when ready.",
 "recovery":"This practice cannot continue safely. Restart Exercise restores its private starting state; Skip or Exit returns to menus. No campaign progress is affected."}
 instructions.text=ControlBindings.instructions(texts.get(stage,"")+("\n"+recovery_reason if stage=="recovery" else ""))+"\n\nCancel targeting: "+ControlBindings.label("cancel")
 marker.visible=stage in ["approach","move"]
 marker.position=(RescueTutorialEncounter.APPROACH_POINT if stage=="approach" else RescueTutorialEncounter.SAFE_POINT)+Vector3.UP*.08
func apply_preferences(_owner: GameAudio) -> void:
 if instructions!=null: _refresh()
func shutdown() -> void:
 cancelled=true
 if controller!=null and controller.player_command_policy==Callable(self,"restriction"): controller.player_command_policy=Callable()
 if marker!=null: marker.hide()
 if panel!=null: panel.hide()
