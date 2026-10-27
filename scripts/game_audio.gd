class_name GameAudio
extends CanvasLayer
## Persistent presentation/preferences only. Never reads or writes combat rules.
const BUSES: PackedStringArray = ["Master","Music","SFX","Ambience"]
const DEFAULTS: Array[float] = [.8,.55,.8,.35]
const CLIPS: String = "res://assets/audio/clips/"
@export var settings_path: String = "user://audio_preferences.cfg"
@export_range(.1,2) var crossfade_seconds: float = .8
signal preferences_changed
var preferences: Dictionary = SettingsSchema.defaults()
var settings_window_size: Vector2i = Vector2i.ZERO
var settings_window_mode: int = 0
var accepted_preferences: Dictionary = {}
var editing: bool = false
var settings_encounter: Node
var previous_pause: bool = false
var display_driver: Callable
var _presentation_queued: bool = false
var test_voice: AudioStreamPlayer
var volumes: Dictionary = {}
var muted: Dictionary = {}
var streams: Dictionary = {}
var music: Array[AudioStreamPlayer] = []
var music_gain: Array[float] = [0.0,0.0]
var music_target: Array[float] = [0.0,0.0]
var ambience: AudioStreamPlayer
var ambience_gain: float = 0.0
var ambience_target: float = 0.0
var interface_voices: Array[AudioStreamPlayer] = []
var context: String = ""
var music_changes: int = 0
var panel: AudioSettingsPanel
var preferences_warning: String = ""
var tutorial_completed: bool = false
var playback_enabled: bool = true

func _ready() -> void:
	# Headless runs still load/check assets and exercise scheduling, without a
	# dummy real-time mixer retaining playbacks after accelerated tests exit.
	playback_enabled=DisplayServer.get_name()!="headless"
	layer=60
	process_mode=Node.PROCESS_MODE_ALWAYS
	add_to_group("game_audio")
	ensure_buses()
	load_preferences()
	for index in range(2):
		var track := AudioStreamPlayer.new()
		track.bus="Music"
		track.volume_db=-60
		add_child(track)
		music.append(track)
	ambience=AudioStreamPlayer.new()
	ambience.bus="Ambience"
	ambience.stream=clip("courtyard",true)
	ambience.volume_db=-60
	add_child(ambience)
	for index in range(4):
		var voice := AudioStreamPlayer.new()
		voice.bus="SFX"
		voice.volume_db=-12
		add_child(voice)
		interface_voices.append(voice)
	panel=AudioSettingsPanel.new()
	add_child(panel)
	panel.bind(self)
	get_tree().node_added.connect(_watch_button)
	test_voice=AudioStreamPlayer.new()
	test_voice.bus="SFX"
	add_child(test_voice)
	apply_preferences(false)
	if get_viewport() is Window and DisplayServer.get_name()!="headless":
		if not apply_display(preferences.Display):
			preferences.Display=SettingsSchema.defaults().Display
			apply_display(preferences.Display)
			preferences_warning="Saved display unavailable; a safe windowed mode was restored."

static func ensure_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
			AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master)==0:
		AudioServer.add_bus_effect(master,AudioEffectLimiter.new())

func clip(id: String,loop: bool=false) -> AudioStream:
	var key := id+("-loop" if loop else "")
	if not streams.has(key):
		var stream := load(CLIPS+id+".wav") as AudioStreamWAV
		if stream==null: return null
		if loop:
			stream=stream.duplicate() as AudioStreamWAV
			stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin=0
			stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
		streams[key]=stream
	return streams[key]

func load_preferences() -> void:
	var config := ConfigFile.new()
	var error := ERR_FILE_NOT_FOUND
	if FileAccess.file_exists(settings_path):
		var raw_text := FileAccess.get_file_as_string(settings_path).strip_edges()
		if raw_text.length()>131072 or not (raw_text.begins_with("[") or raw_text.begins_with(";")): error=ERR_FILE_CORRUPT
		else: error=config.load(settings_path)
	if error!=OK and FileAccess.file_exists(settings_path+".bak"):
		error=config.load(settings_path+".bak")
		preferences_warning="Previous accepted preferences recovered from backup." if error==OK else "Preferences and backup could not be read; using defaults."
	else: preferences_warning="" if error in [OK,ERR_FILE_NOT_FOUND] else "Preferences could not be read; using defaults."
	var raw: Dictionary={}
	var version: Variant=config.get_value("meta","version",1) if error==OK else 1
	if error==OK and version is int and version in [1,SettingsSchema.VERSION]:
		for category in SettingsSchema.defaults():
			if config.has_section(category):
				raw[category]={}
				for key in config.get_section_keys(category): raw[category][key]=config.get_value(category,key)
		if version==1:
			raw.Audio={}
			for bus in BUSES:
				raw.Audio[bus]=config.get_value(bus,"volume",SettingsSchema.defaults().Audio[bus])
				raw.Audio[bus+"_mute"]=config.get_value(bus,"muted",false)
	elif error==OK: preferences_warning="Unsupported preferences version; using defaults."
	var completed: Variant=config.get_value("tutorial","completed",false) if error==OK else false
	tutorial_completed=completed if completed is bool else false
	preferences=SettingsSchema.validated(raw)
	accepted_preferences=preferences.duplicate(true)
	apply_preferences(false)

func save_preferences() -> bool:
	var config := ConfigFile.new()
	var saved := accepted_preferences if editing else preferences
	config.set_value("meta","version",SettingsSchema.VERSION)
	config.set_value("tutorial","completed",tutorial_completed)
	for category: String in saved:
		for key: String in saved[category]: config.set_value(category,key,saved[category][key])
	var temporary := settings_path+".tmp"
	var backup := settings_path+".bak"
	if config.save(temporary)!=OK:
		preferences_warning="Settings could not be saved; previous preferences remain intact."
		return false
	var target := ProjectSettings.globalize_path(settings_path)
	var old := ProjectSettings.globalize_path(backup)
	if FileAccess.file_exists(backup): DirAccess.remove_absolute(old)
	if FileAccess.file_exists(settings_path) and DirAccess.rename_absolute(target,old)!=OK:
		preferences_warning="Previous settings could not be backed up; no changes were saved."
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),target)!=OK:
		if FileAccess.file_exists(backup): DirAccess.rename_absolute(old,target)
		preferences_warning="Settings replacement failed; previous preferences restored."
		return false
	preferences_warning=""
	return true

func apply_preferences(include_display: bool=true) -> void:
	for bus in BUSES:
		volumes[bus]=preferences.Audio[bus]
		muted[bus]=preferences.Audio[bus+"_mute"]
		_apply_bus(bus)
	SettingsSchema.install_bindings(preferences.Controls)
	if include_display: apply_display(preferences.Display)
	preferences_changed.emit()
	if is_inside_tree(): SettingsPresentation.apply_tree(get_tree().root,self)
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group("preference_consumers"):
			if node.has_method("apply_preferences"): node.apply_preferences(self)

func apply_display(display: Dictionary) -> bool:
	if display_driver.is_valid(): return display_driver.call(display)
	if DisplayServer.get_name()=="headless" or not get_viewport() is Window: return false
	var mode: int=[DisplayServer.WINDOW_MODE_WINDOWED,DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN][display.mode]
	if display.mode==2 and OS.get_name()!="Windows": return false
	var screen := DisplayServer.screen_get_size()
	var resolution: Vector2i = SettingsSchema.RESOLUTIONS[display.resolution]
	if display.mode==0 and (resolution.x>screen.x or resolution.y>screen.y): return false
	DisplayServer.window_set_min_size(Vector2i(1280,720))
	DisplayServer.window_set_mode(mode)
	if display.mode==0:
		DisplayServer.window_set_size(SettingsSchema.RESOLUTIONS[display.resolution])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if display.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=display.fps
	return DisplayServer.window_get_mode()==mode

func begin_settings() -> void:
	if editing: return
	editing=true
	settings_window_size=Vector2i.ZERO
	if DisplayServer.get_name()!="headless" and not display_driver.is_valid():
		settings_window_size=DisplayServer.window_get_size()
		settings_window_mode=DisplayServer.window_get_mode()
	accepted_preferences=preferences.duplicate(true)
	settings_encounter=null
	var candidate: Node
	for node in get_tree().get_nodes_in_group("active_encounter"):
		if not node.get("cancelled"): candidate=node
	if candidate!=null and not candidate.get("cancelled"):
		settings_encounter=candidate
		previous_pause=candidate.get_node("CombatController").guidance_paused
		if candidate.get_node("PlayerController").controller!=null: candidate.get_node("PlayerController").cancel_targeting()
		candidate.call("set_guidance_paused",true,"settings")

func finish_settings(accept: bool) -> bool:
	if not editing: return true
	var same_window_options: bool=preferences.Display.mode==accepted_preferences.Display.mode and preferences.Display.resolution==accepted_preferences.Display.resolution
	if accept:
		# Commit to disk before replacing the accepted in-memory snapshot.
		var previous := accepted_preferences.duplicate(true)
		accepted_preferences=preferences.duplicate(true)
		if not save_preferences():
			accepted_preferences=previous
			return false
	if not accept: preferences=accepted_preferences.duplicate(true)
	editing=false
	apply_preferences()
	# Audio/accessibility edits and Cancel must preserve a manually resized window.
	if (not accept or same_window_options) and settings_window_size!=Vector2i.ZERO and settings_window_mode==DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.get_name()!="headless":
		DisplayServer.window_set_size(settings_window_size)
	if accept:
		accepted_preferences=preferences.duplicate(true)
	if is_instance_valid(settings_encounter) and not settings_encounter.get("cancelled"):
		settings_encounter.call("set_guidance_paused",false,"settings")
	settings_encounter=null
	return true

func preview(category: String,key: String,value: Variant) -> void:
	preferences[category][key]=value
	preferences=SettingsSchema.validated(preferences)
	apply_preferences(false)
	if category=="Display" and key in ["vsync","fps"]:
		if DisplayServer.get_name()!="headless":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if preferences.Display.vsync else DisplayServer.VSYNC_DISABLED)
		Engine.max_fps=preferences.Display.fps

func play_test_sound() -> void:
	if test_voice==null or not playback_enabled: return
	test_voice.stop()
	test_voice.stream=clip("ui")
	test_voice.play()

func _apply_bus(bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.0001,float(volumes[bus]))))
	AudioServer.set_bus_mute(index,muted[bus] or float(volumes[bus])<=.0001)

func set_preference(bus: String,value: float,mute: bool) -> void:
	if not BUSES.has(bus) or not is_finite(value): return
	preferences.Audio[bus]=clampf(value,0,1)
	preferences.Audio[bus+"_mute"]=mute
	volumes[bus]=preferences.Audio[bus]
	muted[bus]=mute
	_apply_bus(bus)
	if not editing:
		accepted_preferences=preferences.duplicate(true)
		save_preferences()

func show_settings() -> void:
	panel.open()

func _watch_button(node: Node) -> void:
	if node is Control and not _presentation_queued:
		_presentation_queued=true
		_refresh_presentation.call_deferred()
	if node is Button and not node.pressed.is_connected(play_ui):
		node.pressed.connect(play_ui)

func play_ui(id: String="ui") -> void:
	var outcome := id in ["victory","defeat","draw"]
	var selected: AudioStreamPlayer = interface_voices[0] if outcome else null
	for voice in interface_voices:
		if not voice.playing:
			selected=voice
			break
	if selected!=null:
		selected.stop()
		selected.stream=clip(id)
		selected.volume_db=-8 if outcome else -12
		if playback_enabled: selected.play()
	# A click storm cannot steal an outcome cue or allocate unlimited players.

func set_context(value: String) -> void:
	if value==context: return
	context=value
	var track_name := "menu" if value=="menu" else ("combat" if value=="combat" else "")
	ambience_target=1.0 if value in ["combat","victory","defeat","draw"] else 0.0
	if ambience_target>0 and not ambience.playing and playback_enabled: ambience.play()
	music_target.assign([0.0,0.0])
	if not track_name.is_empty():
		var stream := clip(track_name,true)
		var selected := -1
		for index in range(2):
			if music[index].stream==stream and music[index].playing: selected=index
		if selected<0:
			selected=0 if music_gain[0]<=music_gain[1] else 1
			music[selected].stop()
			music[selected].stream=stream
			music_gain[selected]=0
			music[selected].volume_db=-60
			if playback_enabled: music[selected].play()
			music_changes+=1
		music_target[selected]=1
	if value in ["victory","defeat","draw"]: play_ui(value)

func _process(delta: float) -> void:
	for index in range(music.size()):
		music_gain[index]=move_toward(music_gain[index],music_target[index],delta/maxf(.1,crossfade_seconds))
		music[index].volume_db=linear_to_db(maxf(.001,music_gain[index]))-9
		if music_gain[index]<=0 and music_target[index]<=0: music[index].stop()
	ambience_gain=move_toward(ambience_gain,ambience_target,delta/.6)
	if ambience!=null:
		ambience.volume_db=linear_to_db(maxf(.001,ambience_gain))-16
		if ambience_gain<=0 and ambience_target<=0: ambience.stop()

func _input(event: InputEvent) -> void:
	if panel.visible:
		panel.handle_input(event)
		return
	if ControlBindings.pressed(event,"audio") or ControlBindings.pressed(event,"pause") or (event is InputEventKey and event.pressed and event.keycode==KEY_F10):
		panel.open()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_watch_button): get_tree().node_added.disconnect(_watch_button)
	silence()
	for voice in music:
		voice.stream=null
	for voice in interface_voices:
		voice.stream=null
	if ambience!=null:
		ambience.stream=null
	streams.clear()

func silence() -> void:
	for voice in music: voice.stop()
	for voice in interface_voices: voice.stop()
	if ambience!=null: ambience.stop()
	music_gain.assign([0.0,0.0])
	music_target.assign([0.0,0.0])
	ambience_gain=0
	ambience_target=0
	context=""

func mark_tutorial_completed() -> void:
	tutorial_completed=true
	# Same version-tolerant ConfigFile as audio; retain all audio preferences.
	save_preferences()

func _refresh_presentation() -> void:
	_presentation_queued=false
	if is_inside_tree(): SettingsPresentation.apply_tree(get_tree().root,self)

func get_buses() -> PackedStringArray:
	return BUSES
