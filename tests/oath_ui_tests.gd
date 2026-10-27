extends SceneTree
var failures: int=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var flow:=load("res://scenes/main.tscn").instantiate() as SceneFlow;root.add_child(flow)
	flow.audio.preferences=SettingsSchema.defaults()
	flow.audio.preferences.Camera.reduced_motion=true
	check(OathUI.reduced(flow),"Reduced motion uses Camera settings")
	var control:=Control.new();root.add_child(control);OathUI.reveal(control)
	check(control.modulate.a==1.0,"Reduced motion avoids reveal animation")
	flow.audio.preferences.Camera.reduced_motion=false;OathUI.reveal(control);OathUI.reveal(control)
	for frame in 25:await process_frame
	check(control.modulate.a==1.0,"Repeated reveals settle exactly once")
	control.queue_free()
	var theme:=OathUI.theme()
	check(theme==OathUI.theme(),"Screens reuse one theme")
	for type in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","disabled","focus"]: check(theme.has_stylebox(state,type),"Button state "+type+state)
	for id in ["knight","ranger","mage","cleric","lantern","mission","armoury","training","health","move","attack","settings","fireburst","slow","end_turn"]:check(OathUI.icon(id)!=null,"Runtime vector symbol: "+id)
	var portrait:=CharacterPortrait.new();root.add_child(portrait);portrait.setup("knight")
	for frame in 10:await process_frame
	check(portrait.get_child(0).render_target_update_mode==SubViewport.UPDATE_DISABLED,"Static portrait stops rendering")
	portrait.queue_free()
	# Fast teardown before the deferred portrait freeze finishes.
	var transient:=CharacterPortrait.new();root.add_child(transient);transient.setup("mage");transient.queue_free()
	for frame in 5:await process_frame
	flow.campaign.state=null;flow.queue_free()
	for frame in 5:await process_frame
	print("OATH UI RESULT: %d failures"%failures);quit(0 if failures==0 else 1)
