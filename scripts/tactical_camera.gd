class_name TacticalCamera
extends Node3D

signal control_used(kind: String)
signal view_changed

@export var orbit_sensitivity: float = 0.006
@export var pan_speed: float = 12.0
var zoom_sensitivity: float = 1.0
var invert_x: bool = false
var invert_y: bool = false
var edge_scrolling: bool = false
var edge_speed: float = 1.0
var reduced_motion: bool = false
var shake_intensity: float = .45
var _impact_remaining: float = 0.0
var _impact_strength: float = 0.0
var _impact_clock: float = 0.0
var _framed: bool = false
var yaw: float = 0.0
var pitch: float = -0.9
var distance: float = 19.0
var pan_bounds: Vector2 = Vector2(20, 20)
var maximum_distance: float = 40.0
var focus_target: CombatUnit
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	add_to_group("preference_consumers")
	ControlBindings.ensure()
	process_mode=Node.PROCESS_MODE_ALWAYS
	_update_transform()

func select_unit(unit: CombatUnit) -> void:
	focus_target = unit

func _unhandled_input(event: InputEvent) -> void:
	var owner := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if owner!=null and owner.panel.visible: return
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("tactics_orbit"):
			if event.relative.length()>0: control_used.emit("orbit")
			yaw -= event.relative.x * orbit_sensitivity * (-1 if invert_x else 1)
			pitch = clampf(pitch - event.relative.y * orbit_sensitivity * (-1 if invert_y else 1), -1.4, -0.25)
		elif Input.is_action_pressed("tactics_pan_drag"):
			if event.relative.length()>0: control_used.emit("pan")
			var right := camera.global_basis.x
			var forward := Vector3.FORWARD.rotated(Vector3.UP, yaw)
			position += (-right * event.relative.x - forward * event.relative.y) * distance * 0.0015 * (pan_speed/12.0)
	if ControlBindings.pressed(event,"zoom_in"):
		control_used.emit("zoom")
		distance=clampf(distance*(1.0-.1*zoom_sensitivity),5.0,maximum_distance)
	elif ControlBindings.pressed(event,"zoom_out"):
		control_used.emit("zoom")
		distance=clampf(distance*(1.0+.1*zoom_sensitivity),5.0,maximum_distance)
	if ControlBindings.pressed(event,"focus") and is_instance_valid(focus_target):
		position = focus_target.global_position
		control_used.emit("focus")
	_update_transform()

func _process(delta: float) -> void:
	_impact_clock+=delta
	_impact_remaining=maxf(0,_impact_remaining-delta)
	if get_tree().paused: clear_impulse()
	var owner := get_tree().get_first_node_in_group("game_audio") as GameAudio
	if owner!=null and owner.panel.visible:
		_update_transform()
		return
	if get_viewport().gui_get_focus_owner()!=null and (Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_RIGHT)):
		_update_transform()
		return
	var direction := Vector3.ZERO
	if Input.is_action_pressed("tactics_pan_up"):
		direction.z -= 1.0
	if Input.is_action_pressed("tactics_pan_down"):
		direction.z += 1.0
	if Input.is_action_pressed("tactics_pan_left"):
		direction.x -= 1.0
	if Input.is_action_pressed("tactics_pan_right"):
		direction.x += 1.0
	if edge_scrolling and get_viewport().gui_get_hovered_control()==null:
		var mouse := get_viewport().get_mouse_position()
		var size := get_viewport().get_visible_rect().size
		if Rect2(Vector2.ZERO,size).has_point(mouse):
			direction.x+=edge_speed*((1.0 if mouse.x>size.x-12 else 0.0)-(1.0 if mouse.x<12 else 0.0))
			direction.z+=edge_speed*((1.0 if mouse.y>size.y-12 else 0.0)-(1.0 if mouse.y<12 else 0.0))
	if direction.length_squared()>0: control_used.emit("pan")
	position += direction.limit_length(maxf(1.0,edge_speed)).rotated(Vector3.UP, yaw) * pan_speed * delta
	position.x = clampf(position.x, -pan_bounds.x, pan_bounds.x)
	position.z = clampf(position.z, -pan_bounds.y, pan_bounds.y)
	_update_transform()

func _update_transform() -> void:
	rotation = Vector3(pitch, yaw, 0.0)
	camera.position = Vector3(0, 0, distance)
	if not reduced_motion and shake_intensity>0 and _impact_remaining>0:
		var envelope := pow(_impact_remaining/.22,2)*_impact_strength*shake_intensity
		camera.position+=Vector3(sin(_impact_clock*87),cos(_impact_clock*103)*.55,0)*envelope
	view_changed.emit()

func frame_arena(size: Vector2) -> void:
	pan_bounds = size * 0.5 + Vector2.ONE * 2
	maximum_distance = maxf(40.0, size.length() * 1.8)
	if reduced_motion and _framed: return
	_framed=true
	position = Vector3.ZERO
	yaw = 0.0
	pitch = -1.05
	# Reserve space for combat sidebars and the bottom action panel.
	var aspect := get_viewport().get_visible_rect().size.aspect()
	distance = minf(maximum_distance, maxf(size.x / (0.7 * aspect), size.y / 0.65))
	_update_transform()

func apply_preferences(owner: GameAudio) -> void:
	var data: Dictionary=owner.preferences.Camera
	orbit_sensitivity=.006*data.orbit
	pan_speed=12.0*data.pan
	zoom_sensitivity=data.zoom
	invert_x=data.invert_x; invert_y=data.invert_y
	shake_intensity=data.get("shake",.45)
	if data.reduced_motion or shake_intensity<=0: clear_impulse()
	edge_scrolling=data.edge; edge_speed=data.edge_speed; reduced_motion=data.reduced_motion

# Presentation-only displacement in camera-local XY. Base framing is untouched.
func impact_impulse(point: Vector3, strength: float) -> void:
	if reduced_motion or shake_intensity<=0 or get_tree().paused: return
	var attenuation := clampf(1.0-position.distance_to(point)/35.0,0,1)
	_impact_strength=minf(.16,maxf(_impact_strength*_impact_remaining/.22,strength*attenuation))
	_impact_remaining=.22

func clear_impulse() -> void:
	_impact_remaining=0
	_impact_strength=0
	if is_instance_valid(camera): camera.position=Vector3(0,0,distance)
