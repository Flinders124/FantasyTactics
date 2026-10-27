class_name CombatUnit
extends CharacterBody3D

signal health_changed(unit: CombatUnit)
signal died(unit: CombatUnit)
signal resources_changed(unit: CombatUnit)

enum Faction { HERO, ENEMY }
@export var stable_id: String = ""
var campaign_id: String = ""
@export var definition: UnitDefinition
@export var faction: Faction = Faction.HERO
@export_node_path("Marker3D") var attack_origin_path: NodePath = ^"AttackOrigin"
@export_node_path("Marker3D") var ground_anchor_path: NodePath = ^"GroundAnchor"
@export_node_path("Marker3D") var target_point_path: NodePath = ^"TargetPoint"
var _health: int = 0
var health: int:
	get:
		return _health
	set(value):
		set_health(value)
var movement_remaining: float = 0.0
var movement_granted: float = 0.0
var action_available: bool = false
# Compatibility for existing callers; attacks and abilities share this value.
var attack_available: bool:
	get:
		return action_available
	set(value):
		action_available = value
var owner_turn: int = 0
var cooldown_ready_turn: Dictionary = {}
var statuses: Dictionary = {}
signal runtime_event(kind: String, data: Dictionary)
var death_handled: bool = false
var target_indicator: MeshInstance3D
var health_label: Label3D
var visual_material: StandardMaterial3D
var effect_tween: Tween
var target_material: StandardMaterial3D
var hover_indicator: MeshInstance3D
var _active: bool = false
var _hovered: bool = false
var _targeted: bool = false
var _valid_target: bool = false
var invalid_mesh: ImmediateMesh
@onready var character: CharacterVisual = $Visual

func _ready() -> void:
	add_to_group("combat_units")
	assert(definition != null)
	target_indicator = MeshInstance3D.new()
	target_indicator.mesh = $ActiveIndicator.mesh
	target_indicator.position = Vector3(0, 0.1, 0)
	target_indicator.scale = Vector3.ONE * 1.2
	target_material = StandardMaterial3D.new()
	target_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	target_indicator.material_override = target_material
	add_child(target_indicator)
	hover_indicator = MeshInstance3D.new()
	hover_indicator.mesh = outline_mesh(false)
	var hover_material := StandardMaterial3D.new()
	hover_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hover_material.albedo_color = Color.WHITE
	hover_indicator.material_override = hover_material
	add_child(hover_indicator)
	invalid_mesh = outline_mesh(true)
	health_label = Label3D.new()
	health_label.position = Vector3(0, 0.16, 0.8)
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.font_size = 40
	health_label.pixel_size = 0.012
	health_label.no_depth_test = true
	add_child(health_label)
	health_changed.connect(_update_health_visual)
	reset_for_encounter()

func is_alive() -> bool:
	return health > 0

func set_health(value: int) -> void:
	if death_handled:
		return # Resurrection is explicit through encounter reset only.
	var previous_health := _health
	_health = clampi(value, 0, definition.maximum_health)
	if _health == 0:
		death_handled = true
		statuses.clear()
		attack_available = false
		movement_remaining = 0.0
		movement_granted = 0.0
		collision_layer = 0
		collision_mask = 0
		input_ray_pickable = false
		$CollisionShape3D.set_deferred("disabled", true)
		set_active(false)
		set_target_highlight(false, false)
		set_hovered(false)
		if effect_tween != null:
			effect_tween.kill()
		character.die()
		died.emit(self)
	elif _health < previous_health:
		character.hit()
	health_changed.emit(self)
	resources_changed.emit(self)

func reset_for_encounter() -> void:
	if effect_tween != null:
		effect_tween.kill()
	death_handled = false
	owner_turn = 0
	cooldown_ready_turn.clear()
	statuses.clear()
	_health = definition.maximum_health
	attack_available = false
	movement_remaining = 0.0
	movement_granted = 0.0
	velocity = Vector3.ZERO
	collision_layer = 5 # World collision + unit-target picking layer.
	collision_mask = 1
	input_ray_pickable = true
	$CollisionShape3D.set_deferred("disabled", false)
	$Visual.scale = Vector3.ONE
	$Visual.position = Vector3.ZERO
	_refresh_role_visual()
	character.reset_pose()
	set_active(false)
	set_target_highlight(false, false)
	set_hovered(false)
	health_changed.emit(self)
	resources_changed.emit(self)

func _update_health_visual(_unit: CombatUnit) -> void:
	_update_indicator_text()

func collision_radius() -> float:
	var capsule := $CollisionShape3D.shape as CapsuleShape3D
	var world_scale := global_basis.get_scale()
	return capsule.radius * maxf(absf(world_scale.x), absf(world_scale.z))

func attack_origin_at(origin: Vector3) -> Vector3:
	var marker := get_node(attack_origin_path) as Marker3D
	return origin + marker.global_position - global_position

func attack_markers_valid() -> bool:
	return get_node_or_null(attack_origin_path) is Marker3D and get_node_or_null(target_point_path) is Marker3D

func target_point() -> Vector3:
	return (get_node(target_point_path) as Marker3D).global_position

func role_label() -> String:
	return definition.basic_attack.type_label() if definition.basic_attack != null else "Unarmed"

func _refresh_role_visual() -> void:
	character.configure(self)

func set_target_highlight(enabled: bool, valid: bool) -> void:
	if target_indicator == null:
		return
	target_indicator.visible = enabled and is_alive()
	_targeted = enabled and is_alive()
	_valid_target = valid
	target_indicator.mesh = hover_indicator.mesh if valid else invalid_mesh
	target_material.albedo_color = Color.LIME_GREEN if valid else Color.ORANGE_RED
	_update_indicator_text()

func set_hovered(enabled: bool) -> void:
	_hovered = enabled and is_alive()
	if hover_indicator != null:
		hover_indicator.visible = _hovered
	_update_indicator_text()

func _update_indicator_text() -> void:
	if health_label == null:
		return
	health_label.text = ""
	if not is_alive():
		return
	if _targeted:
		health_label.text = "OK" if _valid_target else "NO"
	elif _active:
		health_label.text = "ACTIVE"
	elif _hovered:
		health_label.text = "HOVER"

static func outline_mesh(cross: bool) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: Array=[]
	if cross:
		segments=[[Vector3(-.5,.12,-.5),Vector3(.5,.12,.5)],[Vector3(-.5,.12,.5),Vector3(.5,.12,-.5)]]
	else:
		# Corner brackets stay legible in pixels without a filled combat footprint.
		for x in [-1,1]:
			for z in [-1,1]:
				var corner := Vector3(x*.63,.12,z*.63)
				segments.append([corner,corner-Vector3(x*.25,0,0)])
				segments.append([corner,corner-Vector3(0,0,z*.25)])
	for segment in segments:
		var a: Vector3=segment[0]; var b: Vector3=segment[1]
		var side := (b-a).normalized().cross(Vector3.UP)*.025
		for point in [a-side,a+side,b+side,a-side,b+side,b-side]: mesh.surface_add_vertex(point)
	mesh.surface_end()
	return mesh

func play_attack_effect(cast: bool = false, target: Vector3 = Vector3.INF) -> void:
	if is_alive():
		if target.is_finite():
			character.face_point(target)
		character.action(cast)

func begin_turn() -> void:
	owner_turn += 1
	var multiplier: float = 1.0
	for value in statuses.values():
		var status := value as StatusEffectInstance
		status.affecting_current_turn = status.future_turns > 0
		if status.affecting_current_turn:
			status.future_turns -= 1
			multiplier = minf(multiplier, status.definition.movement_multiplier)
	movement_granted = definition.movement_allowance * multiplier
	movement_remaining = movement_granted
	action_available = true
	resources_changed.emit(self)

func spend_action() -> void:
	action_available = false
	resources_changed.emit(self)

func spend_attack() -> void:
	spend_action()

func set_active(active: bool) -> void:
	_active = active and is_alive()
	$ActiveIndicator.visible = active and is_alive()
	_update_indicator_text()

func ability_by_id(id: String) -> AbilityDefinition:
	for ability in definition.abilities:
		if ability != null and ability.stable_id == id:
			return ability
	return null

func cooldown_remaining(id: String) -> int:
	return maxi(0, int(cooldown_ready_turn.get(id, 0)) - owner_turn)

func start_cooldown(ability: AbilityDefinition) -> void:
	cooldown_ready_turn[ability.stable_id] = owner_turn + ability.cooldown_turns + 1
	resources_changed.emit(self)

func apply_status(config: StatusEffectDefinition) -> void:
	var refresh := statuses.has(config.stable_id)
	if refresh:
		(statuses[config.stable_id] as StatusEffectInstance).future_turns = config.affected_turns
	else:
		statuses[config.stable_id] = StatusEffectInstance.new(config)
	runtime_event.emit("status_refresh" if refresh else "status_apply", {"status": config.display_name, "turns": config.affected_turns})
	resources_changed.emit(self)

func end_turn() -> void:
	for id in statuses.keys():
		var status := statuses[id] as StatusEffectInstance
		if status.affecting_current_turn and status.future_turns == 0:
			statuses.erase(id)
			runtime_event.emit("status_expire", {"status": status.definition.display_name})
		else:
			status.affecting_current_turn = false
	resources_changed.emit(self)

func status_text() -> String:
	var labels: PackedStringArray = []
	for status in statuses.values():
		labels.append((status as StatusEffectInstance).label())
	return "\n".join(labels)

func ground_anchor() -> Vector3:
	return (get_node(ground_anchor_path) as Marker3D).global_position

func area_markers_valid() -> bool:
	return get_node_or_null(ground_anchor_path) is Marker3D and get_node_or_null(target_point_path) is Marker3D

func set_area_highlight(enabled: bool, friendly: bool = false, damage: int = 0) -> void:
	set_target_highlight(enabled, not friendly)
	health_label.font_size = 28 if enabled else 40
	if enabled and is_alive():
		health_label.text = ("ALLY HIT" if friendly else "HIT") + " −%d" % damage

