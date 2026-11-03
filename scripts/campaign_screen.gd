class_name CampaignScreen
extends MenuScreen
## Headquarters UI only; never owns rules or encounter objects.
var coordinator: Node
var body: VBoxContainer
var tabs: TabContainer
var selection_message: Label
var camp: CampOverview
var panel_overlay: PanelContainer
var panel_title: Label
var camp_back: Button
var save_feedback: Label
func shell(title_text: String,subtitle_text: String) -> void:
	_background()
	var margin := MarginContainer.new()
	add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,20)
	body=VBoxContainer.new(); body.add_theme_constant_override("separation",10); margin.add_child(body)
	_label(body,title_text,28,GOLD)
	var subtitle := _label(body,subtitle_text,16); subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new(); body.add_child(row)
	act(row,"Settings [F10]","audio_settings"); act(row,"Controls & Help","controls")
	save_feedback=text(body,coordinator.save_status if not coordinator.save_status.is_empty() else "Campaign progress saves between encounters.",14)
func act(parent: Node,caption: String,action: String,disabled: bool=false) -> Button:
	var item := _button(parent,caption,action)
	item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	item.custom_minimum_size.x=0; item.disabled=disabled
	item.set_meta("campaign_action",action)
	var symbol := "mission" if "prepare" in action or "deploy" in action else "training" if "learn" in action or "medical" in action else "armoury" if "buy" in action or "equip" in action else "back" if action in ["campaign_hq","main_menu"] else "lantern"
	if action.begins_with("campaign_specialise:"): symbol=action.get_slice(":",2)
	elif action=="campaign_recruit": symbol="recruit"
	OathUI.decorate(item,symbol)
	return item
func text(parent: Node,value: String,size: int=17) -> Label:
	var result := _label(parent,value,size)
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return result
func page(parent: Node,title_text: String="") -> VBoxContainer:
	var scroll := ScrollContainer.new(); 
	if not title_text.is_empty(): scroll.name=title_text
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.follow_focus=true
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var box := VBoxContainer.new(); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",12); scroll.add_child(box)
	return box
func create_run(seed_number: int) -> void:
	shell("THE LANTERN WATCH","Five victories to rekindle the last beacon. Four recruits; deploy two companions initially, up to four after Commander’s Tent upgrades. One automatic campaign slot with a backup.")
	var box := page(body)
	text(box,"Choose a campaign difficulty. It remains fixed throughout the run. The final battle strengthens its existing enemies.")
	var choice := OptionButton.new(); box.add_child(choice)
	for option in EncounterOptions.difficulties(): choice.add_item(option.display_name)
	choice.fit_to_longest_item=false
	choice.custom_minimum_size.y=44
	var description := text(box,EncounterOptions.difficulties()[coordinator.difficulty_index].description)
	choice.select(coordinator.difficulty_index)
	choice.item_selected.connect(func(index: int) -> void:
		coordinator.difficulty_index=index; description.text=EncounterOptions.difficulties()[index].description)
	text(box,"Campaign seed (0–4294967295). Mission offers and battlefield seeds reproduce from this seed.")
	var seed_edit := LineEdit.new(); seed_edit.text=str(seed_number); box.add_child(seed_edit)
	seed_edit.text_changed.connect(func(value: String) -> void: coordinator.seed_text=value)
	text(box,"Downed companions bleed out after three future round ends. Stabilise, carry, and extract them. Victory recovers stabilised companions; retreat preserves only extracted companions. Death is permanent. Failure raises threat by 2; ignored offers add at most 1 more per board. Failed missions return 12 Supplies. Train replacements at the Training Yard (8 Supplies each); resting companions recover injuries twice as fast as deployed companions. You can always deploy injured heroes. Campaign changes autosave between encounters. Closing during combat restarts the same mission from its original deployment; current turns are not saved.")
	var buttons := HBoxContainer.new(); body.add_child(buttons)
	act(buttons,"Establish the Watch","campaign_begin"); act(buttons,"Back","main_menu")
func headquarters(state: CampaignState) -> void:
	_background()
	var margin := MarginContainer.new(); add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,18)
	body=VBoxContainer.new(); body.add_theme_constant_override("separation",8); margin.add_child(body)
	var heading := HBoxContainer.new(); body.add_child(heading)
	var title := text(heading,state.rules.display_name+" · Camp",26); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for entry: Array in [["Settings [F10]","audio_settings"],["Controls & Help","controls"],["Enemy Reference","bestiary"]]:
		var item := _button(heading,entry[0],entry[1]); item.custom_minimum_size=Vector2(140,38); item.add_theme_font_size_override("font_size",15)
	text(body,"WATCH STATUS    /    Victories %d / %d    ·    Threat %d / %d    ·    Supplies %d    ·    %s    ·    Seed %d"%[state.victories,state.rules.victories_required,state.threat,state.rules.threat_maximum,state.supplies,state.difficulty().display_name,state.seed_value],16)
	save_feedback=text(body,coordinator.save_status if not coordinator.save_status.is_empty() else "Progress autosaves after committed changes.",14)
	var wounded: int=0
	for hero: Dictionary in state.heroes.values():
		if not hero.injury.is_empty(): wounded+=1
	text(body,"%d companions deployable · %d injured · Threat %d ends the campaign. Select a camp location to manage the Watch."%[state.living_ids().size(),wounded,state.rules.threat_maximum],14)
	var guide_row := HBoxContainer.new(); body.add_child(guide_row)
	for entry: Array in [["Hide Camp Guide" if coordinator.onboarding.visible else "Show Camp Guide","campaign_guide"],["Camp Rules","campaign_rules"],["Rescue Practice","rescue_tutorial"]]:
		var item := _button(guide_row,entry[0],entry[1]);item.custom_minimum_size=Vector2(160,36);item.add_theme_font_size_override("font_size",14)
	if coordinator.onboarding.visible: text(body,coordinator.onboarding.summary(state),14)
	if not state.pending_event.is_empty():
		var pending := HBoxContainer.new(); body.add_child(pending)
		text(pending,"CAMP DECISION · "+str(state.pending_event.title)+" · resolve or decline before deployment",15).size_flags_horizontal=Control.SIZE_EXPAND_FILL
		act(pending,"Review decision","campaign_event").custom_minimum_size=Vector2(170,36)
	var camp_frame := Control.new(); camp_frame.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_child(camp_frame)
	camp=CampOverview.new(); camp_frame.add_child(camp); camp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); camp.setup(self)
	panel_overlay=PanelContainer.new(); camp_frame.add_child(panel_overlay)
	panel_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_overlay.add_theme_stylebox_override("panel",_style())
	var panel_body := VBoxContainer.new(); panel_overlay.add_child(panel_body)
	var panel_header := HBoxContainer.new(); panel_body.add_child(panel_header)
	panel_title=text(panel_header,"Mission Board",22); panel_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	camp_back=Button.new(); camp_back.text="Back to Camp"; camp_back.custom_minimum_size=Vector2(170,44)
	camp_back.add_theme_stylebox_override("focus",_style(true)); panel_header.add_child(camp_back); camp_back.pressed.connect(close_camp_page)
	tabs=TabContainer.new(); tabs.tabs_visible=false; tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL; panel_body.add_child(tabs)
	var board := page(tabs,"Mission Board")
	text(board,"Victory changes threat by %+d; failure/confirmed abandonment by %+d, plus all unchosen penalties. Unrescued bleeding companions die permanently. Victory recovers stabilised companions; retreat preserves only extracted companions. Recovery/supply success gives every existing injury one extra recovery step."%[state.rules.victory_threat,state.rules.failure_threat])
	var missions := GridContainer.new(); missions.columns=mini(3,maxi(1,state.offers.size())); missions.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	missions.add_theme_constant_override("h_separation",12); board.add_child(missions)
	for offer in state.offers:
		var card := PanelContainer.new(); card.size_flags_horizontal=Control.SIZE_EXPAND_FILL; card.add_theme_stylebox_override("panel",_style())
		missions.add_child(card)
		var details := VBoxContainer.new(); details.size_flags_horizontal=Control.SIZE_EXPAND_FILL; details.add_theme_constant_override("separation",10); card.add_child(details)
		text(details,offer.name+(" · FINAL" if offer.final else ""),21)
		var config := state.configuration_for(offer,PackedStringArray(state.heroes.keys().slice(0,2)))
		text(details,config.generator_settings.display_name+" · "+config.objective.display_name,16)
		if offer.has("template"):
			text(details,str(offer.template.style).capitalize()+" approach · "+str(offer.template.briefing),14)
		elif config.faction_id!="legacy": text(details,FactionCatalog.find(config.faction_id).description,14)
		if config.elite_encounter: text(details,"ELITE WARNING: a prepared area resolves next owner turn.",14)
		text(details,state.difficulty().display_name+(" + final challenge" if offer.final else ""),16)
		for enemy in config.enemies:
			var adjusted := config.difficulty.adjusted(enemy)
			text(details,"%s: %d HP / %d basic damage"%[adjusted.display_name,adjusted.maximum_health,adjusted.basic_attack.damage],15)
		text(details,"Victory: %d Supplies / %d XP each\nFailure: %d Supplies / %d XP each\nIgnored: +%d threat (board cap %d)%s"%[offer.supplies,state.rules.participation_xp+state.rules.success_xp,state.rules.failure_supplies,state.rules.participation_xp,offer.ignored,state.rules.maximum_ignored_threat,"\nSuccess: +1 existing-injury recovery" if offer.recovery else ""],16)
		act(details,"Prepare mission","campaign_prepare:"+offer.id)
	var roster := page(tabs,"Roster")
	if state.recruitment_reserve()>0: text(roster,"%d Supplies reserved for replacements so two companions can deploy." % state.recruitment_reserve(),17)
	act(roster,"Recruit companion (%d Supplies)"%int(state.roster_rules.recruit_cost),"campaign_recruit",state.supplies<int(state.roster_rules.recruit_cost))
	for id: String in state.heroes:
		hero_row(roster,state,id)
		if state.heroes[id].get("dead",false): continue
		var injured: bool=not state.heroes[id].injury.is_empty()
		act(roster,"Herbwarden treatment (%d Supplies, once per mission interval)"%state.rules.medical_cost,"campaign_medical:"+id,not injured or state.heroes[id].medical_at==state.resolutions or not state.can_spend(state.rules.medical_cost))
	var training := page(tabs,"Training")
	text(training,"Experience: %d participation + %d for victory, for surviving participants. Levels 1–4 at %s XP. At level 2, recruits choose one of six permanent classes. Then choose one permanent upgrade at each level, in order."%[state.rules.participation_xp,state.rules.success_xp,str(Array(state.rules.xp_thresholds))])
	for id: String in state.heroes:
		hero_row(training,state,id)
		if state.heroes[id].get("dead",false): continue
		if state.blueprint_id(id)=="recruit":
			act(training,"Basic training (%d Supplies, %d XP)"%[int(state.roster_rules.training_cost),int(state.roster_rules.training_xp)],"campaign_train:"+id,state.heroes[id].level!=1 or not state.can_spend(int(state.roster_rules.training_cost)))
			if state.heroes[id].level>=2:
				for class_id: String in SpecialisationCatalog.ids():
					var choice := SpecialisationCatalog.definition(class_id)
					var class_card := HBoxContainer.new()
					training.add_child(class_card)
					var class_portrait := CharacterPortrait.new()
					class_card.add_child(class_portrait)
					class_portrait.setup(choice.visual_id)
					var class_details := VBoxContainer.new()
					class_details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
					class_card.add_child(class_details)
					text(class_details,choice.display_name+" · "+choice.role+"\n"+stat_summary(choice))
					text(class_details,SpecialisationCatalog.description(class_id),15)
					for ability in choice.abilities: text(class_details,ability.display_name+": "+ability.description,14)
					act(training,"Become "+choice.display_name,"campaign_specialise:"+id+":"+class_id)
			continue
		var level := state.pending_level(id)
		text(training,"Choose a level %d upgrade"%level if level>0 else "No unspent training choice.")
		for option in state.rules.upgrades:
			if option.hero_id==state.blueprint_id(id) and option.required_level==level:
				text(training,option.display_name+": "+option.description)
				act(training,"Learn "+option.display_name,"campaign_learn:"+id+":"+option.stable_id)
		for learned: String in state.heroes[id].upgrades: text(training,"✓ "+state.upgrade(learned).display_name+": "+state.upgrade(learned).description,15)
	var armoury := page(tabs,"Armoury")
	draw_shop(armoury,state)
	var journal := page(tabs,"History")
	draw_command_upgrades(journal,state)
	if not state.pending_event.is_empty(): act(journal,"Pending camp decision: "+str(state.pending_event.title),"campaign_event")
	var decision_lines: PackedStringArray=[]
	if not state.event_records.is_empty(): text(journal,"CAMP DECISIONS",20)
	for entry: Dictionary in state.event_records:
		text(journal,"After mission %d · %s"%[entry.resolution,entry.text],16)
		decision_lines.append(entry.text)
	text(journal,"CAMPAIGN LOG",20)
	for entry in state.history:
		if not decision_lines.has(entry): text(journal,entry)
	if not state.trader.is_empty():
		var trader_page := page(tabs,"Trader")
		draw_trader(trader_page,state)
	tabs.current_tab=clampi(coordinator.hq_tab,0,tabs.get_tab_count()-1)
	tabs.tab_changed.connect(func(index: int) -> void: open_camp_page(index))
	camp.destination_selected.connect(open_camp_page)
	var shortcuts := HBoxContainer.new(); shortcuts.add_theme_constant_override("separation",6); body.add_child(shortcuts)
	for index in range(tabs.get_tab_count()):
		var shortcut := Button.new(); shortcut.text=["Missions","Roster","Training","Shop","Commander","Trader"][index]
		shortcut.tooltip_text=CampOverview.TITLES[index]; shortcut.custom_minimum_size.y=36; shortcut.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		OathUI.decorate(shortcut,["mission","roster","training","armoury","history","armoury"][index]); shortcuts.add_child(shortcut)
		shortcut.pressed.connect(func() -> void: open_camp_page(index))
	var reset := Button.new(); reset.text="Reset view"; reset.custom_minimum_size.y=36; shortcuts.add_child(reset); reset.pressed.connect(camp.reset_view)
	if coordinator.hq_open: open_camp_page(coordinator.hq_tab)
	else: close_camp_page(false)
	var exit_row := HBoxContainer.new(); body.add_child(exit_row)
	act(exit_row,"Save & Main Menu","campaign_main_menu")
	act(exit_row,"Retry Save","campaign_retry_save",not coordinator.dirty)
	act(exit_row,"Abandon campaign","campaign_abandon")
func open_camp_page(index: int) -> void:
	if camp==null or index<0 or index>=tabs.get_tab_count(): return
	coordinator.hq_tab=index; coordinator.hq_open=true
	if tabs.current_tab!=index: tabs.current_tab=index
	panel_title.text=CampOverview.TITLES[index]
	panel_overlay.show(); camp.interactive=false; camp.orbiting=false; camp.highlight(-1)
	for destination in camp.destinations: destination.disabled=true
	camp_back.grab_focus()
func close_camp_page(restore_focus: bool=true) -> void:
	if camp==null: return
	coordinator.hq_open=false; panel_overlay.hide(); camp.interactive=true
	for destination in camp.destinations: destination.disabled=false
	if restore_focus: camp.destinations[coordinator.hq_tab].grab_focus()
func mission_text(state: CampaignState,offer: Dictionary) -> String:
	var config := state.configuration_for(offer,PackedStringArray(state.heroes.keys().slice(0,2)))
	var enemies: PackedStringArray=[]
	for enemy in config.enemies:
		var adjusted := config.difficulty.adjusted(enemy)
		enemies.append("%s (%d HP, %d basic damage)"%[adjusted.display_name,adjusted.maximum_health,adjusted.basic_attack.damage])
	var briefing := str(offer.template.briefing)+"\nApproach: "+str(offer.template.style).capitalize()+"\n" if offer.has("template") else ""
	return briefing+OptionalGoals.briefing(config.optional_goal_id)+("\n" if not config.optional_goal_id.is_empty() else "")+"%s · %s · %s%s\n%s\nEnemies: %s\nVictory: %d Supplies · ignored: +%d threat%s"%[config.generator_settings.display_name,config.objective.display_name,state.difficulty().display_name," + final challenge" if offer.final else "",FieldGuide.objective(config.objective),", ".join(enemies),offer.supplies,offer.ignored," · extra recovery" if offer.recovery else ""]
func hero_row(parent: Node,state: CampaignState,id: String,dossier_link: bool=true) -> void:
	var base := state.preview_definition(id)
	var record: Dictionary=state.heroes[id]
	if dossier_link: act(parent,"Character & equipment · "+state.hero_name(id),"campaign_dossier:"+id)
	if record.get("dead",false):
		text(parent,"IN MEMORIAM · %s · %s · Level %d\n%d missions · %s"%[state.hero_name(id),HeroCatalog.find(state.blueprint_id(id)).role,record.level,int(record.get("missions_completed",0)),record.get("death_cause","Lost on mission")],22)
		return
	var card:=PanelContainer.new(); card.add_theme_stylebox_override("panel",_style()); parent.add_child(card)
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",18); card.add_child(row)
	var portrait:=CharacterPortrait.new(); row.add_child(portrait); portrait.setup(base.visual_id)
	portrait.custom_minimum_size=Vector2(112,154)
	var details:=VBoxContainer.new(); details.size_flags_horizontal=Control.SIZE_EXPAND_FILL; details.add_theme_constant_override("separation",7); row.add_child(details)
	var level: int=record.level
	var progress:=ProgressBar.new(); progress.custom_minimum_size.y=8; progress.show_percentage=false
	var lower: int=state.rules.xp_thresholds[level-1]
	var upper: int=state.rules.xp_thresholds[level] if level<state.rules.xp_thresholds.size() else lower
	progress.max_value=maxi(1,upper-lower); progress.value=record.experience-lower if upper>lower else progress.max_value
	progress.tooltip_text="%d / %d XP to next level"%[record.experience,upper] if upper>lower else "Maximum level"
	details.add_child(progress)
	text(details,"%s · %s · Level %d · %d XP"%[base.display_name,base.role,record.level,record.experience],22)
	var abilities: PackedStringArray=[]
	for ability in base.abilities: abilities.append(ability_summary(ability))
	text(details,"Missions completed: %d · %s" % [int(record.get("missions_completed",0)),"Deployed" if state.active.get("party",[]).has(id) else ("Injured — deployable" if not record.injury.is_empty() else "Available")],15)
	text(details,"%d health · %.2f m movement · %s: %d damage, %s\nAbilities: %s\nRecovery: %s"%[base.maximum_health,base.movement_allowance,base.basic_attack.display_name,base.basic_attack.damage,base.basic_attack.range_label(),(", ".join(abilities) if not abilities.is_empty() else "None yet (Recruit)"),"Ready" if record.injury.is_empty() else "%s — %d resolutions; %d HP, %.1f m. Deploy recovers 1; rest recovers 2."%[record.injury.name,record.injury.remaining,state.rules.injury_health,state.rules.injury_movement]])
	for slot: String in CampaignEquipment.SLOTS:
		var instance: String=record.equipment.get(slot,"")
		text(details,CampaignEquipment.slot_name(slot)+": "+("Locked until level %d"%CampaignEquipment.slot_level(slot,state.headquarters_rules) if record.level<CampaignEquipment.slot_level(slot,state.headquarters_rules) else ("Familiar fallback / empty" if instance.is_empty() else state.item(state.inventory[instance].definition_id).display_name)),15)
func stat_summary(value: UnitDefinition) -> String:
	var abilities: PackedStringArray=[]
	for ability in value.abilities: abilities.append(ability_summary(ability))
	return "%d HP · %.2f m · %d basic damage · %.2f m maximum range · %s"%[value.maximum_health,value.movement_allowance,value.basic_attack.damage,value.basic_attack.maximum_range,", ".join(abilities)]
func preparation(state: CampaignState,mission_id: String,selected: PackedStringArray) -> void:
	var offer := state.offer(mission_id)
	shell("MISSION PREPARATION · "+offer.name,"Choose 2 to %d distinct companions. Deployment commits the party and mission; no free retry or reroll."%state.deployment_capacity())
	var consequences := CampaignOnboarding.deployment(state,offer,selected)
	text(body,consequences.get_slice("\n",0),15)
	var content := page(body)
	text(content,mission_text(state,offer))
	selection_message=text(content,"Selected: %d / %d maximum · minimum 2"%[selected.size(),state.deployment_capacity()],22)
	for id: String in state.living_ids():
		hero_row(content,state,id)
		act(content,("SELECTED / " if selected.has(id) else "Select / ")+state.hero_name(id),"campaign_select:"+id)
	text(content,"CONSEQUENCES\n"+consequences,15)
	for id in selected: text(content,"Deployment: "+state.hero_name(id)+" — "+stat_summary(state.preview_definition(id)),15)
	var problem := state.deployment_error(mission_id,selected)
	text(content,problem if not problem.is_empty() else "Ready. Health is restored; combat cooldowns and statuses start fresh.")
	var row := HBoxContainer.new(); body.add_child(row)
	act(row,"Deploy","campaign_deploy",not problem.is_empty()); act(row,"Back to Headquarters","campaign_hq")
func debrief(state: CampaignState) -> void:
	var value := state.last_debrief
	var heading := "CAMPAIGN VICTORY · The beacon shines" if state.ending=="victory" else ("CAMPAIGN DEFEAT · The Watch is overwhelmed" if state.ending=="defeat" else "MISSION DEBRIEF")
	shell(heading,"%s · %s · %d completed rounds"%[value.mission.name,value.result.tactical_result,value.result.rounds])
	var box := page(body)
	for line: String in value.lines:
		var reward := PanelContainer.new();reward.add_theme_stylebox_override("panel",_style());box.add_child(reward)
		text(reward,line,20)
	text(box,"Victories %d / %d · Threat %d / %d · Supplies %d"%[state.victories,state.rules.victories_required,state.threat,state.rules.threat_maximum,state.supplies])
	act(body,"Return to Headquarters" if state.ending.is_empty() else "Finish campaign / Main Menu","campaign_hq" if state.ending.is_empty() else "campaign_finish")
	act(body,"Retry Save","campaign_retry_save",not coordinator.dirty)
func _unhandled_input(event: InputEvent) -> void:
	if camp!=null:
		if coordinator.flow.audio.editing or (is_instance_valid(coordinator.flow.menu_guide) and coordinator.flow.menu_guide.panel.visible): return
		if ControlBindings.pressed(event,"cancel") and panel_overlay.visible:
			close_camp_page(); get_viewport().set_input_as_handled(); return
	if tabs!=null and event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP,KEY_PAGEDOWN]:
		tabs.current_tab=posmod(tabs.current_tab+(-1 if event.keycode==KEY_PAGEUP else 1),tabs.get_tab_count()); get_viewport().set_input_as_handled()

func ability_summary(ability: AbilityDefinition) -> String:
	var value := "%d damage" % ability.magnitude
	if ability.effect==AbilityDefinition.Effect.HEAL: value="%d healing" % ability.magnitude
	elif ability.effect==AbilityDefinition.Effect.WARD: value="%d absorption" % ability.magnitude
	elif ability.effect==AbilityDefinition.Effect.TOW: value="tow up to %.1f m" % ability.displacement_distance
	elif ability.effect==AbilityDefinition.Effect.PULL: value+=" + pull up to %.1f m" % ability.displacement_distance
	return "%s: %s / CD %d" % [ability.display_name,value,ability.cooldown_turns]

func event_decision(state: CampaignState) -> void:
	var event: Dictionary=state.pending_event
	shell("CAMP DECISION · "+str(event.title),"After mission %d · %s · No hidden rolls"%[event.resolution,event.name])
	var box := page(body)
	text(box,event.description,21)
	text(box,"Every consequence is shown below. You can return to camp and decide later, or decline before deploying. Recruitment reserves are protected.",16)
	for choice: Dictionary in event.choices:
		var frame := PanelContainer.new(); frame.add_theme_stylebox_override("panel",_style()); box.add_child(frame)
		var content := VBoxContainer.new(); frame.add_child(content)
		text(content,choice.label,20)
		text(content,CampaignEvents.effects(event,choice),16)
		var error := CampaignEvents.choice_error(state,event.id,choice.id)
		var button := act(content,"Choose" if error.is_empty() else "Unavailable","campaign_event_choose:"+event.id+":"+choice.id,not error.is_empty())
		button.tooltip_text=error if not error.is_empty() else "Review and confirm this choice."
		if not error.is_empty(): text(content,error,15)
	act(body,"Decide later / Back to Camp","campaign_hq")
func dossier(state: CampaignState,id: String) -> void:
	var hero: Dictionary=state.heroes[id]
	var background := CampaignEvents.background(hero.identity.background_id)
	shell("COMPANION DOSSIER · "+state.hero_name(id),"Personal history · descriptive identity does not change combat stats")
	var box := page(body)
	hero_row(box,state,id,false)
	if not hero.dead: draw_equipment_slots(box,state,id)
	text(box,background.display_name.to_upper(),22)
	text(box,background.origin,18)
	text(box,"Purpose: "+background.motivation,18)
	text(box,"SERVICE RECORD",22)
	for entry: Dictionary in hero.service:
		text(box,"After mission %d · %s"%[entry.resolution,entry.text],16)
	act(body,"Back to Camp","campaign_hq")

func draw_command_upgrades(parent: Node,state: CampaignState) -> void:
	text(parent,"COMMANDER’S TENT · Capacity %d"%state.deployment_capacity(),24)
	text(parent,CampaignTrader.status(state),15)
	text(parent,"Buy permanent deployment capacity and watch the camp grow. You may still field a smaller party (minimum two) to rest companions.",16)
	for tier in [1,2]:
		var error := state.command_upgrade_error(tier)
		text(parent,("Field Command" if tier==1 else "Expanded Command")+" · Up to %d companions · %d Supplies · Requires %d victories"%[tier+2,state.headquarters_rules.command_costs[tier-1],state.headquarters_rules.command_victories[tier-1]],18)
		var label: String="OWNED" if state.command_tier>=tier else "Upgrade"
		var button := act(parent,label,"campaign_command:"+str(tier),not error.is_empty())
		button.tooltip_text=error
		if state.command_tier<tier and not error.is_empty(): text(parent,error,15)
func item_card(parent: Node,state: CampaignState,definition: CampaignItemDefinition,variant: String="") -> VBoxContainer:
	var panel := PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.add_theme_stylebox_override("panel",_style());parent.add_child(panel)
	var row := HBoxContainer.new();row.add_theme_constant_override("separation",12);panel.add_child(row)
	var picture := TextureRect.new();picture.texture=CampaignEquipment.texture(definition,variant);picture.custom_minimum_size=Vector2(96,110)
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(picture)
	var details := VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(details)
	text(details,definition.display_name+" · "+definition.rarity.to_upper(),20)
	var roles: PackedStringArray=[]
	for id: String in definition.compatible_heroes: roles.append(HeroCatalog.find(id).display_name)
	text(details,CampaignEquipment.slot_name(definition.slot)+" · Level %d · Classes: %s"%[CampaignEquipment.level_for(definition,state.headquarters_rules),", ".join(roles)],14)
	text(details,definition.description,16)
	return details
func draw_shop(parent: Node,state: CampaignState) -> void:
	text(parent,"THE CAMP OUTFITTER · Equipment shop",24)
	text(parent,CampaignTrader.status(state),15)
	text(parent,"Buy with Supplies; purchases enter shared inventory. Equip from a companion’s Character screen by selecting an unlocked slot. Locked requirements are shown before you spend.",16)
	var filters := HBoxContainer.new();parent.add_child(filters)
	for slot: String in ["all","weapon","garb","helmet","accessory"]:
		act(filters,("• " if coordinator.shop_filter==slot else "")+("All" if slot=="all" else CampaignEquipment.slot_name(slot)),"campaign_shop_filter:"+slot)
	var goods := GridContainer.new();goods.columns=2;goods.size_flags_horizontal=Control.SIZE_EXPAND_FILL;goods.add_theme_constant_override("h_separation",12);goods.add_theme_constant_override("v_separation",12);parent.add_child(goods)
	for definition: CampaignItemDefinition in CampaignEquipment.catalogue(state):
		if definition.vendor!="armoury" or definition.cost<=0 or (coordinator.shop_filter!="all" and definition.slot!=coordinator.shop_filter): continue
		var details := item_card(goods,state,definition)
		var owned: int=0
		for entry: Dictionary in state.inventory.values():
			if entry.definition_id==definition.stable_id: owned+=1
		text(details,"%d Supplies · Owned %d"%[definition.cost,owned],17)
		var error := CampaignEquipment.purchase_error(state,definition)
		var button := act(details,"Buy" if error.is_empty() else "Unavailable","campaign_shop_buy:"+definition.stable_id+":"+str(state.next_item),not error.is_empty())
		button.tooltip_text=error
		if not error.is_empty(): text(details,error,14)
	act(parent,"Characters & equipment","campaign_roster")
func draw_equipment_slots(parent: Node,state: CampaignState,hero_id: String) -> void:
	text(parent,"EQUIPMENT · Select a slot",22)
	var grid := GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);parent.add_child(grid)
	for slot: String in CampaignEquipment.SLOTS:
		var required := CampaignEquipment.slot_level(slot,state.headquarters_rules)
		var instance: String=state.heroes[hero_id].equipment.get(slot,"")
		var label: String=CampaignEquipment.slot_name(slot)+" · "+("LOCKED (level %d)"%required if state.heroes[hero_id].level<required else "Empty / fallback" if instance.is_empty() else state.item(state.inventory[instance].definition_id).display_name)
		var button := act(grid,label,"campaign_slot:"+hero_id+":"+slot)
		button.custom_minimum_size.y=70;button.clip_text=true
		button.tooltip_text="Unlocks at level %d. Select to inspect owned compatible equipment."%required
		if not instance.is_empty():
			button.icon=CampaignEquipment.texture(state.item(state.inventory[instance].definition_id),state.inventory[instance].art_variant)
			button.expand_icon=true;button.add_theme_constant_override("icon_max_width",48)
func equipment_choices(state: CampaignState,hero_id: String,slot: String) -> void:
	shell(state.hero_name(hero_id)+" · "+CampaignEquipment.slot_name(slot),"Choose owned compatible equipment. Buying items never changes your loadout automatically.")
	var content := page(body)
	var required := CampaignEquipment.slot_level(slot,state.headquarters_rules)
	if state.heroes[hero_id].level<required: text(content,"LOCKED · This slot unlocks at level %d."%required,22)
	var count: int=0
	for instance: String in state.inventory:
		var definition := state.item(state.inventory[instance].definition_id)
		if definition.slot!=slot or not definition.compatible_heroes.has(state.blueprint_id(hero_id)): continue
		count+=1
		var details := item_card(content,state,definition,state.inventory[instance].art_variant)
		var owner: String=state.owner_of(instance)
		text(details,"Owned instance %s · %s"%[instance,"Stored" if owner.is_empty() else "Equipped by "+state.hero_name(owner)],15)
		text(details,CampaignEquipment.comparison(state,hero_id,definition.stable_id),15)
		var error := state.equipment_error(hero_id,instance)
		var caption: String="Equipped" if owner==hero_id else "Transfer & equip" if not owner.is_empty() else "Equip"
		var button := act(details,caption,"campaign_equip_for:"+hero_id+":"+instance,not error.is_empty());button.tooltip_text=error
		if not error.is_empty() and owner!=hero_id: text(details,error,15)
	if count==0: text(content,"No owned compatible items in this slot. Visit the Camp Outfitter or an available trader.",18)
	if state.heroes[hero_id].equipment.has(slot): act(content,"Unequip / restore fallback","campaign_unequip_for:"+hero_id+":"+slot)
	var back := HBoxContainer.new();body.add_child(back)
	act(back,"Back to character","campaign_dossier:"+hero_id);act(back,"Visit shop","campaign_shop")


func draw_trader(parent: Node,state: CampaignState) -> void:
	text(parent,"THE LANTERN CARAVAN · Visiting trader",24)
	text(parent,"Premium equipment · One item per offer · Stock stays fixed when you reload. The trader leaves when a mission is committed. Buy here, equip from a character slot.",17)
	for entry: Dictionary in state.trader.offers:
		var definition := state.item(entry.item_id)
		var details := item_card(parent,state,definition,entry.art_variant)
		text(details,"%d Supplies · %s"%[entry.price,"SOLD OUT" if entry.sold else "ONE AVAILABLE"],18)
		var error := CampaignTrader.purchase_error(state,entry.offer_id)
		var button := act(details,"Sold out" if entry.sold else "Buy premium item","campaign_trader_buy:"+str(entry.offer_id),not error.is_empty())
		button.tooltip_text=error
		if not error.is_empty() and not entry.sold: text(details,error,15)
	act(parent,"Characters & equipment","campaign_roster")
