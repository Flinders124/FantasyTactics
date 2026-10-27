class_name ControlBindings
extends RefCounted
## One binding source for input and instructions; existing custom InputMap entries win.
const MOUSE: Dictionary = {"world":MOUSE_BUTTON_LEFT,"orbit":MOUSE_BUTTON_RIGHT,"pan_drag":MOUSE_BUTTON_MIDDLE,"zoom_in":MOUSE_BUTTON_WHEEL_UP,"zoom_out":MOUSE_BUTTON_WHEEL_DOWN}
const KEYS: Dictionary = {"pause":KEY_P,"move":KEY_M,"attack":KEY_T,"end_turn":KEY_E,"cancel":KEY_ESCAPE,"focus":KEY_F,"ability_1":KEY_1,"ability_2":KEY_2,"ability_3":KEY_3,"help":KEY_F1,"audio":KEY_F10,"pan_up":KEY_W,"pan_down":KEY_S,"pan_left":KEY_A,"pan_right":KEY_D}
static func ensure() -> void:
	for id: String in KEYS:
		var action := "tactics_"+id
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode=KEYS[id]
		InputMap.action_add_event(action,event)
	for id: String in MOUSE:
		var action := "tactics_"+id
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE[id]
		InputMap.action_add_event(action,event)

static func label(id: String) -> String:
	ensure()
	var labels: PackedStringArray=[]
	for event in InputMap.action_get_events("tactics_"+id):
		labels.append(event.as_text().replace(" (Physical)","").replace(" - Physical","").replace("Left Mouse Button","LMB").replace("Right Mouse Button","RMB").replace("Middle Mouse Button","MMB").replace("Mouse Wheel Up","Wheel up").replace("Mouse Wheel Down","Wheel down"))
	return " / ".join(labels) if not labels.is_empty() else "Unbound"
static func pressed(event: InputEvent,id: String) -> bool:
	ensure()
	if event.is_echo(): return false
	var action := "tactics_"+id
	if event.is_action_pressed(action): return true
	# Virtual/keycode-only events have no physical scan code. Normalize a copy,
	# still matching the configured InputMap rather than hard-coded keys.
	if event is InputEventKey and event.physical_keycode==0 and event.keycode!=0:
		var normalized := event.duplicate() as InputEventKey
		normalized.physical_keycode=event.keycode
		return normalized.is_action_pressed(action)
	return false
static func describe() -> String:
	return "Move: %s · Attack: %s · Abilities: %s, %s, %s\nEnd turn: %s · Cancel targeting: %s · Focus active: %s\nOrbit: drag %s · Pan: drag %s or %s / %s / %s / %s\nZoom: %s / %s · Help: %s · Settings: %s" % [label("move"),label("attack"),label("ability_1"),label("ability_2"),label("ability_3"),label("end_turn"),label("cancel"),label("focus"),label("orbit"),label("pan_drag"),label("pan_up"),label("pan_left"),label("pan_down"),label("pan_right"),label("zoom_in"),label("zoom_out"),label("help"),label("audio")]+"\nWorld select/confirm: %s · Pause/settings: %s (F10 always available)"%[label("world"),label("pause")]

static func compact() -> String:
	var pan: PackedStringArray=[]
	for id in ["pan_up","pan_left","pan_down","pan_right"]: pan.append(label(id).split(" / ")[0])
	return "%s Move · %s Attack · %s/%s/%s Abilities\n%s End · %s Cancel · %s Focus\n%s Orbit · %s Pan\n%s Pan · %s / %s Zoom\n%s Help · %s Settings" % [label("move"),label("attack"),label("ability_1"),label("ability_2"),label("ability_3"),label("end_turn"),label("cancel"),label("focus"),label("orbit"),label("pan_drag"),"/".join(pan),label("zoom_in"),label("zoom_out"),label("help"),label("audio")]

static func instructions(text: String) -> String:
	return text.replace("Left-click","Press "+label("world")).replace("left-click","press "+label("world")).replace("Click","Press "+label("world")).replace("click","press "+label("world"))
