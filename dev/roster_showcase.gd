extends SceneTree
## Capture real roster models and campaign UI; no combat rules changed.
var failures: int=0
var flow: SceneFlow
const OUTPUT := "res://docs/roster-milestone/screenshots"
func _initialize() -> void: call_deferred("run")
func settle(count: int=16) -> void:
 for frame in range(count): await process_frame
func shot(name: String) -> void:
 await settle()
 await RenderingServer.frame_post_draw
 if root.get_texture().get_image().save_png(OUTPUT.path_join(name+".png"))!=OK: failures+=1
func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 root.size=Vector2i(1280,720)
 var showcase: Node3D = load("res://scenes/character_showcase.tscn").instantiate()
 root.add_child(showcase)
 for view_index in range(4):
  showcase.set_view(view_index)
  await shot(["roster-front","roster-side","roster-rear","roster-tactical"][view_index])
 for clip in ["Walk","Attack","Cast","Hit","Death"]:
  showcase.set_clip(clip)
  for visual in showcase.visuals:
   visual.player.advance(.12) # Finish the ordinary cross-fade before freezing a review pose.
   visual.player.pause()
   var phase: float=.15 if clip in ["Attack","Cast"] else (1.0 if clip=="Death" else .5)
   visual.player.seek(visual.player.get_animation(visual._clips[clip]).length*phase,true)
  await shot("roster-"+clip.to_lower())
 showcase.queue_free()
 await settle()
 if "--models-only" in OS.get_cmdline_user_args():
  print("ROSTER MODEL SHOWCASE RESULT: %d failures" % failures)
  quit(1 if failures else 0)
  return
 flow=load("res://scenes/main.tscn").instantiate()
 root.add_child(flow)
 flow.campaign.store.path="user://roster-showcase/active.json"
 flow.campaign.state=CampaignState.new(423)
 flow.campaign.selected=PackedStringArray(flow.campaign.state.living_ids().slice(0,2))
 flow.campaign.armoury_hero=flow.campaign.selected[0]
 flow.campaign.headquarters()
 await shot("recruits-camp-1280")
 var state: CampaignState=flow.campaign.state
 state.supplies=300
 var ids := state.living_ids()
 state.train_recruit(ids[0])
 flow.campaign.headquarters()
 flow.menu.open_camp_page(2)
 await settle()
 var training_scroll: ScrollContainer=flow.menu.tabs.get_child(2)
 for item in training_scroll.find_children("*","Button",true,false):
  if item.text=="Become Chainbinder": training_scroll.ensure_control_visible(item)
 await shot("specialisation-1280")
 root.size=Vector2i(1920,1080)
 await shot("specialisation-1920")
 root.size=Vector2i(1280,720)
 state.specialise(ids[0],"aegisbearer")
 state.train_recruit(ids[1])
 state.specialise(ids[1],"chainbinder")
 flow.campaign.hq_open=false
 flow.campaign.headquarters()
 await shot("specialists-camp-1280")
 flow.menu.open_camp_page(1)
 await shot("roster-1280")
 root.size=Vector2i(1920,1080)
 await shot("roster-1920")
 root.size=Vector2i(1280,720)
 flow.campaign.selected=PackedStringArray([ids[0],ids[1]])
 flow.campaign.prepare(state.offers[0].id)
 await shot("deployment-1280")
 flow.campaign.deploy()
 for frame in range(2000):
  await process_frame
  if flow.combat!=null and flow.combat.navigation_ready: break
 if flow.combat==null or not flow.combat.navigation_ready:
  failures+=1
 else:
  flow.combat.get_node("EnemyController").enabled=false
  flow.combat.guide.close()
  var combat: CombatController=flow.combat.get_node("CombatController")
  for step in range(8):
   var active := combat.scheduler.active_unit()
   if active.faction==CombatUnit.Faction.HERO: break
   combat.submit_command(EndTurnCommand.new(active.stable_id))
  await shot("combat-1280")
  root.size=Vector2i(1920,1080)
  await shot("combat-1920")
  root.size=Vector2i(1280,720)
  combat._deal_damage(combat.find_unit("hero-01"),999)
  flow.combat.get_node("PlayerController").target_rescue(0)
  await shot("rescue-1280")
 flow.campaign.state=null
 flow.show_title()
 flow.queue_free()
 await settle()
 print("ROSTER SHOWCASE RESULT: %d failures" % failures)
 quit(1 if failures else 0)
