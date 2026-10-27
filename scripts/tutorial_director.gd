class_name TutorialDirector
extends CanvasLayer
## Guidance policy is encounter-local; advancement observes authoritative results.
signal step_changed(step: Step)
signal completed
signal requested(action: String)
enum Step { CAMERA, PREVIEW, MOVE, ATTACK, MOVE_AGAIN, END_TURN, OBSERVE, ABILITY, FINISH, COMPLETE, RECOVERY }
var step: Step = Step.CAMERA
var encounter: CombatEncounter
var controller: CombatController
var instructions: Label
var panel: PanelContainer
var marker: MeshInstance3D
var camera_actions: Dictionary = {}
var observed_enemy: bool = false
var pending_action: String = ""
var pending_actor: String = ""
var abandoned: bool = false
var history: Array[int] = [Step.CAMERA]
func bind(owner_encounter: CombatEncounter) -> void:
	add_to_group("preference_consumers")
	encounter=owner_encounter
	controller=encounter.get_node("CombatController")
	layer=24
	process_mode=Node.PROCESS_MODE_ALWAYS
	controller.player_command_policy=restriction
	controller.action_completed.connect(_action_completed)
	controller.combat_event.connect(_event)
	controller.turn_started.connect(_turn)
	controller.encounter_updated.connect(_check_required)
	controller.feedback_changed.connect(_feedback)
	controller.encounter_reset.connect(func() -> void:
		if abandoned: return
		step=Step.CAMERA
		camera_actions.clear()
		observed_enemy=false
		pending_action=""
		pending_actor=""
		history=[Step.CAMERA]
		panel.show()
		_refresh())
	encounter.get_node("TacticalCamera").control_used.connect(_camera)
	encounter.get_node("PlayerController").route_previewed.connect(_preview)
	_build()
	_refresh()
func _build() -> void:
	var root := Control.new()
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel=PanelContainer.new()
	panel.theme=encounter.get_node("HUD").root.theme
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left=1.0
	panel.offset_left=-280
	panel.offset_right=-20
	panel.offset_top=124
	panel.offset_bottom=-20
	var style := StyleBoxFlat.new()
	style.bg_color=Color(.035,.065,.09,.97)
	style.border_color=Color(.4,.85,1)
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel",style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	instructions=Label.new()
	instructions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	instructions.custom_minimum_size=Vector2(210,60)
	instructions.add_theme_font_size_override("font_size",16)
	box.add_child(instructions)
	var row := VBoxContainer.new()
	box.add_child(row)
	for item: Array in [["Restart Tutorial","tutorial"],["Skip Tutorial","skip_tutorial"],["Exit to Main Menu","main_menu"],["Help","controls"]]:
		var action: String=item[1]
		var button := Button.new()
		button.text=item[0]
		button.custom_minimum_size.y=32
		row.add_child(button)
		button.pressed.connect(func() -> void: requested.emit(action))
	marker=MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius=.45
	ring.outer_radius=.55
	marker.mesh=ring
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(.4,.85,1)
	marker.material_override=material
	encounter.add_child(marker)
	var label := Label3D.new()
	label.text="TRAINING DESTINATION"
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size=24
	label.position.y=.25
	label.no_depth_test=true
	marker.add_child(label)
func _advance(next: Step) -> void:
	if abandoned or step==Step.RECOVERY or step==Step.COMPLETE: return
	step=next
	history.append(step)
	_refresh()
	step_changed.emit(step)
func _refresh() -> void:
	encounter.get_node("HUD").root.get_node("CombatLogPanel").visible=abandoned or step==Step.COMPLETE
	var texts: Dictionary={
		Step.CAMERA:"1 · CAMERA: Orbit (%s), pan (%s or movement keys), zoom (%s), then focus the active hero (%s). The gold initiative card is active; health, movement and action are at left." % [ControlBindings.label("orbit"),ControlBindings.label("pan_drag"),ControlBindings.label("zoom_in"),ControlBindings.label("focus")],
		Step.PREVIEW:"2 · ROUTE COST: Choose Move (%s). Hover the blue training ring. The preview measures the full navigation route, not a straight line." % ControlBindings.label("move"),
		Step.MOVE:"3 · MOVE: Choose Move (%s), then click the blue training ring. Watch metres spent in the active-unit panel. Only this marked move is enabled for this step." % ControlBindings.label("move"),
		Step.ATTACK:"4 · BASIC ATTACK: Choose Attack (%s), inspect Raider, then click it. One action is shared by basic attacks and abilities." % ControlBindings.label("attack"),
		Step.MOVE_AGAIN:"5 · MOVE AFTER ATTACK: No action remains, but movement does! Choose Move (%s) and click the new blue ring. This uses the SAME turn budget." % ControlBindings.label("move"),
		Step.END_TURN:"6 · END TURN: Use %s or End Turn. Watch initiative advance. Training opponents hold position and legally end their turns; normal enemies fight back." % ControlBindings.label("end_turn"),
		Step.OBSERVE:"Watch the enemy turn finish. Camera, help and audio remain available.",
		Step.ABILITY:"7 · RANGED ABILITY: Scout is active. Select Crippling Shot (%s), inspect Sentinel, then click. It spends the shared action and applies Slowed for two future turns; cooldown blocks Scout's next two turns." % ControlBindings.label("ability_1"),
		Step.FINISH:"8 · FINISH: Defeat both training opponents. End turns to regain actions. Move, use basic attacks or abilities; inspect previews first. Training enemies continue holding position. Help has optional tips.",
		Step.RECOVERY:"The required demonstration can no longer be completed safely. Restart Tutorial to restore the authored encounter, or Skip / Exit. No partial-state rewind is attempted.",
		Step.COMPLETE:"Tutorial complete! You can replay it from the title screen."}
	instructions.text=ControlBindings.instructions(texts.get(step,""))
	marker.visible=step in [Step.PREVIEW,Step.MOVE,Step.MOVE_AGAIN]
	marker.position=(TutorialEncounter.SECOND_DESTINATION if step==Step.MOVE_AGAIN else TutorialEncounter.FIRST_DESTINATION)+Vector3.UP*.08
	if step==Step.COMPLETE: panel.hide()
func _camera(kind: String) -> void:
	if step!=Step.CAMERA or controller.guidance_paused: return
	camera_actions[kind]=true
	if camera_actions.size()==4: _advance(Step.PREVIEW)
func _preview(point: Vector3,cost: float,valid: bool) -> void:
	if step==Step.PREVIEW and valid and cost>.1 and point.distance_to(TutorialEncounter.FIRST_DESTINATION)<.65:
		_advance(Step.MOVE)
func restriction(command: CombatCommand) -> String:
	if step==Step.FINISH: return ""
	var allowed := false
	match step:
		Step.MOVE,Step.MOVE_AGAIN:
			var goal := TutorialEncounter.FIRST_DESTINATION if step==Step.MOVE else TutorialEncounter.SECOND_DESTINATION
			allowed=command is MoveCommand and command.actor_id=="hero-01" and command.destination.distance_to(goal)<.6
		Step.ATTACK:
			allowed=command is AttackCommand and command.actor_id=="hero-01" and command.target_id=="enemy-01"
		Step.END_TURN: allowed=command is EndTurnCommand and command.actor_id=="hero-01"
		Step.ABILITY: allowed=command is UseAbilityCommand and command.actor_id=="hero-02" and command.ability_id=="crippling_shot" and command.target_id=="enemy-02"
	return "" if allowed else "Tutorial: follow the current instruction. Camera, Help, Skip and Exit are always available."
func _event(kind: String,data: Dictionary) -> void:
	if abandoned: return
	if kind in ["attack","ability"]:
		pending_action="ability" if data.has("ability_id") else kind
		pending_actor=str(data.get("actor_id",""))
	if kind=="result":
		if step==Step.FINISH and bool(data.get("victory",false)):
			_advance(Step.COMPLETE)
			var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
			if audio!=null: audio.mark_tutorial_completed()
			completed.emit()
		elif step!=Step.COMPLETE:
			step=Step.RECOVERY
			_refresh()
func _action_completed(actor: String,action: String,_reason: String) -> void:
	if actor=="hero-01" and action=="move":
		var unit := controller.find_unit(actor)
		if step==Step.MOVE and unit.global_position.distance_to(TutorialEncounter.FIRST_DESTINATION)<.61 and controller.evaluate_attack(unit,controller.find_unit("enemy-01")).valid(): _advance(Step.ATTACK)
		elif step==Step.MOVE_AGAIN and unit.global_position.distance_to(TutorialEncounter.SECOND_DESTINATION)<.61: _advance(Step.END_TURN)
	elif actor==pending_actor and action=="attack":
		if step==Step.ATTACK and actor=="hero-01" and pending_action=="attack": _advance(Step.MOVE_AGAIN)
		elif step==Step.ABILITY and actor=="hero-02" and pending_action=="ability": _advance(Step.FINISH)
	pending_action=""
	pending_actor=""
func _turn(unit: CombatUnit,_serial: int) -> void:
	if step==Step.END_TURN and unit.faction==CombatUnit.Faction.ENEMY:
		observed_enemy=true
		_advance(Step.OBSERVE)
	elif step==Step.OBSERVE and observed_enemy and unit.stable_id=="hero-02": _advance(Step.ABILITY)
func _feedback(message: String) -> void:
	if step in [Step.MOVE,Step.MOVE_AGAIN] and ("blocked" in message.to_lower() or "unreachable" in message.to_lower()):
		_refresh()
		instructions.text+="\nRoute blocked: cancel targeting and try the marked point again, or Restart Tutorial."
func _check_required() -> void:
	if abandoned: return
	if step>=Step.FINISH or controller.units.is_empty(): return
	for id in ["hero-01","hero-02","enemy-01","enemy-02"]:
		var unit := controller.find_unit(id)
		if unit==null or not unit.is_alive():
			step=Step.RECOVERY
			_refresh()
			return
func shutdown() -> void:
	abandoned=true
	if is_instance_valid(encounter): encounter.get_node("HUD").root.get_node("CombatLogPanel").show()
	visible=false
	controller.player_command_policy=Callable()
	if marker!=null: marker.hide()
	if panel!=null: panel.hide()

func apply_preferences(_owner: GameAudio) -> void:
	if instructions!=null: _refresh()
