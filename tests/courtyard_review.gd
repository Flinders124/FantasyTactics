extends "res://tests/generation_tests.gd"
## Rendered review only: run without --headless. No altered gameplay definitions.
var report: Array[Dictionary] = []
const OUTPUT: String = "res://../verification/courtyard/"

func snapshot(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+label+".png"))

func profile_scene(label: String) -> void:
	for frame in range(40): await process_frame
	var samples: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	for frame in range(120):
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now-previous)/1000.0)
		previous=now
	samples.sort()
	var result := {"scene":label,"resolution":str(root.size),"frames":120,"wall_fps":120000000.0/float(Time.get_ticks_usec()-start),"median_frame_ms":samples[60],"p95_frame_ms":samples[114],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	report.append(result)
	print("PROFILE ",JSON.stringify(result))

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		for seed_value in [7,19,23]:
			var config := EncounterConfiguration.new()
			config.battlefield_seed=seed_value
			config.hero_ids=["mage","cleric"]
			var encounter := await prepare(config)
			var combat := encounter.get_node("CombatController") as CombatController
			while combat.scheduler.active_unit().faction==CombatUnit.Faction.ENEMY:
				combat.submit_command(EndTurnCommand.new(combat.scheduler.active_unit().stable_id))
			var player := encounter.get_node("PlayerController") as PlayerController
			player.set_process(false) # Hold shared previews steady for review captures.
			player.cancel_targeting()
			var rig := encounter.get_node("TacticalCamera") as TacticalCamera
			var hud := encounter.get_node("HUD") as CanvasLayer
			hud.hide()
			for angle in [0.4,2.0,3.7]:
				rig.distance=30
				rig.pitch=-.82
				rig.yaw=angle
				rig._update_transform()
				await snapshot("seed-%d-%d-angle-%d"%[seed_value,resolution.x,int(angle*10)])
			if seed_value==7:
				rig.frame_arena(config.layout.arena_size)
				hud.show()
				var actor := combat.scheduler.active_unit()
				var point := actor.position+Vector3(2,0,0)
				var route := combat.evaluate_move(actor,point)
				check(route.valid(),"Review move has legal route")
				player.set_mode(PlayerController.Mode.MOVE)
				player._draw(route.path,route.valid())
				player._show_destination(point,route.valid(),route.distance)
				player._feedback(route.distance,route.valid(),"Click destination to move. Cost follows the full route.")
				await snapshot("route-%d"%resolution.x)
				player.select_ability("fireburst")
				check(player._can_command() and combat.evaluate_ground_ability(actor,actor.position,"fireburst").valid(),"Review area preview uses legal hero cast")
				player.ground_selected=true
				player.selected_ground=actor.position
				player.show_ground_preview(actor.position)
				await snapshot("area-%d"%resolution.x)
				player.cancel_targeting()
				await profile_scene("seed-7-normal-HUD")
			await dispose(encounter)
	var file := FileAccess.open(OUTPUT+"profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("RESULT: %d failures"%failures)
	quit(0 if failures==0 else 1)
