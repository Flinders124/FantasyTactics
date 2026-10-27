class_name CourtyardAtmosphere
extends RefCounted
const ART = preload("res://scripts/lantern_art.gd")
static func configure(environment_node: WorldEnvironment,sun: DirectionalLight3D) -> void:
	ART.lighting(environment_node,sun)