class_name AbilityDefinition
extends AttackDefinition

# Inherit the exact range convention and obstruction configuration of attacks.
enum Effect { DAMAGE, HEAL, WARD, PULL, TOW }
enum Target { HOSTILE, FRIENDLY, GROUND }
@export var stable_id: String = ""
@export_multiline var description: String = ""
@export var effect: Effect = Effect.DAMAGE
@export var targeting: Target = Target.HOSTILE
@export_range(1, 999) var magnitude: int = 4
@export_range(0, 10) var cooldown_turns: int = 2
@export var applied_status: StatusEffectDefinition

@export_range(0.01, 20.0) var area_radius: float = 2.5
# Relative to caster, with self independent of the ally flag.
@export_flags("Hostiles", "Allies", "Caster") var affected_factions: int = 7
@export_flags_3d_physics var area_obstruction_mask: int = 8
@export_range(0.01, 1.0) var blast_origin_offset: float = 0.15

@export var telegraphed: bool = false

@export_range(0.0, 6.0) var displacement_distance: float = 0.0
