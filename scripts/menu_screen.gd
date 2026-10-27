class_name MenuScreen
extends Control

signal requested(action: String)
const GOLD: Color = OathUI.GOLD
var model: PartySelection
var cards: Dictionary = {}
var card_titles: Dictionary = {}
var selected_label: Label
var message: Label
var start_button: Button
var new_button: Button
var back_button: Button
var faction_selector: OptionButton
var elite_toggle: CheckButton
var preset_selector: OptionButton
var objective_selector: OptionButton
var objective_description: Label
var difficulty_selector: OptionButton
var difficulty_description: Label
var summary_label: Label
var seed_input: LineEdit
var code_input: LineEdit
var copy_code_button: Button
var import_code_button: Button
var randomize_button: Button
var use_native_clipboard: bool = true
var settings_scroll: ScrollContainer
var _updating: bool = false
var tutorial_suggestion: Label
var quit_button: Button
var title_box: VBoxContainer

func _style(selected: bool = false) -> StyleBoxFlat:
	return OathUI.panel(selected)

func _label(parent: Node, text: String, size: int = 18, color: Color = OathUI.PAPER) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	if size>=22: item.theme_type_variation="OathHeading"
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func _button(parent: Node, text: String, action: String) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size = Vector2(180, 44)
	item.add_theme_font_size_override("font_size", 18)
	parent.add_child(item)
	OathUI.decorate(item,"play" if action in ["new_campaign","start_encounter","new_encounter"] else ("settings" if action=="audio_settings" else "help" if action=="controls" else "back" if action in ["main_menu","back"] else "lantern"))
	item.pressed.connect(func() -> void: requested.emit(action))
	return item

func _background() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme=OathUI.theme()
	var background := OathBackdrop.new()
	background.name="OathBackdrop"
	add_child(background)
	OathUI.reveal(self)

func title(game_name: String) -> void:
	_background()
	get_node("OathBackdrop").title_art=true
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.anchor_right=.52
	center.offset_left=28
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, minf(650,get_viewport_rect().size.y-40))
	panel.add_theme_stylebox_override("panel", _style(true))
	center.add_child(panel)
	var box := VBoxContainer.new()
	title_box=box
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	var title_scroll := ScrollContainer.new()
	title_scroll.follow_focus=true
	title_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(title_scroll)
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title_scroll.add_child(box)
	var crest := _label(box, "THE LANTERN OATH", 16, GOLD)
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var heading := _label(box, game_name, 38, GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _label(box, "Hold the line. Rekindle the last beacon.", 17, Color(0.7, 0.78, 0.85))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(box,"New Campaign","new_campaign")
	new_button = _button(box, "Skirmish", "new_encounter")
	_button(box,"Tutorial","tutorial")
	_button(box,"Controls & Help","controls")
	tutorial_suggestion=_label(box,"New here? Try the short guided tutorial, or start a skirmish.",14,GOLD)
	tutorial_suggestion.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_button(box,"Settings [%s]" % ControlBindings.label("audio"),"audio_settings")
	quit_button = _button(box, "Quit", "quit")

func show_campaign_save(info: Dictionary) -> void:
	var button := _button(title_box,"Recover Backup" if info.status=="backup" else "Continue Campaign","campaign_continue")
	button.disabled=info.status not in ["valid","backup"]
	title_box.move_child(button,3)
	var description := _label(title_box,info.description,14,GOLD)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title_box.move_child(description,4)

func party(selection: PartySelection) -> void:
	model = selection
	_background()
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var title_label := _label(heading, "CHOOSE YOUR COMPANIONS", 28, GOLD)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_label = _label(heading, "", 20, GOLD)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation",14)
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for definition in HeroCatalog.definitions():
		var id := definition.selection_id
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 190)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.focus_mode = Control.FOCUS_ALL
		card.add_theme_stylebox_override("focus",_style(true))
		grid.add_child(card)
		cards[id] = card
		var card_scroll := ScrollContainer.new()
		card_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		card_scroll.mouse_filter=Control.MOUSE_FILTER_PASS
		card.add_child(card_scroll)
		card_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_scroll.offset_left=12; card_scroll.offset_top=10; card_scroll.offset_right=-12; card_scroll.offset_bottom=-10
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP,KEY_PAGEDOWN]:
				card_scroll.scroll_vertical+=-80 if event.keycode==KEY_PAGEUP else 80
				card.accept_event())
		var row := HBoxContainer.new()
		row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card_scroll.add_child(row)
		row.add_theme_constant_override("separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var portrait := CharacterPortrait.new()
		row.add_child(portrait)
		portrait.setup(definition.visual_id)
		portrait.custom_minimum_size=Vector2(85,142)
		var content := VBoxContainer.new()
		row.add_child(content)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_titles[id] = _label(content, definition.display_name, 21, GOLD)
		card_titles[id].autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		_label(content, definition.role.to_upper(), 14, Color(0.7, 0.85, 0.9))
		var stats := _label(content, "%d health · %.0f m movement · %d initiative" % [definition.maximum_health, definition.movement_allowance, definition.initiative], 14)
		stats.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var attack := definition.basic_attack
		var basic := _label(content, "%s: %d damage · %s · %s" % [attack.display_name, attack.damage, attack.type_label(), attack.range_label()], 14)
		basic.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var names: PackedStringArray = []
		var descriptions: PackedStringArray = []
		for ability in definition.abilities:
			names.append(ability.display_name)
			descriptions.append(ability.display_name + ": " + ability.description)
		var abilities := _label(content, "Abilities: " + ", ".join(names), 14)
		abilities.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.tooltip_text = "\n".join(descriptions)
		card.pressed.connect(func() -> void:
			if not is_queued_for_deletion():
				model.toggle(id))
	var settings_panel := PanelContainer.new()
	settings_panel.custom_minimum_size.x=366
	settings_panel.add_theme_stylebox_override("panel",_style())
	body.add_child(settings_panel)
	var scroll := ScrollContainer.new()
	settings_scroll=scroll
	scroll.follow_focus=true
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	settings_panel.add_child(scroll)
	var settings := VBoxContainer.new()
	settings.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	settings.add_theme_constant_override("separation",5)
	scroll.add_child(settings)
	_build_setup(settings)
	message = _label(box, "", 16, Color(0.85, 0.8, 0.65))
	message.custom_minimum_size.y = 26
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	back_button = _button(buttons, "Back", "main_menu")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	start_button = _button(buttons, "Start Encounter", "start_encounter")
	model.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	if is_queued_for_deletion():
		return
	selected_label.text = "Selected: %d / 2" % model.selected.size()
	start_button.disabled = not model.ready()
	_refresh_setup()
	start_button.tooltip_text = "Choose exactly two distinct companions." if start_button.disabled else "Generate a battlefield for this party."
	message.text = model.code_feedback if not model.code_feedback.is_empty() else (model.validation_error() if not model.ready() else model.feedback)
	for id in cards:
		var card: Button = cards[id]
		var selected := model.selected.has(id)
		card.disabled = model.party_ready() and not selected
		card.add_theme_stylebox_override("normal", _style(selected))
		card.add_theme_stylebox_override("disabled", _style(false))
		card.add_theme_stylebox_override("hover", _style(true))
		card.add_theme_stylebox_override("pressed", _style(true))
		card_titles[id].text = ("✓ SELECTED · " if selected else "") + HeroCatalog.find(id).display_name

func _compact(parent: Node,text: String,callback: Callable) -> Button:
	var item := Button.new()
	item.text=text
	item.custom_minimum_size.y=32
	item.add_theme_font_size_override("font_size",14)
	parent.add_child(item)
	item.pressed.connect(callback)
	return item

func _build_setup(side: VBoxContainer) -> void:
	_label(side,"ENEMY FACTION",13,GOLD)
	faction_selector=OptionButton.new(); faction_selector.add_item("Random faction")
	for faction in FactionCatalog.list(): faction_selector.add_item(faction.display_name)
	side.add_child(faction_selector)
	var faction_index:=FactionCatalog.ids().find(model.faction_choice)
	faction_selector.select(faction_index+1)
	faction_selector.item_selected.connect(func(index: int) -> void:
		model.faction_choice="random" if index==0 else FactionCatalog.ids()[index-1]
		model.imported_configuration=null; model.edited())
	elite_toggle=CheckButton.new(); elite_toggle.text="Elite encounter · warned area attack"; elite_toggle.button_pressed=model.elite_choice; side.add_child(elite_toggle)
	elite_toggle.toggled.connect(func(value: bool) -> void:
		model.elite_choice=value; model.imported_configuration=null; model.edited())
	_compact(side,"Enemy Reference",func() -> void: requested.emit("bestiary"))
	_label(side,"BATTLEFIELD",13,GOLD)
	preset_selector=OptionButton.new()
	for preset in EncounterOptions.presets(): preset_selector.add_item(preset.display_name)
	side.add_child(preset_selector)
	preset_selector.item_selected.connect(func(index: int) -> void:
		model.preset_index=index
		model.edited())
	_label(side,"OBJECTIVE",13,GOLD)
	objective_selector=OptionButton.new()
	for objective in EncounterOptions.objectives(): objective_selector.add_item(objective.display_name)
	side.add_child(objective_selector)
	objective_description=_label(side,"",13,Color(.7,.85,.9))
	objective_description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	objective_selector.item_selected.connect(func(index: int) -> void:
		model.objective_index=index
		model.edited())
	_label(side,"DIFFICULTY",13,GOLD)
	difficulty_selector=OptionButton.new()
	for difficulty in EncounterOptions.difficulties(): difficulty_selector.add_item(difficulty.display_name)
	side.add_child(difficulty_selector)
	difficulty_description=_label(side,"",13,Color(.7,.85,.9))
	difficulty_description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	difficulty_selector.item_selected.connect(func(index: int) -> void:
		model.difficulty_index=index
		model.edited())
	_label(side,"BATTLEFIELD SEED (optional)",13,GOLD)
	var seed_row := HBoxContainer.new()
	side.add_child(seed_row)
	seed_input=LineEdit.new()
	seed_input.placeholder_text="Random on Start"
	seed_input.max_length=32
	seed_input.custom_minimum_size.x=190
	seed_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	seed_row.add_child(seed_input)
	seed_input.text_changed.connect(func(value: String) -> void:
		if _updating: return
		model.seed_text=value
		model.edited())
	randomize_button=_compact(seed_row,"Randomize",func() -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		model.preview_seed=rng.randi()
		model.seed_text=str(model.preview_seed)
		model.edited())
	_label(side,"ENCOUNTER SUMMARY",13,GOLD)
	summary_label=_label(side,"",13)
	summary_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_label(side,"SHARE SETUP (not a combat save)",13,GOLD)
	code_input=LineEdit.new()
	code_input.placeholder_text="Paste an FT1 encounter code"
	code_input.max_length=EncounterCode.MAX_CODE
	side.add_child(code_input)
	var code_buttons := HBoxContainer.new()
	side.add_child(code_buttons)
	copy_code_button=_compact(code_buttons,"Copy code",func() -> void:
		if not model.ready(): return
		if model.seed_text.strip_edges().is_empty():
			model.seed_text=str(model.preview_seed)
			model.changed.emit()
		var config := model.configuration(model.preview_seed)
		var code := EncounterCode.encode(config)
		code_input.text=code
		code_input.grab_focus()
		code_input.select_all()
		model.code_feedback="Code selected. Copy it and paste into another setup."
		if use_native_clipboard and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
			DisplayServer.clipboard_set(code)
			if DisplayServer.clipboard_get()==code: model.code_feedback="Configuration code copied."
		_refresh())
	import_code_button=_compact(code_buttons,"Import",func() -> void: model.import_code(code_input.text))

func _refresh_setup() -> void:
	if seed_input==null: return
	_updating=true
	seed_input.text=model.seed_text
	preset_selector.select(model.preset_index)
	objective_selector.select(model.objective_index)
	difficulty_selector.select(model.difficulty_index)
	_updating=false
	var difficulty := EncounterOptions.difficulties()[model.difficulty_index]
	var objective := EncounterOptions.objectives()[model.objective_index]
	if model.imported_configuration!=null:
		if model.imported_configuration.difficulty.stable_id==difficulty.stable_id: difficulty=model.imported_configuration.difficulty
		if model.imported_configuration.objective.stable_id==objective.stable_id: objective=model.imported_configuration.objective
	objective_description.text=objective.description
	difficulty_description.text=difficulty.description
	copy_code_button.disabled=not model.ready()
	var names: PackedStringArray=[]
	for id in model.selected: names.append(HeroCatalog.find(id).display_name)
	var seed_value := model.seed_text.to_int() if not model.seed_text.strip_edges().is_empty() else model.preview_seed
	var resolved:=FactionCatalog.choose(model.faction_choice,seed_value)
	var roster:=FactionCatalog.roster(resolved,difficulty.stable_id,3,model.elite_choice,seed_value)
	if model.imported_configuration!=null:
		resolved=model.imported_configuration.faction_id
		roster=model.imported_configuration.resolved_enemy_ids
	var faction_name:=FactionCatalog.find(resolved).display_name if FactionCatalog.find(resolved)!=null else "Legacy opposing party"
	summary_label.text="Party: %s\n%s / %s / %s\nSeed: %d%s\n%s%s · %d enemies:\n%s"%[" + ".join(names) if not names.is_empty() else "Choose two",EncounterOptions.presets()[model.preset_index].display_name,objective.display_name,difficulty.display_name,seed_value," (random)" if model.seed_text.strip_edges().is_empty() else "",faction_name," · ELITE" if model.elite_choice else "",roster.size(),difficulty.roster_summary(roster)]

func set_tutorial_suggestion(show_suggestion: bool) -> void:
	if tutorial_suggestion!=null: tutorial_suggestion.visible=show_suggestion
