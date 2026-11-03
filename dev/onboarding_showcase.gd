extends "res://tests/rescue_tutorial_tests.gd"
## Actual renderer capture; isolated campaign and settings, never a player slot.
var view: SubViewport
const OUTPUT := "res://docs/onboarding/screenshots"
func capture(label: String) -> void:
 await settle()
 await RenderingServer.frame_post_draw
 var image := view.get_texture().get_image()
 check(image.save_png(OUTPUT.path_join(label+".png"))==OK,"Renderer screenshot saved: "+label)
func wait_stage(value: String) -> void:
 for frame in range(2000):
  if flow.combat.rescue_lesson.stage==value: return
  await process_frame
 check(false,"Capture reaches actual lesson stage: "+value)
func click(button: Button) -> void:
 check(button!=null,"Capture interaction button exists")
 if button==null: return
 var point := button.get_global_rect().get_center()
 for down in [true,false]:
  var event := InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=down
  view.push_input(event,true);Input.flush_buffered_events()
 await settle()
func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 view=SubViewport.new();view.own_world_3d=true;view.gui_embed_subwindows=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 flow=load("res://scenes/main.tscn").instantiate();view.add_child(flow)
 flow.audio.settings_path="user://onboarding-showcase-settings.cfg"
 flow.campaign.store.path="user://onboarding-showcase-campaign.json"
 for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
  view.size=size
  flow.audio.preferences.Accessibility.ui_scale=1.0;flow.audio.preferences.Accessibility.large_text=false
  flow.campaign.state=null;flow.show_title();flow.audio.apply_preferences(false)
  await capture("title-%d"%size.x)
  flow.campaign.state=CampaignState.new(423)
  flow.campaign.selected=PackedStringArray(flow.campaign.state.living_ids().slice(0,2))
  flow.campaign.onboarding.reset()
  flow.campaign.headquarters();flow.audio.apply_preferences(false)
  await capture("camp-guide-%d"%size.x)
  var rules_button: Button
  for button in flow.menu.find_children("*","Button",true,false):
   if button.text=="Camp Rules": rules_button=button
  await click(rules_button)
  check(flow.menu_guide!=null and flow.menu_guide.panel.visible,"Real menu click opens campaign rules")
  await capture("camp-rules-%d"%size.x)
  flow.menu_guide.close()
  flow.campaign.prepare(flow.campaign.state.offers[0].id);flow.audio.apply_preferences(false)
  await capture("deployment-%d"%size.x)
  flow.start_rescue_tutorial();await wait_ready();await wait_stage("approach")
  flow.audio.apply_preferences(false)
  await capture("rescue-approach-%d"%size.x)
  var combat: CombatController=flow.combat.get_node("CombatController")
  check(combat.submit_player_command(MoveCommand.new("hero-02",Vector3(-5.8,0,1.2))),"Showcase approved approach")
  await action_wait(combat)
  await capture("rescue-stabilise-%d"%size.x)
  check(combat.submit_player_command(RescueCommand.new("hero-02","hero-01",RescueCommand.Kind.STABILISE)),"Showcase stabilises")
  combat.submit_player_command(EndTurnCommand.new("hero-02"));await wait_stage("carry")
  check(combat.submit_player_command(RescueCommand.new("hero-02","hero-01",RescueCommand.Kind.PICKUP)),"Showcase carries")
  await capture("rescue-carry-%d"%size.x)
  check(combat.submit_player_command(MoveCommand.new("hero-02",Vector3(-3.5,0,1.2))),"Showcase carry move")
  await action_wait(combat)
  combat.submit_player_command(EndTurnCommand.new("hero-02"));await wait_stage("extract")
  check(combat.submit_player_command(RescueCommand.new("hero-02","",RescueCommand.Kind.EXTRACT)),"Showcase extracts")
  await capture("rescue-complete-%d"%size.x)
  flow.request_transition("main_menu");await settle()
 # Existing maximum UI scale/large text; no settings save is performed.
 view.size=Vector2i(1280,720)
 flow.campaign.state=CampaignState.new(423);flow.campaign.headquarters()
 flow.audio.preferences.Accessibility.ui_scale=1.15;flow.audio.preferences.Accessibility.large_text=true;flow.audio.apply_preferences(false)
 await capture("camp-large-text-1280")
 flow.request_transition("campaign_rules");flow.audio.apply_preferences(false)
 await capture("camp-rules-large-text-1280")
 flow.menu_guide.close();flow.start_rescue_tutorial();await wait_ready();await wait_stage("approach")
 flow.audio.apply_preferences(false)
 await capture("rescue-large-text-1280")
 flow.campaign.state=null;flow.show_title();flow.queue_free();await settle();view.queue_free();await settle()
 print("ONBOARDING SHOWCASE RESULT: %d failures"%failures)
 quit(1 if failures else 0)
