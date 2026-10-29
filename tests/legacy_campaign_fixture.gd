class_name LegacyCampaignFixture
extends CampaignState
func _init(seed_number: int=1,difficulty_id_value: String="standard",definition: CampaignDefinition=null,restoring: bool=false) -> void:
	super(seed_number,difficulty_id_value,definition,true)
	if restoring: return
	threat=rules.threat_start; supplies=rules.starting_supplies
	for base in HeroCatalog.definitions():
		var id: String=base.selection_id
		heroes[id]={"id":id,"name":base.display_name,"specialisation":id,"legacy_specialist":true,"dead":false,"death_cause":"","trained":false,"missions_completed":0,"experience":0,"level":1,"upgrades":[],"injury":{},"equipment":{},"medical_at":-1}
		for item_id: String in [id+"_issue","watch_kit"]:
			var instance := create_item(item_id)
			heroes[id].equipment[item(item_id).slot]=instance
	generate_offers()
func configuration_for(chosen: Dictionary,party: PackedStringArray) -> EncounterConfiguration:
	var config := super(chosen,party)
	if config!=null: config.survival_enabled=false
	return config
