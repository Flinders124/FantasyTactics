class_name CombatEncounter
extends Node3D

signal setup_finished(success: bool)
signal loading_changed(message: String)
signal flow_requested(action: String)
const UNIT_SCENE: PackedScene = preload("res://scenes/combat_unit.tscn")
@export var hero_definition: UnitDefinition = preload("res://definitions/hero.tres")
@export var enemy_definition: UnitDefinition = preload("res://definitions/enemy.tres")
@export var scout_definition: UnitDefinition = preload("res://definitions/scout.tres")
@export var sentinel_definition: UnitDefinition = preload("res://definitions/sentinel.tres")
var pause_sources: Dictionary = {}
var tutorial_mode: bool = false
var rescue_practice: bool = false
var rescue_lesson: RescueTutorialDirector
var tutorial: TutorialDirector
var guide: GuideOverlay
var configuration: EncounterConfiguration
var navigation_ready: bool = false
var preparing: bool = false
var cancelled: bool = false
var generator: BattlefieldGenerator
var setup_error: String = ""
var courtyard_occlusion: CourtyardOcclusion

func _ready() -> void:
	add_to_group("active_encounter")
	if get_tree().get_first_node_in_group("game_audio")==null:
		var audio := GameAudio.new()
		audio.name="StandaloneAudio"
		add_child(audio)
		audio.set_context("loading")
	preparing = true
	CourtyardAtmosphere.configure($WorldEnvironment,$Sun)
	# This small static arena is built once during loading. Commit navigation
	# iterations synchronously; a background region iteration can otherwise lag
	# behind a replacement even after the mesh resource reports baked polygons.
	NavigationServer3D.region_set_use_async_iterations($NavigationRegion3D.get_rid(), false)
	NavigationServer3D.map_set_use_async_iterations($NavigationRegion3D.get_navigation_map(), false)
	$NavigationRegion3D.navigation_mesh = $NavigationRegion3D.navigation_mesh.duplicate()
	var success: bool = true
	if configuration != null:
		success = await _prepare_generated()
	else:
		# Fixed regression fixture / direct-scene development launch.
		_build_arena()
		$NavigationRegion3D.bake_navigation_mesh(false)
		await $NavigationService.synchronize($NavigationRegion3D)
		success = $NavigationService.ready_for_queries
	if success and not cancelled:
		await _spawn_and_bind()
		if not cancelled:
			navigation_ready = true
	preparing = false
	setup_finished.emit(success and not cancelled)

func _prepare_generated() -> bool:
	if not configuration.valid_party():
		setup_error = "Choose two to four companions and two to four opponents."
		return false
	generator = BattlefieldGenerator.new()
	generator.name = "BattlefieldGenerator"
	add_child(generator)
	var settings := configuration.generator_settings
	if settings == null:
		settings = BattlefieldSettings.new()
	var cached := configuration.layout
	if cached!=null and (cached.spawns.size()!=configuration.hero_ids.size()+configuration.enemies.size() or cached.hero_count!=configuration.hero_ids.size() or cached.original_seed!=configuration.battlefield_seed or cached.preset_id!=settings.preset_id or cached.objective_id!=configuration.objective.stable_id or cached.generator_version!=settings.generator_version):
		setup_error="Cached battlefield does not match its encounter configuration."
		return false
	var limit := clampi(settings.generation_attempts, 1, 8)
	for attempt in range(configuration.requested_attempt if configuration.requested_attempt>0 else 1, limit + 2):
		if cancelled:
			return false
		loading_changed.emit("Preparing your battlefield…" if attempt == 1 else "Preparing a clear route between the parties…")
		var fallback := attempt == limit + 1
		var layout := cached if cached != null else generator.make_layout(configuration.battlefield_seed, settings, attempt, fallback, configuration.objective, configuration.enemies.size(),configuration.hero_ids.size())
		if layout == null:
			await get_tree().process_frame
			continue
		$NavigationService.ready_for_queries = false
		generator.build($NavigationRegion3D, layout,settings)
		$NavigationRegion3D.bake_navigation_mesh(false)
		await $NavigationService.synchronize($NavigationRegion3D)
		if cancelled:
			return false
		if generator.validate_spawns(layout, $NavigationService, get_world_3d(), settings, configuration.enemies.size(),configuration.hero_ids.size()) and generator.validate_objective(layout,$NavigationService,configuration.objective):
			if tutorial_mode and not TutorialEncounter.valid_routes(layout,$NavigationService):
				setup_error="Training routes are unavailable. Return to the title screen and retry Tutorial."
				return false
			configuration.layout = layout
			$TacticalCamera.frame_arena(layout.arena_size)
			print("Battlefield seed %d: attempt %d%s, %d obstacles" % [configuration.battlefield_seed, layout.attempt, " (fallback)" if layout.used_fallback else "", layout.obstacle_centers.size()])
			return true
		if cached != null or configuration.requested_attempt>0:
			break # A retry must never silently change the cached battlefield.
	setup_error = "The battlefield could not be prepared. Return to the menu and try again."
	return false

func _spawn_and_bind() -> void:
	var roster: Array[CombatUnit] = []
	var hero_count: int=configuration.hero_ids.size() if configuration!=null else 2
	var definitions: Array[UnitDefinition] = [hero_definition, scout_definition, enemy_definition, sentinel_definition]
	var positions: PackedVector3Array = [Vector3(-4, 0, 3), Vector3(-2, 0, 4), Vector3(4, 0, -3), Vector3(2, 0, -4)]
	if configuration != null:
		definitions=[]
		for id: String in configuration.hero_ids: definitions.append(HeroCatalog.find(id))
		for enemy in configuration.enemies:
			definitions.append(configuration.difficulty.adjusted(enemy))
		if not configuration.hero_overrides.is_empty():
			for index in range(hero_count): definitions[index]=configuration.hero_overrides[index]
		positions = configuration.layout.spawns
	# Stable numbering follows roster order, including repeated enemy definitions.
	for index in range(definitions.size()):
		var unit := UNIT_SCENE.instantiate() as CombatUnit
		unit.stable_id = ("hero-%02d" % (index + 1)) if index < hero_count else ("enemy-%02d" % (index-hero_count+1))
		if index<hero_count and configuration!=null and not configuration.campaign_hero_ids.is_empty(): unit.campaign_id=configuration.campaign_hero_ids[index]
		unit.survival_enabled = configuration!=null and configuration.survival_enabled and index<hero_count
		unit.definition = RescueTutorialEncounter.private_hero(definitions[index],index,definitions[2].basic_attack.damage) if rescue_practice and index<hero_count else definitions[index]
		unit.faction = CombatUnit.Faction.HERO if index < hero_count else CombatUnit.Faction.ENEMY
		unit.position = positions[index]
		$Units.add_child(unit)
		roster.append(unit)
	$CombatController.selection_changed.connect($TacticalCamera.select_unit)
	$CombatController.survival_enabled=configuration!=null and configuration.survival_enabled
	$CombatController.retreat_center=(positions[0]+positions[1])*.5
	if rescue_practice:
		$CombatController.retreat_center=RescueTutorialEncounter.SAFE_POINT
		$CombatController.retreat_radius=.9
	$CombatController.configure_movement($NavigationService, $MovementMotor)
	if configuration!=null:
		$CombatController.objectives.configure(configuration.objective,configuration.layout)
		var marker := ObjectiveMarker.new()
		marker.name="ObjectiveMarker"
		add_child(marker)
		marker.bind($CombatController.objectives)
	if configuration!=null:
		var goal: OptionalGoalController=$CombatController.optional_goals
		goal.configure(configuration.optional_goal_id,configuration.survival_enabled and not configuration.deployment_id.is_empty())
		goal.changed.connect(func() -> void:
			if goal.collected and not goal.finished:$CombatController._publish_event("optional",{"message":"Optional cache collected; win the mission to complete the challenge."}))
		if not goal.place(configuration.layout,$NavigationService):
			setup_error="Optional cache has no reachable location.";cancelled=true;return
		if goal.definition!=null and goal.definition.rule=="cache":
			var goal_marker := OptionalGoalMarker.new();goal_marker.name="OptionalGoalMarker";add_child(goal_marker);goal_marker.bind(goal)
	if $CombatController.survival_enabled and configuration.objective.kind!=ObjectiveDefinition.Kind.EXTRACTION:
		var retreat := Node3D.new()
		retreat.name="RetreatMarker"
		add_child(retreat)
		retreat.position=$CombatController.retreat_center
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius=maxf(.1,$CombatController.retreat_radius-.06)
		mesh.outer_radius=$CombatController.retreat_radius
		ring.mesh=mesh
		ring.position.y=.06
		var material := StandardMaterial3D.new()
		material.albedo_color=Color(.65,.8,.95)
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override=material
		retreat.add_child(ring)
		var label := Label3D.new()
		label.text="RETREAT · Extract here"
		label.font_size=34
		label.position=Vector3(0,.35,0)
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		retreat.add_child(label)
	$HUD.rescue_practice_ui=rescue_practice
	$HUD.bind($CombatController)
	if configuration != null:
		$HUD.bind_flow(configuration.battlefield_seed,configuration)
		$HUD.flow_requested.connect(func(action: String) -> void: flow_requested.emit(action))
	$CombatLog.bind($CombatController)
	$HUD.bind_log($CombatLog)
	$CombatPresentation.bind($CombatController, roster, $TacticalCamera/Camera3D)
	$TacticalCamera.view_changed.connect(func() -> void:
		if not cancelled and $CombatController.guidance_paused:
			# Reproject health labels while paused without advancing presentation time.
			$CombatPresentation._process(0.0))
	$PlayerController.bind($CombatController, $TacticalCamera/Camera3D)
	$PlayerController.preview_changed.connect($HUD.show_preview)
	$HUD.bind_targeting($PlayerController)
	$EnemyController.tutorial_policy=tutorial_mode
	if tutorial_mode: $EnemyController.presentation_delay=.5
	if rescue_practice: $EnemyController.enabled=false
	$EnemyController.bind($CombatController)
	$HUD.bind_enemy($EnemyController)
	if configuration!=null:
		courtyard_occlusion=CourtyardOcclusion.new()
		courtyard_occlusion.name="CourtyardOcclusion"
		add_child(courtyard_occlusion)
		courtyard_occlusion.bind($CombatController,$PlayerController,$TacticalCamera/Camera3D,self)
	guide=GuideOverlay.new()
	guide.encounter=self
	add_child(guide)
	$HUD.add_guidance(self)
	if tutorial_mode:
		$HUD.code_button.hide()
		$HUD.result_flow_buttons["retry"].text="Replay Tutorial"
		$HUD.result_flow_buttons["new_battlefield"].text="New Skirmish"
		if rescue_practice:
			rescue_lesson=RescueTutorialDirector.new()
			add_child(rescue_lesson)
			rescue_lesson.bind(self)
			rescue_lesson.requested.connect(func(action: String) -> void: flow_requested.emit(action))
		else:
			tutorial=TutorialDirector.new()
			add_child(tutorial)
			tutorial.bind(self)
			tutorial.completed.connect(func() -> void:
				$HUD.tutorial_finished=true
				$HUD._refresh())
			tutorial.requested.connect(func(action: String) -> void: flow_requested.emit(action))
	# Synchronize newly spawned collision bodies before granting any turn.
	await get_tree().physics_frame
	if cancelled:
		return
	await get_tree().physics_frame
	if not cancelled:
		$CombatController.setup(roster, $TurnManager)
		var preferences_owner := get_tree().get_first_node_in_group("game_audio") as GameAudio
		if preferences_owner!=null: preferences_owner.apply_preferences(false)
		var audio := get_tree().get_first_node_in_group("game_audio") as GameAudio
		if audio!=null: audio.set_context("combat")

func shutdown() -> void:
	pause_sources.clear()
	set_guidance_paused(false)
	if tutorial!=null: tutorial.shutdown()
	if rescue_lesson!=null: rescue_lesson.shutdown()
	if guide!=null: guide.close()
	cancelled = true
	if has_node("StandaloneAudio"): ($StandaloneAudio as GameAudio).silence()
	if courtyard_occlusion!=null: courtyard_occlusion.restore_all()
	navigation_ready = false
	$EnemyController.enabled = false
	$NavigationService.cancel_synchronization()
	$CombatController.shutdown()
	if $PlayerController.controller != null:
		$PlayerController.cancel_targeting()
	$CombatPresentation.clear_effects()
	$HUD.visible = false
	$NavigationRegion3D.enabled = false
	$WorldEnvironment.environment = null
	for node in $NavigationRegion3D.get_children():
		if node is CollisionObject3D:
			node.collision_layer = 0
	for unit in $Units.get_children():
		unit.collision_layer = 0
		if unit.effect_tween != null:
			unit.effect_tween.kill()
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

func _build_arena() -> void:
	_add_box("Ground", Vector3(0, -0.25, 0), Vector3(24, 0.5, 24), Color(0.4, 0.42, 0.45))
	_add_box("CentralObstacle", Vector3(0, 1, 0), Vector3(3, 2, 2), Color(0.25, 0.27, 0.3))
	_add_box("WestObstacle", Vector3(-6, 0.75, -3), Vector3(2, 1.5, 4), Color(0.3, 0.32, 0.35))
	_add_box("EastObstacle", Vector3(6, 0.75, 3), Vector3(2, 1.5, 4), Color(0.3, 0.32, 0.35))

func _add_box(box_name: String, center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	if box_name == "Ground":
		body.collision_layer = 3 # World collision plus ground-only mouse ray layer.
	body.collision_layer |= 8 # Static arena-only visibility layer for area casts/blasts.
	body.position = center
	$NavigationRegion3D.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var art = preload("res://scripts/lantern_art.gd")
	visual.material_override = art.paint(Color("50677e") if box_name=="Ground" else Color("85a5ab"))
	body.add_child(visual)

func set_guidance_paused(value: bool,source: String="guide") -> void:
	if value: pause_sources[source]=true
	else: pause_sources.erase(source)
	var paused := not pause_sources.is_empty()
	$CombatController.guidance_paused=paused
	get_tree().paused=paused
	if not paused and not cancelled:
		var enemy := $EnemyController as EnemyController
		if enemy.controller!=null and enemy.stage!=EnemyController.Stage.IDLE:
			enemy._schedule()
func show_briefing() -> void:
	if guide==null: return
	var definition := configuration.objective if configuration!=null else ObjectiveDefinition.new()
	var intro := "TRAINING: Warden and Scout. Training opponents have 10 / 8 health and hold their positions and end turns; normal skirmish enemies use tactical AI. Blue rings mark required movement. Only the requested commands are enabled until the final free-play step.\n\n" if tutorial_mode else ""
	if rescue_practice: intro="RESCUE PRACTICE: the companion uses reduced training health so one attack demonstrates downing; campaign heroes keep their normal stats. Later training opponents hold position. Stabilise, carry, move and extract with normal commands. No campaign progress or saved tutorial completion is changed.\n\n"
	guide.open("OBJECTIVE · "+definition.display_name,intro+FieldGuide.objective(definition)+( "\n\n"+OptionalGoals.briefing(configuration.optional_goal_id) if configuration!=null and not configuration.optional_goal_id.is_empty() else "")+("\n\n"+$HUD.SURVIVAL_HELP if $CombatController.survival_enabled else ""))
func show_help() -> void:
	if guide!=null: guide.open_dynamic("CONTROLS & FIELD GUIDE",help_text)



func help_text() -> String:
	return ControlBindings.describe()+FieldGuide.tips()+("\n\n"+FieldGuide.survival() if $CombatController.survival_enabled else "")
