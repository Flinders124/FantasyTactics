extends "res://tests/campaign_flow_tests.gd"
func rebind() -> void:
 flow.audio.begin_settings()
 flow.audio.preferences.Controls.move=["K:%d"%KEY_B]
 flow.audio.preferences.Controls.cancel=["K:%d"%KEY_ESCAPE,"K:%d"%KEY_N]
 check(SettingsSchema.bindings_valid(flow.audio.preferences.Controls),"Binding edit is valid with protected Escape")
 check(flow.audio.finish_settings(true),"Accepted bindings save in isolated settings")
func run() -> void:
 flow=load("res://scenes/main.tscn").instantiate();root.add_child(flow)
 flow.audio.settings_path="user://onboarding-bindings-test.cfg"
 var original: Dictionary=flow.audio.preferences.duplicate(true)
 flow.request_transition("controls")
 rebind()
 check("Move: B" in flow.menu_guide.body.text,"Already-open menu help refreshes accepted Move binding")
 var once := ControlBindings.instructions("Escape cancels.")
 check(ControlBindings.instructions(once)==once,"Repeated formatting does not duplicate alternate cancel bindings")
 flow.menu_guide.close()
 flow.start_rescue_tutorial();await wait_ready()
 for frame in range(1600):
  if flow.combat.rescue_lesson.stage=="approach": break
  await process_frame
 flow.combat.show_help()
 var combat: CombatController=flow.combat.get_node("CombatController")
 flow.audio.begin_settings();flow.audio.preferences.Controls.move=original.Controls.move.duplicate();check(flow.audio.finish_settings(true),"Binding can be restored while combat help is open")
 check("Move: M" in flow.combat.guide.body.text,"Already-open combat help refreshes restored binding")
 for frame in range(20): await process_frame
 check(paused and combat.guidance_paused and flow.combat.rescue_lesson.stage=="approach","Settings closing preserves help pause ownership")
 flow.combat.guide.close()
 check(not paused,"Closing final guide releases pause")
 flow.request_transition("main_menu");flow.combat.guide.confirm_button.pressed.emit();await settle()
 flow.audio.begin_settings();flow.audio.preferences=original;flow.audio.finish_settings(true)
 flow.queue_free();await settle()
 print("ONBOARDING BINDINGS RESULT: %d failures"%failures)
 quit(1 if failures else 0)
