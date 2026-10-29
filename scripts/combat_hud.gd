extends CanvasLayer

signal flow_requested(action: String)
var tutorial_finished: bool = false
var encounter_configuration: EncounterConfiguration
var code_button: Button
var code_overlay: EncounterCodeOverlay
var use_native_clipboard: bool = true
var flow_enabled: bool = false
var info_host: HBoxContainer
var objective_label: Label
var seed_label: Label
var result_flow_buttons: Dictionary = {}

const PANEL: Color = Color(0.045, 0.065, 0.1, 0.96)
const MUTED: Color = OathUI.MUTED
const GOLD: Color = OathUI.GOLD
var reference_label: Label
var controller: CombatController
var player: PlayerController
var root: Control
var label: Label
var button: Button
var move_button: Button
var ability_buttons: Array[Button] = []
var rescue_buttons: Array[Button] = []
var rescue_row: HBoxContainer
const SURVIVAL_HELP: String = "Downed heroes bleed out after 3 future round-end checks; the round they fall does not count. Stabilise stops bleeding. Carry halves movement; Drop and Extract each cost one shared action. Extract in the marked retreat zone. Unrescued losses are permanent. Victory recovers conscious and stabilised heroes; retreat preserves only extracted heroes."
var attack_button: Button
var restart_button: Button
var preview_label: Label
var attack_preview_label: Label
var feedback_label: Label
var result_label: Label
var round_label: Label
var name_label: Label
var faction_label: Label
var mode_label: Label
var health_bar: ProgressBar
var initiative_row: HBoxContainer
var initiative_cards: Dictionary = {}
var log_label: Label
var log_scroll: ScrollContainer
var overlay: Control
var overlay_title: Label
var overlay_summary: Label
var overlay_restart: Button
var layout_panels: Array[Control] = []

func _style(color: Color, border: Color = Color(0.18, 0.24, 0.33)) -> StyleBoxFlat:
	var style := OathUI.panel(border==GOLD)
	style.bg_color=OathUI.PANEL
	style.set_content_margin_all(10)
	return style

func _text(parent: Node, text: String, font_size: int = 16, color: Color = OathUI.PAPER) -> Label:
	var item := Label.new()
	item.text = text
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
	return item

func _button(parent: Node, text: String) -> Button:
	var item := ReadableActionButton.new()
	item.text = text
	item.custom_minimum_size.y = 38
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.focus_mode = Control.FOCUS_ALL
	parent.add_child(item)
	return item

func _panel(panel_name: String, anchors: Vector4, offsets: Vector4) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	root.add_child(panel)
	panel.anchor_left = anchors.x
	panel.anchor_top = anchors.y
	panel.anchor_right = anchors.z
	panel.anchor_bottom = anchors.w
	panel.offset_left = offsets.x
	panel.offset_top = offsets.y
	panel.offset_right = offsets.z
	panel.offset_bottom = offsets.w
	panel.add_theme_stylebox_override("panel", _style(PANEL))
	layout_panels.append(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	if panel_name in ["ActiveUnitPanel","HelpPanel","ActionsPanel","AbilitiesPanel"]:
		var scroll := ScrollContainer.new()
		scroll.follow_focus=true
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		panel.add_child(scroll)
		box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		scroll.add_child(box)
	else: panel.add_child(box)
	return box

func bind(encounter_controller: CombatController) -> void:
	add_to_group("preference_consumers")
	layer = 10
	process_mode=Node.PROCESS_MODE_ALWAYS
	ControlBindings.ensure()
	controller = encounter_controller
	root = Control.new()
	root.name = "Interface"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := OathUI.theme()
	root.theme = theme
	root.resized.connect(_fit_layout)
	var top := _panel("InitiativeBar", Vector4(0, 0, 1, 0), Vector4(20, 16, -20, 100))
	var heading := HBoxContainer.new()
	info_host = heading
	heading.add_theme_constant_override("separation", 16)
	top.add_child(heading)
	var round_box := VBoxContainer.new()
	round_box.custom_minimum_size.x = 100
	heading.add_child(round_box)
	_text(round_box, "INITIATIVE", 12, MUTED)
	round_label = _text(round_box, "ROUND 1", 22, GOLD)
	initiative_row = HBoxContainer.new()
	initiative_row.add_theme_constant_override("separation", 8)
	initiative_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(initiative_row)
	var active := _panel("ActiveUnitPanel", Vector4.ZERO, Vector4(20, 108, 272, 354))
	_text(active, "ACTIVE UNIT", 12, MUTED)
	name_label = _text(active, "", 26)
	name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	faction_label = _text(active, "", 14, GOLD)
	faction_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size.y = 14
	health_bar.show_percentage = false
	health_bar.add_theme_stylebox_override("background", OathUI.theme().get_stylebox("background","ProgressBar"))
	var health_fill := StyleBoxFlat.new()
	health_fill.bg_color = Color(0.3, 0.7, 1)
	health_fill.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("fill", health_fill)
	active.add_child(health_bar)
	label = _text(active, "", 16)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label = _text(active, "", 14, GOLD)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := _panel("ActionsPanel", Vector4(0.5, 1, 0.5, 1), Vector4(-325, -154, 325, -20))
	mode_label = _text(actions, "Choose an action", 16, GOLD)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	actions.add_child(buttons)
	move_button = _button(buttons, "Move [%s]" % ControlBindings.label("move"))
	move_button.toggle_mode = true
	attack_button = _button(buttons, "Attack [%s]" % ControlBindings.label("attack"))
	attack_button.toggle_mode = true
	button = _button(buttons, "End Turn [%s]" % ControlBindings.label("end_turn"))
	button.pressed.connect(_end_turn)
	var ability_row := HBoxContainer.new()
	ability_row.add_theme_constant_override("separation", 8)
	var ability_panel := _panel("AbilitiesPanel", Vector4(0.5, 1, 0.5, 1), Vector4(-325, -244, 325, -160))
	ability_panel.add_child(ability_row)
	for index in range(3):
		var slot := index
		var ability_button := _button(ability_row, "Ability")
		ability_button.add_theme_font_size_override("font_size", 14)
		ability_button.toggle_mode = true
		ability_button.pressed.connect(func() -> void:
			var unit := controller.scheduler.active_unit()
			if player != null and unit != null and slot < unit.definition.abilities.size():
				player.select_ability(unit.definition.abilities[slot].stable_id))
		ability_buttons.append(ability_button)
	rescue_row = HBoxContainer.new()
	rescue_row.add_theme_constant_override("separation", 8)
	ability_panel.add_child(rescue_row)
	rescue_row.visible = controller.survival_enabled
	for index in range(PlayerController.RESCUE_NAMES.size()):
		var kind := index
		var rescue := _button(rescue_row, PlayerController.RESCUE_NAMES[kind])
		rescue.add_theme_font_size_override("font_size", 14)
		rescue.toggle_mode = kind < 2
		rescue.tooltip_text = ["Stop an adjacent ally's bleeding.", "Pick up an adjacent downed ally.", "Put down the ally you are carrying.", "Leave the battle from its retreat zone, taking any carried ally."][kind] + "\nCosts 1 shared action.\n" + SURVIVAL_HELP
		rescue.pressed.connect(func() -> void:
			if player != null: player.target_rescue(kind))
		rescue_buttons.append(rescue)
	preview_label = _text(actions, "", 15)
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attack_preview_label = _text(actions, "", 15)
	attack_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label = _text(actions, "", 14, MUTED)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.visible = false
	attack_preview_label.visible = false
	controller.feedback_changed.connect(_show_feedback)
	var history := _panel("CombatLogPanel", Vector4(1, 1, 1, 1), Vector4(-272, -244, -20, -20))
	_text(history, "COMBAT LOG", 16)
	_text(history, "Recent events · scroll for history", 12, MUTED)
	log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	history.add_child(log_scroll)
	log_label = _text(log_scroll, "", 14, Color(0.8, 0.85, 0.93))
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var help := _panel("HelpPanel", Vector4(0, 1, 0, 1), Vector4(20, -158, 272, -20))
	_text(help, "FIELD GUIDE", 12, MUTED)
	reference_label = _text(help,ControlBindings.compact(),12,MUTED)
	reference_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	reference_label.hide()
	var help_buttons := HBoxContainer.new()
	help.add_child(help_buttons)
	var focus := _button(help_buttons, "Focus [%s]" % ControlBindings.label("focus"))
	focus.set_meta("binding_id","focus")
	focus.set_meta("binding_caption","Focus")
	focus.pressed.connect(_focus_active)
	restart_button = _button(help_buttons, "Restart")
	restart_button.pressed.connect(_retry)
	var audio_button := _button(help_buttons,"Settings")
	audio_button.tooltip_text="Settings [%s]. Opens pause/settings; combat is frozen." % ControlBindings.label("audio")
	audio_button.pressed.connect(func() -> void:
		var service := get_tree().get_first_node_in_group("game_audio") as GameAudio
		if service!=null: service.show_settings())
	for help_button: Button in [focus,restart_button,audio_button]:
		help_button.add_theme_font_size_override("font_size",13)
	var objective_strip := PanelContainer.new()
	root.add_child(objective_strip)
	objective_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	objective_strip.offset_left=20; objective_strip.offset_right=272; objective_strip.offset_top=362; objective_strip.offset_bottom=430
	var objective_style := _style(PANEL,GOLD)
	objective_style.set_content_margin_all(4)
	objective_strip.add_theme_stylebox_override("panel",objective_style)
	objective_label=_text(objective_strip,"",14,GOLD)
	objective_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	objective_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	OathUI.decorate(move_button,"move")
	OathUI.decorate(attack_button,"attack")
	OathUI.decorate(button,"end_turn")
	_build_overlay()
	controller.encounter_updated.connect(_refresh)
	controller.state_changed.connect(func(_state: CombatController.State) -> void: _refresh())
	controller.encounter_reset.connect(_clear_presentation)

func _build_overlay() -> void:
	overlay = Control.new()
	overlay.name = "EncounterResult"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 270)
	panel.add_theme_stylebox_override("panel", _style(PANEL, GOLD))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	overlay_title = _text(content, "", 42, GOLD)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_summary = _text(content, "", 18)
	overlay_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	overlay_restart = _button(content, "Restart Encounter")
	overlay_restart.pressed.connect(_retry)
	overlay.visible = false

func _clear_presentation() -> void:
	tutorial_finished=false
	if root!=null and root.has_node("ReadableTooltips"): root.get_node("ReadableTooltips").hide()
	overlay.visible = false
	if code_overlay!=null: code_overlay.hide()
	_show_feedback("")
	show_preview(0, false, "")
	show_attack_preview("", 0, false, "")

func _focus_active() -> void:
	var rig := get_parent().get_node_or_null("TacticalCamera") as TacticalCamera
	if rig!=null: rig.control_used.emit("focus")
	var active := controller.scheduler.active_unit()
	if active != null and active.is_alive():
		get_viewport().get_camera_3d().get_parent().position = active.global_position

func bind_targeting(targeting: PlayerController) -> void:
	player = targeting
	move_button.pressed.connect(func() -> void: player.set_mode(PlayerController.Mode.MOVE))
	attack_button.pressed.connect(player.toggle_attack_targeting)
	player.mode_changed.connect(func(_mode: PlayerController.Mode) -> void: _refresh())
	player.attack_preview_changed.connect(show_attack_preview)
	player.area_preview_changed.connect(show_area_preview)

func bind_enemy(enemy: EnemyController) -> void:
	enemy.status_changed.connect(func(message: String) -> void:
		if not message.is_empty():
			_show_feedback(message))

func bind_log(history: CombatLog) -> void:
	history.changed.connect(func(entries: PackedStringArray) -> void:
		log_label.text = "\n\n".join(entries)
		log_scroll.set_deferred("scroll_vertical", 2147483647))

func _show_feedback(message: String) -> void:
	var tip := ""
	if "line of sight" in message.to_lower() or "obstruct" in message.to_lower(): tip="Reposition for a clear line. Walls block attacks; living units also block ranged shots."
	elif "out of" in message.to_lower() and "range" in message.to_lower(): tip="Move closer, or choose another target. Invalid actions spend nothing."
	elif "full health" in message.to_lower(): tip="Healing restores missing health and can revive downed or stabilised allies in campaign battles. Permanent deaths cannot be reversed."
	elif "no action remaining" in message.to_lower(): tip="Basic attacks and abilities share one action. You may still move with remaining metres."
	feedback_label.text = ControlBindings.instructions(message)+("\n"+tip if not tip.is_empty() else "")
	feedback_label.visible = not message.is_empty()

func show_attack_preview(target_name: String, distance: float, valid: bool, message: String) -> void:
	attack_preview_label.add_theme_font_size_override("font_size", 15)
	var active := controller.scheduler.active_unit() if controller.scheduler != null else null
	var attack := active.definition.basic_attack if active != null else null
	var ability := active.ability_by_id(player.selected_ability_id) if active != null and player != null and not player.selected_ability_id.is_empty() else null
	if ability != null:
		attack = ability
	var ranged := attack != null and attack.attack_type == AttackDefinition.Type.RANGED
	attack_preview_label.text = "" if message.is_empty() else ("%s · %.2f m %s · %s\n" % [target_name, distance, "range" if ability != null or (player != null and player.selected_rescue >= 0) else ("shot" if ranged else "gap"), "TARGET OK" if valid else "INVALID"] if not target_name.is_empty() else "") + message
	attack_preview_label.visible = not message.is_empty()
	attack_preview_label.add_theme_color_override("font_color", Color(0.45, 1, 0.75) if valid else Color(1, 0.65, 0.45))

func show_preview(distance: float, affordable: bool, message: String) -> void:
	var active := controller.scheduler.active_unit() if controller.scheduler != null else null
	var remaining := active.movement_remaining if active != null else 0.0
	preview_label.text = "" if message.is_empty() else "Route %.2f m / %.2f m left · %s\n%s" % [distance, remaining, "AFFORDABLE" if affordable else "INVALID", message]
	preview_label.visible = not message.is_empty()
	preview_label.add_theme_color_override("font_color", Color(0.45, 1, 0.75) if affordable else Color(1, 0.65, 0.45))

func _end_turn() -> void:
	var unit := controller.scheduler.active_unit()
	if unit != null:
		controller.submit_player_command(EndTurnCommand.new(unit.stable_id))

func _refresh_initiative(active: CombatUnit) -> void:
	var living_ids: Array[String] = []
	for unit in controller.scheduler.order:
		if unit.is_alive():
			living_ids.append(unit.stable_id)
	for id in initiative_cards.keys():
		if not living_ids.has(id):
			var card: Control = initiative_cards[id]
			initiative_row.remove_child(card)
			card.queue_free()
			initiative_cards.erase(id)
	for index in range(living_ids.size()):
		var id := living_ids[index]
		var unit := controller.find_unit(id)
		if not initiative_cards.has(id):
			var card := PanelContainer.new()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var content := VBoxContainer.new()
			card.add_child(content)
			var title:=_text(content,"",16)
			title.clip_text=true; title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			var stats:=_text(content,"",12,MUTED)
			stats.clip_text=true; stats.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			initiative_row.add_child(card)
			initiative_cards[id] = card
		var card: PanelContainer = initiative_cards[id]
		initiative_row.move_child(card, index)
		var selected := unit == active and controller.state not in [CombatController.State.VICTORY, CombatController.State.DEFEAT, CombatController.State.DRAW, CombatController.State.SETUP]
		var style := _style(Color(0.14, 0.16, 0.18) if selected else Color(0.075, 0.1, 0.15), GOLD if selected else Color(0.2, 0.27, 0.36))
		style.set_border_width_all(2 if selected else 1)
		card.add_theme_stylebox_override("panel", style)
		var content := card.get_child(0)
		content.get_child(0).text = ("> " if selected else "") + ("H · " if unit.faction == CombatUnit.Faction.HERO else "E · ") + unit.definition.display_name + (" [R]" if unit.role_label() == "Ranged" else " [M]")
		content.get_child(1).text = "%d initiative · %d/%d HP" % [unit.definition.initiative, unit.health, unit.definition.maximum_health]
		card.tooltip_text = "%s · %s%s" % [unit.definition.display_name, "Hero" if unit.faction == CombatUnit.Faction.HERO else "Enemy", " · ACTIVE" if selected else ""]

func _refresh() -> void:
	if controller.scheduler == null:
		return
	var active := controller.scheduler.active_unit()
	objective_label.text=controller.objectives.summary()
	round_label.text = "ROUND %d" % controller.scheduler.round_number
	_refresh_initiative(active)
	name_label.text = active.definition.display_name if active != null else "Preparing…"
	if active != null:
		faction_label.text = ("HERO" if active.faction == CombatUnit.Faction.HERO else "ENEMY") + " · " + active.definition.role + " · " + active.role_label().to_upper()
		health_bar.max_value = active.definition.maximum_health
		health_bar.value = active.health
		var fill := health_bar.get_theme_stylebox("fill") as StyleBoxFlat
		fill.bg_color = Color(0.3, 0.7, 1) if active.faction == CombatUnit.Faction.HERO else Color(1, 0.4, 0.35)
		label.text = "%d / %d HP  ·  %.2f / %.2f m\n%s" % [active.health, active.definition.maximum_health, active.movement_remaining, active.movement_granted, "Action READY · 1 / 1" if active.attack_available else "Action SPENT · 0 / 1"]
		if not active.status_text().is_empty():
			label.text += "\n" + active.status_text()
		if active.definition.basic_attack != null:
			label.text += "\n%s · %d damage" % [active.definition.basic_attack.range_label(), active.definition.basic_attack.damage]
	var terminal := controller.state in [CombatController.State.VICTORY, CombatController.State.DEFEAT, CombatController.State.DRAW]
	var available := controller.state == CombatController.State.AWAITING_COMMAND and active != null and active.is_alive() and active.faction == CombatUnit.Faction.HERO
	for index in range(ability_buttons.size()):
		var item := ability_buttons[index]
		item.visible = active != null and index < active.definition.abilities.size()
		if not item.visible:
			continue
		var ability := active.definition.abilities[index]
		OathUI.decorate(item,"aegisbearer" if ability.effect==AbilityDefinition.Effect.WARD else "chainbinder" if ability.effect in [AbilityDefinition.Effect.PULL,AbilityDefinition.Effect.TOW] else "health" if ability.effect==AbilityDefinition.Effect.HEAL else "fireburst" if ability.targeting==AbilityDefinition.Target.GROUND else "slow" if ability.applied_status!=null else "attack")
		var cooldown := active.cooldown_remaining(ability.stable_id)
		item.text = "%s [%s]\n%s" % [ability.display_name, ControlBindings.label("ability_"+str(index+1)), "COOLDOWN" if cooldown > 0 else "1 action"]
		item.tooltip_text = "%s\nCosts 1 shared action · blocks next %d owner turns\n%s" % [ability.description, ability.cooldown_turns, "Ready in %d owner turn start(s)" % cooldown if cooldown > 0 else ("Ready" if available and active.action_available else "Unavailable: action spent or not your turn")]
		item.disabled = not available or not active.action_available or cooldown > 0
		item.set_pressed_no_signal(player != null and player.selected_ability_id == ability.stable_id and available)
	rescue_row.visible = controller.survival_enabled
	for index in rescue_buttons.size():
		var rescue := rescue_buttons[index]
		rescue.disabled = not available or not active.action_available
		rescue.set_pressed_no_signal(available and player != null and player.selected_rescue == index)
	var ability_panel := root.get_node("AbilitiesPanel") as Control
	ability_panel.offset_top = -288 if controller.survival_enabled and active!=null and not active.definition.abilities.is_empty() else -244
	button.disabled = not available
	var minimum_move := controller.motor.arrival_tolerance if controller.motor != null else 0.005
	move_button.disabled = not available or active.movement_remaining <= minimum_move
	attack_button.disabled = not available or not active.attack_available or active.definition.basic_attack == null
	restart_button.disabled = controller.state == CombatController.State.SETUP or (encounter_configuration!=null and not encounter_configuration.deployment_id.is_empty())
	overlay_restart.disabled = restart_button.disabled
	var selected_mode := player.mode if player != null else PlayerController.Mode.NONE
	move_button.set_pressed_no_signal(available and selected_mode == PlayerController.Mode.MOVE)
	attack_button.set_pressed_no_signal(available and selected_mode == PlayerController.Mode.ATTACK and player.selected_ability_id.is_empty() and player.selected_rescue < 0)
	result_label.text = ""
	if terminal:
		result_label.text = controller.outcome_reason
	elif active != null and active.faction == CombatUnit.Faction.ENEMY and controller.state != CombatController.State.SETUP:
		result_label.text = "ENEMY TURN — automated"
	var reason := ""
	if terminal:
		reason = "Encounter complete. Restart to play again."
	elif controller.state == CombatController.State.SETUP:
		reason = "Preparing encounter…"
	elif not available:
		reason = "Action in progress — camera controls remain available." if controller.state == CombatController.State.RESOLVING_ACTION else "Enemy turn — watch their actions. Camera controls remain available."
	else:
		reason = ["Choose Move [%s] or Attack [%s]. %s cancels targeting." % [ControlBindings.label("move"),ControlBindings.label("attack"),ControlBindings.label("cancel")], "MOVE selected · hover ground, then click to commit.", "ATTACK selected · hover a unit, then click to strike."][selected_mode]
	if available and player != null and not player.selected_ability_id.is_empty():
		var ability := active.ability_by_id(player.selected_ability_id)
		if ability != null:
			reason = ("%s · select ground, then click ground again to CONFIRM. Esc cancels." if ability.targeting == AbilityDefinition.Target.GROUND else "%s selected · hover a unit, then click to use.") % ability.display_name
	if available and player != null and player.selected_rescue >= 0:
		reason = PlayerController.RESCUE_NAMES[player.selected_rescue] + " selected · hover a downed ally, then click to confirm. Esc cancels."
	mode_label.text = ControlBindings.instructions(reason).replace("Esc cancels",ControlBindings.label("cancel")+" cancels")
	mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.tooltip_text = "End this hero's turn [%s]" % ControlBindings.label("end_turn") if available else reason
	move_button.tooltip_text = "No movement remaining" if available and move_button.disabled else ("Preview and spend movement [%s]" % ControlBindings.label("move") if available else reason)
	attack_button.tooltip_text = "Action SPENT · 0 / 1" if available and not active.attack_available else ("Preview equipped attack [%s]" % ControlBindings.label("attack") if available else reason)
	if available and active.definition.basic_attack == null:
		attack_button.tooltip_text = "No melee attack is defined for this unit"
	overlay.visible = terminal
	if terminal:
		overlay_title.text = "DRAW" if controller.state == CombatController.State.DRAW else ("VICTORY" if controller.state == CombatController.State.VICTORY else "DEFEAT")
		var result := controller.result_summary
		var defeated_enemies: PackedStringArray=result.get("defeated_enemies",PackedStringArray())
		var defeated_heroes: PackedStringArray=result.get("defeated_heroes",PackedStringArray())
		var setup := (encounter_configuration.difficulty.display_name if encounter_configuration!=null else "Standard")+" / "+controller.objectives.definition.display_name
		overlay_summary.text=setup+"\n"+controller.outcome_reason+"\nRounds completed: %d (ended in round %d)"%[controller.completed_rounds,controller.scheduler.round_number]+"\nEnemies defeated: "+(", ".join(defeated_enemies) if not defeated_enemies.is_empty() else "None")+"\nHeroes defeated: "+(", ".join(defeated_heroes) if not defeated_heroes.is_empty() else "None")

		if tutorial_finished: overlay_summary.text+="\nTutorial complete! Replay any time from the title."

func show_area_preview(message: String, valid: bool) -> void:
	attack_preview_label.add_theme_font_size_override("font_size", 14)
	attack_preview_label.text = ControlBindings.instructions(message)
	attack_preview_label.visible = not message.is_empty()
	attack_preview_label.add_theme_color_override("font_color", Color(1, 0.8, 0.4) if valid else Color(1, 0.5, 0.35))

func _retry() -> void:
	if flow_enabled:
		flow_requested.emit("retry")
	else:
		controller.restart_encounter()

func bind_flow(seed_value: int, config: EncounterConfiguration = null) -> void:
	encounter_configuration=config
	assert(not flow_enabled)
	flow_enabled = true
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info_host.add_child(info)
	seed_label = _text(info, "%s / Seed: %d" % [config.difficulty.display_name if config!=null else "Standard",seed_value], 12, GOLD)
	var links := HBoxContainer.new()
	info.add_child(links)
	if config!=null:
		code_button=_button(links,"Code")
		code_button.custom_minimum_size=Vector2(70,26)
		code_button.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		code_button.clip_text=false
		code_button.add_theme_font_size_override("font_size",12)
		code_overlay=EncounterCodeOverlay.new()
		root.add_child(code_overlay)
		code_button.pressed.connect(func() -> void:
			if player!=null: player.cancel_targeting()
			var code := EncounterCode.encode(encounter_configuration)
			code_overlay.show_code(code)
			if use_native_clipboard and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD): DisplayServer.clipboard_set(code))
	var menu := _button(links, "Pause [%s]"%ControlBindings.label("pause"))
	menu.custom_minimum_size = Vector2(125,28)
	menu.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	menu.clip_text=false
	menu.add_theme_font_size_override("font_size",12)
	menu.set_meta("binding_id","pause")
	menu.set_meta("binding_caption","Pause")
	menu.pressed.connect(func() -> void:
		var owner := get_tree().get_first_node_in_group("game_audio") as GameAudio
		if owner!=null: owner.show_settings())
	restart_button.text = "Retry"
	overlay_restart.text = "Retry Battlefield"
	result_flow_buttons["retry"] = overlay_restart
	for action in ["new_battlefield", "change_party", "main_menu"]:
		var key: String = action
		var item := _button(overlay_restart.get_parent(), "Change Setup" if action=="change_party" else action.replace("_", " ").capitalize())
		item.pressed.connect(func() -> void: flow_requested.emit(key))
		result_flow_buttons[key] = item

func add_guidance(encounter: CombatEncounter) -> void:
	var box := root.get_node("HelpPanel").get_child(0).get_child(0) as VBoxContainer
	var row := HBoxContainer.new()
	box.add_child(row)
	var help := _button(row,"Help [%s]" % ControlBindings.label("help"))
	help.set_meta("binding_id","help")
	help.set_meta("binding_caption","Help")
	help.pressed.connect(encounter.show_help)
	var briefing := _button(row,"Briefing")
	briefing.pressed.connect(encounter.show_briefing)
	label.mouse_filter=Control.MOUSE_FILTER_PASS
	round_label.mouse_filter=Control.MOUSE_FILTER_PASS
	objective_label.mouse_filter=Control.MOUSE_FILTER_PASS
	label.tooltip_text="Movement follows the full navigation route. Basic attacks and abilities share ONE action. Movement resets only at this unit's next turn start."
	round_label.tooltip_text="Living units act by descending initiative, regardless of faction. Stable unit IDs break ties. One round ends after every scheduled living unit has acted."
	objective_label.tooltip_text=FieldGuide.objective(controller.objectives.definition) + ("\n\n" + SURVIVAL_HELP if controller.survival_enabled else "")
	var tooltips := ReadableTooltips.new()
	tooltips.name="ReadableTooltips"
	root.add_child(tooltips)
	tooltips.bind_tree(root)

func apply_preferences(_owner: GameAudio) -> void:
	if controller==null or button==null: return
	move_button.text="Move [%s]"%ControlBindings.label("move")
	attack_button.text="Attack [%s]"%ControlBindings.label("attack")
	button.text="End Turn [%s]"%ControlBindings.label("end_turn")
	reference_label.text=ControlBindings.compact()
	_refresh()

func _fit_layout() -> void:
	if root==null: return
	# Anchored centre strips expand on wide displays; side panels keep readable type.
	var half := minf(390,(root.size.x-600)*.5)
	for id in ["ActionsPanel","AbilitiesPanel"]:
		var panel := root.get_node_or_null(id) as Control
		if panel!=null: panel.offset_left=-half;panel.offset_right=half
