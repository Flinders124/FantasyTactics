extends "res://tests/campaign_flow_tests.gd"
func run() -> void:
 root.size=Vector2i(1280,720)
 flow=load("res://scenes/main.tscn").instantiate();root.add_child(flow)
 var coordinator: Node=flow.campaign
 check(coordinator.has_signal("change_committed"),"Guidance observes authoritative persisted changes")
 if not coordinator.has_signal("change_committed"):
  flow.queue_free();await settle();print("CAMPAIGN ONBOARDING RESULT: %d failures"%failures);quit(1);return
 var state := CampaignState.new(17)
 coordinator.state=state;coordinator.store.path="user://camp-guide-test.json"
 check(coordinator.store.write(state,"headquarters"),"Isolated guide fixture saved")
 var accepted: Array[String]=[]
 coordinator.connect("change_committed",func(method: String) -> void: accepted.append(method))
 var guide: Variant=coordinator.get("onboarding")
 check(guide!=null,"Camp guidance is separate from campaign state")
 var before := state.snapshot()
 guide.visible=false
 check(state.snapshot()==before,"Dismissing guidance never mutates campaign")
 var id: String=state.living_ids()[0]
 check(coordinator.mutate("train_recruit",[id]),"Training accepted through existing persisted pipeline")
 check(accepted==["train_recruit"] and guide.operations.has("train_recruit"),"Accepted operation advances contextual guidance once")
 check(not coordinator.mutate("train_recruit",[id]) and accepted.size()==1,"Rejected repeated operation cannot advance guidance")
 var trained := state.snapshot()
 coordinator.store.fail_stage="write"
 check(not coordinator.mutate("specialise",[id,"knight"]) and accepted.size()==1,"Failed persistence cannot advance guidance")
 check(state.snapshot()==trained and not guide.operations.has("specialise"),"Failed change rolls back actual campaign and guidance")
 coordinator.store.fail_stage=""
 check(coordinator.mutate("specialise",[id,"knight"]),"Legal class choice succeeds")
 check(accepted.size()==2 and guide.operations.has("specialise"),"Successful class choice advances guidance")
 var rules: RosterRules=state.roster_rules.duplicate(true);rules.training_cost=9;state.roster_rules=rules
 check("9 Supplies" in FieldGuide.campaign(state),"Campaign explanations read actual editable values")
 state.roster_rules=load("res://definitions/roster_rules.tres")
 coordinator.selected=PackedStringArray(state.living_ids().slice(0,2))
 coordinator.headquarters(); await settle()
 check(flow.screen=="headquarters","Guidance preserves normal camp flow")
 flow.request_transition("campaign_guide");await settle()
 check(guide.visible,"Guide can be reopened")
 flow.request_transition("campaign_rules");await settle()
 check(flow.menu_guide!=null and flow.menu_guide.panel.visible and "RECRUITS" in flow.menu_guide.body.text,"Contextual campaign reference can be reopened")
 var bar: VScrollBar=flow.menu_guide.body.get_v_scroll_bar()
 bar.value=0
 var paging := InputEventKey.new();paging.keycode=KEY_PAGEDOWN;paging.pressed=true
 flow.menu_guide._input(paging)
 check(bar.value>0,"Long guides support keyboard page scrolling")
 flow.menu_guide.close()
 coordinator.prepare(state.offers[0].id);await settle()
 var scrolls: Array[Node]= flow.menu.body.find_children("*","ScrollContainer",true,false)
 check(not scrolls.is_empty() and scrolls[0].size.y>=250,"Deployment guidance leaves usable space for hero cards at 720p")
 coordinator.state=null;flow.queue_free();await settle()
 print("CAMPAIGN ONBOARDING RESULT: %d failures"%failures)
 quit(1 if failures else 0)
