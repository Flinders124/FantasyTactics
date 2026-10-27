@static_unload
class_name EnemyCatalog
extends RefCounted
const VERSION: int = 1
const CACHE_KEY: StringName = &"_enemy_catalog_definitions"
static func _session_definitions() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null: return {}
	if not tree.root.has_meta(CACHE_KEY):
		var definitions := {}
		tree.root.set_meta(CACHE_KEY, definitions)
		# The tree owns the cache; a static cache retains its resource script graph.
		tree.root.tree_exiting.connect(func() -> void: definitions.clear(), CONNECT_ONE_SHOT)
	return tree.root.get_meta(CACHE_KEY)
static func ids() -> PackedStringArray:
	return ["ashfang_raider", "ashfang_shieldguard", "ashfang_bowhunter", "ashfang_shaman", "ashfang_chieftain", "hollow_gravebound", "hollow_archer", "hollow_adept", "hollow_warden", "hollow_castellan", "verdant_thornblade", "verdant_stalker", "verdant_tender", "verdant_sentinel", "verdant_grovekeeper"]
static func find(id: String) -> UnitDefinition:
	var definitions := _session_definitions()
	if definitions.has(id): return definitions[id]
	var definition:=_load_definition(id)
	if definition!=null: definitions[id]=definition
	return definition
static func _load_definition(id: String) -> UnitDefinition:
	if id=="raider": return load("res://definitions/enemy.tres") as UnitDefinition
	if id=="sentinel": return load("res://definitions/sentinel.tres") as UnitDefinition
	if id in ids(): return load("res://definitions/enemies/" + id + ".tres") as UnitDefinition
	return null
