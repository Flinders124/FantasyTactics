class_name SceneFlow
extends Node

const ENCOUNTER_SCENE: PackedScene = preload("res://scenes/combat_encounter.tscn")
@export var game_title: String = ""
@export var generator_settings: BattlefieldSettings = preload("res://definitions/presets/open_courtyard.tres")
var party: PartySelection = PartySelection.new()
var current_configuration: EncounterConfiguration
var combat: CombatEncounter
var menu: MenuScreen
var interface_layer: CanvasLayer
var loading: Control
var loading_label: Label
var screen: String = ""
var epoch: int = 0
var initial_seed_override: int = -1
var seed_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var retired: Array[CombatEncounter] = []
var audio: GameAudio
var campaign: Node
var menu_guide: GuideOverlay

func _ready() -> void:
	add_to_group("scene_flow")
	process_mode=Node.PROCESS_MODE_ALWAYS
	ControlBindings.ensure()
	seed_rng.randomize()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed=") and argument.trim_prefix("--seed=").is_valid_int():
			initial_seed_override = maxi(-1, argument.trim_prefix("--seed=").to_int())
	interface_layer = CanvasLayer.new()
	interface_layer.layer = 30
	add_child(interface_layer)
	audio=GameAudio.new()
	audio.name="GameAudio"
	add_child(audio)
	campaign=CampaignCoordinator.new(); campaign.flow=self; add_child(campaign)
	get_tree().auto_accept_quit=false
	show_title()

func _clear_screen() -> void:
	epoch += 1
	if audio!=null: audio.panel.close()
	if is_instance_valid(menu_guide):
		menu_guide.close(); menu_guide.queue_free(); menu_guide=null
	if menu != null:
		menu.hide()
		menu.process_mode = Node.PROCESS_MODE_DISABLED
		menu.queue_free()
		menu = null
	if loading != null:
		loading.queue_free()
		loading = null
		loading_label = null
	if combat != null:
		var old := combat
		combat = null
		old.shutdown()
		retired.append(old)
		_retire.call_deferred(old)

func _retire(old: CombatEncounter) -> void:
	# Cancelled async navigation is allowed to return before freeing its owner.
	while is_instance_valid(old) and old.preparing:
		await get_tree().process_frame
	retired.erase(old)
	if is_instance_valid(old):
		old.queue_free()

func show_title() -> void:
	_clear_screen()
	audio.set_context("menu")
	screen = "title"
	menu = MenuScreen.new()
	interface_layer.add_child(menu)
	menu.title(game_title if not game_title.is_empty() else str(ProjectSettings.get_setting("application/config/name", "Fantasy Tactics")))
	menu.show_campaign_save(campaign.save_summary())
	_bind_menu_requests()
	menu.set_tutorial_suggestion(not audio.tutorial_completed)

func show_party() -> void:
	if combat!=null and combat.configuration!=null and not combat.tutorial_mode and combat.configuration.deployment_id.is_empty(): party.populate(combat.configuration)
	_clear_screen()
	if initial_seed_override>=0 and party.seed_text.is_empty(): party.seed_text=str(initial_seed_override)
	audio.set_context("menu")
	screen = "party"
	menu = MenuScreen.new()
	interface_layer.add_child(menu)
	menu.party(party)
	_bind_menu_requests()

func _bind_menu_requests() -> void:
	var ticket := epoch
	menu.requested.connect(func(action: String) -> void:
		if ticket == epoch:
			request_transition(action))

func _new_seed() -> int:
	var value: int = seed_rng.randi()
	if current_configuration != null and value == current_configuration.battlefield_seed:
		value = (value + 1) % 4294967296
	return value

func request_transition(action: String) -> void:
	if action=="bestiary":
		if menu==null or menu.has_node("EnemyReference"): return
		var reference:=EnemyReference.new(); reference.name="EnemyReference"; menu.add_child(reference); reference.open()
		if menu is CampaignScreen and menu.camp!=null:
			menu.camp.interactive=false
			reference.tree_exiting.connect(func() -> void:
				if is_instance_valid(menu) and menu is CampaignScreen and menu.camp!=null: menu.camp.interactive=not menu.panel_overlay.visible)
		return
	if action=="new_campaign" or action.begins_with("campaign_"):
		campaign.handle(action); return
	if campaign!=null and campaign.state!=null:
		if action=="quit": campaign.quit_run(); return
		if campaign.active_mission() and action in ["retry","new_battlefield","main_menu","change_party","change_setup"]:
			if action in ["retry","new_battlefield"]: return
			campaign.abandon_mission(); return
	if combat!=null and combat.tutorial_mode and combat.tutorial!=null and combat.tutorial.step!=TutorialDirector.Step.COMPLETE and action in ["main_menu","skip_tutorial","tutorial","retry","new_battlefield","change_party","change_setup"]:
		var destination := "party" if action=="skip_tutorial" else ("main_menu" if action=="main_menu" else "tutorial")
		combat.guide.open("Leave tutorial progress?","Progress in this tutorial will be discarded. You can replay from the title screen at any time. Skipping does not mark it completed.","Restart Tutorial" if destination=="tutorial" else "Leave tutorial",func() -> void:
			if destination=="tutorial": start_tutorial()
			elif destination=="party": show_party()
			else: show_title())
		return
	match action:
		"tutorial": start_tutorial()
		"controls":
			if combat!=null: combat.show_help()
			else:
				if not is_instance_valid(menu_guide):
					menu_guide=GuideOverlay.new()
					menu.add_child(menu_guide)
				menu_guide.open("CONTROLS & FIELD GUIDE",(FieldGuide.camp_controls() if screen=="headquarters" else "")+ControlBindings.describe()+FieldGuide.tips())
		"briefing":
			if combat!=null: combat.show_briefing()
		"audio_settings":
			audio.show_settings()
		"new_encounter":
			show_party()
		"main_menu":
			show_title()
		"change_party", "change_setup":
			show_party()
		"start_encounter":
			if screen != "party" or not party.ready():
				return
			var seed_value := initial_seed_override if initial_seed_override>=0 else party.preview_seed
			var config := party.configuration(seed_value,generator_settings)
			initial_seed_override=-1
			start_configuration(config)
		"retry":
			if combat!=null and combat.tutorial_mode:
				start_tutorial()
				return
			if combat != null and combat.navigation_ready:
				start_configuration(combat.configuration.snapshot() as EncounterConfiguration)
		"new_battlefield":
			if combat!=null and combat.tutorial_mode:
				show_party()
				return
			if combat != null and combat.navigation_ready:
				var config := combat.configuration.snapshot() as EncounterConfiguration
				config.layout = null
				config.battlefield_seed = _new_seed()
				config.requested_attempt=0
				config.resolve_roster()
				start_configuration(config)
		"quit":
			get_tree().quit()

func start_tutorial() -> void:
	start_configuration(TutorialEncounter.configuration(),true)

func start_configuration(config: EncounterConfiguration,is_tutorial: bool=false) -> void:
	if config == null or not config.validation_error().is_empty():
		if screen=="party":
			party.code_feedback=config.validation_error() if config!=null else "Choose a valid encounter setup."
			party.changed.emit()
		return
	_clear_screen()
	audio.set_context("loading")
	screen = "loading"
	current_configuration = config.snapshot() as EncounterConfiguration
	if not is_tutorial and config.deployment_id.is_empty(): party.populate(current_configuration)
	_build_loading()
	combat = ENCOUNTER_SCENE.instantiate() as CombatEncounter
	combat.configuration = current_configuration
	combat.tutorial_mode=is_tutorial
	combat.process_mode=Node.PROCESS_MODE_PAUSABLE
	var ticket := epoch
	combat.loading_changed.connect(func(message: String) -> void:
		if ticket == epoch and loading_label != null:
			loading_label.text = message)
	combat.setup_finished.connect(_on_encounter_ready.bind(ticket))
	combat.flow_requested.connect(func(action: String) -> void:
		if ticket == epoch:
			request_transition(action))
	add_child(combat)

func _build_loading() -> void:
	loading = Control.new()
	loading.theme=OathUI.theme()
	interface_layer.add_child(loading)
	loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading.mouse_filter = Control.MOUSE_FILTER_STOP
	var background := OathBackdrop.new()
	loading.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	loading.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)
	loading_label = Label.new()
	loading_label.text = "Preparing the battlefield…"
	var brand:=Label.new(); brand.text="THE LANTERN WATCH / PREPARING THE FIELD"; brand.theme_type_variation="OathHeading"; brand.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; box.add_child(brand)
	loading_label.add_theme_font_size_override("font_size", 26)
	loading_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.4))
	box.add_child(loading_label)
	var back := Button.new()
	back.text = "Main Menu"
	back.custom_minimum_size.y = 44
	box.add_child(back)
	var ticket := epoch
	back.pressed.connect(func() -> void:
		if ticket == epoch:
			request_transition("main_menu"))

func _on_encounter_ready(success: bool, ticket: int) -> void:
	if ticket != epoch:
		return
	if success:
		audio.set_context("combat")
		screen = "combat"
		loading.queue_free()
		loading = null
		loading_label = null
		if not combat.configuration.deployment_id.is_empty(): campaign.bind_encounter(combat)
		if not combat.pause_sources.has("campaign_confirmation"): combat.show_briefing()
	else:
		screen = "failed"
		loading_label.text = combat.setup_error if not combat.setup_error.is_empty() else "The battlefield could not be prepared. Return to the menu."

func _unhandled_input(event: InputEvent) -> void:
	if ControlBindings.pressed(event,"help"):
		request_transition("controls")
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		request_transition("quit")
