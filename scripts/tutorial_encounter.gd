class_name TutorialEncounter
extends RefCounted
## Authored, validated teaching layout. No shared resources are modified.
const FIRST_DESTINATION: Vector3 = Vector3(-3,0,0)
const SECOND_DESTINATION: Vector3 = Vector3(-3,0,1)
static func configuration() -> EncounterConfiguration:
	var config := EncounterConfiguration.new()
	config.battlefield_seed=7001
	config.difficulty=config.difficulty.duplicate(true) as DifficultyDefinition
	config.difficulty.display_name="Training"
	config.enemies[0].maximum_health=10
	config.enemies[1].maximum_health=8
	config.generator_settings=BattlefieldSettings.new()
	config.generator_settings.opposing_separation=4.0
	config.generator_settings.detail_density=.55
	var layout := BattlefieldLayout.new()
	layout.original_seed=7001
	layout.arena_size=config.generator_settings.arena_size
	layout.hero_zone=Rect2(-7,-2,4,8)
	layout.enemy_zone=Rect2(-1.5,-2,4,8)
	layout.spawns=PackedVector3Array([Vector3(-5.8,0,0),Vector3(-5,0,4),Vector3(-1.5,0,0),Vector3(1,0,4)])
	layout.obstacle_centers=PackedVector3Array([Vector3(3,1,-5)])
	layout.obstacle_sizes=PackedVector3Array([Vector3(3,2,1.5)])
	config.layout=layout
	return config

static func valid_routes(layout: BattlefieldLayout,navigation: NavigationService) -> bool:
	var first := navigation.query_path(layout.spawns[0],FIRST_DESTINATION)
	var second := navigation.query_path(FIRST_DESTINATION,SECOND_DESTINATION)
	return first.valid() and second.valid() and first.distance+second.distance<=HeroCatalog.find("knight").movement_allowance-.1
