class_name Might extends Status

#var member_var := 0
const ID = "might"

func init_status(target: Node) -> void:
	status_changed.connect(_on_status_changed.bind(target))
	_on_status_changed(target)

func _on_status_changed(target: Node) -> void:

	assert(target.get("modifier_system"), "No modifier on %s" % target)
	
	var dmg_dealt_modifier: Modifier = (target as Fighter).modifier_system.get_modifier(Modifier.Type.DMG_DEALT)
	assert(dmg_dealt_modifier, "No dmg dealt modifier on %s" % target)
	
	var modifier_value := dmg_dealt_modifier.get_value(ID)
	
	if !modifier_value:
		modifier_value = ModifierValue.create_new_modifier(ID, ModifierValue.Type.FLAT)
	
	modifier_value.flat_value = intensity
	dmg_dealt_modifier.add_new_value(modifier_value)
	
func get_tooltip() -> String:
	var base_tooltip: String = "Might: Deals %s additional damage."
	return base_tooltip % intensity
