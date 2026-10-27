class_name EnemyReference
extends MenuScreen
var faction_choice: OptionButton
var unit_choice: OptionButton
var content: HBoxContainer
func open() -> void:
	_background()
	var margin:=MarginContainer.new(); add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,24)
	var box:=VBoxContainer.new(); margin.add_child(box)
	_label(box,"ENEMY REFERENCE",28,GOLD)
	var warning:=_label(box,"! Elite warnings lock their location. Leave the outlined area before that elite's next turn. Allies and caster can also be hit. Defeating the elite cancels its warning.",17)
	warning.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	faction_choice=OptionButton.new(); box.add_child(faction_choice)
	for faction in FactionCatalog.list(): faction_choice.add_item(faction.display_name)
	unit_choice=OptionButton.new(); box.add_child(unit_choice)
	var scroll:=ScrollContainer.new(); scroll.follow_focus=true; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; box.add_child(scroll)
	content=HBoxContainer.new(); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(content)
	faction_choice.item_selected.connect(func(_index: int) -> void: choose_faction())
	unit_choice.item_selected.connect(func(_index: int) -> void: show_unit())
	_button(box,"Close Reference","close_reference").pressed.connect(queue_free)
	choose_faction(); faction_choice.grab_focus()
func choose_faction() -> void:
	unit_choice.clear()
	var faction:=FactionCatalog.list()[faction_choice.selected]
	for id in Array(faction.regular_ids)+[faction.elite_id]: unit_choice.add_item(EnemyCatalog.find(id).display_name)
	unit_choice.select(0); show_unit()
func show_unit() -> void:
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	var faction:=FactionCatalog.list()[faction_choice.selected]
	var ids: Array=Array(faction.regular_ids)+[faction.elite_id]
	var unit:=EnemyCatalog.find(ids[unit_choice.selected])
	var portrait:=CharacterPortrait.new(); content.add_child(portrait); portrait.setup(unit.visual_id)
	var details:=VBoxContainer.new(); details.size_flags_horizontal=Control.SIZE_EXPAND_FILL; content.add_child(details)
	var lines: PackedStringArray=[faction.description,"%s [%s] · %s%s"%[unit.display_name,unit.role_icon,unit.role," · ELITE" if unit.is_elite else ""],"Base values: %d HP · %.1f m movement · %d initiative"%[unit.maximum_health,unit.movement_allowance,unit.initiative],"Difficulty scales enemy health/offensive damage only. Mission briefings show adjusted values.","%s: %d damage · %s · %s"%[unit.basic_attack.display_name,unit.basic_attack.damage,unit.basic_attack.type_label(),unit.basic_attack.range_label()],"Strength: "+unit.strengths,"Weakness: "+unit.weaknesses]
	for ability in unit.abilities:
		lines.append("%s: %d %s · %.1f m range · cooldown %d subsequent owner turns%s"%[ability.display_name,ability.magnitude,"healing" if ability.effect==AbilityDefinition.Effect.HEAL else "damage",ability.maximum_range,ability.cooldown_turns," · PREPARE, then resolve at next owner turn" if ability.telegraphed else ""])
	for line in lines:
		var label:=_label(details,line,18); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
