extends SceneTree
## Standalone external script: no res://tests dependencies in the production pack.
var failures: int=0
var flow: SceneFlow
func check(value: bool,message: String) -> void:
 if not value: failures+=1;push_error(message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
 for frame in range(16): await process_frame
func ready() -> void:
 for frame in range(2400):
  if flow.combat!=null and flow.combat.navigation_ready:
   flow.combat.guide.close();return
  await process_frame
 check(false,"Pack encounter setup completes")
func stage(value: String) -> void:
 for frame in range(2400):
  if flow.combat.rescue_lesson.stage==value: return
  await process_frame
 check(false,"Pack lesson reaches "+value)
func idle(combat: CombatController) -> void:
 for frame in range(1200):
  if combat.state!=CombatController.State.RESOLVING_ACTION: return
  await process_frame
 check(false,"Pack action completes")
func run() -> void:
 flow=load("res://scenes/main.tscn").instantiate();root.add_child(flow)
 var campaign := CampaignState.new(423)
 flow.campaign.state=campaign;flow.campaign.store.path="user://pack-onboarding-campaign.json"
 check(flow.campaign.store.write(campaign,"headquarters"),"Pack campaign fixture saves")
 var before := campaign.snapshot()
 var bytes := FileAccess.get_file_as_string(flow.campaign.store.path)
 var old_completion: bool=flow.audio.tutorial_completed
 flow.start_rescue_tutorial();await ready();await stage("approach")
 var combat: CombatController=flow.combat.get_node("CombatController")
 check(combat.submit_player_command(MoveCommand.new("hero-02",Vector3(-5.8,0,1.2))),"Pack approach")
 await idle(combat)
 check(combat.submit_player_command(RescueCommand.new("hero-02","hero-01",RescueCommand.Kind.STABILISE)),"Pack stabilise")
 combat.submit_player_command(EndTurnCommand.new("hero-02"));await stage("carry")
 check(combat.submit_player_command(RescueCommand.new("hero-02","hero-01",RescueCommand.Kind.PICKUP)),"Pack carry")
 check(combat.submit_player_command(MoveCommand.new("hero-02",Vector3(-3.5,0,1.2))),"Pack movement")
 await idle(combat)
 combat.submit_player_command(EndTurnCommand.new("hero-02"));await stage("extract")
 check(combat.submit_player_command(RescueCommand.new("hero-02","",RescueCommand.Kind.EXTRACT)),"Pack extract")
 await settle()
 check(flow.combat.rescue_lesson.stage=="complete" and combat.state==CombatController.State.DEFEAT,"Pack retreat teaching preserves outcome")
 check(flow.audio.tutorial_completed==old_completion and campaign.snapshot()==before and FileAccess.get_file_as_string(flow.campaign.store.path)==bytes,"Pack training preserves campaign and completion")
 flow.request_transition("campaign_hq");await settle()
 flow.request_transition("campaign_rules");await settle()
 check(flow.menu_guide!=null and flow.menu_guide.panel.visible,"Pack campaign help opens")
 flow.menu_guide.close();flow.campaign.state=null
 flow.start_tutorial();await ready()
 check(flow.combat.tutorial!=null and flow.combat.tutorial.step==TutorialDirector.Step.CAMERA,"Pack basic tutorial remains available")
 flow.show_title();flow.queue_free();await settle()
 print("ONBOARDING PACK RESULT: %d failures"%failures)
 quit(1 if failures else 0)
