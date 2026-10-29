extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var config := ConfigFile.new()
	check(config.load("res://export_presets.cfg") == OK, "Windows export preset exists")
	check(config.get_value("preset.0", "export_filter") == "all_resources", "String-loaded resources are retained")
	var exclusions: String = config.get_value("preset.0", "exclude_filter")
	for required in ["tests/*", "docs/*", "verification/*", "build/*", "assets/*/source/*", "scenes/*showcase*", "scripts/*showcase*"]:
		check(required in exclusions, "Authoring exclusion: " + required)
	for directory in ["res://definitions", "res://assets/characters/models", "res://assets/audio/clips", "res://assets/courtyard/meshes", "res://assets/courtyard/collision", "res://assets/courtyard/materials"]:
		check(DirAccess.dir_exists_absolute(directory), "Runtime resource directory: " + directory)
	check(config.get_value("preset.0.options", "binary_format/embed_pck") == false, "Separate PCK supports inspection and signing")
	check(ProjectSettings.get_setting("editor/export/convert_text_resources_to_binary",true)==false,"Preserve campaign PackedStringArray values in exported resources")
	check(ProjectSettings.get_setting("application/config/name") == "Fantasy Tactics", "Save location stays stable")
	check(FileAccess.file_exists("res://assets/branding/icon.ico"), "Native Windows icon exists")
	for notice in ["GODOT-LICENSE.txt", "GODOT-THIRD-PARTY.txt"]:
		check(FileAccess.file_exists("res://docs/licenses/"+notice), "Engine distribution notice: "+notice)
	print("EXPORT SCOPE RESULT: %d failures"%failures)
	quit(1 if failures else 0)




