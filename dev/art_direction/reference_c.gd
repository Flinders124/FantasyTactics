extends "res://dev/art_direction/comparison.gd"
## Selected C reference. The original three-option lab remains untouched.
const REFERENCE_SHADER = preload("res://dev/art_direction/reference_surface.gdshader")
var reference_enabled: bool = true
var portrait_view: bool = false

func set_direction(_index: int) -> void:
	super.set_direction(2)
	if reference_enabled:
		title.text="C / THE LANTERN OATH"
		subtitle.text="Selected reference / copper light, teal armour, folded silhouettes"
	else:
		title.text="C / ORIGINAL EXPLORATION"
		subtitle.text="Baseline C / same camera, placements and pose"
	update_status()

func material(key: String,color: Color,metal: float=0.0,rough: float=.86,vertex: bool=false) -> ShaderMaterial:
	var m: ShaderMaterial = super.material(key,color,metal,rough,vertex)
	if not reference_enabled: return m
	m.shader=REFERENCE_SHADER
	var actor: bool = key.begins_with("character") or key in ["pauldron","trim","clasp","watch_emblem","brow"]
	m.set_shader_parameter("rim_strength",.17 if actor else 0.0)
	m.set_shader_parameter("surface_kind",1.0 if actor or "leaf" in key or "crown" in key or "banner" in key else 0.0)
	return m

func character_color(source: Color,name_hint: String,index: int) -> Color:
	var c: Color = super.character_color(source,name_hint,index)
	if not reference_enabled: return c
	if index==0:
		if name_hint=="steel": return Color("a0d3d3")
		if name_hint=="cloth": return Color("378b9b")
		if name_hint=="leather": return Color("354963")
	if index==1:
		if name_hint=="cloth": return Color("d66d58")
		if name_hint=="magic": return Color("ffdc9c")
	if index==4:
		return Color("d6e5a1") if source.v>.65 else Color("77b5a0") if source.v>.42 else Color("4b8589")
	return c

func configure_light() -> void:
	super.configure_light()
	if not reference_enabled: return
	sun.light_energy=1.08
	sun.light_color=Color("ffd0a1")
	sun.rotation_degrees=Vector3(-48,-40,0)
	environment_node.environment.ambient_light_color=Color("a2bad0")
	environment_node.environment.ambient_light_energy=.44
	environment_node.environment.fog_light_color=Color("7594a7")
	# A restrained cool fill separates shaded equipment; it casts no extra shadows.
	var fill := DirectionalLight3D.new();fill.name="ReferenceFill"
	fill.rotation_degrees=Vector3(-25,135,0);fill.light_color=Color("9ecbde");fill.light_energy=.22;fill.shadow_enabled=false
	stage.add_child(fill)

func build_arch(x: float) -> void:
	super.build_arch(x)
	if not reference_enabled: return
	# Repeat the Watch's lantern/diamond motif in architecture and equipment.
	for side in [-1.0,1.0]:
		var inlay := block(Vector3(x+side*2.47,.65,-6.045),Vector3(.09,1.55,.055),"gold")
		inlay.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var diamond := add_mesh(GEOMETRY.leaf(.32,.55,.06),Vector3(x+side*2.47,1.30,-5.99),material("watch_emblem",Color("e8bb81"),.55,.5))
		diamond.rotation.z=PI
		var relief := block(Vector3(x+side*2.47,.36,-6.02),Vector3(.36,.055,.07),"edge")
		relief.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Narrow copper returns make the chevrons feel like constructed masonry.
	for side in [-1.0,1.0]:
		var edge := block(Vector3(x+side*2.3,2.8,-6.91),Vector3(.055,3.25,.04),"gold")
		edge.rotation.z=side*.78
		edge.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func style_character(visual: CharacterVisual,index: int) -> void:
	super.style_character(visual,index)
	if not reference_enabled: return
	if index==0:
		var hand := BoneAttachment3D.new();hand.bone_name="L_hand";visual.skeleton.add_child(hand)
		var badge := add_mesh(GEOMETRY.leaf(.18,.30,.025),Vector3(-.01,.17,-.265),material("watch_emblem",Color("efc58a"),.65,.4),hand)
		badge.rotation.z=PI
		var crossbar := add_mesh(GEOMETRY.bevel_box(Vector3(.16,.025,.025),.005),Vector3(-.01,.03,-.285),material("watch_emblem",Color("efc58a"),.65,.4),hand)
		crossbar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func make_marker(index: int) -> void:
	super.make_marker(index)
	if not reference_enabled: return
	for child in marker_nodes[-1].get_children():
		if child is Label3D:
			child.font_size=32;child.pixel_size=.0065;child.modulate=Color("fff0d3")
			# Raise the baseline to clear enlarged hats and antlers in the focus view.
			child.position.y=2.7

func set_view(index: int) -> void:
	portrait_view=false
	super.set_view(index)

func focus_characters() -> void:
	portrait_view=true
	camera_rig.position=Vector3(-1.2,1.05,1.7)
	camera_rig.distance=8.5;camera_rig.pitch=-.30;camera_rig.yaw=.08
	camera_rig._update_transform()
	update_status()

func update_status() -> void:
	super.update_status()
	if status!=null:
		if portrait_view: status.text="CHARACTER FOCUS / 8.5 m / 55 deg FOV"
		status.text+=" / "+("REFERENCE" if reference_enabled else "BASELINE")

func make_ui() -> void:
	ui=CanvasLayer.new();add_child(ui)
	var panel := PanelContainer.new();panel.position=Vector2(24,22);ui.add_child(panel)
	var style := StyleBoxFlat.new();style.bg_color=Color(.035,.055,.085,.94);style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=12;style.content_margin_bottom=12;style.border_width_left=3;style.border_color=Color("efb875");panel.add_theme_stylebox_override("panel",style)
	var rows := VBoxContainer.new();rows.add_theme_constant_override("separation",7);panel.add_child(rows)
	var kicker := Label.new();kicker.text="THE LANTERN WATCH / SELECTED ART REFERENCE";kicker.add_theme_font_size_override("font_size",12);kicker.modulate=Color("efb875");rows.add_child(kicker)
	title=Label.new();title.add_theme_font_size_override("font_size",23);rows.add_child(title)
	subtitle=Label.new();subtitle.add_theme_font_size_override("font_size",13);subtitle.modulate=Color("b8c8cf");rows.add_child(subtitle)
	var buttons := HBoxContainer.new();rows.add_child(buttons)
	for i in 3:
		var button := Button.new();button.text=["G Tactical","D Ensemble","L Architecture"][i];button.pressed.connect(set_view.bind(i));buttons.add_child(button)
	var focus := Button.new();focus.text="F Characters";focus.pressed.connect(focus_characters);buttons.add_child(focus)
	var before := Button.new();before.text="B Before/After";before.pressed.connect(toggle_reference);buttons.add_child(before)
	status=Label.new();status.add_theme_font_size_override("font_size",12);status.modulate=Color("d5c6a7");rows.add_child(status)
	var footer := Label.new();footer.text="RMB orbit / MMB or arrows pan / Wheel zoom / Space animate / Q W E R T Y clips / H markers / F9 interface";footer.add_theme_font_size_override("font_size",14);footer.add_theme_constant_override("outline_size",5);footer.position=Vector2(24,get_viewport().get_visible_rect().size.y-32);ui.add_child(footer)
	get_viewport().size_changed.connect(func(): footer.position.y=get_viewport().get_visible_rect().size.y-32)

func toggle_reference() -> void:
	reference_enabled=not reference_enabled
	set_direction(2)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_B: toggle_reference();return
		if event.keycode==KEY_F: focus_characters();return
	super._unhandled_key_input(event)
