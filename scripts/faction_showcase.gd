extends Node3D
const FACTION_IDS: PackedStringArray = ["ashfang_raider","ashfang_shieldguard","ashfang_bowhunter","ashfang_shaman","ashfang_chieftain","hollow_gravebound","hollow_archer","hollow_adept","hollow_warden","hollow_castellan","verdant_thornblade","verdant_stalker","verdant_tender","verdant_sentinel","verdant_grovekeeper"]
## F6 review scene: view keys 1–4, clips Q/W/E/R/T/Y, Space autoplay.
var visuals: Array[CharacterVisual] = []
var camera: Camera3D
var caption: Label
var clip: String = "Idle"
var elapsed: float = 0.0
var automatic: bool = false
var view_index: int = 0
const CLIPS: PackedStringArray = ["Idle", "Walk", "Attack", "Cast", "Hit", "Death"]

func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.055, 0.075, 0.11)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.82, 1)
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -35, 0)
	key.light_energy = 1.5
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 135, 0)
	fill.light_color = Color(0.63, 0.78, 1)
	fill.light_energy = 0.7
	add_child(fill)
	for index in FACTION_IDS.size():
		var visual := CharacterVisual.new()
		add_child(visual)
		visual.position = Vector3((index % 5 - 2) * 2.65, 0, floori(index / 5.0) * 4.3)
		visual.load_role(FACTION_IDS[index])
		visuals.append(visual)
		var label := Label3D.new()
		label.text = role_marker(FACTION_IDS[index]) + " " + FACTION_IDS[index].get_slice("_", 1).capitalize()
		label.position = visual.position + Vector3(0, -0.15, -0.25)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 19
		label.pixel_size = 0.009
		add_child(label)
		var base := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.78
		mesh.bottom_radius = 0.83
		mesh.height = 0.10
		mesh.radial_segments = 12
		base.mesh = mesh
		base.position = visual.position - Vector3.UP * 0.05
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.13, 0.18, 0.23)
		base.material_override = material
		add_child(base)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.6
	set_view(0)
	var layer := CanvasLayer.new()
	add_child(layer)
	caption = Label.new()
	caption.position = Vector2(24, 18)
	caption.add_theme_font_size_override("font_size", 20)
	layer.add_child(caption)
	set_clip("Idle")

func set_view(index: int) -> void:
	view_index = index
	# Rotate each character together so every role is inspectable in each view.
	for visual in visuals:
		visual.rotation.y = [0.0, PI * 0.5, PI, 0.0][index]
	camera.position = Vector3(0, 14, -14) if index != 3 else Vector3(0, 20, -9)
	camera.look_at(Vector3(0, 0.95, 4.3))

func set_clip(value: String) -> void:
	clip = value
	elapsed = 0.0
	for visual in visuals:
		visual.reset_pose()
		visual.play_clip(clip, true)
	set_view(view_index)
	caption.text = "FACTION ROSTER  /  " + clip + "\n1 Front · 2 Side · 3 Rear · 4 Tactical\nQ Idle · W Walk · E Attack · R Cast/Heal · T Hit · Y Death · Space Cycle"

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		var key: Key = (event as InputEventKey).keycode
		if key >= KEY_1 and key <= KEY_4:
			set_view(key - KEY_1)
		var keys := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y]
		if keys.has(key):
			set_clip(CLIPS[keys.find(key)])
		if key == KEY_SPACE:
			automatic = not automatic

func _process(delta: float) -> void:
	elapsed += delta
	if automatic and elapsed > 2.8:
		set_clip(CLIPS[(CLIPS.find(clip) + 1) % CLIPS.size()])





func role_marker(id: String) -> String:
	var job: String = id.get_slice("_", 1)
	if job in ["shieldguard", "warden", "sentinel"]: return "[SHIELD]"
	if job in ["bowhunter", "archer", "stalker"]: return "[BOW]"
	if job in ["shaman", "adept", "tender"]: return "[STAFF]"
	if job in ["chieftain", "castellan", "grovekeeper"]: return "[CROWN]"
	return "[AXE]"
