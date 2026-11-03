extends "res://tests/headquarters_flow_tests.gd"
## Isolated scripted native review of the real menu widgets and campaign operations.
const OUTPUT: String="res://docs/headquarters/screenshots"
var view: SubViewport
func capture(label: String) -> void:
 await settle();await RenderingServer.frame_post_draw
 check(view.get_texture().get_image().save_png(OUTPUT.path_join(label+".png"))==OK,"Capture "+label)
func copy_state(state: CampaignState) -> CampaignState:
 var decoded := CampaignSaveCodec.decode(CampaignSaveCodec.encode(state,"headquarters"))
 check(decoded.state!=null,"Showcase checkpoint validates: "+decoded.error)
 return decoded.state
func resolve_win(state: CampaignState) -> void:
 var party := PackedStringArray(state.living_ids().slice(0,2))
 check(state.commit(state.offers[0].id,party)!=null,"Showcase mission commits")
 var people: Dictionary={}
 for id: String in party:
  var definition := state.preview_definition(id)
  people[id]={"health":definition.maximum_health,"maximum_health":definition.maximum_health,"survival":"recovered","death_cause":""}
 check(state.resolve(CampaignMissionResult.new({"version":2,"mission_id":state.active.id,"outcome":"victory","abandoned":false,"reason":"Mission complete","heroes":people,"rounds":3,"tactical_result":"VICTORY"})),"Showcase authoritative result")
 if not state.pending_event.is_empty(): state.choose_event(state.pending_event.id,"decline")
func mount(state: CampaignState) -> void:
 flow.campaign.state=state;flow.campaign.selected=PackedStringArray(state.living_ids().slice(0,2));flow.campaign.armoury_hero=state.living_ids()[0];flow.campaign.hq_open=false
 check(flow.campaign.store.write(state,"headquarters"),"Private rendered fixture saves")
 flow.campaign.headquarters();flow.audio.apply_preferences(false)
func find_action(action: String) -> Button:
 for node in flow.menu.find_children("*","Button",true,false):
  if node.get_meta("campaign_action","")==action: return node
 return null
func click(button: Button) -> void:
 check(button!=null,"Requested real button exists")
 if button==null: return
 button.grab_focus();await settle()
 var point := button.get_global_rect().get_center()
 check(Rect2(Vector2.ZERO,Vector2(view.size)).has_point(point),"Focused button scrolls into view")
 for down in [true,false]:
  var event := InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=down
  view.push_input(event,true);Input.flush_buffered_events()
 await settle()
func confirm() -> void:
 check(flow.menu_guide!=null and flow.menu_guide.panel.visible,"Confirmation is visible")
 if flow.menu_guide!=null: await click(flow.menu_guide.confirm_button)
func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 Engine.max_fps=60;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 view=SubViewport.new();view.own_world_3d=true;view.gui_embed_subwindows=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 flow=load("res://scenes/main.tscn").instantiate();view.add_child(flow)
 flow.audio.settings_path="user://headquarters-showcase-settings.cfg";flow.campaign.store.path="user://headquarters-showcase-campaign.json"
 for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
  view.size=size;flow.audio.preferences.Accessibility.ui_scale=1.0;flow.audio.preferences.Accessibility.large_text=false
  var suffix := "-%d"%size.x
  var state := CampaignState.new(37)
  mount(state);await capture("camp-tier0"+suffix)
  resolve_win(state)
  var ids := state.living_ids()
  state.specialise(ids[0],"knight");state.specialise(ids[1],"ranger")
  mount(state);flow.menu.open_camp_page(4);await settle()
  await capture("commander"+suffix)
  await click(find_action("campaign_command:1"));await confirm()
  check(state.command_tier==1,"Real commander purchase unlocks three heroes")
  flow.menu.close_camp_page(false);await capture("camp-tier1"+suffix)
  resolve_win(state);var trade_checkpoint := copy_state(state)
  mount(state);flow.menu.open_camp_page(4);await settle()
  await click(find_action("campaign_command:2"));await confirm()
  check(state.command_tier==2,"Real commander purchase unlocks four heroes")
  check(state.train_recruit(ids[2]) and state.specialise(ids[2],"cleric"),"Third hero is prepared using normal training")
  check(state.train_recruit(ids[3]) and state.specialise(ids[3],"mage"),"Fourth hero is prepared using normal training")
  var combat_checkpoint := copy_state(state)
  mount(state);await capture("camp-tier2-trader"+suffix)
  # Separate legitimate checkpoint demonstrates choosing premium equipment over the second command purchase.
  state=trade_checkpoint;mount(state);flow.menu.open_camp_page(5);await settle()
  await capture("trader"+suffix)
  var entry: Dictionary={}
  for offer: Dictionary in state.trader.offers:
   if offer.item_id=="beacon_helm": entry=offer
  check(not entry.is_empty(),"Useful premium helmet is offered")
  var original_variant: String=entry.art_variant
  await click(find_action("campaign_trader_buy:"+str(entry.offer_id)));await confirm()
  var purchased: String=""
  for id: String in state.inventory:
   if state.inventory[id].definition_id=="beacon_helm": purchased=id
  check(not purchased.is_empty() and state.owner_of(purchased).is_empty(),"Trader purchase does not equip")
  flow.campaign.shop_filter="helmet";flow.campaign.hq_tab=3;flow.campaign.hq_open=true;flow.campaign.headquarters();flow.audio.apply_preferences(false)
  var shop_scroll := flow.menu.tabs.get_child(3) as ScrollContainer
  shop_scroll.scroll_vertical=250
  await capture("shop"+suffix)
  flow.campaign.show_dossier(ids[0]);flow.audio.apply_preferences(false);await capture("character"+suffix)
  await click(find_action("campaign_slot:"+ids[0]+":helmet"));await capture("slot-chooser"+suffix)
  await click(find_action("campaign_equip_for:"+ids[0]+":"+purchased))
  check(state.owner_of(purchased)==ids[0] and state.inventory[purchased].art_variant==original_variant,"Character slot equips the same purchased variant")
  await capture("equipped"+suffix)
  if size.x==1280:
   flow.audio.preferences.Accessibility.ui_scale=1.15;flow.audio.preferences.Accessibility.large_text=true;flow.audio.apply_preferences(false)
   flow.campaign.show_dossier(ids[0]);flow.audio.apply_preferences(false)
   var slot_button := find_action("campaign_slot:"+ids[0]+":helmet")
   slot_button.grab_focus();await settle();await capture("character-large-1280")
   mount(combat_checkpoint);flow.audio.apply_preferences(false);await capture("camp-large-1280")
   flow.menu.open_camp_page(5);await capture("trader-large-1280")
   flow.audio.preferences.Accessibility.ui_scale=1.0;flow.audio.preferences.Accessibility.large_text=false;flow.audio.apply_preferences(false)
  state=combat_checkpoint;mount(state);flow.campaign.selected=PackedStringArray(state.living_ids())
  flow.campaign.prepare(state.offers[0].id);flow.audio.apply_preferences(false);await capture("four-hero-preparation"+suffix)
  flow.request_transition("campaign_deploy");await wait_ready()
  check(flow.combat.get_node("CombatController").units.size()==state.active.party.size()+flow.combat.configuration.enemies.size(),"All four heroes and opponents appear")
  flow.combat.set_guidance_paused(true,"showcase")
  await capture("four-hero-combat"+suffix)
  flow.campaign.state=null;flow.show_title();await settle()
 var texture := load("res://assets/equipment/icons/generated_v1/legendary_helmet_a.png") as Texture2D
 check(texture.get_width()<=256,"Equipment texture import is capped for UI memory")
 flow.queue_free();await settle();view.queue_free();await settle()
 print("HEADQUARTERS SHOWCASE RESULT: %d failures"%failures);quit(1 if failures else 0)
