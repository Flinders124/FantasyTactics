extends "res://tests/ability_tests.gd"

var presentation: CombatPresentation
var audio: GameAudio

func ranged_fixture() -> void:
	await fresh("hero-02")
	scout.position=Vector3(-4,0,7)
	warden.position=Vector3(-8,0,-8)
	raider.position=Vector3(2,0,7)
	await physics_frame
	await physics_frame

func preferences() -> void:
	var old_path := audio.settings_path
	var old_volumes := audio.volumes.duplicate()
	var old_mutes := audio.muted.duplicate()
	audio.settings_path="user://audio-regression.cfg"
	for bus in GameAudio.BUSES:
		audio.set_preference(bus,0,false)
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)),"Zero volume silences "+bus)
		audio.set_preference(bus,1,false)
		check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)) and is_zero_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))),"Maximum is unity, never amplified: "+bus)
		audio.set_preference(bus,.37,true)
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)),"Explicit mute applies immediately: "+bus)
	# A distinct service reads the saved file, rather than in-memory preferences.
	var verifier := GameAudio.new()
	verifier.settings_path=audio.settings_path
	root.add_child(verifier)
	check(Array(GameAudio.BUSES).all(func(bus: String) -> bool: return is_equal_approx(verifier.volumes[bus],.37) and verifier.muted[bus]),"Fresh service restores all persisted preferences")
	verifier.queue_free()
	await process_frame
	var bad := ConfigFile.new()
	bad.set_value("Master","volume","loud")
	bad.set_value("SFX","muted","yes")
	bad.set_value("Music","volume",4.0)
	bad.set_value("Ambience","volume",-3.0)
	bad.save(audio.settings_path)
	audio.load_preferences()
	check(is_equal_approx(audio.volumes.Master,.8) and not audio.muted.SFX and audio.volumes.Music==1 and audio.volumes.Ambience==0,"Malformed values use defaults; out-of-range values clamp")
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(audio.settings_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(audio.settings_path+suffix))
	audio.load_preferences()
	check(is_equal_approx(audio.volumes.SFX,.8),"Missing preferences safely restore defaults")
	audio.settings_path=old_path
	audio.volumes=old_volumes
	audio.muted=old_mutes
	for bus in GameAudio.BUSES: audio._apply_bus(bus)
	audio.settings_path="user://audio-regression.cfg"
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		audio.show_settings()
		await process_frame
		await process_frame
		var rect := audio.panel.card.get_global_rect()
		check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(rect),"Settings panel fits "+str(resolution))
		audio.panel.sliders.Master.value=64
		audio.panel.mutes.SFX.button_pressed=true
		check(is_equal_approx(audio.volumes.Master,.64) and audio.muted.SFX,"Actual slider and mute signals apply preferences")
		var active_id := controller.scheduler.active_unit().stable_id
		var click := InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=true
		click.position=rect.get_center()
		Input.parse_input_event(click)
		Input.flush_buffered_events()
		click=click.duplicate() as InputEventMouseButton
		click.pressed=false
		Input.parse_input_event(click)
		Input.flush_buffered_events()
		var key := InputEventKey.new()
		key.keycode=KEY_E
		key.pressed=true
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		check(not controller.motor.running and controller.scheduler.active_unit().stable_id==active_id,"Settings clicks and action shortcuts never issue world commands")
		audio.panel.close()
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(audio.settings_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(audio.settings_path+suffix))
	audio.settings_path=old_path
	audio.volumes=old_volumes
	audio.muted=old_mutes
	for bus in GameAudio.BUSES: audio._apply_bus(bus)

func run() -> void:
	root.size=Vector2i(1280,720)
	encounter=(load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate() as Node3D
	encounter.get_node("EnemyController").enabled=false
	root.add_child(encounter)
	for frame in range(1600):
		await process_frame
		if encounter.navigation_ready: break
	check(encounter.navigation_ready,"Audio fixture reaches playable state")
	controller=encounter.get_node("CombatController") as CombatController
	ai=encounter.get_node("EnemyController") as EnemyController
	presentation=encounter.get_node("CombatPresentation") as CombatPresentation
	audio=get_first_node_in_group("game_audio") as GameAudio
	warden=controller.find_unit("hero-01")
	scout=controller.find_unit("hero-02")
	raider=controller.find_unit("enemy-01")
	sentinel=controller.find_unit("enemy-02")
	controller.combat_event.connect(func(kind: String,data: Dictionary) -> void: events.append({"kind":kind,"data":data}))
	await preferences()
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/manifest.json"))
	check(manifest.size()==40,"All 40 authored local audio assets ship")
	for asset: Dictionary in manifest:
		var stream := audio.clip(asset.id,asset.loop)
		check(stream!=null and stream.get_length()>.05,"Non-empty imported audio: "+asset.id)
		if asset.loop: check((stream as AudioStreamWAV).loop_mode==AudioStreamWAV.LOOP_FORWARD,"Loop metadata applied: "+asset.id)
	await fresh()
	var idle_steps := presentation.steps_played
	for frame in range(20): await process_frame
	check(presentation.steps_played==idle_steps,"Idle never produces footsteps")
	check(controller.submit_command(MoveCommand.new(warden.stable_id,warden.position+Vector3(0,0,1))),"Movement accepted")
	await wait_action()
	check(presentation.steps_played>idle_steps and presentation.voices.all(func(voice: Dictionary) -> bool: return voice.tag!="foot") and presentation.pending_sounds.all(func(sound: Dictionary) -> bool: return sound.tag!="foot"),"Only actual travel creates steps; completion stops them promptly")
	await fresh()
	var barrier := StaticBody3D.new()
	barrier.position=warden.position+Vector3(0,1,.4)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(2,2,.25)
	collision.shape=shape
	barrier.add_child(collision)
	encounter.add_child(barrier)
	await physics_frame
	await physics_frame
	var blocked_steps := presentation.steps_played
	check(controller.submit_command(MoveCommand.new(warden.stable_id,warden.position+Vector3(0,0,1))),"Route may be blocked after navigation bake")
	await wait_action()
	check(not controller.motor.running and presentation.steps_played==blocked_steps and warden.movement_remaining>5.5,"Blocked movement recovers without idle footsteps or full budget charge")
	barrier.queue_free()
	await physics_frame
	await fresh()
	check(controller.submit_command(MoveCommand.new(warden.stable_id,warden.position+Vector3(0,0,2))),"Movement restart fixture accepted")
	for frame in range(16): await physics_frame
	check(controller.motor.running,"Restart fixture is still moving")
	await controller.restart_encounter()
	check(presentation.voices.is_empty() and presentation.pending_sounds.is_empty(),"Restart during travel cancels active and pending footsteps")
	# Events and presentation are delivered once, independently of frame updates.
	await fresh()
	check(controller.submit_command(AttackCommand.new(warden.stable_id,raider.stable_id)),"Basic melee accepted")
	var attack: Dictionary = events.filter(func(event: Dictionary) -> bool: return event.kind=="attack")[0].data
	check(not str(attack.event_id).is_empty() and not str(attack.action_id).is_empty(),"Committed events carry stable identity")
	var damage := raider.health
	var glyph_count := presentation.glyphs.size()
	for duplicate in range(10): presentation._on_event("attack",attack)
	check(presentation.presented_events.attack==1 and presentation.glyphs.size()==glyph_count and raider.health==damage,"Duplicate delivery produces neither duplicate feedback nor gameplay")
	check(not controller.submit_command(AttackCommand.new(warden.stable_id,raider.stable_id)),"Repeated input rejected during resolution")
	await controller.restart_encounter()
	presentation._on_event("attack",attack)
	check(presentation.glyphs.is_empty() and presentation.effects.is_empty() and presentation.pending_sounds.is_empty(),"Restart rejects stale presentation identity")
	check(audio.context=="combat","In-place restart restores combat music context")
	await fresh()
	check(controller.submit_command(UseAbilityCommand.new(warden.stable_id,raider.stable_id,"power_strike")),"Power Strike accepted")
	check(not presentation.oath_fx.trails.is_empty() and presentation.pending_sounds.any(func(sound: Dictionary) -> bool: return sound.id=="power"),"Power has stronger trail and impact cue")
	await fresh()
	warden.set_health(10)
	check(controller.submit_command(UseAbilityCommand.new(warden.stable_id,warden.stable_id,"mend")),"Mend accepted")
	check(presentation.effects.any(func(effect: Dictionary) -> bool: return effect.label.text.begins_with("+")) and presentation.glyphs.any(func(glyph: Dictionary) -> bool: return glyph.kind=="heal"),"Healing uses signed numbers and a distinct cross/ring")
	await ranged_fixture()
	check(controller.submit_command(AttackCommand.new(scout.stable_id,raider.stable_id)),"Bow attack accepted")
	check(presentation.tracers.size()==1 and presentation.pending_sounds.any(func(sound: Dictionary) -> bool: return sound.id.begins_with("bow_")),"Ranged tracer and release cue follow committed attack")
	await ranged_fixture()
	check(controller.submit_command(UseAbilityCommand.new(scout.stable_id,raider.stable_id,"crippling_shot")),"Crippling Shot accepted")
	check(presentation.glyphs.any(func(glyph: Dictionary) -> bool: return glyph.kind=="slow") and presentation.presented_events.status_apply==1,"Slowed application has readable glyph and event")
	await wait_action()
	var music_changes := audio.music_changes
	for turn in range(12):
		if int(presentation.presented_events.get("status_expire",0))>0: break
		controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
	check(int(presentation.presented_events.get("status_expire",0))==1,"Turn-based expiration produces one presentation event")
	check(audio.music_changes==music_changes,"Turn/UI updates never restart combat music")
	await fresh("hero-02")
	var point := Vector3(0,0,7)
	var offsets: Array[Vector3] = [Vector3(-1,0,0),Vector3(1,0,0),Vector3(0,0,-1),Vector3(0,0,1)]
	for index in range(4):
		controller.units[index].position=point+offsets[index]
		controller.units[index].set_health(3)
	await physics_frame
	await physics_frame
	check(controller.submit_command(UseAbilityCommand.on_ground(scout.stable_id,"fireburst",point)),"Multi-hit Fireburst accepted")
	check(controller.state==CombatController.State.DRAW and count("area_hit")==4 and count("death")==4,"Atomic four-death draw remains authoritative")
	check(presentation.blasts.size()==1 and is_equal_approx(presentation.blasts[0].radius,2.5) and presentation.pending_sounds.filter(func(sound: Dictionary) -> bool: return sound.id=="fireburst").size()==1,"One blast and one main cue match exact configured footprint")
	check(presentation.pending_sounds.size()<=3 and audio.context=="draw","Area audio is capped at one blast plus two quiet deaths and one nonspatial outcome")
	for index in range(60):
		presentation._spawn_glyph(point,"heal",Color.GREEN)
		presentation._spawn_effect(scout.stable_id,"+3 HP",Color.GREEN)
		presentation._queue_sound("mend",point,-16)
	check(presentation.glyphs.size()<=16 and presentation.effects.size()<=24 and presentation.pending_sounds.size()+presentation.voices.size()<=12,"Presentation allocations remain bounded under burst load")
	presentation._process(.02)
	var listener_transform := presentation.listener.global_transform
	var rig := encounter.get_node("TacticalCamera") as TacticalCamera
	rig.yaw+=2
	rig.distance=5
	rig._update_transform()
	check(presentation.listener.global_transform==listener_transform and presentation.voices.all(func(voice: Dictionary) -> bool: return voice.player.unit_size==20 and voice.player.max_distance==120),"Camera zoom/orbit leave listener and useful attenuation unchanged")
	await controller.restart_encounter()
	check(presentation.world_effects.get_child_count()==1 and presentation.oath_fx.active_count()==0 and presentation.oath_fx.trails.is_empty() and presentation.voices.is_empty() and presentation.glyphs.is_empty() and presentation.pending_sounds.is_empty(),"Restart clears voices, delayed sounds, glyphs, numbers and blasts")
	encounter.shutdown()
	encounter.queue_free()
	await process_frame
	await process_frame
	print("SOUND RESULT: %d failures (headless schedules/resources only; listening quality not assessed)"%failures)
	quit(0 if failures==0 else 1)
