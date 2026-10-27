class_name SettingsPresentation
extends RefCounted
## Cosmetic only: no definitions, collisions, navigation, RNG or transforms are edited.
static func apply_tree(node: Node,owner: Node) -> void:
	if node==owner: return
	var preferences: Dictionary=owner.get("preferences")
	var options: Dictionary=preferences.Accessibility
	var factor: float=options.ui_scale*(1.15 if options.large_text else 1.0)
	if node is Control and (node is Label or node is Button or node is RichTextLabel):
		var key := "normal_font_size" if node is RichTextLabel else "font_size"
		if not node.has_meta("settings_base_font"): node.set_meta("settings_base_font",node.get_theme_font_size(key))
		node.add_theme_font_size_override(key,roundi(float(node.get_meta("settings_base_font"))*(options.combat_text if node.get_meta("settings_combat_text",false) else factor)))
		if node is Button:
			if node.has_meta("binding_id"): node.text=str(node.get_meta("binding_caption"))+" [%s]"%ControlBindings.label(node.get_meta("binding_id"))
			if node.size_flags_horizontal & Control.SIZE_EXPAND: node.clip_text=true
			if not node.has_meta("settings_base_minimum"): node.set_meta("settings_base_minimum",node.custom_minimum_size)
			var minimum: Vector2=node.get_meta("settings_base_minimum")
			node.custom_minimum_size.y=maxf(minimum.y,minimum.y*options.ui_scale)
		if node is Label:
			node.add_theme_constant_override("outline_size",2 if options.high_contrast else 0)
			node.add_theme_color_override("font_outline_color",Color.BLACK)
	if node is Viewport:
		node.msaa_3d=[Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][preferences.Display.graphics]
	if node is DirectionalLight3D:
		node.shadow_enabled=preferences.Display.graphics>0 and node.get_meta("lantern_shadow_source",true)
	if node is MultiMeshInstance3D and node.get_meta("dressing_id","") in ["grass","fern","shrub","leaves"]:
		var density: float=[.35,.7,1.0][preferences.Display.graphics]
		node.multimesh.visible_instance_count=roundi(node.multimesh.instance_count*density)
	if node.is_in_group("combat_units"):
		var health := node.get("health_label") as Label3D
		if health==null: return
		health.outline_size=16 if options.high_contrast else 8
		health.no_depth_test=options.high_contrast
		var target := node.get("target_material") as StandardMaterial3D
		target.no_depth_test=options.high_contrast
		var indicator := node.get_node("ActiveIndicator") as MeshInstance3D
		if indicator.material_override==null: indicator.material_override=indicator.mesh.surface_get_material(0).duplicate()
		indicator.material_override.no_depth_test=options.high_contrast
	for child in node.get_children(): apply_tree(child,owner)
