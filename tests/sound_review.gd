extends "res://tests/sound_tests.gd"
## Real-device review/capture. Run WITHOUT --headless or --fixed-fps.
const OUTPUT: String = "res://../verification/sound/"
var capture: AudioEffectCapture
var mixed: PackedVector2Array = []
var metrics: Array[Dictionary] = []

func drain_audio() -> void:
	if capture!=null and capture.can_get_buffer(1): mixed.append_array(capture.get_buffer(capture.get_frames_available()))

func wait_seconds(seconds: float) -> void:
	var end := Time.get_ticks_msec()+roundi(seconds*1000)
	while Time.get_ticks_msec()<end:
		await process_frame
		drain_audio()

func shot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	drain_audio()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+label+".png"))

func profile_effects(point: Vector3=Vector3(-4,0,7)) -> void:
	print("Starting bounded effects profile at ",root.size)
	var times: Array[float] = []
	var previous := Time.get_ticks_usec()
	for voice in range(12): presentation._queue_sound("mend",point,-26)
	for frame in range(120):
		# Bounded presentation stress only; no gameplay damage fabricated.
		if frame%12==0:
			presentation._spawn_blast(point,2.5)
			presentation._spawn_glyph(warden.position+Vector3.UP,"heal",Color.GREEN)
		await process_frame
		drain_audio()
		var now := Time.get_ticks_usec()
		times.append(float(now-previous)/1000)
		previous=now
	times.sort()
	metrics.append({"scene":"courtyard" if encounter.configuration!=null else "fixed combat fixture","resolution":str(root.size),"sample_frames":120,"median_frame_ms":times[60],"p95_frame_ms":times[114],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"voices":presentation.voices.size(),"blasts":presentation.blasts.size()})
	print("Profile finished")

func write_capture() -> void:
	var bytes := PackedByteArray()
	bytes.resize(mixed.size()*4)
	var peak := 0.0
	var energy := 0.0
	for index in range(mixed.size()):
		var value := mixed[index]
		peak=maxf(peak,maxf(absf(value.x),absf(value.y)))
		energy+=value.length_squared()
		bytes.encode_s16(index*4,roundi(clampf(value.x,-1,1)*32767))
		bytes.encode_s16(index*4+2,roundi(clampf(value.y,-1,1)*32767))
	var stream := AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.stereo=true
	stream.mix_rate=roundi(AudioServer.get_mix_rate())
	stream.data=bytes
	stream.save_to_wav(ProjectSettings.globalize_path(OUTPUT+"runtime-mix.wav"))
	metrics.append({"mixed_frames":mixed.size(),"mix_rate":stream.mix_rate,"peak":peak,"rms":sqrt(energy/maxi(1,mixed.size()*2)),"discarded_frames":capture.get_discarded_frames()})
	check(mixed.size()>48000 and peak>.001,"Real rendered audio mixer produces non-silent output")
	var report := FileAccess.open(OUTPUT+"render-profile.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics,"\t"))
	report.close()

func courtyard_effects() -> void:
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		encounter=(load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate() as CombatEncounter
		encounter.configuration=EncounterConfiguration.new()
		encounter.configuration.hero_ids=["mage","cleric"]
		encounter.configuration.battlefield_seed=7
		encounter.get_node("EnemyController").enabled=false
		root.add_child(encounter)
		for frame in range(1600):
			await process_frame
			if encounter.navigation_ready: break
		check(encounter.navigation_ready,"Courtyard review navigation ready")
		controller=encounter.get_node("CombatController") as CombatController
		presentation=encounter.get_node("CombatPresentation") as CombatPresentation
		audio=get_first_node_in_group("game_audio") as GameAudio
		var center: Vector2 = encounter.configuration.layout.hero_zone.get_center()
		var point := Vector3(center.x,0,center.y)
		var offsets: Array[Vector3] = [Vector3(-1,0,0),Vector3(1,0,0),Vector3(0,0,-1),Vector3(0,0,1)]
		for index in range(4): controller.units[index].position=point+offsets[index]
		while controller.scheduler.active_unit().stable_id!="hero-01": controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
		warden=controller.find_unit("hero-01")
		var rig := encounter.get_node("TacticalCamera") as TacticalCamera
		rig.position=point+Vector3(3,0,0)
		rig.yaw=.45
		rig.pitch=-.95
		rig.distance=22
		rig._update_transform()
		await physics_frame
		await physics_frame
		var player := encounter.get_node("PlayerController") as PlayerController
		player.set_process(false)
		player.select_ability("fireburst")
		player.ground_selected=true
		player.selected_ground=point
		player.show_ground_preview(point)
		await shot("courtyard-preview-%d"%resolution.x)
		check(controller.submit_command(UseAbilityCommand.on_ground("hero-01","fireburst",point)),"Courtyard Fireburst resolves normally")
		await wait_seconds(.12)
		await shot("courtyard-blast-%d"%resolution.x)
		await wait_seconds(.6)
		await profile_effects(point)
		presentation.clear_effects()
		while controller.scheduler.active_unit().stable_id!="hero-02": controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
		check(controller.submit_command(AttackCommand.new("hero-02","enemy-01")),"Cleric mace cue resolves in courtyard")
		await wait_seconds(.12)
		await shot("courtyard-mace-%d"%resolution.x)
		await wait_seconds(.3)
		while controller.scheduler.active_unit().stable_id!="hero-01": controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
		check(controller.submit_command(AttackCommand.new("hero-01","enemy-01")),"Mage focus bolt uses arcane cue")
		await wait_seconds(.1)
		await shot("courtyard-arcane-%d"%resolution.x)
		await wait_seconds(.3)
		encounter.shutdown()
		encounter.queue_free()
		await process_frame
		await wait_seconds(.1)

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size=Vector2i(1280,720)
	capture=AudioEffectCapture.new()
	capture.buffer_length=4
	AudioServer.add_bus_effect(0,capture)
	var flow := (load("res://scenes/main.tscn") as PackedScene).instantiate() as SceneFlow
	root.add_child(flow)
	await wait_seconds(.6)
	await shot("title-1280")
	flow.audio.show_settings()
	await shot("settings-title-1280")
	flow.audio.panel.close()
	var old_path := flow.audio.settings_path
	flow.audio.settings_path="user://review-audio.cfg"
	for bus in ["Music","SFX","Ambience"]: flow.audio.set_preference(bus,1,true)
	await wait_seconds(.1)
	capture.clear_buffer()
	flow.audio.play_ui()
	await create_timer(.15).timeout
	var muted_buffer := capture.get_buffer(capture.get_frames_available())
	var muted_peak := 0.0
	for value in muted_buffer: muted_peak=maxf(muted_peak,maxf(absf(value.x),absf(value.y)))
	check(muted_peak<.0001,"Muted child buses produce silent master capture")
	metrics.append({"muted_bus_peak":muted_peak})
	flow.audio.settings_path=old_path
	flow.audio.load_preferences()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://review-audio.cfg"))
	flow.queue_free()
	await process_frame
	await wait_seconds(.1)
	# Fixed collision fixture makes each weapon/ability review reproducible.
	encounter=(load("res://scenes/combat_encounter.tscn") as PackedScene).instantiate() as Node3D
	encounter.get_node("EnemyController").enabled=false
	root.add_child(encounter)
	for frame in range(1600):
		await process_frame
		if encounter.navigation_ready: break
	controller=encounter.get_node("CombatController") as CombatController
	ai=encounter.get_node("EnemyController") as EnemyController
	presentation=encounter.get_node("CombatPresentation") as CombatPresentation
	audio=get_first_node_in_group("game_audio") as GameAudio
	warden=controller.find_unit("hero-01")
	scout=controller.find_unit("hero-02")
	raider=controller.find_unit("enemy-01")
	sentinel=controller.find_unit("enemy-02")
	var rig := encounter.get_node("TacticalCamera") as TacticalCamera
	rig.position=Vector3(-2,0,5)
	rig.distance=19
	rig.pitch=-.95
	rig._update_transform()
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		audio.show_settings()
		await shot("settings-combat-%d"%resolution.x)
		audio.panel.close()
		await fresh()
		controller.submit_command(MoveCommand.new(warden.stable_id,warden.position+Vector3(0,0,2)))
		await wait_seconds(.38)
		await shot("movement-%d"%resolution.x)
		await fresh()
		controller.submit_command(AttackCommand.new(warden.stable_id,raider.stable_id))
		await wait_seconds(.04)
		await shot("sword-%d"%resolution.x)
		await fresh()
		controller.submit_command(UseAbilityCommand.new(warden.stable_id,raider.stable_id,"power_strike"))
		await wait_seconds(.05)
		await shot("power-%d"%resolution.x)
		await fresh()
		warden.set_health(10)
		controller.submit_command(UseAbilityCommand.new(warden.stable_id,warden.stable_id,"mend"))
		await wait_seconds(.18)
		await shot("mend-%d"%resolution.x)
		await ranged_fixture()
		controller.submit_command(AttackCommand.new(scout.stable_id,raider.stable_id))
		await wait_seconds(.06)
		await shot("bow-%d"%resolution.x)
		await ranged_fixture()
		controller.submit_command(UseAbilityCommand.new(scout.stable_id,raider.stable_id,"crippling_shot"))
		await wait_seconds(.06)
		await shot("crippling-%d"%resolution.x)
		await ranged_fixture()
		warden.position=Vector3(0,0,6)
		raider.position=Vector3(0,0,8)
		await physics_frame
		await physics_frame
		check(controller.submit_command(UseAbilityCommand.on_ground(scout.stable_id,"fireburst",Vector3(0,0,7))),"Rendered Fireburst commits")
		await wait_seconds(.13)
		await shot("fireburst-%d"%resolution.x)
		await wait_seconds(.5)
		await profile_effects()
		await fresh()
		print("Preparing lethal draw fixture")
		for unit in controller.units:
			unit.position=Vector3(0,0,7)+Vector3(-1 if unit==scout else 1,0,0)
			unit.set_health(3)
		# Spread overlapping staged units before querying; blast ignores bodies.
		scout.position=Vector3(-1,0,7)
		warden.position=Vector3(1,0,7)
		raider.position=Vector3(0,0,6)
		sentinel.position=Vector3(0,0,8)
		while controller.scheduler.active_unit()!=scout: controller.submit_command(EndTurnCommand.new(controller.scheduler.active_unit().stable_id))
		await physics_frame
		await physics_frame
		controller.submit_command(UseAbilityCommand.on_ground(scout.stable_id,"fireburst",Vector3(0,0,7)))
		check(controller.state==CombatController.State.DRAW,"Rendered simultaneous death draw")
		await wait_seconds(.12)
		await shot("draw-%d"%resolution.x)
		await wait_seconds(.4)
	encounter.shutdown()
	encounter.queue_free()
	await process_frame
	await wait_seconds(.15)
	await courtyard_effects()
	write_capture()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	print("SOUND RENDER RESULT: %d failures; non-silent mixer capture does not assess listening quality"%failures)
	quit(0 if failures==0 else 1)
