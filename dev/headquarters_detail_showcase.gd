extends "res://dev/headquarters_showcase.gd"
func run() -> void:
 Engine.max_fps=60;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 view=SubViewport.new();view.own_world_3d=true;view.gui_embed_subwindows=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 flow=load("res://scenes/main.tscn").instantiate();view.add_child(flow)
 flow.audio.settings_path="user://headquarters-detail-settings.cfg";flow.campaign.store.path="user://headquarters-detail-campaign.json"
 var state := CampaignState.new(37)
 resolve_win(state);resolve_win(state)
 var ids := state.living_ids();state.specialise(ids[0],"knight");state.specialise(ids[1],"ranger")
 for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
  view.size=size;flow.audio.preferences.Accessibility.ui_scale=1.0;flow.audio.preferences.Accessibility.large_text=false
  flow.campaign.shop_filter="helmet";flow.campaign.hq_tab=3;flow.campaign.hq_open=true;mount(state)
  flow.menu.open_camp_page(3);await settle()
  var scroll := flow.menu.tabs.get_child(3) as ScrollContainer
  scroll.scroll_vertical=250;await settle();await capture("shop-"+str(size.x))
  flow.audio.preferences.Accessibility.ui_scale=1.15;flow.audio.preferences.Accessibility.large_text=true
  flow.campaign.show_dossier(ids[0]);flow.audio.apply_preferences(false);await settle()
  var button := find_action("campaign_slot:"+ids[0]+":helmet")
  button.grab_focus();await settle()
  check(Rect2(Vector2.ZERO,Vector2(size)).has_point(button.get_global_rect().get_center()),"Large-text slot scrolls into view via keyboard focus")
  await capture("character-large-"+str(size.x))
 flow.campaign.state=null;flow.queue_free();await settle();view.queue_free();await settle()
 print("HEADQUARTERS DETAIL RESULT: %d failures"%failures);quit(1 if failures else 0)
