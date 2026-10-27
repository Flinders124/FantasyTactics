class_name GuideOverlay
extends CanvasLayer
## Blocking guidance pauses simulation, not camera/audio/UI. Never resolves gameplay.
signal dismissed
var panel: Control
var heading: Label
var body: RichTextLabel
var close_button: Button
var confirm_button: Button
var on_confirm: Callable
var encounter: CombatEncounter
var owns_pause: bool = false
func _ready() -> void:
	layer=45
	process_mode=Node.PROCESS_MODE_ALWAYS
	panel=Control.new()
	panel.theme=OathUI.theme()
	if encounter!=null: panel.theme=encounter.get_node("HUD").root.theme
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter=Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color=Color(.015,.025,.04,.88)
	panel.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.custom_minimum_size=Vector2(720,450)
	center.add_child(card)
	var style := OathUI.panel(true)
	style.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel",style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",16)
	card.add_child(box)
	heading=Label.new()
	heading.add_theme_font_size_override("font_size",26)
	box.add_child(heading)
	body=RichTextLabel.new()
	body.custom_minimum_size=Vector2(660,300)
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size",17)
	box.add_child(body)
	var row := HBoxContainer.new()
	box.add_child(row)
	close_button=Button.new()
	close_button.text="Continue"
	close_button.custom_minimum_size=Vector2(180,44)
	row.add_child(close_button)
	close_button.pressed.connect(close)
	confirm_button=Button.new()
	confirm_button.custom_minimum_size=Vector2(180,44)
	row.add_child(confirm_button)
	confirm_button.pressed.connect(func() -> void:
		var callback := on_confirm
		close()
		if callback.is_valid(): callback.call())
	if encounter!=null and encounter.tutorial_mode:
		var options := HBoxContainer.new()
		box.add_child(options)
		for entry: Array in [["Skip Tutorial","skip_tutorial"],["Exit to Main Menu","main_menu"],["Restart Tutorial","tutorial"]]:
			var action: String=entry[1]
			var option := Button.new()
			option.text=entry[0]
			option.custom_minimum_size.y=38
			options.add_child(option)
			option.pressed.connect(func() -> void: encounter.flow_requested.emit(action))
	panel.hide()
func open(title: String,text: String,confirm_text: String="",callback: Callable=Callable()) -> void:
	if encounter!=null:
		encounter.get_node("PlayerController").cancel_targeting()
		if not owns_pause:
			owns_pause=true
			encounter.set_guidance_paused(true)
	heading.text=title
	body.text=ControlBindings.instructions(text)
	on_confirm=callback
	confirm_button.text=confirm_text
	confirm_button.visible=not confirm_text.is_empty()
	close_button.text="Keep playing" if confirm_button.visible else "Continue"
	panel.show()
	OathUI.reveal(panel)
	close_button.grab_focus()
func close() -> void:
	panel.hide()
	on_confirm=Callable()
	if owns_pause:
		owns_pause=false
		if is_instance_valid(encounter): encounter.set_guidance_paused(false)
	dismissed.emit()
func _input(event: InputEvent) -> void:
	if not panel.visible: return
	var owner := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if owner!=null and owner.panel.visible: return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_TAB,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
		var buttons: Array[Button]=[]
		for control in panel.find_children("*","Button",true,false):
			if control.is_visible_in_tree() and not control.disabled: buttons.append(control)
		var index := buttons.find(get_viewport().gui_get_focus_owner())
		var backwards: bool = event.shift_pressed if event.keycode==KEY_TAB else event.keycode in [KEY_UP,KEY_LEFT]
		if not buttons.is_empty(): buttons[posmod(index+(-1 if backwards else 1),buttons.size())].grab_focus()
		get_viewport().set_input_as_handled()
	elif ControlBindings.pressed(event,"cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and not ControlBindings.pressed(event,"audio"):
		# Leave UI navigation to focused buttons, consume combat shortcuts.
		if event.keycode not in [KEY_TAB,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]: get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if owns_pause and get_tree()!=null:
		get_tree().paused=false
