class_name SettingsSchema
extends RefCounted
## Data validation and serialization only. GameAudio remains the preference owner.
const VERSION: int = 2
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]
static func defaults() -> Dictionary:
	var bindings: Dictionary={}
	for id: String in ControlBindings.KEYS: bindings[id]=["K:%d"%ControlBindings.KEYS[id]]
	for id: String in ControlBindings.MOUSE: bindings[id]=["M:%d"%ControlBindings.MOUSE[id]]
	for pair: Array in [["pan_up",KEY_UP],["pan_down",KEY_DOWN],["pan_left",KEY_LEFT],["pan_right",KEY_RIGHT]]: bindings[pair[0]].append("K:%d"%pair[1])
	return {"Display":{"mode":0,"resolution":0,"vsync":true,"fps":0,"graphics":1},"Audio":{"Master":.8,"Music":.55,"SFX":.8,"Ambience":.35,"Master_mute":false,"Music_mute":false,"SFX_mute":false,"Ambience_mute":false},"Controls":bindings,"Camera":{"orbit":1.0,"pan":1.0,"zoom":1.0,"invert_x":false,"invert_y":false,"edge":false,"edge_speed":1.0,"reduced_motion":false,"shake":.45},"Accessibility":{"ui_scale":1.0,"large_text":false,"high_contrast":false,"reduced_effects":false,"combat_text":1.0}}
static func event_token(event: InputEvent) -> String:
	if event is InputEventKey:
		if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed: return ""
		var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if key in [0,KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META]: return ""
		return "K:%d"%key
	if event is InputEventMouseButton: return "M:%d"%event.button_index
	return ""
static func token_event(token: String) -> InputEvent:
	var bits := token.split(":")
	if bits.size()!=2 or not bits[1].is_valid_int(): return null
	var value := bits[1].to_int()
	if bits[0]=="K" and value>0 and value<16777216 and value not in [KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META]:
		var event := InputEventKey.new()
		event.physical_keycode=value
		return event
	if bits[0]=="M" and value>=1 and value<=9:
		var event := InputEventMouseButton.new()
		event.button_index=value
		return event
	return null
static func bindings_valid(bindings: Dictionary) -> bool:
	var defaults_map: Dictionary=defaults().Controls
	if bindings.size()!=defaults_map.size(): return false
	var seen: Dictionary={}
	for id: String in defaults_map:
		if not bindings.has(id) or not (bindings[id] is Array or bindings[id] is PackedStringArray) or bindings[id].size()>3: return false
		for token: Variant in bindings[id]:
			if not token is String or token_event(token)==null or seen.has(token): return false
			if token in ["K:%d"%KEY_TAB,"K:%d"%KEY_SPACE,"K:%d"%KEY_ENTER,"K:%d"%KEY_KP_ENTER]: return false
			if token=="K:%d"%KEY_ESCAPE and id!="cancel": return false
			if token=="K:%d"%KEY_F10 and id!="audio": return false
			if id in ["orbit","pan_drag"] and token.begins_with("M:") and token.get_slice(":",1).to_int() in [4,5,6,7]: return false
			seen[token]=id
	return bindings.cancel.has("K:%d"%KEY_ESCAPE) and bindings.audio.has("K:%d"%KEY_F10)
static func validated(raw: Dictionary) -> Dictionary:
	var result := defaults()
	for category: String in result:
		if not raw.get(category) is Dictionary: continue
		if category=="Controls":
			if bindings_valid(raw[category]): result[category]=raw[category].duplicate(true)
			continue
		for key: String in result[category]:
			var value: Variant=raw[category].get(key)
			var default: Variant=result[category][key]
			if default is bool:
				if value is bool: result[category][key]=value
			elif (value is int or value is float) and is_finite(float(value)):
				result[category][key]=float(value) if default is float else int(value)
	var d: Dictionary=result.Display
	d.mode=clampi(d.mode,0,2); d.resolution=clampi(d.resolution,0,RESOLUTIONS.size()-1); d.graphics=clampi(d.graphics,0,2)
	d.fps=d.fps if d.fps in [0,30,60,120,144] else 0
	for key: String in result.Audio:
		if not key.ends_with("_mute"): result.Audio[key]=clampf(result.Audio[key],0,1)
	for key in ["orbit","pan","zoom","edge_speed"]: result.Camera[key]=clampf(result.Camera[key],.25,2.0)
	result.Camera.shake=clampf(result.Camera.shake,0,1)
	result.Accessibility.ui_scale=clampf(result.Accessibility.ui_scale,.85,1.15)
	result.Accessibility.combat_text=clampf(result.Accessibility.combat_text,.8,1.5)
	return result
static func install_bindings(bindings: Dictionary) -> void:
	ControlBindings.ensure()
	for id: String in bindings:
		var action := "tactics_"+id
		InputMap.action_erase_events(action)
		for token: String in bindings[id]:
			var event := token_event(token)
			if event!=null: InputMap.action_add_event(action,event)
