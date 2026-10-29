class_name CampOverview
extends Control
const ART = preload("res://scripts/lantern_art.gd")
## Scene-local camp presentation; selecting a location only requests an HQ page.
signal destination_selected(index: int)
const TITLES: PackedStringArray = ["Mission Board","Companions’ Tents","Training Yard","Armoury Tent","Commander’s Table"]
const PURPOSES: PackedStringArray = ["Choose a mission","Roster & recovery","Learn upgrades","Shop & equipment","Campaign history"]
const POINTS: Array[Vector3] = [Vector3(-6.4,0,4.6),Vector3(-7,0,-3.8),Vector3(6.5,0,-3.8),Vector3(7,0,4.6),Vector3(0,0,-8)]
var destinations: Array[Button] = []
var landmarks: Array[MeshInstance3D] = []
var view: SubViewport
var surface: SubViewportContainer
var camera: Camera3D
var stage: Node3D
var flame: MeshInstance3D
var caption: Label
var help: Label
var guides: Control
var host: Node
var interactive: bool = true:
	set(value):
		interactive=value
		# HQ pages fully cover the camp; resume its existing world on return.
		if view!=null: view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
		if stage!=null: stage.process_mode=Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
		layout_dirty=true
var layout_dirty: bool = true
var yaw: float = 0
var zoom: float = 1.0
var orbiting: bool = false
var hovered: int = -1
var clock: float = 0
var reduced_motion: bool = false
var reduced_effects: bool = false
var orbit_sensitivity: float = 1
var zoom_sensitivity: float = 1
var invert_x: float = 1
var preference_owner: Node

func setup(owner_screen: Node) -> void:
	host=owner_screen
	add_to_group("headquarters_camps")
	yaw=host.coordinator.camp_yaw; zoom=host.coordinator.camp_zoom
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	custom_minimum_size=Vector2(0,180)
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	surface=SubViewportContainer.new(); add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.stretch=true; surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	view=SubViewport.new(); view.name="CampWorld"; view.own_world_3d=true
	view.gui_disable_input=true; view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	surface.add_child(view)
	stage=Node3D.new(); view.add_child(stage)
	build_camp()
	guides=Control.new(); add_child(guides); guides.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	guides.mouse_filter=Control.MOUSE_FILTER_IGNORE; guides.draw.connect(draw_guides)
	for i in range(5):
		var button := Button.new(); button.name="CampDestination%d"%i
		button.text=TITLES[i]
		OathUI.decorate(button,["mission","roster","training","armoury","history"][i]); button.tooltip_text=PURPOSES[i]+" — select to open"
		button.add_theme_font_size_override("font_size",16)
		for state: String in ["normal","hover","focus"]:
			var style: StyleBoxFlat=host._style(state!="normal")
			style.set_content_margin_all(9)
			button.add_theme_stylebox_override(state,style)
		add_child(button); destinations.append(button)
		button.pressed.connect(func() -> void: select_destination(i))
		button.mouse_entered.connect(func() -> void: highlight(i))
		button.mouse_exited.connect(func() -> void: highlight(-1))
		button.focus_entered.connect(func() -> void: highlight(i))
		button.minimum_size_changed.connect(func() -> void: layout_dirty=true)
	caption=Label.new(); caption.text="THE WATCH ENCAMPMENT · Select a camp location"; caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size",16); caption.add_theme_color_override("font_color",MenuScreen.GOLD)
	caption.add_theme_constant_override("outline_size",4); caption.add_theme_color_override("font_outline_color",Color("142126"))
	add_child(caption); caption.position=Vector2(18,12)
	help=Label.new(); help.mouse_filter=Control.MOUSE_FILTER_IGNORE; help.add_theme_font_size_override("font_size",14)
	help.add_theme_constant_override("outline_size",4); help.add_theme_color_override("font_outline_color",Color.BLACK)
	add_child(help)
	gui_input.connect(handle_input)
	resized.connect(update_camera)
	add_to_group("preference_consumers")
	preference_owner=host.coordinator.flow.audio
	apply_preferences(preference_owner)
	update_camera()

func blocked() -> bool:
	if not interactive or not is_instance_valid(host): return true
	var flow: Node=host.coordinator.flow
	return flow.audio.editing or (is_instance_valid(flow.menu_guide) and flow.menu_guide.panel.visible)

func apply_preferences(owner: Node) -> void:
	layout_dirty=true
	var prefs: Dictionary=owner.preferences
	reduced_motion=prefs.Camera.reduced_motion; reduced_effects=prefs.Accessibility.reduced_effects
	orbit_sensitivity=prefs.Camera.orbit; zoom_sensitivity=prefs.Camera.zoom
	invert_x=-1 if prefs.Camera.invert_x else 1
	if help!=null:
		help.text="Drag %s to orbit · %s / %s zoom · Reset view below"%[ControlBindings.label("orbit"),ControlBindings.label("zoom_in"),ControlBindings.label("zoom_out")]
	if flame!=null: flame.visible=not reduced_effects

func build_camp() -> void:
	var kit := CampKit.new()
	var environment := WorldEnvironment.new(); environment.environment=Environment.new()
	var env := environment.environment
	env.background_mode=Environment.BG_COLOR; env.background_color=Color("344a53")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("a4bbc2"); env.ambient_light_energy=.42
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	stage.add_child(environment)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-48,-32,0); sun.light_color=Color("ffe0cf"); sun.light_energy=.9; sun.shadow_enabled=true
	sun.directional_shadow_max_distance=60; stage.add_child(sun)
	ART.lighting(environment,sun,false,true)
	var ground := CylinderMesh.new(); ground.top_radius=16; ground.bottom_radius=16.5; ground.height=.7; ground.radial_segments=64
	kit.piece(stage,ground,Vector3(0,-.38,0),CourtyardKit.earth_material())
	var path_material := CampKit.material(Color("8d8064"))
	# Radial worn paths meet a shared campfire clearing; all are cosmetic.
	var clearing := CylinderMesh.new(); clearing.top_radius=3.3; clearing.bottom_radius=3.3; clearing.height=.025; clearing.radial_segments=32
	kit.piece(stage,clearing,Vector3(0,-.005,1),path_material)
	preload("res://scripts/lantern_camp_dressing.gd").build(stage,POINTS)
	kit.tent(stage,Vector3(-7,0,-5),Color("638181"),.12)
	kit.tent(stage,Vector3(7,0,4),Color("966848"),-.17)
	kit.tent(stage,Vector3(0,0,-9),Color("5b6579"),0)
	kit.tent(stage,Vector3(-10.5,0,1),Color("82715d"),.65).scale=Vector3.ONE*.65
	kit.board(stage,POINTS[0])
	kit.table(stage,Vector3(0,0,-6.4))
	kit.rack(stage,Vector3(6,0,6.2))
	for at: Vector3 in [Vector3(5,0,-5),Vector3(7.2,0,-5.5),Vector3(9,0,-4.2)]: kit.dummy(stage,at)
	flame=kit.fire(stage,Vector3(0,0,1))
	var firelight := OmniLight3D.new(); firelight.position=Vector3(0,1.5,1); firelight.light_color=Color("ffc27c"); firelight.light_energy=.9; firelight.omni_range=5; stage.add_child(firelight)
	var people: PackedStringArray=host.coordinator.state.living_ids()
	var positions: Array[Vector3]=[Vector3(4.8,0,-2.8),Vector3(-5,0,4.8),Vector3(-1.9,0,-5.8),Vector3(-5.3,0,-2.8)]
	for index in range(mini(4,people.size())):
		var person: String=people[index]
		var character := CharacterVisual.new()
		character.name="Camp_"+person
		stage.add_child(character)
		character.load_role(host.coordinator.state.blueprint_id(person))
		character.position=positions[index]
		character.rotation.y=[.5,-1.1,-1.8,2.2][index]
	for data: Array in [["crate",Vector3(9,0,6.2)],["barrel",Vector3(9.6,0,5.5)],["bench",Vector3(-2.4,0,2.5)],["bench",Vector3(2.6,0,2.5)],["cart",Vector3(-10,0,7.5)]]:
		kit.piece(stage,CourtyardKit.mesh(data[0]),data[1],null)
	for i in range(5):
		var pick := StaticBody3D.new(); pick.position=POINTS[i]+Vector3.UP; pick.set_meta("camp_destination",i)
		var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size=Vector3(4,3,3.5); shape.shape=box; pick.add_child(shape); stage.add_child(pick)
		var ring := TorusMesh.new(); ring.inner_radius=1.65; ring.outer_radius=1.72; ring.rings=32; ring.ring_segments=6
		var marker := kit.piece(stage,ring,POINTS[i]+Vector3.UP*.07,CampKit.material(MenuScreen.GOLD))
		marker.visible=false; marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; landmarks.append(marker)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.near=.1; camera.far=100
	stage.add_child(camera); camera.current=true
	ART.theme_world(stage)

func update_camera() -> void:
	layout_dirty=true
	if camera==null: return
	var aspect := size.x/maxf(1,size.y)
	camera.size=maxf(19.5,29.5/maxf(.5,aspect))*zoom
	camera.position=Vector3(sin(yaw)*29,27,cos(yaw)*29)
	camera.look_at(Vector3(0,0,-.4))

func reset_view() -> void:
	yaw=0; zoom=1; orbiting=false; update_camera()
	host.coordinator.camp_yaw=yaw; host.coordinator.camp_zoom=zoom

func select_destination(index: int) -> void:
	if blocked() or index<0 or index>=5: return
	orbiting=false; destination_selected.emit(index)

func highlight(index: int) -> void:
	hovered=index if not blocked() else -1
	if guides!=null: guides.queue_redraw()
	for i in range(landmarks.size()): landmarks[i].visible=i==hovered
	if caption!=null: caption.text=(TITLES[hovered]+" · "+PURPOSES[hovered]) if hovered>=0 else "THE WATCH ENCAMPMENT · Select a camp location"

func pick_at(point: Vector2) -> int:
	var from := camera.project_ray_origin(point)
	var ray := PhysicsRayQueryParameters3D.create(from,from+camera.project_ray_normal(point)*100)
	var hit := stage.get_world_3d().direct_space_state.intersect_ray(ray)
	return int(hit.collider.get_meta("camp_destination",-1)) if not hit.is_empty() else -1

func handle_input(event: InputEvent) -> void:
	if blocked(): orbiting=false; return
	if ControlBindings.pressed(event,"orbit"):
		orbiting=true; accept_event(); return
	if event.is_action_released("tactics_orbit"):
		orbiting=false; accept_event(); return
	if ControlBindings.pressed(event,"zoom_in") or ControlBindings.pressed(event,"zoom_out"):
		zoom=clampf(zoom+(-.05 if ControlBindings.pressed(event,"zoom_in") else .05)*zoom_sensitivity,.86,1.15)
		host.coordinator.camp_zoom=zoom; update_camera(); accept_event(); return
	if event is InputEventMouseMotion:
		if orbiting:
			yaw=clampf(yaw-event.relative.x*.004*orbit_sensitivity*invert_x,-.48,.48)
			host.coordinator.camp_yaw=yaw; update_camera(); accept_event()
		else: highlight(pick_at(event.position))
	if event is InputEventMouseButton:
		if ControlBindings.pressed(event,"world"):
			select_destination(pick_at(event.position)); accept_event()

func _input(event: InputEvent) -> void:
	# A release can arrive over a projected button or outside the camp rectangle.
	if event.is_action_released("tactics_orbit"): orbiting=false

func _unhandled_input(event: InputEvent) -> void:
	# Camera bindings may be keyboard keys; GUI focus keeps menu keys first.
	if event is InputEventKey: handle_input(event)

func _process(delta: float) -> void:
	if not interactive: return
	var input_blocked := blocked()
	if input_blocked:
		orbiting=false
		if hovered!=-1: highlight(-1)
	clock+=delta
	if flame!=null and not reduced_motion and not reduced_effects and not input_blocked: flame.scale=Vector3(1,1+sin(clock*3.0)*.07,1)
	for button in destinations: button.disabled=input_blocked
	if not layout_dirty: return
	layout_dirty=false
	for i in range(destinations.size()):
		var button := destinations[i]
		var at := camera.unproject_position(POINTS[i]+Vector3.UP*3.3)
		at+=[Vector2(-55,25),Vector2(-85,0),Vector2(85,0),Vector2(55,25),Vector2(0,-52)][i]
		var extent := button.get_combined_minimum_size(); button.size=extent
		button.position=Vector2(clampf(at.x-extent.x*.5,8,maxf(8,size.x-extent.x-8)),clampf(at.y-extent.y*.5,40,maxf(40,size.y-extent.y-42)))
	# Preserve projected anchors, resolving overlap in stable front-to-back order.
	# This also handles the largest supported text setting and camera extremes.
	var placed: Array[Rect2] = []
	for index: int in [4,1,2,0,3]:
		var button := destinations[index]
		for rect in placed:
			if button.get_rect().grow(4).intersects(rect): button.position.y=rect.end.y+8
		placed.append(button.get_rect())
	if help!=null: help.position=Vector2(18,maxf(0,size.y-help.size.y-10))
	guides.queue_redraw()

func draw_guides() -> void:
	if camera==null or not interactive: return
	for i in range(destinations.size()):
		var button := destinations[i]
		var from := button.position+Vector2(button.size.x*.5,button.size.y)
		var to := camera.unproject_position(POINTS[i]+Vector3.UP*1.7)
		guides.draw_line(from,to,Color(.05,.08,.1,.8),4,true)
		guides.draw_line(from,to,MenuScreen.GOLD if hovered==i else Color(.8,.76,.61,.7),1.2,true)
		guides.draw_circle(to,3,MenuScreen.GOLD)
