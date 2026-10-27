class_name EncounterCodeOverlay
extends Control
## Selectable configuration text is always available, even if a platform
## clipboard is unavailable. This overlay never stores combat progress.
var field: LineEdit
var close_button: Button

func _ready() -> void:
	theme=OathUI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color=Color(.02,.03,.06,.85)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size=Vector2(650,180)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",14)
	panel.add_child(box)
	var title := Label.new()
	title.text="ENCOUNTER CODE - setup only, not combat progress"
	title.add_theme_font_size_override("font_size",18)
	box.add_child(title)
	field=LineEdit.new()
	field.editable=false
	field.custom_minimum_size=Vector2(620,38)
	box.add_child(field)
	var instructions := Label.new()
	instructions.text="Select the code and Ctrl+C. Paste it into setup and choose Import.\nClipboard access depends on the desktop. Escape closes this panel."
	instructions.add_theme_font_size_override("font_size",14)
	box.add_child(instructions)
	close_button=Button.new()
	close_button.text="Close"
	close_button.custom_minimum_size.y=36
	box.add_child(close_button)
	close_button.pressed.connect(hide)
	hide()

func show_code(code: String) -> void:
	field.text=code
	show()
	field.grab_focus()
	field.select_all()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey: return
	if event.pressed and event.keycode==KEY_ESCAPE: hide()
	# Allow native copy/select shortcuts, block combat/camera hotkeys in this
	# temporary modal. Mouse input goes through the full-screen GUI backdrop.
	if not event.ctrl_pressed: get_viewport().set_input_as_handled()
