extends CombatEncounter
## Review the shipped generated environment, not a separate hand-built level.
var help: Label

func _ready() -> void:
	configuration=EncounterConfiguration.new()
	configuration.battlefield_seed=7
	configuration.hero_ids=["knight","mage"]
	$EnemyController.enabled=false
	await super._ready()
	if not navigation_ready: return
	$HUD.hide()
	$TacticalCamera.distance=30
	$TacticalCamera.pitch=-.82
	$TacticalCamera.yaw=.5
	$TacticalCamera._update_transform()
	var layer := CanvasLayer.new()
	add_child(layer)
	help=Label.new()
	help.position=Vector2(20,16)
	help.text="OVERGROWN COURTYARD · SEED 7\nRMB orbit · MMB/WASD pan · Wheel zoom · F8 rotate quarter turn · F9 combat HUD"
	help.add_theme_font_size_override("font_size",16)
	help.add_theme_color_override("font_outline_color",Color.BLACK)
	help.add_theme_constant_override("outline_size",4)
	help.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(help)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F8:
			$TacticalCamera.yaw+=PI*.5
			$TacticalCamera._update_transform()
			get_viewport().set_input_as_handled()
		elif event.keycode==KEY_F9:
			$HUD.visible=not $HUD.visible
			help.visible=not $HUD.visible
			get_viewport().set_input_as_handled()
