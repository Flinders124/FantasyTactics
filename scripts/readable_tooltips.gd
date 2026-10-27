class_name ReadableTooltips
extends CanvasLayer
## Bounded in-canvas tooltips work with mouse hover and keyboard focus.
var panel: PanelContainer
var source: Control
var text: Label
var keyboard: bool = false
func _ready() -> void:
	layer=40
	process_mode=Node.PROCESS_MODE_ALWAYS
	panel=PanelContainer.new()
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.theme=OathUI.theme()
	var style := OathUI.panel(true)
	panel.add_theme_stylebox_override("panel",style)
	text=Label.new()
	text.custom_minimum_size.x=340
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size",15)
	text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(text)
	hide()
func bind_tree(node: Node) -> void:
	if node==self: return
	if node is Control:
		var control := node as Control
		control.mouse_entered.connect(func() -> void: show_for(control,false))
		control.mouse_exited.connect(func() -> void:
			if source==control: hide(); source=null)
		control.focus_entered.connect(func() -> void: show_for(control,true))
		control.focus_exited.connect(func() -> void:
			if source==control: hide(); source=null)
	for child in node.get_children(): bind_tree(child)
func show_for(control: Control,from_keyboard: bool) -> void:
	if control.tooltip_text.is_empty(): return
	source=control
	keyboard=from_keyboard
	text.text=source.tooltip_text
	show()
	OathUI.reveal(panel)
	_update_position()
func _process(_delta: float) -> void:
	if not visible: return
	if not is_instance_valid(source) or not source.is_visible_in_tree(): hide(); source=null; return
	text.text=source.tooltip_text
	_update_position()
func _update_position() -> void:
	var desired := source.get_global_rect().end if keyboard else get_viewport().get_mouse_position()+Vector2(18,18)
	text.custom_minimum_size.x=minf(340,get_viewport().get_visible_rect().size.x-48)
	panel.position=desired.clamp(Vector2.ONE*8,get_viewport().get_visible_rect().size-panel.size-Vector2.ONE*8)
