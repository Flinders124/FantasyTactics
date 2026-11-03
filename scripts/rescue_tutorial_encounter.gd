class_name RescueTutorialEncounter
extends RefCounted
const APPROACH_POINT := Vector3(-5.8,0,1.2)
const SAFE_POINT := Vector3(-3.5,0,1.2)
static func configuration() -> EncounterConfiguration:
 var config := TutorialEncounter.configuration()
 config.survival_enabled=true
 config.enemies[0].initiative=25
 config.enemies[0].abilities=[]
 return config

static func private_hero(base: UnitDefinition,index: int,attack_damage: int) -> UnitDefinition:
 var result := base.duplicate(true) as UnitDefinition
 if index==0:
  result.maximum_health=attack_damage
  result.initiative=4
 return result
