class_name AudioSettingsPanel
extends Control
## One transactional settings/pause interface, retaining the existing service API.
var audio: Node
var sliders: Dictionary={}
var mutes: Dictionary={}
var values: Dictionary={}
var widgets: Dictionary={}
var card: PanelContainer
var notice: Label
var heading: Label
var tabs: TabContainer
var apply_button: Button
var cancel_button: Button
var reset_button: Button
var confirm: PanelContainer
var confirm_label: Label
var capture_label: Label
var capture_buttons: HBoxContainer
var capture_id: String=""
var candidate: String=""
var conflicts: PackedStringArray=[]
var remaining: float=0
var confirmation_seconds: float=12.0
var display_checkpoint: Dictionary={}
var updating: bool=false
var test_headless_display: bool=false
func label_for(parent: Node,caption: String) -> Label:
	var label := Label.new()
	label.text=caption
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label
func button(parent: Node,caption: String,callback: Callable) -> Button:
	var item := Button.new()
	item.text=caption
	item.set_meta("caption",caption)
	item.custom_minimum_size.y=40
	item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	item.clip_text=true
	parent.add_child(item)
	item.pressed.connect(callback)
	return item
func bind(service: Node) -> void:
	theme=OathUI.theme()
	audio=service
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color=Color(.01,.02,.035,.93)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card=PanelContainer.new()
	add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.offset_left=48; card.offset_right=-48; card.offset_top=24; card.offset_bottom=-24
	var style := OathUI.panel(true)
	style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel",style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	card.add_child(box)
	heading = label_for(box,"SETTINGS · combat is paused while this screen is open")
	heading.theme_type_variation="OathHeading"
	heading.add_theme_font_size_override("font_size",24)
	heading.text+=" · PgUp/PgDn categories · Tab fields"
	tabs=TabContainer.new()
	tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	for category in ["Display","Audio","Controls","Camera","Accessibility"]:
		var scroll := ScrollContainer.new()
		scroll.name=category
		scroll.follow_focus=true
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		var content := VBoxContainer.new()
		content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation",14)
		scroll.add_child(content)
		build_category(category,content)
	notice=label_for(box,"")
	notice.custom_minimum_size.y=38
	capture_label=label_for(box,"")
	capture_label.hide()
	capture_buttons=HBoxContainer.new()
	box.add_child(capture_buttons)
	button(capture_buttons,"Swap",func() -> void: resolve_binding("swap"))
	button(capture_buttons,"Replace",func() -> void: resolve_binding("replace"))
	button(capture_buttons,"Cancel Capture [Esc]",cancel_capture)
	capture_buttons.hide()
	var row := HBoxContainer.new()
	box.add_child(row)
	reset_button=button(row,"Reset Category",reset_category)
	apply_button=button(row,"Apply",accept)
	cancel_button=button(row,"Cancel / Resume",close)
	button(row,"Main Menu",func() -> void:
		var encounter: Node = audio.get("settings_encounter")
		close()
		if is_instance_valid(encounter): encounter.emit_signal("flow_requested","main_menu")
		else:
			var flow: Node = get_tree().get_first_node_in_group("scene_flow")
			if flow!=null: flow.call("request_transition","main_menu"))
	confirm=PanelContainer.new()
	add_child(confirm)
	confirm.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	confirm.offset_left=-310; confirm.offset_right=310; confirm.offset_top=-95; confirm.offset_bottom=95
	confirm.add_theme_stylebox_override("panel",style)
	var confirmation := VBoxContainer.new()
	confirm.add_child(confirmation)
	confirm_label=label_for(confirmation,"")
	var choices := HBoxContainer.new()
	confirmation.add_child(choices)
	button(choices,"Keep Display",keep_display)
	button(choices,"Revert",revert_display)
	confirm.hide()
	hide()
func build_category(category: String,box: VBoxContainer) -> void:
	match category:
		"Display":
			label_for(box,"Display changes require confirmation within 12 seconds. Exclusive fullscreen is offered on Windows. Cosmetic quality changes apply immediately; they never rebuild gameplay geometry or require an encounter reload.")
			choice(box,category,"mode","Window mode",["Windowed","Borderless fullscreen","Exclusive fullscreen (Windows)"])
			choice(box,category,"resolution","Windowed resolution",["1280 × 720","1600 × 900","1920 × 1080"])
			toggle(box,category,"vsync","VSync")
			choice(box,category,"fps","Frame limit",["Unlimited","30","60","120","144"],[0,30,60,120,144])
			choice(box,category,"graphics","Cosmetic quality",["Low · no shadows or AA, fewer plants","Standard · sun shadows, 2× AA","High · sun shadows, 4× AA, full plants"])
		"Audio":
			label_for(box,"Volumes preview immediately. Apply saves; Cancel restores all volumes and mute states. Combat cues also have text and visual equivalents.")
			for bus in audio.call("get_buses"):
				range_row(box,category,bus,bus+" volume",0,100,1,true)
				toggle(box,category,bus+"_mute",bus+" mute")
			button(box,"Play Test Sound (replaces previous test)",audio.play_test_sound)
		"Controls":
			label_for(box,"Select an action, then press a single key or mouse button. Escape cancels capture. F10 always opens settings; Escape always cancels targeting. These safety bindings cannot be assigned to other actions. Conflicts require an explicit swap, replace or cancellation. Tab, Enter and Space are reserved for interface navigation. Controller and modifier-chord rebinding are not included.")
			for id: String in audio.preferences.Controls:
				var action: String=id
				var item := button(box,"",func() -> void: begin_capture(action))
				widgets[category+"/"+id]=item
		"Camera":
			range_row(box,category,"shake","Impact shake (0 disables)",0,1,.05)
			for pair: Array in [["orbit","Orbit sensitivity"],["pan","Pan sensitivity"],["zoom","Zoom sensitivity"],["edge_speed","Edge-scroll speed"]]: range_row(box,category,pair[0],pair[1],.25,2,.05)
			for pair: Array in [["invert_x","Invert horizontal orbit"],["invert_y","Invert vertical orbit"],["edge","Enable edge scrolling"],["reduced_motion","Reduced camera motion (no automatic framing or shake)"]]: toggle(box,category,pair[0],pair[1])
		"Accessibility":
			range_row(box,category,"ui_scale","Interface scale",.85,1.15,.05)
			toggle(box,category,"large_text","Larger text")
			toggle(box,category,"high_contrast","High-contrast indicators and outlines")
			toggle(box,category,"reduced_effects","Reduced effects · suppress flashes and decorative bursts")
			range_row(box,category,"combat_text","Damage / healing / status text size",.8,1.5,.1)
			label_for(box,"Faction letters, ACTIVE / OK / NO / ALLY HIT labels, status names, objective progress and the combat log remain available. Reduced effects keep targeting areas and damage feedback visible.")
func range_row(box: VBoxContainer,category: String,key: String,caption: String,minimum: float,maximum: float,step: float,percent: bool=false) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := label_for(row,caption)
	label.custom_minimum_size.x=260
	var slider := HSlider.new()
	slider.min_value=minimum; slider.max_value=maximum; slider.step=step
	slider.custom_minimum_size=Vector2(200,40)
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var number := label_for(row,"")
	number.custom_minimum_size.x=70
	number.size_flags_horizontal=Control.SIZE_SHRINK_END
	widgets[category+"/"+key]=slider
	if percent: sliders[key]=slider; values[key]=number
	slider.value_changed.connect(func(value: float) -> void:
		number.text=("%d%%"%roundi(value)) if percent else "%.2f×"%value
		if not updating: change(category,key,value/100.0 if percent else value))
	slider.set_meta("number",number)
	slider.set_meta("percent",percent)
func toggle(box: VBoxContainer,category: String,key: String,caption: String) -> void:
	var item := CheckButton.new()
	item.set_meta("caption",caption)
	item.text=caption
	item.custom_minimum_size.y=40
	box.add_child(item)
	widgets[category+"/"+key]=item
	if category=="Audio": mutes[key.trim_suffix("_mute")]=item
	item.toggled.connect(func(value: bool) -> void:
		if not updating: change(category,key,value))
func choice(box: VBoxContainer,category: String,key: String,caption: String,options: Array,ids: Array=[]) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	label_for(row,caption)
	var item := OptionButton.new()
	item.custom_minimum_size=Vector2(360,42)
	row.add_child(item)
	for index in range(options.size()): item.add_item(str(options[index]),ids[index] if not ids.is_empty() else index)
	widgets[category+"/"+key]=item
	item.item_selected.connect(func(index: int) -> void:
		if not updating: change(category,key,item.get_item_id(index)))
func refresh() -> void:
	updating=true
	for path: String in widgets:
		var pieces := path.split("/")
		var value: Variant=audio.preferences[pieces[0]][pieces[1]]
		var widget: Control=widgets[path]
		if pieces[0]=="Controls": widget.text=pieces[1].replace("_"," ").capitalize()+"  ·  "+ControlBindings.label(pieces[1])
		elif widget is HSlider:
			widget.set_value_no_signal(float(value)*(100 if widget.get_meta("percent") else 1))
			widget.get_meta("number").text=("%d%%"%roundi(widget.value)) if widget.get_meta("percent") else "%.2f×"%widget.value
		elif widget is CheckButton:
			widget.set_pressed_no_signal(value)
			widget.text=str(widget.get_meta("caption"))+" · "+("On" if value else "Off")
		elif widget is OptionButton:
			for index in range(widget.item_count):
				if widget.get_item_id(index)==int(value): widget.select(index)
	var factor: float=audio.preferences.Accessibility.ui_scale*(1.15 if audio.preferences.Accessibility.large_text else 1.0)
	var theme := Theme.new()
	theme.default_font_size=roundi(17*factor)
	var focus := StyleBoxFlat.new()
	focus.bg_color=Color(0,0,0,0); focus.border_color=Color(1,.85,.25); focus.set_border_width_all(3)
	for type in ["Button","CheckButton","OptionButton","HSlider","TabBar"]: theme.set_stylebox("focus",type,focus)
	card.theme=theme
	updating=false
func change(category: String,key: String,value: Variant) -> void:
	if remaining>0 or not capture_id.is_empty(): return
	audio.preview(category,key,value)
	if category=="Display" and key in ["mode","resolution"]: request_display()
	refresh()
func request_display() -> void:
	if not audio.apply_display(audio.preferences.Display):
		audio.preferences.Display=display_checkpoint.duplicate(true)
		audio.apply_display(display_checkpoint)
		notice.text="Display setting is unsupported or could not be applied. Previous display restored."
		return
	remaining=confirmation_seconds
	confirm.show()
	apply_button.disabled=true
	confirm.get_child(0).get_child(1).get_child(1).grab_focus()
func keep_display() -> void:
	display_checkpoint=audio.preferences.Display.duplicate(true)
	remaining=0; confirm.hide(); apply_button.disabled=false
	notice.text="Display preview confirmed. Apply to save it; Cancel still restores the opening settings."
	apply_button.grab_focus()
func revert_display() -> void:
	audio.preferences.Display=display_checkpoint.duplicate(true)
	audio.apply_display(display_checkpoint)
	remaining=0; confirm.hide(); apply_button.disabled=false
	refresh()
	notice.text="Display reverted. Nothing was saved."
	apply_button.grab_focus()
func _process(delta: float) -> void:
	if not visible or remaining<=0: return
	remaining=maxf(0,remaining-delta)
	confirm_label.text="Keep this display? Reverting in %d seconds."%ceili(remaining)
	if remaining<=0: revert_display()
func open() -> void:
	if visible: return
	audio.begin_settings()
	display_checkpoint=audio.preferences.Display.duplicate(true)
	remaining=0; confirm.hide(); cancel_capture()
	heading.text=("PAUSED · SETTINGS" if audio.settings_encounter!=null else "SETTINGS")+" · PgUp/PgDn categories · Tab fields"
	if audio.settings_encounter!=null and audio.settings_encounter.get_node("CombatController").call("encounter_has_ended"): heading.text="ENCOUNTER COMPLETE · SETTINGS"
	show(); refresh()
	notice.text="Apply saves all categories. Cancel restores the opening values. F10 / Escape cancels. Tutorial completion is retained."
	if not str(audio.preferences_warning).is_empty(): notice.text+="\n"+str(audio.preferences_warning)
	cancel_button.grab_focus()
func close() -> void:
	if not visible: return
	remaining=0; confirm.hide(); cancel_capture()
	audio.finish_settings(false)
	hide()
	get_viewport().gui_release_focus()
func accept() -> void:
	if remaining>0 or not capture_id.is_empty(): return
	if audio.finish_settings(true): hide()
	else: notice.text=audio.preferences_warning
func reset_category() -> void:
	if remaining>0: return
	cancel_capture()
	var category := tabs.get_tab_title(tabs.current_tab)
	audio.preferences[category]=SettingsSchema.defaults()[category]
	audio.apply_preferences(false)
	if category=="Display": request_display()
	refresh()
	notice.text="Category defaults previewed. Apply to save, or Cancel to restore. Tutorial completion is unchanged."
func begin_capture(id: String) -> void:
	capture_id=id; candidate=""; conflicts.clear()
	capture_label.text="Bind %s: press a single key or mouse button. Escape cancels. F10 remains the safety menu key."%id
	capture_label.show(); capture_buttons.show()
	capture_buttons.get_child(0).disabled=true; capture_buttons.get_child(1).disabled=true
func cancel_capture() -> void:
	capture_id=""; candidate=""; conflicts.clear()
	if capture_label!=null: capture_label.hide(); capture_buttons.hide()
func capture(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event is InputEventKey and (event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE): cancel_capture(); return
	var token := SettingsSchema.event_token(event)
	if token.is_empty(): capture_label.text="Use a single key or mouse button; Escape cancels. Modifier chords are not supported."; return
	if token in ["K:%d"%KEY_TAB,"K:%d"%KEY_SPACE,"K:%d"%KEY_ENTER,"K:%d"%KEY_KP_ENTER]:
		capture_label.text="That key is reserved for interface navigation. Choose another, or Escape to cancel."; return
	if (token=="K:%d"%KEY_F10 and capture_id!="audio") or token=="K:%d"%KEY_ESCAPE:
		capture_label.text="That key is protected for settings/cancellation. Choose another, or Escape to cancel."; return
	if capture_id in ["orbit","pan_drag"] and event is InputEventMouseButton and event.button_index in [4,5,6,7]: capture_label.text="Choose a held button/key for dragging, not a wheel tick."; return
	candidate=token; conflicts.clear()
	for id: String in audio.preferences.Controls:
		if id!=capture_id and audio.preferences.Controls[id].has(token): conflicts.append(id)
	if conflicts.is_empty(): resolve_binding("replace"); return
	capture_label.text="Conflicts with %s. Swap their bindings, replace (leave the other action unbound), or cancel."%", ".join(conflicts)
	capture_buttons.get_child(0).disabled=conflicts.size()!=1
	capture_buttons.get_child(1).disabled=false
	capture_buttons.get_child(0 if conflicts.size()==1 else 1).grab_focus()
func resolve_binding(choice: String) -> void:
	if candidate.is_empty(): return
	var map: Dictionary=audio.preferences.Controls.duplicate(true)
	var old: Array=map[capture_id]
	for id: String in conflicts:
		map[id]=old.duplicate() if choice=="swap" else []
	map[capture_id]=[candidate]
	if capture_id=="audio" and candidate!="K:%d"%KEY_F10: map[capture_id].append("K:%d"%KEY_F10)
	if capture_id=="cancel": map[capture_id].append("K:%d"%KEY_ESCAPE)
	if not SettingsSchema.bindings_valid(map): capture_label.text="That conflict cannot be resolved safely. Cancel and choose another binding."; return
	audio.preferences.Controls=map
	audio.apply_preferences(false)
	cancel_capture(); refresh()
	notice.text="Binding previewed. Apply saves; Cancel restores previous bindings."
func handle_input(event: InputEvent) -> void:
	if not capture_id.is_empty() and not candidate.is_empty() and not conflicts.is_empty():
		if event is InputEventKey and event.pressed:
			if event.keycode==KEY_ESCAPE: cancel_capture(); get_viewport().set_input_as_handled()
			elif event.keycode in [KEY_TAB,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
				focus_cycle(capture_buttons,event.shift_pressed or event.keycode in [KEY_LEFT,KEY_UP])
				get_viewport().set_input_as_handled()
			elif event.keycode not in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]: get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and not capture_buttons.get_global_rect().has_point(event.position): get_viewport().set_input_as_handled()
		return
	if not capture_id.is_empty():
		if event is InputEventKey or event is InputEventMouseButton:
			# Conflict choices must receive GUI clicks, but never world input.
			if event is InputEventMouseButton and capture_buttons.get_global_rect().has_point(event.position): return
			capture(event); get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ESCAPE,KEY_F10] or ControlBindings.pressed(event,"pause"):
			if remaining>0: revert_display()
			else: close()
			get_viewport().set_input_as_handled(); return
		if event.keycode in [KEY_PAGEUP,KEY_PAGEDOWN]:
			tabs.current_tab=posmod(tabs.current_tab+(-1 if event.keycode==KEY_PAGEUP else 1),tabs.get_tab_count())
			tabs.get_tab_bar().grab_focus()
			get_viewport().set_input_as_handled(); return
		if event.keycode==KEY_TAB:
			focus_cycle(confirm if remaining>0 else card,event.shift_pressed)
			get_viewport().set_input_as_handled(); return
		if event.keycode not in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_PAGEUP,KEY_PAGEDOWN]: get_viewport().set_input_as_handled()

func focus_cycle(scope: Node,backwards: bool) -> void:
	var controls: Array[Control]=[]
	for node in scope.find_children("*","Control",true,false):
		if node.is_visible_in_tree() and node.focus_mode==Control.FOCUS_ALL and not (node is BaseButton and node.disabled): controls.append(node)
	var index := controls.find(get_viewport().gui_get_focus_owner())
	if not controls.is_empty(): controls[posmod(index+(-1 if backwards else 1),controls.size())].grab_focus()

