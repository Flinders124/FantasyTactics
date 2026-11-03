extends "res://tests/campaign_events_flow_tests.gd"
## Isolated actual-renderer review. No player saves or settings are touched.
var view: SubViewport
const OUTPUT: String="res://docs/campaign-events/screenshots"
func capture(label: String) -> void:
 await settle();await RenderingServer.frame_post_draw
 check(view.get_texture().get_image().save_png(OUTPUT.path_join(label+".png"))==OK,"Capture saved: "+label)
func click(button: Button) -> void:
 check(button!=null,"Visible interaction exists")
 if button==null: return
 var point := button.get_global_rect().get_center()
 check(Rect2(Vector2.ZERO,Vector2(view.size)).has_point(point),"Button is within viewport")
 for down in [true,false]:
  var event := InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=down
  view.push_input(event,true);Input.flush_buffered_events()
 await settle()
func button_named(label: String) -> Button:
 for node: Node in flow.menu.find_children("*","Button",true,false):
  if node is Button and node.text==label and not node.disabled: return node
 return null
func fixture() -> CampaignState:
 var state := CampaignState.new(37)
 var party := PackedStringArray(state.living_ids().slice(0,2))
 state.commit(state.offers[0].id,party)
 var people: Dictionary={}
 for id: String in party: people[id]={"health":3,"maximum_health":10,"survival":"recovered","death_cause":""}
 check(state.resolve(CampaignMissionResult.new({"version":2,"mission_id":state.active.id,"outcome":"victory","abandoned":false,"reason":"Rendered review fixture","heroes":people,"rounds":3,"tactical_result":"VICTORY"})),"Showcase uses real result pipeline")
 state.pending_event=CampaignEvents.freeze(state,CampaignEvents.definition("herbs"))
 return state
func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 view=SubViewport.new();view.own_world_3d=true;view.gui_embed_subwindows=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 flow=load("res://scenes/main.tscn").instantiate();view.add_child(flow)
 flow.audio.settings_path="user://events-showcase-settings.cfg";flow.campaign.store.path="user://events-showcase.json"
 for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
  for large: bool in [false,true]:
   view.size=size
   flow.audio.preferences.Accessibility.ui_scale=1.15 if large else 1.0;flow.audio.preferences.Accessibility.large_text=large
   var state := fixture();flow.campaign.state=state;flow.campaign.selected=PackedStringArray(state.living_ids().slice(0,2));flow.campaign.armoury_hero=state.living_ids()[0]
   check(flow.campaign.store.write(state,"headquarters"),"Showcase private checkpoint valid")
   flow.campaign.headquarters();flow.audio.apply_preferences(false)
   var suffix := "-%d%s"%[size.x,"-large" if large else ""]
   await capture("camp"+suffix)
   await click(button_named("Review decision"))
   check(flow.screen=="campaign_event","Real click opens event")
   await capture("event"+suffix)
   await click(button_named("Choose"))
   check(flow.menu_guide!=null and flow.menu_guide.panel.visible,"Choice asks for confirmation")
   await capture("confirmation"+suffix)
   var point := flow.menu_guide.confirm_button.get_global_rect().get_center()
   for down in [true,false]:
    var event := InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=down
    view.push_input(event,true);Input.flush_buffered_events()
   await settle()
   check(state.pending_event.is_empty() and state.event_records.size()==1,"Real confirmation persists one decision")
   flow.campaign.show_dossier(state.living_ids()[0]);flow.audio.apply_preferences(false)
   await capture("dossier"+suffix)
   check(flow.menu.get_global_rect().size.y<=view.size.y+1,"Dossier stays within viewport")
 flow.campaign.state=null;flow.show_title();flow.queue_free();await settle();view.queue_free();await settle()
 print("CAMPAIGN EVENTS SHOWCASE RESULT: %d failures"%failures);quit(1 if failures else 0)
