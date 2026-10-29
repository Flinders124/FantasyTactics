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
	shell("THE LANTERN WATCH","Five victories to rekindle the last beacon. Four recruits; exactly two living companions deploy. One automatic campaign slot with a backup.")
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
	text(armoury,"One weapon and one armour/accessory slot per hero. Bought items are unique owned instances. Transfers remove the old owner's item; empty slots retain familiar base-stat gear. Equipment follows each companion's selected class.")
	var role_row := HBoxContainer.new(); armoury.add_child(role_row)
	for id: String in state.living_ids(): act(role_row,("✓ " if coordinator.armoury_hero==id else "")+state.hero_name(id),"campaign_armoury:"+id)
	var equipped_hero: String=coordinator.armoury_hero
	hero_row(armoury,state,equipped_hero)
	text(armoury,"SHOP · compatible with "+state.hero_name(equipped_hero),22)
	for definition in state.rules.items:
		if definition.cost<=0 or not definition.compatible_heroes.has(state.blueprint_id(equipped_hero)): continue
		text(armoury,"%s · %s · %d Supplies: %s"%[definition.display_name,definition.slot,definition.cost,definition.description])
		text(armoury,"If equipped: "+stat_summary(state.projected_definition(equipped_hero,definition.stable_id)),15)
		act(armoury,"Buy "+definition.display_name,"campaign_buy:"+definition.stable_id,not state.can_spend(definition.cost))
	text(armoury,"OWNED INVENTORY · one instance, one owner",22)
	for instance: String in state.inventory:
		var definition := state.item(state.inventory[instance].definition_id)
		var owner := state.owner_of(instance)
		text(armoury,"OWNED · %s · %s · Owner: %s"%[definition.display_name,definition.slot,state.hero_name(owner) if not owner.is_empty() else "Stored"])
		if owner==equipped_hero: act(armoury,"Unequip "+definition.display_name,"campaign_unequip:"+definition.slot)
		elif definition.compatible_heroes.has(state.blueprint_id(equipped_hero)):
			text(armoury,"Projected: "+stat_summary(state.projected_definition(equipped_hero,definition.stable_id)),15)
			act(armoury,("Transfer & equip " if not owner.is_empty() else "Equip ")+definition.display_name,"campaign_equip:"+instance)
		else: text(armoury,"Incompatible with selected role.",15)
	var journal := page(tabs,"History")
	for entry in state.history: text(journal,entry)
	tabs.current_tab=clampi(coordinator.hq_tab,0,4)
	tabs.tab_changed.connect(func(index: int) -> void: open_camp_page(index))
	camp.destination_selected.connect(open_camp_page)
	var shortcuts := HBoxContainer.new(); shortcuts.add_theme_constant_override("separation",6); body.add_child(shortcuts)
	for index in range(5):
		var shortcut := Button.new(); shortcut.text=["Missions","Roster","Training","Armoury","History"][index]
		shortcut.tooltip_text=CampOverview.TITLES[index]; shortcut.custom_minimum_size.y=36; shortcut.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		OathUI.decorate(shortcut,["mission","roster","training","armoury","history"][index]); shortcuts.add_child(shortcut)
		shortcut.pressed.connect(func() -> void: open_camp_page(index))
	var reset := Button.new(); reset.text="Reset view"; reset.custom_minimum_size.y=36; shortcuts.add_child(reset); reset.pressed.connect(camp.reset_view)
	if coordinator.hq_open: open_camp_page(coordinator.hq_tab)
	else: close_camp_page(false)
	var exit_row := HBoxContainer.new(); body.add_child(exit_row)
	act(exit_row,"Save & Main Menu","campaign_main_menu")
	act(exit_row,"Retry Save","campaign_retry_save",not coordinator.dirty)
	act(exit_row,"Abandon campaign","campaign_abandon")
func open_camp_page(index: int) -> void:
	if camp==null or index<0 or index>=5: return
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
	return briefing+"%s · %s · %s%s\n%s\nEnemies: %s\nVictory: %d Supplies · ignored: +%d threat%s"%[config.generator_settings.display_name,config.objective.display_name,state.difficulty().display_name," + final challenge" if offer.final else "",FieldGuide.objective(config.objective),", ".join(enemies),offer.supplies,offer.ignored," · extra recovery" if offer.recovery else ""]
func hero_row(parent: Node,state: CampaignState,id: String) -> void:
	var base := state.preview_definition(id)
	var record: Dictionary=state.heroes[id]
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
	text(details,"%d health · %.2f m movement · %s: %d damage, %s\nAbilities: %s\nRecovery: %s"%[base.maximum_health,base.movement_allowance,base.basic_attack.display_name,base.basic_attack.damage,base.basic_attack.range_label(),", ".join(abilities),"Ready" if record.injury.is_empty() else "%s — %d resolutions; %d HP, %.1f m. Deploy recovers 1; rest recovers 2."%[record.injury.name,record.injury.remaining,state.rules.injury_health,state.rules.injury_movement]])
	for slot: String in ["weapon","garb"]:
		var instance: String=record.equipment.get(slot,"")
		text(details,slot.capitalize()+": "+("Familiar fallback (base stats)" if instance.is_empty() else state.item(state.inventory[instance].definition_id).display_name),15)
func stat_summary(value: UnitDefinition) -> String:
	var abilities: PackedStringArray=[]
	for ability in value.abilities: abilities.append(ability_summary(ability))
	return "%d HP · %.2f m · %d basic damage · %.2f m maximum range · %s"%[value.maximum_health,value.movement_allowance,value.basic_attack.damage,value.basic_attack.maximum_range,", ".join(abilities)]
func preparation(state: CampaignState,mission_id: String,selected: PackedStringArray) -> void:
	var offer := state.offer(mission_id)
	shell("MISSION PREPARATION · "+offer.name,"Choose exactly two distinct companions. Deployment commits this offer, party and encounter; there is no free retry or reroll.")
	var content := page(body)
	text(content,mission_text(state,offer))
	selection_message=text(content,"Selected: %d / 2"%selected.size(),22)
	for id: String in state.living_ids():
		hero_row(content,state,id)
		act(content,("SELECTED / " if selected.has(id) else "Select / ")+state.hero_name(id),"campaign_select:"+id)
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
