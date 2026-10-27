class_name MovementMotor
extends Node

signal progress
signal completed(reason: String)
signal distance_advanced(unit: CombatUnit, metres: float)
@export_range(0.1, 20.0) var movement_speed: float = 3.0
@export_range(0.001, 0.1) var arrival_tolerance: float = 0.005
@export_range(0.1, 5.0) var blocked_timeout: float = 0.6
const NUMERICAL_TOLERANCE: float = 0.002
var actor: CombatUnit
var path: PackedVector3Array
var index: int = 0
var running: bool = false
var stalled_time: float = 0.0
var elapsed: float = 0.0
var maximum_duration: float = 0.0
var travelled_distance: float = 0.0
var _generation: int = 0

func start(unit: CombatUnit, approved_path: PackedVector3Array) -> void:
	_generation += 1
	actor = unit
	path = approved_path.duplicate()
	index = 1
	stalled_time = 0.0
	elapsed = 0.0
	travelled_distance = 0.0
	maximum_duration = NavigationService.path_length(path) / movement_speed * 3.0 + blocked_timeout
	running = true

func stop(reason: String) -> void:
	if not running:
		return
	_generation += 1
	running = false
	if is_instance_valid(actor):
		actor.velocity = Vector3.ZERO
	completed.emit(reason)

func _physics_process(delta: float) -> void:
	if not running:
		return
	if not is_instance_valid(actor) or not actor.is_alive():
		stop("Movement cancelled")
		return
	elapsed += delta
	if index >= path.size():
		stop("Destination reached")
		return
	var offset := path[index] - NavigationService.planar(actor.global_position)
	if offset.length() <= arrival_tolerance:
		index += 1
		if index >= path.size():
			stop("Destination reached")
		return
	if actor.movement_remaining <= 0.000001:
		stop("Movement allowance spent")
		return
	var step := minf(movement_speed * delta, minf(offset.length(), actor.movement_remaining))
	var before := actor.global_position
	var motion := offset.normalized() * step
	# A newly overlapping collider can add recovery displacement. Do not let that
	# recovery push a nearly exhausted unit beyond its remaining budget.
	var probe := actor.move_and_collide(motion, true, 0.0001)
	if probe != null and NavigationService.planar(probe.get_travel()).length() > actor.movement_remaining + NUMERICAL_TOLERANCE:
		stop("Movement blocked: collision recovery exceeds allowance")
		return
	actor.move_and_collide(motion, false, 0.0001)
	var travelled := NavigationService.planar(actor.global_position - before).length()
	travelled_distance += travelled
	actor.movement_remaining = maxf(0.0, actor.movement_remaining - travelled)
	var ticket := _generation
	progress.emit()
	if ticket != _generation or not running: return
	if travelled>0.0001:
		distance_advanced.emit(actor,travelled)
		if ticket != _generation or not running: return
	# Require meaningful progress and also enforce an overall bound for creeping collisions.
	stalled_time = stalled_time + delta if travelled < step * 0.1 else 0.0
	if stalled_time >= blocked_timeout or elapsed >= maximum_duration:
		stop("Movement blocked; travelled distance spent")
