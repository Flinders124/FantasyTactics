class_name PartySelection
extends RefCounted

signal changed
var preview_seed: int = 1
var difficulty_index: int = 1
var seed_text: String = ""
var imported_configuration: EncounterConfiguration
var code_feedback: String = ""
var faction_choice: String = "random"
var elite_choice: bool = false
var preset_index: int = 0
var objective_index: int = 0
var selected: PackedStringArray = []
var feedback: String = "Choose two distinct companions."

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	preview_seed=rng.randi()

func toggle(id: String) -> bool:
	_invalidate()
	if HeroCatalog.find(id) == null:
		feedback = "Unknown companion."
		return false
	if selected.has(id):
		selected.remove_at(selected.find(id))
	elif selected.size() < 2:
		selected.append(id)
	else:
		feedback = "Party full — deselect a companion to choose another."
		changed.emit()
		return false
	feedback = "Party full — deselect a companion to choose another." if party_ready() else "Choose two distinct companions."
	changed.emit()
	return true

func party_ready() -> bool:
	return selected.size() == 2 and selected[0] != selected[1] and HeroCatalog.find(selected[0]) != null and HeroCatalog.find(selected[1]) != null

func clear() -> void:
	selected.clear()
	imported_configuration=null
	feedback = "Choose two distinct companions."
	changed.emit()

func validation_error() -> String:
	if not party_ready(): return "Choose exactly two distinct companions."
	if preset_index<0 or preset_index>2 or objective_index<0 or objective_index>2 or difficulty_index<0 or difficulty_index>2: return "Choose a supported battlefield, objective and difficulty."
	var difficulty := EncounterOptions.difficulties()[difficulty_index]
	if imported_configuration!=null and imported_configuration.difficulty.stable_id==difficulty.stable_id: difficulty=imported_configuration.difficulty
	if not difficulty.valid(): return "Selected difficulty has invalid tuning or an unsupported enemy roster."
	var settings := EncounterOptions.presets()[preset_index]
	if imported_configuration!=null and imported_configuration.generator_settings.preset_id==settings.preset_id: settings=imported_configuration.generator_settings
	if settings.generator_version!=2 or settings.preset_id not in ["open_courtyard","ruined_lanes","central_plaza"]: return "Selected battlefield version is unsupported."
	var value := seed_text.strip_edges()
	if not value.is_empty() and (not value.is_valid_int() or value.to_int()<0 or value.to_int()>4294967295 or value.length()>10): return "Seed: enter a whole number from 0 to 4294967295, or leave blank for random."
	return ""

func ready() -> bool:
	return validation_error().is_empty()

func _invalidate() -> void:
	if imported_configuration!=null:
		imported_configuration.layout=null
		imported_configuration.requested_attempt=0
	code_feedback=""

func edited() -> void:
	_invalidate()
	changed.emit()

func configuration(seed_value: int, open_settings: BattlefieldSettings = null) -> EncounterConfiguration:
	if not ready(): return null
	var config := imported_configuration.snapshot() as EncounterConfiguration if imported_configuration!=null else EncounterConfiguration.new()
	config.hero_ids=selected.duplicate()
	config.battlefield_seed=seed_text.strip_edges().to_int() if not seed_text.strip_edges().is_empty() else seed_value
	var preset := open_settings if preset_index==0 and open_settings!=null else EncounterOptions.presets()[preset_index]
	if imported_configuration==null or config.generator_settings.preset_id!=preset.preset_id: config.generator_settings=preset.duplicate(true) as BattlefieldSettings
	var objective := EncounterOptions.objectives()[objective_index]
	if imported_configuration==null or config.objective.stable_id!=objective.stable_id: config.objective=objective.duplicate(true) as ObjectiveDefinition
	var difficulty := EncounterOptions.difficulties()[difficulty_index]
	if imported_configuration==null or config.difficulty.stable_id!=difficulty.stable_id: config.difficulty=difficulty.duplicate(true) as DifficultyDefinition
	if imported_configuration==null:
		config.faction_id=faction_choice
		config.campaign_stage=3
		config.elite_encounter=elite_choice
	config.resolve_roster()
	return config

func populate(config: EncounterConfiguration) -> void:
	faction_choice=config.faction_id
	elite_choice=config.elite_encounter
	selected=config.hero_ids.duplicate()
	seed_text=str(config.battlefield_seed)
	for index in range(3):
		if EncounterOptions.presets()[index].preset_id==config.generator_settings.preset_id: preset_index=index
		if EncounterOptions.objectives()[index].stable_id==config.objective.stable_id: objective_index=index
		if EncounterOptions.difficulties()[index].stable_id==config.difficulty.stable_id: difficulty_index=index
	imported_configuration=config.snapshot() as EncounterConfiguration
	feedback="Setup restored. Adjust any selection, or start the same configuration."
	changed.emit()

func import_code(code: String) -> bool:
	var decoded := EncounterCode.decode(code)
	if decoded.configuration==null:
		code_feedback=decoded.error
		changed.emit()
		return false
	populate(decoded.configuration)
	code_feedback="Encounter code imported. This reconstructs setup, not combat progress."
	changed.emit()
	return true
