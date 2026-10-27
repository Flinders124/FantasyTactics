@static_unload
class_name OathUI
extends RefCounted
## Shared presentation only. Palette follows The Lantern Oath world materials.
const INK = Color("101e28")
const PANEL = Color("172d36")
const EDGE = Color("41606a")
const PAPER = Color("f2e5c9")
const MUTED = Color("b2c7c7")
const GOLD = Color("e8bc78")
const TEAL = Color("64c6bb")
const COPPER = Color("d98a67")
const CACHE_KEY: StringName = &"_oath_ui_assets"
static func _session_assets() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null: return {"symbols": {}}
	if not tree.root.has_meta(CACHE_KEY):
		var assets := {"symbols": {}}
		tree.root.set_meta(CACHE_KEY, assets)
		# The tree owns shared assets without retaining a static script graph.
		tree.root.tree_exiting.connect(func() -> void: assets.clear(), CONNECT_ONE_SHOT)
	return tree.root.get_meta(CACHE_KEY)
static func panel(accent: bool=false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=PANEL; s.border_color=GOLD if accent else EDGE
	s.set_border_width_all(1); s.border_width_left=3 if accent else 1
	s.set_corner_radius_all(2); s.corner_detail=1
	s.set_content_margin_all(14); s.shadow_color=Color(0,0,0,.24); s.shadow_size=6; s.shadow_offset=Vector2(0,3)
	return s
static func theme() -> Theme:
	var assets := _session_assets()
	var shared: Theme = assets.get("theme")
	if shared!=null: return shared
	shared=Theme.new(); assets["theme"]=shared; shared.default_font=ThemeDB.fallback_font; shared.default_font_size=17
	for type in ["Label","Button","OptionButton","CheckButton","CheckBox","LineEdit","TabContainer","TabBar","PopupMenu"]:
		shared.set_color("font_color",type,PAPER)
		shared.set_color("font_hover_color",type,PAPER)
		shared.set_color("font_pressed_color",type,PAPER)
		shared.set_color("font_focus_color",type,PAPER)
		shared.set_color("font_disabled_color",type,Color("809194"))
	var heading := FontVariation.new(); heading.base_font=ThemeDB.fallback_font; heading.variation_embolden=.5; heading.spacing_glyph=1
	shared.set_type_variation("OathHeading","Label"); shared.set_font("font","OathHeading",heading)
	for type in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","focus","disabled"]:
			var s := panel(state in ["focus","pressed"])
			s.set_content_margin_all(10); s.shadow_size=0
			if state=="hover": s.bg_color=Color("27454d");s.border_color=TEAL
			if state=="pressed": s.bg_color=Color("315650")
			if state=="focus": s.bg_color=Color(0,0,0,0);s.set_border_width_all(2)
			if state=="disabled": s.bg_color=Color("17242c");s.border_color=Color("2b3c44")
			shared.set_stylebox(state,type,s)
		shared.set_constant("h_separation",type,10)
		shared.set_constant("outline_size",type,0)
	for type in ["PanelContainer","Panel","PopupPanel"]: shared.set_stylebox("panel",type,panel())
	for state in ["normal","focus","read_only"]: shared.set_stylebox(state,"LineEdit",panel(state=="focus"))
	shared.set_color("caret_color","LineEdit",TEAL)
	shared.set_color("selection_color","LineEdit",Color("416d69"))
	shared.set_stylebox("panel","TabContainer",panel())
	for type in ["TabContainer","TabBar"]:
		for state in ["tab_selected","tab_unselected","tab_hovered","tab_disabled","tab_focus"]:
			shared.set_stylebox(state,type,panel(state in ["tab_selected","tab_focus"]))
		shared.set_color("font_selected_color",type,GOLD)
		shared.set_color("font_unselected_color",type,MUTED)
	shared.set_stylebox("panel","TooltipPanel",panel(true));shared.set_color("font_color","TooltipLabel",PAPER)
	shared.set_font_size("font_size","TooltipLabel",16)
	var track := panel();track.shadow_size=0;track.set_content_margin_all(0);track.bg_color=INK
	var fill := track.duplicate() as StyleBoxFlat;fill.bg_color=TEAL;fill.set_border_width_all(0)
	shared.set_stylebox("background","ProgressBar",track);shared.set_stylebox("fill","ProgressBar",fill)
	return shared
static func icon(id: String) -> Texture2D:
	var symbols: Dictionary = _session_assets()["symbols"]
	if not symbols.has(id): symbols[id]=load("res://assets/ui/"+id+".svg")
	return symbols[id]
static func decorate(button: Button,id: String) -> void:
	button.icon=icon(id);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",22)
static func reduced(node: Node) -> bool:
	var audio := node.get_tree().get_first_node_in_group("game_audio")
	return audio!=null and bool(audio.preferences.get("Camera",{}).get("reduced_motion",false))
static func reveal(node: Control) -> void:
	if not node.is_inside_tree(): return
	var previous: Tween=node.get_meta("oath_reveal") if node.has_meta("oath_reveal") else null
	if previous!=null and previous.is_valid(): previous.kill()
	node.modulate.a=1.0
	if reduced(node): return
	node.modulate.a=.45
	var tween:=node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	node.set_meta("oath_reveal",tween)
	tween.tween_property(node,"modulate:a",1.0,.14)


