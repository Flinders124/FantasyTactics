extends SceneTree
var failures: int=0
var flow: SceneFlow
var view: SubViewport
var measurements: Array[Dictionary]=[]
const OUTPUT: String="res://docs/tactical-situations/screenshots"
func check(ok: bool,message: String) -> void:
 if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func settle(frames: int=12) -> void:
 for frame in range(frames):await process_frame
func capture(name: String) -> void:
 await settle();await RenderingServer.frame_post_draw
 check(view.get_texture().get_image().save_png(OUTPUT.path_join(name+".png"))==OK,"Actual renderer capture: "+name)
func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT));Engine.max_fps=60;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 view=SubViewport.new();view.own_world_3d=true;view.gui_embed_subwindows=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 flow=load("res://scenes/main.tscn").instantiate();view.add_child(flow);flow.audio.settings_path="user://situations-showcase-settings.cfg"
 for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
  view.size=size
  for preset in range(3):
   var config := EncounterConfiguration.new();config.battlefield_seed=37;config.generator_settings=EncounterOptions.presets()[preset].duplicate(true);config.generator_settings.generator_version=3;config.optional_goal_id="cache"
   var start := Time.get_ticks_msec();flow.start_configuration(config)
   for frame in range(2400):
    if flow.screen!="loading":break
    await process_frame
   check(flow.combat!=null and flow.combat.navigation_ready,"Native architecture setup")
   if flow.combat==null:continue
   var scene := flow.combat;scene.get_node("EnemyController").enabled=false;scene.guide.close();await settle()
   var setup_ms := Time.get_ticks_msec()-start
   var player: PlayerController=scene.get_node("PlayerController");player.set_process(false)
   var rig: TacticalCamera=scene.get_node("TacticalCamera")
   for angle in range(2):
    rig.yaw=float(angle)*PI*.6;rig._update_transform();player.show_move_preview(Vector3.ZERO)
    check(player.line.mesh!=null and player.line.mesh.get_surface_count()==2,"Native preview shows green route and red continuation")
    scene.courtyard_occlusion.update_visibility()
    await capture("%s-%d-angle%d"%[config.generator_settings.preset_id,size.x,angle])
   var begin := Time.get_ticks_usec();await settle(45)
   measurements.append({"preset":config.generator_settings.preset_id,"resolution":str(size),"setup_ms":setup_ms,"capped_frame_ms":(Time.get_ticks_usec()-begin)/45000.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)})
   if preset==0:
    rig.yaw=PI*.30;rig.pitch=-.55;rig.distance=17;rig.position=Vector3(0,0,2);rig._update_transform();player.cancel_targeting();await capture("courtyard-detail-"+str(size.x))
    var house_index: int=scene.configuration.layout.obstacle_kinds.find("house")
    var interior := NavigationService.planar(scene.configuration.layout.obstacle_centers[house_index])
    scene.get_node("CombatController").scheduler.active_unit().global_position=interior
    rig.position=interior;rig.yaw=0;rig.pitch=-.55;rig.distance=10;rig._update_transform();scene.courtyard_occlusion.update_visibility()
    var house := scene.get_node("NavigationRegion3D/Obstacle%d"%house_index)
    check(scene.courtyard_occlusion.entries.has(house) and scene.courtyard_occlusion.entries[house].active,"Native interior remains readable through faded walls")
    await capture("house-interior-"+str(size.x))
   flow.show_title();await settle()
 flow.queue_free();await settle();view.queue_free();await settle()
 var file := FileAccess.open("res://verification/tactical-situations/native-measurements.json",FileAccess.WRITE);file.store_string(JSON.stringify(measurements,"\t"));file.close()
 print("TACTICAL SHOWCASE RESULT: %d failures"%failures);quit(1 if failures else 0)
