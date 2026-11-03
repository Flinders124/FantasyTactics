class_name CombatUnit
extends CharacterBody3D

signal health_changed(unit: CombatUnit)
signal died(unit: CombatUnit)
signal resources_changed(unit: CombatUnit)

enum Faction { HERO, ENEMY }
enum LifeState { ACTIVE, DOWNED, STABILISED, EXTRACTED, DEAD }
@export var survival_enabled: bool = false
var life_state: LifeState = LifeState.ACTIVE
var downed_round: int = -1
var bleed_remaining: int = 0
var survival_outcome: String = ""
var death_cause: String = ""
var carried_unit: CombatUnit
var carried_by: CombatUnit
var _last_bleed_round: int = -1
var ward_remaining: int:
	get:
		var total := 0
		for entry in statuses.values(): total += (entry as StatusEffectInstance).absorption_remaining
		return total
var ward_future_turns: int:
	get:
		return (statuses["aegis_ward"] as StatusEffectInstance).future_turns if statuses.has("aegis_ward") else 0
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

func _physics_process(_delta: float) -> void:
	if carried_by != null: global_position = carried_by.global_position

func is_alive() -> bool:
	return life_state == LifeState.ACTIVE and health > 0

func is_downed() -> bool:
	return life_state in [LifeState.DOWNED, LifeState.STABILISED]

func is_surviving() -> bool:
	return life_state != LifeState.DEAD

func set_health(value: int) -> void:
	if life_state in [LifeState.DEAD, LifeState.EXTRACTED] or death_handled: return
	var previous := _health
	_health = clampi(value, 0, definition.maximum_health)
	if _health == 0 and life_state == LifeState.ACTIVE:
		if survival_enabled and faction == Faction.HERO:
			life_state = LifeState.DOWNED
			bleed_remaining = (load("res://definitions/roster_rules.tres") as RosterRules).bleed_rounds
			statuses.clear()
			drop_carried()
			_stop_resources()
			_refresh_life_visual()
			runtime_event.emit("downed", {})
		else:
			force_death("damage")
			return
	elif _health > 0 and life_state in [LifeState.DOWNED, LifeState.STABILISED]:
		life_state = LifeState.ACTIVE
		bleed_remaining = 0
		if carried_by != null: carried_by.drop_carried()
		_refresh_life_visual()
	elif _health < previous and character != null:
		character.hit()
	health_changed.emit(self)
	resources_changed.emit(self)

func damage(amount: int) -> int:
	if amount <= 0 or life_state in [LifeState.DEAD, LifeState.EXTRACTED]: return 0
	if life_state in [LifeState.DOWNED, LifeState.STABILISED]:
		if life_state == LifeState.DOWNED:
			bleed_remaining = maxi(0, bleed_remaining - 1)
			if bleed_remaining == 0: force_death("further damage")
		resources_changed.emit(self)
		return 0
	var remaining := amount
	for id in statuses.keys():
		var status := statuses[id] as StatusEffectInstance
		if status.absorption_remaining <= 0: continue
		var absorbed := mini(remaining, status.absorption_remaining)
		remaining -= absorbed
		status.absorption_remaining -= absorbed
		if status.absorption_remaining == 0: statuses.erase(id)
		if remaining == 0: break
	var previous := health
	set_health(health - remaining)
	resources_changed.emit(self)
	return previous - health

func heal(amount: int) -> int:
	if amount <= 0 or life_state in [LifeState.DEAD, LifeState.EXTRACTED]: return 0
	var previous := health
	set_health(health + amount)
	return health - previous

func apply_ward(amount: int, turns: int = 2) -> void:
	if not is_alive(): return
	var ward := (load("res://definitions/aegis_ward.tres") as StatusEffectDefinition).duplicate() as StatusEffectDefinition
	ward.damage_absorption = maxi(0, amount)
	ward.affected_turns = maxi(1, turns)
	apply_status(ward)

func _stop_resources() -> void:
	action_available = false
	movement_remaining = 0.0
	movement_granted = 0.0
	velocity = Vector3.ZERO
	set_active(false)
	set_target_highlight(false, false)
	set_hovered(false)
	if effect_tween != null: effect_tween.kill()

func _refresh_life_visual() -> void:
	collision_layer = 5 if is_alive() else (4 if life_state in [LifeState.DOWNED, LifeState.STABILISED] and carried_by == null else 0)
	collision_mask = 1 if is_alive() else 0
	input_ray_pickable = collision_layer != 0
	$CollisionShape3D.set_deferred("disabled", collision_layer == 0)
	visible = life_state != LifeState.EXTRACTED and carried_by == null
	if character != null:
		character.set_survival_pose(LifeState.keys()[life_state], carried_unit != null)

func force_death(cause: String = "") -> void:
	if life_state == LifeState.DEAD: return
	if carried_by != null: carried_by.drop_carried()
	drop_carried()
	life_state = LifeState.DEAD
	_health = 0
	death_handled = true
	death_cause = cause
	survival_outcome = "dead"
	statuses.clear()
	_stop_resources()
	_refresh_life_visual()
	if character != null: character.die()
	died.emit(self)
	health_changed.emit(self)
	resources_changed.emit(self)

func stabilise() -> bool:
	if life_state != LifeState.DOWNED: return false
	life_state = LifeState.STABILISED
	_refresh_life_visual()
	resources_changed.emit(self)
	return true

func pickup(ally: CombatUnit) -> bool:
	if not is_alive() or carried_unit != null or ally == null or ally == self or ally.faction != faction or ally.carried_by != null or ally.life_state not in [LifeState.DOWNED, LifeState.STABILISED]: return false
	carried_unit = ally
	ally.carried_by = self
	var spent := movement_granted-movement_remaining
	movement_granted *= .5
	movement_remaining = maxf(0,movement_granted-spent)
	ally._refresh_life_visual()
	_refresh_life_visual()
	resources_changed.emit(self)
	return true

func drop_carried() -> CombatUnit:
	var ally := carried_unit
	if ally == null: return null
	carried_unit = null
	ally.carried_by = null
	ally.global_position = global_position
	ally._refresh_life_visual()
	_refresh_life_visual()
	resources_changed.emit(self)
	return ally

func set_extracted() -> void:
	if life_state in [LifeState.DEAD, LifeState.EXTRACTED]: return
	if carried_by != null: carried_by.drop_carried()
	var ally := carried_unit
	carried_unit = null
	if ally != null:
		ally.carried_by = null
		ally.set_extracted()
	life_state = LifeState.EXTRACTED
	survival_outcome = "extracted"
	_stop_resources()
	_refresh_life_visual()
	resources_changed.emit(self)

func on_round_end(round_number: int) -> void:
	if life_state != LifeState.DOWNED or round_number <= downed_round or round_number <= _last_bleed_round: return
	_last_bleed_round = round_number
	bleed_remaining -= 1
	if bleed_remaining <= 0: force_death("bleed out")
	resources_changed.emit(self)

func finalize_survival(recover: bool) -> String:
	if life_state == LifeState.EXTRACTED: return "extracted"
	if life_state == LifeState.DEAD: return "dead"
	if recover and (life_state in [LifeState.ACTIVE, LifeState.STABILISED] or (is_downed() and carried_by!=null and carried_by.is_alive())):
		survival_outcome = "recovered"
	else:
		force_death("unrescued")
	return survival_outcome

func reset_for_encounter() -> void:
	if carried_by != null: carried_by.drop_carried()
	drop_carried()
	if effect_tween != null:
		effect_tween.kill()
	death_handled = false
	life_state = LifeState.ACTIVE
	downed_round = -1
	_last_bleed_round = -1
	bleed_remaining = 0
	survival_outcome = ""
	death_cause = ""
	carried_unit = null
	carried_by = null
	visible = true
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
	target_indicator.visible = enabled and (is_alive() or (is_downed() and carried_by==null))
	_targeted = enabled and (is_alive() or (is_downed() and carried_by==null))
	_valid_target = valid
	target_indicator.mesh = hover_indicator.mesh if valid else invalid_mesh
	target_material.albedo_color = Color.LIME_GREEN if valid else Color.ORANGE_RED
	_update_indicator_text()

func set_hovered(enabled: bool) -> void:
	_hovered = enabled and (is_alive() or (is_downed() and carried_by==null))
	if hover_indicator != null:
		hover_indicator.visible = _hovered
	_update_indicator_text()

func _update_indicator_text() -> void:
	if health_label == null:
		return
	health_label.text = ""
	if is_downed():
		health_label.text=("STABILISED" if life_state==LifeState.STABILISED else "DOWNED · %d rounds" % bleed_remaining)+(" · OK" if _targeted and _valid_target else "")
		return
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
	if not is_alive(): return
	owner_turn += 1
	var multiplier: float = 1.0
	for value in statuses.values():
		var status := value as StatusEffectInstance
		status.affecting_current_turn = status.future_turns > 0
		if status.affecting_current_turn:
			status.future_turns -= 1
			multiplier = minf(multiplier, status.definition.movement_multiplier)
	movement_granted = definition.movement_allowance * multiplier * (0.5 if carried_unit != null else 1.0)
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
	if not is_alive() or config == null: return
	var refresh := statuses.has(config.stable_id)
	if refresh:
		statuses[config.stable_id] = StatusEffectInstance.new(config)
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
	if carried_unit!=null: labels.append("Carrying "+carried_unit.definition.display_name+" · movement halved")
	for status in statuses.values():
		var instance := status as StatusEffectInstance
		labels.append(instance.label() + (" [%d ward]" % instance.absorption_remaining if instance.definition.damage_absorption > 0 else ""))
	return "\n".join(labels)

func ground_anchor() -> Vector3:
	return (get_node(ground_anchor_path) as Marker3D).global_position

func area_markers_valid() -> bool:
	return get_node_or_null(ground_anchor_path) is Marker3D and get_node_or_null(target_point_path) is Marker3D

func set_area_highlight(enabled: bool, friendly: bool = false, damage: int = 0) -> void:
	set_target_highlight(enabled, not friendly)
	health_label.font_size = 28 if enabled else 40
	if enabled and (is_alive() or (is_downed() and carried_by==null)):
		health_label.text = ("ALLY HIT" if friendly else "HIT") + " −%d" % damage
