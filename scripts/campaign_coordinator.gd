class_name CampaignCoordinator
extends Node
## Strategy/lifecycle bridge; CombatController continues to own tactical rules.
var flow: Node
var state: CampaignState
var difficulty_index: int=1
var seed_text: String="1"
var selected: PackedStringArray=["knight","ranger"]
var selected_mission: String=""
var hq_tab: int=0
var hq_open: bool=false
var camp_yaw: float=0
var camp_zoom: float=1
var armoury_hero: String="knight"
var notice: String=""
var store: CampaignSaveStore=CampaignSaveStore.new()
var save_phase: String="headquarters"
var save_status: String=""
var dirty: bool=false
var replace_allowed: bool=false
func _ready() -> void:
	store.path=CampaignSaveStore.default_path()
func feedback(message: String) -> void:
	save_status=message
	if flow.menu is CampaignScreen and is_instance_valid(flow.menu.save_feedback): flow.menu.save_feedback.text=message
func persist(phase: String) -> bool:
	save_phase=phase; feedback("Saving campaign…")
	var success := store.write(state,phase)
	dirty=not success; feedback(store.last_message)
	return success
func stable_phase() -> String:
	return "complete" if state!=null and not state.ending.is_empty() else ("in_progress" if state!=null and not state.active.is_empty() else save_phase)
func mutate(method: String,args: Array) -> Variant:
	if state==null or not state.active.is_empty() or not state.ending.is_empty(): return false
	if dirty and not persist(stable_phase()): return false
	var before := state.snapshot()
	var result: Variant=state.callv(method,args)
	if (result is bool and not result) or (result is String and result.is_empty()): return result
	if not persist("headquarters"):
		CampaignSaveCodec.apply_snapshot(state,before); dirty=false
		return false
	return result
func save_summary() -> Dictionary:
	var info := store.inspect()
	var saved: CampaignSaveCodec.Decoded=info.current if info.status=="valid" else info.backup
	var description := "No saved campaign."
	if saved.state!=null:
		description="%s · %d / 5 victories · Threat %d / 10 · %d Supplies\n%s"%[saved.state.difficulty().display_name,saved.state.victories,saved.state.threat,saved.state.supplies,{"headquarters":"At camp","debrief":"Mission debrief","in_progress":"Interrupted mission — restarts from original deployment","complete":"Campaign "+saved.state.ending}.get(saved.phase,saved.phase)]
	if info.status=="backup": description="Main save unavailable. Backup recovery is available.\n"+description
	elif info.status=="invalid": description=info.current.error+" No usable backup was found. New Campaign requires confirmation before replacing these files."
	return {"status":info.status,"description":description}
func continue_campaign() -> void:
	var info := store.inspect()
	if info.status=="valid": load_campaign(info.current)
	elif info.status=="backup":
		confirm("Recover backup campaign?","The main save is unavailable. Recover the previous valid backup? Its progress may be older. Damaged bytes are preserved.",func() -> void:
			var recovered := store.recover_backup()
			if recovered.state!=null: load_campaign(recovered); feedback(store.last_message)
			else: feedback(recovered.error))
	else:
		confirm("Campaign unavailable",str(info.current.error)+" No progress was changed. Start New Campaign only if you want to replace it.",func() -> void: pass)
func load_campaign(decoded: CampaignSaveCodec.Decoded) -> bool:
	if decoded.state==null: feedback(decoded.error); return false
	var config := CampaignSaveCodec.resume(decoded.state) if decoded.phase=="in_progress" else null
	if decoded.phase=="in_progress" and config==null: feedback("The committed mission could not be restored. No progress was changed."); return false
	# Parsing, content checks and encounter reconstruction all finish before this commit.
	state=decoded.state; save_phase=decoded.phase; dirty=false; replace_allowed=false
	armoury_hero=state.living_ids()[0] if not state.living_ids().is_empty() else str(state.heroes.keys()[0])
	selected=PackedStringArray(state.active.party) if not state.active.is_empty() else PackedStringArray(state.living_ids().slice(0,2))
	hq_open=false; hq_tab=0; camp_yaw=0; camp_zoom=1
	save_status="Campaign loaded. Interrupted missions restart from original deployment."
	if config!=null: flow.start_configuration(config)
	elif decoded.phase in ["debrief","complete"]: show_debrief()
	else: headquarters()
	return true
func mount() -> CampaignScreen:
	flow._clear_screen()
	flow.audio.set_context("menu")
	var view := CampaignScreen.new(); view.coordinator=self
	flow.menu=view; flow.interface_layer.add_child(view)
	var ticket: int=flow.epoch
	view.requested.connect(func(action: String) -> void:
		if ticket==flow.epoch: flow.request_transition(action))
	return view
func creation() -> void:
	seed_text=str(flow._new_seed())
	var view := mount(); flow.screen="campaign_creation"; view.create_run(seed_text.to_int())
func begin() -> void:
	if not seed_text.is_valid_int() or seed_text.to_int()<0 or seed_text.to_int()>4294967295:
		flow.request_transition("controls")
		flow.menu_guide.open("Invalid campaign seed","Enter a whole number from 0 to 4294967295.")
		return
	if store.inspect().exists and not replace_allowed:
		confirm("Replace saved campaign?","This replaces the one saved campaign. Unreadable files are preserved, but their progress will no longer be the active campaign.",func() -> void: replace_allowed=true; begin())
		return
	var candidate := CampaignState.new(seed_text.to_int(),EncounterOptions.difficulties()[difficulty_index].stable_id)
	if not store.write(candidate,"headquarters",replace_allowed): feedback(store.last_message); return
	state=candidate; save_phase="headquarters"; dirty=false; replace_allowed=false; save_status=store.last_message
	selected=PackedStringArray(state.living_ids().slice(0,2)); armoury_hero=selected[0]; selected_mission=""; hq_tab=0; hq_open=false
	camp_yaw=0; camp_zoom=1
	headquarters()
func headquarters() -> void:
	if state==null: flow.show_title(); return
	if not state.active.is_empty(): abandon_mission(); return
	selected=PackedStringArray(Array(selected).filter(func(id: String) -> bool: return state.living_ids().has(id)))
	if not state.living_ids().has(armoury_hero) and not state.living_ids().is_empty(): armoury_hero=state.living_ids()[0]
	var view := mount(); flow.screen="headquarters"; view.headquarters(state)
	if not notice.is_empty(): view.text(view.body,notice,15); notice=""
func prepare(id: String) -> void:
	if state==null or state.offer(id).is_empty() or not state.active.is_empty(): return
	selected_mission=id
	var view := mount(); flow.screen="campaign_preparation"; view.preparation(state,id,selected)
	if not notice.is_empty(): view.text(view.body,notice,15); notice=""
func choose(id: String) -> void:
	if state==null or not state.living_ids().has(id): return
	if selected.has(id): selected.remove_at(selected.find(id))
	elif selected.size()<2: selected.append(id)
	else: notice="Two companions are selected. Deselect one before choosing another."
	prepare(selected_mission)
func deploy() -> void:
	if state==null: return
	if dirty and not persist(stable_phase()): return
	var before := state.snapshot()
	var config := state.commit(selected_mission,selected)
	if config!=null:
		if not persist("in_progress"):
			CampaignSaveCodec.apply_snapshot(state,before); save_phase="headquarters"; dirty=false
			return
		flow.start_configuration(config)
func bind_encounter(scene: Node) -> void:
	if state==null or scene.configuration.deployment_id.is_empty(): return
	var mission_id: String=scene.configuration.deployment_id
	if not state.active.is_empty():
		state.active.encounter.generation_attempt=scene.configuration.layout.attempt
		state.active.encounter.layout_signature=scene.configuration.layout.geometry_signature()
		state.active.encounter.code=EncounterCode.encode(scene.configuration)
		# This records completed generation, never mutable tactical state.
		if not persist("in_progress"):
			scene.set_guidance_paused(true,"save_failure")
			scene.guide.dismissed.connect(func() -> void:
				if is_instance_valid(scene) and not scene.cancelled: scene.set_guidance_paused(false,"save_failure"),CONNECT_ONE_SHOT)
			scene.guide.open("Campaign checkpoint update failed",save_status+"\nThe earlier committed deployment is safe. Retry saving, or close this message to continue using that checkpoint.","Retry Save",func() -> void:
				if persist("in_progress"): scene.set_guidance_paused(false,"save_failure")
				else: scene.guide.open("Campaign save still unavailable",save_status+" The original deployment remains saved."))
	var ticket: int=flow.epoch
	var hud: Node=scene.get_node("HUD")
	hud.restart_button.hide(); hud.code_button.hide()
	for item: Button in hud.result_flow_buttons.values(): item.hide()
	var button := Button.new(); button.text="Mission Debrief"; button.custom_minimum_size.y=44
	hud.overlay_restart.get_parent().add_child(button)
	button.pressed.connect(func() -> void:
		if flow.epoch==ticket and state!=null and state.processed.has(mission_id): show_debrief())
	scene.get_node("CombatController").combat_event.connect(func(kind: String,_data: Dictionary) -> void:
		if kind=="result" and flow.epoch==ticket and state!=null:
			if state.resolve(CampaignMissionResult.capture(mission_id,scene.configuration.campaign_hero_ids,scene.get_node("CombatController")) as CampaignMissionResult): persist("complete" if not state.ending.is_empty() else "debrief"))
func show_debrief() -> void:
	if state==null or state.last_debrief.is_empty(): return
	var view := mount(); flow.screen="campaign_debrief"; view.debrief(state)
func active_mission() -> bool:
	return flow.combat!=null and not str(flow.combat.configuration.deployment_id).is_empty()
func confirm(title: String,message: String,callback: Callable) -> void:
	var guide: GuideOverlay
	if flow.combat!=null and flow.combat.guide!=null:
		flow.audio.panel.close()
		guide=flow.combat.guide
	else:
		if not is_instance_valid(flow.menu_guide):
			flow.menu_guide=GuideOverlay.new()
			flow.interface_layer.add_child(flow.menu_guide)
			flow.menu_guide.layer=50
		guide=flow.menu_guide
		if flow.combat!=null:
			var scene: Node=flow.combat
			scene.set_guidance_paused(true,"campaign_confirmation")
			guide.dismissed.connect(func() -> void:
				if is_instance_valid(scene) and not scene.cancelled:
					scene.set_guidance_paused(false,"campaign_confirmation")
					if scene.navigation_ready: scene.show_briefing(),CONNECT_ONE_SHOT)
	guide.open(title,message,"Confirm",callback)
func abandon_mission() -> void:
	if state==null or not active_mission(): return
	if state.active.is_empty(): show_debrief(); return
	confirm("Abandon this mission?","All companions not explicitly extracted will be permanently lost, including conscious or stabilised heroes. Only extracted companions survive a retreat. This also counts as a failed mission; consequences resolve once.",func() -> void:
		var config: EncounterConfiguration=flow.combat.configuration
		if flow.combat.navigation_ready:
			flow.combat.get_node("CombatController").abandon_encounter()
			state.resolve(CampaignMissionResult.capture(config.deployment_id,config.campaign_hero_ids,flow.combat.get_node("CombatController"),true) as CampaignMissionResult)
		else:
			var people: Dictionary={}
			for id in config.campaign_hero_ids:
				var definition := state.preview_definition(id)
				people[id]={"health":definition.maximum_health,"maximum_health":definition.maximum_health}
			state.resolve(CampaignMissionResult.new({"version":1,"mission_id":config.deployment_id,"outcome":"failure","abandoned":true,"reason":"Mission abandoned during preparation","heroes":people,"rounds":0,"tactical_result":"ABANDONED"}))
		persist("complete" if not state.ending.is_empty() else "debrief")
		show_debrief())
func abandon_run() -> void:
	confirm("Abandon the Lantern Watch?","This permanently removes the active campaign and its automatic backup. Use Save & Main Menu to continue another time.",func() -> void:
		if store.discard(): state=null; flow.show_title()
		else: feedback(store.last_message))
func quit_run() -> void:
	if dirty and not persist(stable_phase()):
		confirm("Quit without latest progress?",save_status+" The previous valid save remains available. Unsaved changes may be lost.",func() -> void: get_tree().quit())
	else:
		confirm("Quit game?","Your saved campaign remains available. If a mission is active, Continue restarts that same mission from its original deployment, not its current turn.",func() -> void: get_tree().quit())
func handle(action: String) -> void:
	if action=="new_campaign":
		if store.inspect().exists or state!=null:
			confirm("Replace saved campaign?","There is one campaign slot. Establishing a new Watch replaces the saved campaign; Cancel keeps it. Damaged files will not be silently overwritten.",func() -> void: replace_allowed=true; creation())
		else: replace_allowed=false; creation()
	elif action=="campaign_continue": continue_campaign()
	elif action=="campaign_retry_save": persist(stable_phase())
	elif action=="campaign_main_menu":
		if not dirty or persist(stable_phase()): state=null; flow.show_title()
	elif action=="campaign_begin": begin()
	elif action=="campaign_hq":
		if state!=null and not state.ending.is_empty(): show_debrief(); return
		if (save_phase!="headquarters" or dirty) and not persist("headquarters"): return
		hq_open=false; headquarters()
	elif action.begins_with("campaign_prepare:"): prepare(action.trim_prefix("campaign_prepare:"))
	elif action.begins_with("campaign_select:"): choose(action.trim_prefix("campaign_select:"))
	elif action=="campaign_recruit":
		mutate("recruit",[state.campaign_id+":recruit:"+str(state.next_hero)]); headquarters()
	elif action.begins_with("campaign_train:"):
		mutate("train_recruit",[action.trim_prefix("campaign_train:")]); headquarters()
	elif action.begins_with("campaign_specialise:"):
		var bits := action.split(":")
		mutate("specialise",[bits[1],bits[2]]); headquarters()
	elif action.begins_with("campaign_learn:"):
		var bits := action.split(":")
		var option: CampaignUpgradeDefinition=state.upgrade(bits[2])
		if option!=null: confirm("Permanent training choice",option.display_name+": "+option.description+". The other choice at this level is forfeited for this run.",func() -> void:
			mutate("learn",[bits[1],bits[2]]); headquarters())
	elif action.begins_with("campaign_armoury:"):
		armoury_hero=action.trim_prefix("campaign_armoury:"); hq_tab=3; headquarters()
	elif action.begins_with("campaign_buy:"):
		var id := action.trim_prefix("campaign_buy:")
		var purchased: Variant=mutate("purchase",[id,state.campaign_id+":purchase:"+str(state.next_item)])
		notice="Bought "+state.item(id).display_name+". Equip it from owned inventory below." if purchased is String and not purchased.is_empty() else "Purchase unavailable or save failed; no Supplies spent."
		headquarters()
	elif action.begins_with("campaign_equip:"):
		var instance := action.trim_prefix("campaign_equip:")
		var owner: String=state.owner_of(instance)
		if not owner.is_empty() and owner!=armoury_hero:
			confirm("Transfer owned equipment?","Move this instance from %s to %s? Replaced equipment stays in inventory; familiar fallback stays usable."%[state.hero_name(owner),state.hero_name(armoury_hero)],func() -> void:
				mutate("equip",[armoury_hero,instance]); headquarters())
		else: mutate("equip",[armoury_hero,instance]); headquarters()
	elif action.begins_with("campaign_unequip:"):
		mutate("unequip",[armoury_hero,action.trim_prefix("campaign_unequip:")]); headquarters()
	elif action.begins_with("campaign_medical:"):
		var id := action.trim_prefix("campaign_medical:")
		confirm("Request recovery treatment?","Spend %d Supplies to remove one existing injury step from %s? Limited to once per hero between missions."%[state.rules.medical_cost,state.hero_name(id)],func() -> void:
			mutate("medical",[id]); headquarters())
	elif action=="campaign_deploy": deploy()
	elif action=="campaign_abandon": abandon_run()
	elif action=="campaign_finish":
		if not dirty or persist(stable_phase()): state=null; flow.show_title()
