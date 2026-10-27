class_name CombatPresentation
extends CanvasLayer

const OATH_FX = preload("res://scripts/oath_combat_fx.gd")
var oath_fx: Node3D
const MAX_EFFECTS: int = 24
var bars: Dictionary = {}
var effects: Array[Dictionary] = []
var _effect_rects: Array[Rect2] = []
var camera: Camera3D
var root: Control
var controller: CombatController
@export_range(0.05, 0.4) var tracer_lifetime: float = 0.18
const MAX_TRACERS: int = 12
var tracers: Array[Dictionary] = []
@export_range(0.1, 0.8) var blast_lifetime: float = 0.65
var blasts: Array[Dictionary] = []
var world_effects: Node3D
const MAX_VOICES: int = 12
const MAX_GLYPHS: int = 16
var audio: GameAudio
var listener: AudioListener3D
var voices: Array[Dictionary] = []
var pending_sounds: Array[Dictionary] = []
var glyphs: Array[Dictionary] = []
var seen_events: Dictionary = {}
var event_queue: Array[String] = []
var presented_events: Dictionary = {}
var variation_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var footsteps: Dictionary = {}
var steps_played: int = 0
var voices_started: int = 0
var _area_action: String = ""
var _area_death_cues: int = 0
var _last_event_sequence: int = 0

func bind(combat: CombatController, roster: Array[CombatUnit], view: Camera3D) -> void:
	add_to_group("preference_consumers")
	layer = 2
	controller = combat
	camera = view
	audio=get_tree().get_first_node_in_group("game_audio") as GameAudio
	variation_rng.seed=0x534f554e44 # Separate cosmetic RNG; never uses global rand*.
	listener=AudioListener3D.new()
	listener.name="TacticalAudioListener"
	add_child(listener)
	listener.position=Vector3(0,3,0)
	listener.make_current() # Fixed arena-centre listener: zoom/orbit never pump gain.
	controller.motor.distance_advanced.connect(_on_distance_advanced)
	controller.motor.completed.connect(func(_reason: String) -> void: _stop_footsteps())
	world_effects = Node3D.new()
	world_effects.name = "ResolvedAttackEffects"
	add_child(world_effects)
	oath_fx=OATH_FX.new()
	world_effects.add_child(oath_fx)
	oath_fx.view=camera
	if audio!=null: oath_fx.configure(audio.preferences)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	for unit in roster:
		var leader := Line2D.new()
		leader.width = 1.5
		leader.default_color = Color(0.85, 0.9, 1, 0.65)
		root.add_child(leader)
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(146, 42)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.035, 0.05, 0.08, 0.92)
		style.set_corner_radius_all(4)
		style.content_margin_left = 6
		style.content_margin_right = 6
		panel.add_theme_stylebox_override("panel", style)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		panel.add_child(box)
		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 13)
		box.add_child(name_label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(114, 9)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.3, 0.7, 1) if unit.faction == CombatUnit.Faction.HERO else Color(1, 0.4, 0.35)
		bar.add_theme_stylebox_override("fill", fill)
		box.add_child(bar)
		_ignore_mouse(panel)
		root.add_child(panel)
		bars[unit.stable_id] = {"id":unit.stable_id,"unit": unit, "panel": panel, "label": name_label, "bar": bar, "leader": leader, "anchor": Vector2.ZERO}
		unit.health_changed.connect(_update_bar)
		unit.resources_changed.connect(_update_bar)
		_update_bar(unit)
	controller.combat_event.connect(_on_event)
	controller.encounter_reset.connect(clear_effects)
	controller.state_changed.connect(func(state: CombatController.State) -> void:
		if state in [CombatController.State.VICTORY, CombatController.State.DEFEAT, CombatController.State.DRAW]:
			clear_tracers())

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

func _update_bar(unit: CombatUnit) -> void:
	var data: Dictionary = bars[unit.stable_id]
	data.label.text = "%s [%s] %d/%d" % [unit.definition.display_name, unit.definition.role_icon if not unit.definition.role_icon.is_empty() else ("R" if unit.role_label() == "Ranged" else "M"), unit.health, unit.definition.maximum_health]
	if not unit.status_text().is_empty():
		data.label.text += "\n" + unit.status_text()
	data.bar.max_value = unit.definition.maximum_health
	data.bar.value = unit.health
	data.panel.visible = unit.is_alive()
	if not unit.is_alive():
		data.leader.visible = false

func _on_event(kind: String, data: Dictionary) -> void:
	var sequence: int = int(data.get("event_sequence",0))
	if sequence>0:
		if sequence<=_last_event_sequence: return
		_last_event_sequence=sequence
	var event_id: String = str(data.get("event_id",""))
	if not event_id.is_empty():
		if seen_events.has(event_id): return
		seen_events[event_id]=true
		event_queue.append(event_id)
		if event_queue.size()>256: seen_events.erase(event_queue.pop_front())
	_present_oath(kind,data)
	presented_events[kind]=int(presented_events.get(kind,0))+1
	if kind=="turn" and audio!=null and audio.context in ["loading","victory","defeat","draw"]:
		audio.set_context("combat")
	if kind=="telegraph_prepare":
		_spawn_effect(data.actor_id,"! AREA WARNING",Color(1,.8,.25))
		_queue_sound("arcane",data.point,-10)
	if kind == "area":
		_spawn_blast(data.point, data.radius, OATH_FX.area_tint(data.get("actor_role","")))
		_area_action=str(data.action_id)
		_area_death_cues=0
		_queue_sound("arcane" if str(data.get("actor_role","")).begins_with("hollow") or str(data.get("actor_role","")).begins_with("verdant") else "fireburst",data.point,-9)
	if kind == "area_hit":
		_spawn_effect(data.target_id, "−%d HP" % data.health_lost, Color(1, 0.65, 0.25))
		_impact(data.target_id,OATH_FX.area_tint(data.get("actor_role","")),false)
	if kind == "heal":
		_spawn_effect(data.target_id, "+%d HP" % data.healing, Color.LIME_GREEN)
		_spawn_glyph(data.target_position+Vector3.UP*1.25,"heal",Color(.4,1,.65))
		_queue_sound("mend",data.target_position,-10)
		_flash(data.target_id,Color(.3,1,.5))
	if kind == "attack":
		_spawn_effect(data.target_id, "−%d HP" % data.health_lost, Color(1, 0.8, 0.5))
		var power: bool = data.get("ability_id","")=="power_strike"
		var cripple: bool = data.get("ability_id","")=="crippling_shot"
		var tint := Color(.65,.5,1) if cripple else (Color(1,.72,.2) if power else Color(1,.9,.65))
		_impact(data.target_id,tint,true)
		if data.attack_type == "Ranged":
			_spawn_tracer(data)
			_queue_sound("arcane" if FactionVisualKit.base_role(data.get("actor_role","")) not in ["ranger","sentinel"] else _variant("bow"),data.origin,-13)
			if FactionVisualKit.base_role(data.get("actor_role","")) in ["ranger","sentinel"]: _queue_sound(_variant("arrow"),data.target_point,-16)
		else:
			_queue_sound(_variant("swing"),data.origin,-14)
			var impact_id := "mace" if FactionVisualKit.base_role(data.get("actor_role",""))=="cleric" else "impact"
			_queue_sound("power" if power else _variant(impact_id),data.target_point,-12)
	elif kind == "death":
		_spawn_effect(data.actor_id, "DEFEATED", Color(1, 0.5, 0.4))
		clear_tracers(data.actor_id)
		_spawn_glyph(data.actor_position+Vector3.UP*.08,"death",Color(.7,.65,.55))
		if str(data.action_id)!=_area_action or _area_death_cues<2:
			_queue_sound(_variant("death"),data.actor_position,-16)
			_area_death_cues+=1
	elif kind in ["status_apply","status_refresh","status_expire"]:
		var expired := kind=="status_expire"
		_spawn_effect(data.actor_id,data.status+(" ENDED" if expired else " · %d turns"%data.turns),Color(.75,.7,1))
		_spawn_glyph(data.actor_position+Vector3.UP*.8,"slow",Color(.7,.55,1))
		_queue_sound("expire" if expired else "slow",data.actor_position,-17)
	elif kind=="result" and audio!=null:
		audio.set_context("draw" if data.get("draw",false) else ("victory" if data.victory else "defeat"))
		_stop_footsteps()
		# The committed final hit/death may finish under the result cue. Area hits
		# have no individual impact voices and at most two quiet death voices.

func _spawn_tracer(data: Dictionary) -> void:
	while tracers.size() >= MAX_TRACERS:
		var old: Dictionary = tracers.pop_front()
		old.line.free()
		old.bead.free()
	var role: String=data.get("actor_role","")
	var magic := FactionVisualKit.base_role(role) not in ["ranger","sentinel"]
	var material := CombatEffectMeshes.material(OATH_FX.tint(role,data.get("ability_id","")),.72)
	var origin: Vector3=data.origin
	var actor := controller.find_unit(data.actor_id)
	if actor!=null and actor.character.authored: origin=actor.character.emission_point()
	var end: Vector3=data.target_point
	var direction := (end-origin).normalized()
	var side := direction.cross(Vector3.UP).normalized()*(.045 if magic else .018)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# A resolved-path afterimage, present at the hit frame; never delayed damage.
	for v: Vector3 in [origin-side,origin+side,end+side,origin-side,end+side,end-side]: mesh.surface_add_vertex(v)
	mesh.surface_end()
	var line := CombatEffectMeshes.visual(world_effects,mesh,material)
	line.top_level=true; line.global_transform=Transform3D.IDENTITY
	var head := ImmediateMesh.new()
	head.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3 in [end,end-direction*.32+side*4,end-direction*.32-side*4]: head.surface_add_vertex(v)
	if magic:
		for v: Vector3 in [end-direction*.55,end-direction*.8+side*3,end-direction*.8-side*3]: head.surface_add_vertex(v)
	head.surface_end()
	var bead := CombatEffectMeshes.visual(world_effects,head,material)
	bead.top_level=true; bead.global_transform=Transform3D.IDENTITY
	tracers.append({"line":line,"bead":bead,"material":material,"from":origin,"to":end,"actor_id":data.actor_id,"target_id":data.target_id,"age":0.0})

func clear_tracers(unit_id: String = "") -> void:
	for index in range(tracers.size() - 1, -1, -1):
		var tracer: Dictionary = tracers[index]
		if unit_id.is_empty() or tracer.actor_id == unit_id or tracer.target_id == unit_id:
			tracer.line.free()
			tracer.bead.free()
			tracers.remove_at(index)

func _spawn_effect(id: String, message: String, color: Color) -> void:
	var unit := controller.find_unit(id)
	if unit == null:
		return
	while effects.size() >= MAX_EFFECTS:
		var old: Dictionary = effects.pop_front()
		old.label.queue_free()
	var text := Label.new()
	text.text = message
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.z_index = 5
	text.add_theme_color_override("font_color", color)
	text.add_theme_color_override("font_outline_color", Color.BLACK)
	text.add_theme_constant_override("outline_size", 5)
	text.add_theme_font_size_override("font_size", roundi(20*(audio.preferences.Accessibility.combat_text if audio!=null else 1.0)))
	text.set_meta("settings_base_font",20)
	text.set_meta("settings_combat_text",true)
	root.add_child(text)
	var lane := mini(3,effects.filter(func(effect: Dictionary) -> bool: return effect.unit_id==id).size())
	effects.append({"label": text,"unit_id":id,"lane":lane, "position": unit.global_position + Vector3.UP * (2.9 if message == "DEFEATED" else 2.5), "age": 0.0})

func clear_effects() -> void:
	if is_instance_valid(oath_fx): oath_fx.clear()
	if is_instance_valid(camera) and camera.get_parent() is TacticalCamera: camera.get_parent().clear_impulse()
	_stop_sounds()
	for glyph in glyphs:
		glyph.root.free()
	glyphs.clear()
	seen_events.clear()
	event_queue.clear()
	presented_events.clear()
	_area_action=""
	_area_death_cues=0
	if is_instance_valid(controller):
		for unit in controller.units:
			if is_instance_valid(unit): unit.character.restore_flash()
	clear_tracers()
	for blast in blasts:
		blast.mesh.free()
	blasts.clear()
	for effect in effects:
		effect.label.free()
	effects.clear()

func _process(delta: float) -> void:
	_update_sounds(delta)
	for index in range(glyphs.size()-1,-1,-1):
		var glyph: Dictionary = glyphs[index]
		glyph.age+=delta
		if glyph.age>=glyph.life:
			glyph.root.free()
			glyphs.remove_at(index)
		else:
			var progress: float = glyph.age/glyph.life
			glyph.material.albedo_color.a=.8*(1.0-progress)
			glyph.root.scale=Vector3.ONE*(.85+.4*progress)
			if glyph.kind=="heal": glyph.root.position.y=glyph.start_y+progress*.55
			elif glyph.kind=="slow": glyph.root.position.y=glyph.start_y-progress*.25
	if not is_instance_valid(camera):
		return
	for index in range(blasts.size() - 1, -1, -1):
		var blast: Dictionary = blasts[index]
		blast.age += delta
		if blast.age >= blast_lifetime:
			blast.mesh.free()
			blasts.remove_at(index)
		else:
			var phase: float = blast.age/blast_lifetime
			blast.material.albedo_color.a = .65*(1.0-phase)
			blast.wave.scale=Vector3.ONE*minf(1.0,.12+phase*1.8)
			for spark_index in range(blast.sparks.size()):
				var spark: MeshInstance3D = blast.sparks[spark_index]
				spark.position.y=.1+sin(minf(1.0,phase*1.4)*PI)*(.35+float(spark_index%3)*.18)
	for index in range(tracers.size() - 1, -1, -1):
		var tracer: Dictionary = tracers[index]
		tracer.age += delta
		if tracer.age >= tracer_lifetime:
			tracer.line.free()
			tracer.bead.free()
			tracers.remove_at(index)
		else:
			tracer.material.albedo_color.a=.72*(1.0-tracer.age/tracer_lifetime)
	var viewport_rect := get_viewport().get_visible_rect()
	var projected: Array[Dictionary] = []
	for data in bars.values():
		var unit: CombatUnit = data.unit
		if not is_instance_valid(unit):
			data.panel.queue_free()
			data.leader.queue_free()
			bars.erase(data.id)
			continue
		var point := unit.global_position + Vector3.UP * 2.4
		var visible := unit.is_alive() and not camera.is_position_behind(point)
		data.panel.visible = visible
		data.leader.visible = false
		if visible:
			var screen := camera.unproject_position(point)
			data.panel.visible = viewport_rect.grow(50).has_point(screen)
			data.anchor = screen
			if data.panel.visible:
				projected.append(data)
	# Four labels at most: bounded screen-space separation, always upwards.
	projected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(a.anchor.y, b.anchor.y):
			return a.anchor.y > b.anchor.y
		return a.unit.stable_id < b.unit.stable_id)
	var placed: Array[Rect2] = []
	for data in projected:
		var panel: Control = data.panel
		panel.position = data.anchor - Vector2(panel.size.x * 0.5, panel.size.y)
		for attempt in range(projected.size()):
			var shifted: bool = false
			for previous in placed:
				if panel.get_rect().grow(3).intersects(previous):
					panel.position.y = minf(panel.position.y, previous.position.y - panel.size.y - 6)
					shifted = true
			if not shifted:
				break
		placed.append(panel.get_rect())
		var end := panel.position + Vector2(panel.size.x * 0.5, panel.size.y)
		data.leader.points = PackedVector2Array([end, data.anchor])
		data.leader.visible = end.distance_to(data.anchor) > 2.0
	_effect_rects.clear()
	for index in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[index]
		effect.age += delta
		if effect.age >= 0.9:
			effect.label.queue_free()
			effects.remove_at(index)
			continue
		var point: Vector3 = effect.position + Vector3.UP * float(effect.age) * 0.7
		effect.label.visible = not camera.is_position_behind(point)
		if effect.label.visible:
			# Separate simultaneous damage/status/death text and place it beside,
			# rather than on top of, the anchored health panel.
			var screen := camera.unproject_position(point)+Vector2(84,-8-float(effect.lane)*25)
			var size: Vector2=effect.label.get_minimum_size()
			screen=Vector2(clampf(screen.x,8,viewport_rect.size.x-size.x-8),clampf(screen.y,8,viewport_rect.size.y-size.y-8))
			var anchor := screen
			for attempt in range(MAX_EFFECTS*2+1):
				var row := ceili(float(attempt)/2)
				var direction := 1 if attempt%2==1 else -1
				var candidate := Vector2(anchor.x,clampf(anchor.y+row*direction*(size.y+4),8,viewport_rect.size.y-size.y-8))
				var occupied := Rect2(candidate,size+Vector2(4,3))
				if not _effect_rects.any(func(rect: Rect2) -> bool: return rect.intersects(occupied)):
					screen=candidate
					break
			_effect_rects.append(Rect2(screen,size+Vector2(4,3)))
			effect.label.position=screen
			effect.label.modulate.a = minf(1.0, (0.9 - effect.age) * 3.0)

func _spawn_blast(point: Vector3, radius: float, color: Color=Color(1,.5,.16)) -> void:
	if audio!=null and audio.preferences.Accessibility.reduced_effects: return
	if blasts.size() >= 4:
		var old: Dictionary = blasts.pop_front()
		old.mesh.free()
	var mesh := Node3D.new()
	var material := CombatEffectMeshes.material(color,.65)
	world_effects.add_child(mesh)
	mesh.global_position = point
	# Exact configured outer radius from the first frame; no opaque sphere hiding units.
	CombatEffectMeshes.visual(mesh,CombatEffectMeshes.ring(radius,.045),material,Vector3.UP*.12)
	var wave := CombatEffectMeshes.visual(mesh,CombatEffectMeshes.ring(radius,.06),material,Vector3.UP*.10)
	wave.scale=Vector3.ONE*.12
	var sparks: Array[MeshInstance3D] = []
	blasts.append({"mesh": mesh, "material": material,"wave":wave,"sparks":sparks,"radius":radius, "age": 0.0})

func _spawn_glyph(point: Vector3,kind: String,color: Color,toward: Vector3=Vector3.INF) -> void:
	if audio!=null and audio.preferences.Accessibility.reduced_effects: return
	while glyphs.size()>=MAX_GLYPHS: glyphs.pop_front().root.free()
	var item := Node3D.new()
	world_effects.add_child(item)
	item.global_position=point
	var material := CombatEffectMeshes.material(color)
	if kind in ["heal","death"]:
		CombatEffectMeshes.visual(item,CombatEffectMeshes.ring(.55),material,Vector3(0,-.5 if kind=="heal" else 0,0))
	if kind!="death": CombatEffectMeshes.visual(item,CombatEffectMeshes.glyph(kind),material)
	if toward.is_finite(): item.rotation.y=atan2(toward.x-point.x,toward.z-point.z)
	elif kind!="death": item.quaternion=Basis.looking_at(camera.global_position-point).get_rotation_quaternion()
	glyphs.append({"root":item,"material":material,"kind":kind,"start_y":point.y,"age":0.0,"life":.65 if kind in ["heal","death","slow"] else .32})

func _flash(id: String,color: Color) -> void:
	if audio!=null and audio.preferences.Accessibility.reduced_effects: return
	var unit := controller.find_unit(id)
	if unit!=null: unit.character.flash(color)

func _impact(id: String,color: Color,sound: bool) -> void:
	var unit := controller.find_unit(id)
	if unit==null: return
	_flash(id,color)
	if sound: _queue_sound(_variant("damage"),unit.target_point(),-21)

func _variant(id: String) -> String:
	return "%s_%d"%[id,variation_rng.randi_range(0,2)]

func _on_distance_advanced(unit: CombatUnit,metres: float) -> void:
	if not unit.is_alive() or metres<=.0001 or not controller.motor.running: return
	footsteps[unit.stable_id]=float(footsteps.get(unit.stable_id,0.0))+metres
	if float(footsteps[unit.stable_id])>=.65:
		footsteps[unit.stable_id]=fmod(float(footsteps[unit.stable_id]),.65)
		steps_played+=1
		_queue_sound(_variant("step"),unit.global_position,-15,"foot")
		if steps_played%3==0 and unit.definition.visual_id in ["knight","cleric","raider"]:
			_queue_sound(_variant("armour"),unit.global_position,-24,"foot")

func _queue_sound(id: String,point: Vector3,gain: float,tag: String="",delay: float=0) -> void:
	if audio==null or not point.is_finite(): return
	if tag=="foot" and pending_sounds.size()+voices.size()>=MAX_VOICES: return
	while pending_sounds.size()+voices.size()>=MAX_VOICES:
		var discarded := false
		for i in pending_sounds.size():
			if pending_sounds[i].tag=="foot":
				pending_sounds.remove_at(i); discarded=true; break
		if discarded: continue
		for i in voices.size():
			if voices[i].tag=="foot":
				voices[i].player.stop(); voices[i].player.free(); voices.remove_at(i); discarded=true; break
		if discarded: continue
		if not pending_sounds.is_empty(): pending_sounds.pop_front()
		else:
			var old: Dictionary = voices.pop_front()
			old.player.stop()
			old.player.free()
	# Keep melodic magic in tune with the score; vary only Foley variants.
	var pitch := variation_rng.randf_range(.96,1.04) if id.contains("_") else 1.0
	pending_sounds.append({"id":id,"point":point,"gain":gain,"tag":tag,"delay":clampf(delay,0,.2),"pitch":pitch})

func _stop_footsteps() -> void:
	footsteps.clear()
	pending_sounds=pending_sounds.filter(func(sound: Dictionary) -> bool: return sound.tag!="foot")
	for index in range(voices.size()-1,-1,-1):
		if voices[index].tag=="foot":
			voices[index].player.stop()
			voices[index].player.free()
			voices.remove_at(index)

func _stop_sounds() -> void:
	footsteps.clear()
	pending_sounds.clear()
	for voice in voices:
		voice.player.stop()
		voice.player.free()
	voices.clear()

func _update_sounds(delta: float) -> void:
	for index in range(voices.size()-1,-1,-1):
		var voice: Dictionary = voices[index]
		voice.age+=delta
		if voice.age>=voice.life:
			voice.player.stop()
			voice.player.free()
			voices.remove_at(index)
	for index in range(pending_sounds.size()-1,-1,-1):
		var sound: Dictionary = pending_sounds[index]
		sound.delay-=delta
		if sound.delay>0: continue
		pending_sounds.remove_at(index)
		var stream := audio.clip(sound.id)
		if stream==null: continue
		var voice := AudioStreamPlayer3D.new()
		voice.stream=stream
		voice.bus="SFX"
		voice.volume_db=sound.gain
		voice.pitch_scale=sound.pitch
		voice.unit_size=20
		voice.max_distance=120
		voice.max_db=-6
		voice.panning_strength=.45
		voice.attenuation_filter_cutoff_hz=18000
		world_effects.add_child(voice)
		voice.global_position=sound.point
		if audio.playback_enabled: voice.play()
		voices_started+=1
		voices.append({"player":voice,"tag":sound.tag,"age":0.0,"life":stream.get_length()/sound.pitch+.08})

func _exit_tree() -> void:
	clear_effects()

func apply_preferences(owner: GameAudio) -> void:
	if is_instance_valid(oath_fx): oath_fx.configure(owner.preferences)
	var reduced: bool=owner.preferences.Accessibility.reduced_effects
	for glyph in glyphs: glyph.root.visible=not reduced
	for blast in blasts:
		blast.mesh.visible=not reduced
		for spark in blast.sparks: spark.visible=not reduced and owner.preferences.Display.graphics>0

# Called only after the existing sequence / identity gate accepts a rules event.
func _present_oath(kind: String,data: Dictionary) -> void:
	if not is_instance_valid(oath_fx): return
	var role: String=data.get("actor_role","")
	var ability: String=data.get("ability_id","")
	var color := OATH_FX.tint(role,ability)
	var actor := controller.find_unit(str(data.get("actor_id","")))
	var base := FactionVisualKit.base_role(role)
	if kind=="attack":
		var heavy := ability=="power_strike"
		var magical: bool=data.attack_type=="Ranged" and base not in ["ranger","sentinel"]
		var shape := OATH_FX.family(role) if magical else ("blunt" if base=="cleric" else "blade")
		var direction: Vector3=data.target_point-data.origin
		oath_fx.burst(data.target_point,shape,color,direction,1.35 if heavy else .85,3)
		if data.attack_type=="Melee": oath_fx.begin_trail(actor,color,heavy)
		elif actor!=null:
			oath_fx.burst(actor.character.emission_point(),OATH_FX.family(role) if magical else "blade",color,-direction,.55,1)
		if heavy: _camera_impact(data.target_point,.13)
	elif kind=="telegraph_prepare":
		if actor!=null: oath_fx.burst(actor.character.emission_point(),OATH_FX.family(role),color,Vector3.UP,.8,2)
	elif kind=="area":
		color=OATH_FX.area_tint(role)
		if actor!=null: oath_fx.burst(actor.character.emission_point(),OATH_FX.family(role),color,Vector3.UP,.65,1)
		var shape := "ember" if data.get("ability","")=="Fireburst" else OATH_FX.family(role)
		var count := 4 if oath_fx.quality==0 else 8
		for i in count:
			var angle := TAU*float(i)/count
			var offset := Vector3(cos(angle),0,sin(angle))*float(data.radius)*.62
			oath_fx.burst(data.point+offset+Vector3.UP*.28,shape,color,Vector3.UP,.85,2)
		_camera_impact(data.point,.16)
	elif kind=="heal":
		oath_fx.burst(data.target_position+Vector3.UP*.85,"heal",Color("b4e3aa"),Vector3.UP,1.2,3)
		if actor!=null: oath_fx.burst(actor.character.emission_point(),"heal",Color("f4d79a"),Vector3.UP,.65,1)
	elif kind=="death":
		oath_fx.burst(data.actor_position+Vector3.UP*.13,"death",Color("b6a57e"),Vector3.UP,.65,1)

func _camera_impact(point: Vector3,strength: float) -> void:
	if is_instance_valid(camera) and camera.get_parent() is TacticalCamera:
		camera.get_parent().impact_impulse(point,strength)
